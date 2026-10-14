//! The engine: accounts and their workers (connect, run pending operations, sync, wait with
//! IDLE), the outbox, and the operations behind every D-Bus method. Local changes are applied at
//! once and queued for the server, so the app never waits on the network.

use std::collections::{BTreeMap, HashMap};
use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::time::Duration;

use serde::{Deserialize, Serialize};
use serde_json::json;
use tokio::sync::{Mutex, Notify, mpsc};
use tracing::{info, warn};
use zbus::Connection;
use zbus::object_server::SignalEmitter;

use crate::config::{Account, AccountConfig};
use crate::dbus::{MailService, OBJECT_PATH};
use crate::error::{Error, Result};
use crate::imap::{self, Op, Session};
use crate::message;
use crate::secrets::Keyring;
use crate::smtp::{self, Draft, ReplyTo};
use crate::store::{Flags, Store};

/// How long to wait with IDLE before syncing again anyway.
const IDLE_TIMEOUT: Duration = Duration::from_secs(25 * 60);
/// How often to poll servers without IDLE.
const POLL: Duration = Duration::from_secs(5 * 60);
/// First wait after a failed connection; doubles up to `MAX_BACKOFF`.
const FIRST_BACKOFF: Duration = Duration::from_secs(15);
const MAX_BACKOFF: Duration = Duration::from_secs(10 * 60);
/// A pending server operation is dropped after this many refusals.
const MAX_ATTEMPTS: i64 = 5;
const MAX_LIST: usize = 500;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Wake {
    Sync,
    Stop,
}

struct Worker {
    wake: mpsc::UnboundedSender<Wake>,
}

pub struct Engine {
    store: Store,
    keyring: Keyring,
    conn: Connection,
    data_dir: PathBuf,
    workers: Mutex<HashMap<String, Worker>>,
    outbox: Notify,
}

#[derive(Debug, Deserialize)]
struct ListQuery {
    mailbox: String,
    #[serde(default)]
    offset: usize,
    #[serde(default = "default_limit")]
    limit: usize,
    #[serde(default)]
    threads: bool,
}

fn default_limit() -> usize {
    50
}

#[derive(Serialize)]
struct AccountView<'a> {
    id: &'a str,
    name: &'a str,
    address: &'a str,
    provider: &'a str,
    state: &'a str,
}

fn parse_id(id: &str) -> Result<i64> {
    id.trim()
        .parse::<i64>()
        .map_err(|_| Error::Invalid(format!("\"{id}\" is not an id")))
}

fn parse_ids(json: &str) -> Result<Vec<i64>> {
    let ids: Vec<serde_json::Value> = serde_json::from_str(json)?;
    ids.iter()
        .take(10_000)
        .map(|v| match v {
            serde_json::Value::String(s) => parse_id(s),
            serde_json::Value::Number(n) => n
                .as_i64()
                .ok_or_else(|| Error::Invalid("an id is not valid".into())),
            _ => Err(Error::Invalid("ids must be strings".into())),
        })
        .collect()
}

fn ids_json(ids: &[i64]) -> String {
    serde_json::to_string(&ids.iter().map(i64::to_string).collect::<Vec<_>>())
        .unwrap_or_else(|_| "[]".into())
}

fn now() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| i64::try_from(d.as_secs()).unwrap_or(i64::MAX))
        .unwrap_or(0)
}

impl Engine {
    pub fn new(conn: Connection, data_dir: PathBuf) -> Result<Engine> {
        let store = Store::open(&data_dir)?;
        std::fs::create_dir_all(data_dir.join("sent"))?;
        Ok(Engine {
            store,
            keyring: Keyring::new(conn.clone()),
            conn,
            data_dir,
            workers: Mutex::new(HashMap::new()),
            outbox: Notify::new(),
        })
    }

    pub fn store(&self) -> &Store {
        &self.store
    }

    /// Starts a worker per account and the outbox.
    pub async fn start(self: &Arc<Self>) -> Result<()> {
        for (account, _) in self.store.accounts()? {
            self.spawn_worker(&account.id).await;
        }
        let engine = Arc::clone(self);
        tokio::spawn(async move { engine.run_outbox().await });
        Ok(())
    }

    /// Stops every worker (the process is about to exit, or a test is done).
    pub async fn shutdown(&self) {
        for (_, worker) in self.workers.lock().await.drain() {
            let _ = worker.wake.send(Wake::Stop);
        }
    }

    // Signals.

    fn emitter(&self) -> Option<SignalEmitter<'_>> {
        SignalEmitter::new(&self.conn, OBJECT_PATH).ok()
    }

    async fn accounts_changed(&self) {
        if let Some(e) = self.emitter() {
            let _ = MailService::accounts_changed(&e).await;
        }
    }

    async fn mailboxes_changed(&self, account: &str) {
        if let Some(e) = self.emitter() {
            let _ = MailService::mailboxes_changed(&e, account).await;
        }
    }

    async fn messages_changed(
        &self,
        mailbox: i64,
        added: &[i64],
        removed: &[i64],
        changed: &[i64],
    ) {
        if added.is_empty() && removed.is_empty() && changed.is_empty() {
            return;
        }
        if let Some(e) = self.emitter() {
            let _ = MailService::messages_changed(
                &e,
                &mailbox.to_string(),
                &ids_json(added),
                &ids_json(removed),
                &ids_json(changed),
            )
            .await;
        }
    }

    async fn sync_state(&self, account: &str, state: &str, error: &str) {
        let _ = self.store.set_account_state(account, state);
        if let Some(e) = self.emitter() {
            let _ = MailService::sync_state(&e, account, state, error).await;
        }
    }

    // Accounts.

    pub fn list_accounts(&self) -> Result<String> {
        let accounts = self.store.accounts()?;
        let views: Vec<AccountView<'_>> = accounts
            .iter()
            .map(|(a, state)| AccountView {
                id: &a.id,
                name: &a.name,
                address: &a.address,
                provider: &a.provider,
                state,
            })
            .collect();
        Ok(serde_json::to_string(&views)?)
    }

    pub async fn discover(&self, address: &str) -> Result<String> {
        let config = crate::autoconfig::discover(address).await?;
        Ok(serde_json::to_string(&config)?)
    }

    pub async fn add_account(self: &Arc<Self>, config_json: &str) -> Result<String> {
        let config: AccountConfig = serde_json::from_str(config_json)?;
        let (imap_server, smtp_server) = config.validate()?;
        let password = config
            .password
            .clone()
            .filter(|p| !p.is_empty())
            .ok_or_else(|| Error::Invalid("the password is missing".into()))?;
        // The servers must accept the credentials before anything is kept.
        let mut session = imap::connect(imap_server, config.login_name(), &password).await?;
        let _ = tokio::time::timeout(Duration::from_secs(10), session.logout()).await;
        let id = uuid::Uuid::new_v4().simple().to_string();
        let account = Account {
            id: id.clone(),
            name: if config.name.is_empty() {
                config.address.clone()
            } else {
                config.name.clone()
            },
            address: config.address.clone(),
            provider: crate::config::provider_of(&imap_server.host),
            imap: imap_server.clone(),
            smtp: smtp_server.clone(),
            username: config.login_name().to_owned(),
        };
        self.keyring.store(&id, &account.address, &password).await?;
        self.store.add_account(&account)?;
        info!("account {id} added ({})", account.provider);
        self.spawn_worker(&id).await;
        self.accounts_changed().await;
        Ok(id)
    }

    pub async fn remove_account(&self, id: &str) -> Result<()> {
        self.store.account(id)?;
        if let Some(worker) = self.workers.lock().await.remove(id) {
            let _ = worker.wake.send(Wake::Stop);
        }
        if let Err(err) = self.keyring.delete(id).await {
            warn!("account {id}: the password could not be removed from the keyring: {err}");
        }
        self.store.remove_account(id)?;
        self.accounts_changed().await;
        Ok(())
    }

    pub async fn sync(&self, account: &str) -> Result<()> {
        self.store.account(account)?;
        self.wake(account).await;
        Ok(())
    }

    async fn wake(&self, account: &str) {
        if let Some(worker) = self.workers.lock().await.get(account) {
            let _ = worker.wake.send(Wake::Sync);
        }
    }

    // Reading.

    pub fn list_mailboxes(&self, account: &str) -> Result<String> {
        self.store.account(account)?;
        Ok(serde_json::to_string(&self.store.mailbox_views(account)?)?)
    }

    pub fn list_messages(&self, query: &str) -> Result<String> {
        let q: ListQuery = serde_json::from_str(query)?;
        let mailbox = parse_id(&q.mailbox)?;
        self.store.mailbox(mailbox)?;
        let list = self
            .store
            .list(mailbox, q.offset, q.limit.min(MAX_LIST), q.threads)?;
        Ok(serde_json::to_string(&list)?)
    }

    pub fn get_message(&self, id: &str) -> Result<String> {
        let id = parse_id(id)?;
        let location = self.store.location(id)?;
        let raw = self.store.raw(id)?;
        let detail = message::detail(&raw, location.date)
            .ok_or_else(|| Error::NotFound(format!("a readable body for message {id}")))?;
        let mut value = serde_json::to_value(&detail)?;
        if let Some(map) = value.as_object_mut() {
            map.insert("id".into(), json!(id.to_string()));
            map.insert("flags".into(), json!(location.flags.names()));
        }
        Ok(value.to_string())
    }

    pub fn save_attachment(&self, message_id: &str, attachment: &str, path: &str) -> Result<()> {
        let id = parse_id(message_id)?;
        let index: usize = attachment
            .trim()
            .parse()
            .map_err(|_| Error::Invalid(format!("\"{attachment}\" is not an attachment id")))?;
        let target = Path::new(path);
        if !target.is_absolute() || target.is_dir() {
            return Err(Error::Invalid(format!("{path} is not a file path")));
        }
        let raw = self.store.raw(id)?;
        let (_, bytes) = message::attachment(&raw, index)
            .ok_or_else(|| Error::NotFound(format!("attachment {index} of message {id}")))?;
        let tmp = target.with_extension("silica-mail-part");
        std::fs::write(&tmp, &bytes)?;
        std::fs::rename(&tmp, target)?;
        Ok(())
    }

    pub fn search(&self, query: &str) -> Result<String> {
        Ok(ids_json(&self.store.search(query, 1000)?))
    }

    // Changing messages.

    pub async fn set_flags(&self, ids: &str, add: &str, remove: &str) -> Result<()> {
        let ids = parse_ids(ids)?;
        let add: Vec<String> = serde_json::from_str(add)?;
        let remove: Vec<String> = serde_json::from_str(remove)?;
        let mut groups: BTreeMap<(String, i64, String), Vec<u32>> = BTreeMap::new();
        let mut changed: BTreeMap<i64, Vec<i64>> = BTreeMap::new();
        for id in ids {
            let loc = self.store.location(id)?;
            let flags = loc.flags.apply(&add, &remove);
            if self.store.set_flags(id, flags)? {
                changed.entry(loc.mailbox).or_default().push(id);
            }
            groups
                .entry((loc.account.clone(), loc.mailbox, loc.mailbox_name.clone()))
                .or_default()
                .push(loc.uid);
        }
        let mut accounts = Vec::new();
        for ((account, _, mailbox), uids) in groups {
            let op = Op::SetFlags {
                mailbox,
                uids,
                add: add.clone(),
                remove: remove.clone(),
            };
            self.store
                .push_pending(&account, &serde_json::to_string(&op)?)?;
            accounts.push(account);
        }
        for (mailbox, ids) in &changed {
            self.messages_changed(*mailbox, &[], &[], ids).await;
        }
        for account in accounts {
            self.mailboxes_changed(&account).await;
            self.wake(&account).await;
        }
        Ok(())
    }

    pub async fn move_messages(&self, ids: &str, mailbox: &str) -> Result<()> {
        let target = self.store.mailbox(parse_id(mailbox)?)?;
        if !target.selectable {
            return Err(Error::Invalid("messages cannot be moved there".into()));
        }
        self.relocate(&parse_ids(ids)?, |loc| {
            if loc.account != target.account {
                return Err(Error::Invalid(
                    "messages can only be moved within their account".into(),
                ));
            }
            Ok((loc.mailbox != target.id).then(|| target.name.clone()))
        })
        .await
    }

    pub async fn delete(&self, ids: &str) -> Result<()> {
        let ids = parse_ids(ids)?;
        let mut trash: HashMap<String, Option<String>> = HashMap::new();
        for id in &ids {
            let loc = self.store.location(*id)?;
            if !trash.contains_key(&loc.account) {
                let t = self
                    .store
                    .mailbox_by_role(&loc.account, "trash")?
                    .map(|m| m.name);
                trash.insert(loc.account.clone(), t);
            }
        }
        self.relocate(&ids, |loc| {
            // In the Trash (or without one) deleting is for good: `None` means expunge.
            match trash.get(&loc.account).cloned().flatten() {
                Some(t) if loc.role != "trash" => Ok(Some(t)),
                _ => Ok(None),
            }
        })
        .await
    }

    /// Moves (Some(target name)) or expunges (None) messages: locally at once, on the server by
    /// pending operations.
    async fn relocate(
        &self,
        ids: &[i64],
        target: impl Fn(&crate::store::Location) -> Result<Option<String>>,
    ) -> Result<()> {
        // (account, mailbox id, mailbox name, target) → (message id, uid).
        type Group = (String, i64, String, Option<String>);
        let mut groups: BTreeMap<Group, Vec<(i64, u32)>> = BTreeMap::new();
        for id in ids {
            let loc = self.store.location(*id)?;
            let to = target(&loc)?;
            if to.as_deref() == Some(loc.mailbox_name.as_str()) {
                continue;
            }
            groups
                .entry((
                    loc.account.clone(),
                    loc.mailbox,
                    loc.mailbox_name.clone(),
                    to,
                ))
                .or_default()
                .push((*id, loc.uid));
        }
        let mut accounts = Vec::new();
        for ((account, mailbox_id, mailbox, to), items) in groups {
            let uids: Vec<u32> = items.iter().map(|(_, uid)| *uid).collect();
            let local: Vec<i64> = items.iter().map(|(id, _)| *id).collect();
            let op = match to {
                Some(to) => Op::Move { mailbox, uids, to },
                None => Op::Expunge { mailbox, uids },
            };
            self.store
                .push_pending(&account, &serde_json::to_string(&op)?)?;
            self.store.delete_messages(&local)?;
            self.messages_changed(mailbox_id, &[], &local, &[]).await;
            accounts.push(account);
        }
        accounts.dedup();
        for account in accounts {
            self.mailboxes_changed(&account).await;
            self.wake(&account).await;
        }
        Ok(())
    }

    // Sending.

    pub async fn send(&self, draft_json: &str) -> Result<String> {
        let draft: Draft = serde_json::from_str(draft_json)?;
        draft.validate()?;
        self.store.account(&draft.account)?;
        let id = self.store.queue_outgoing(&draft.account, draft_json)?;
        self.outbox.notify_one();
        Ok(id.to_string())
    }

    async fn run_outbox(self: Arc<Self>) {
        loop {
            if let Err(err) = self.send_due().await {
                warn!("outbox: {err}");
            }
            let _ = tokio::time::timeout(Duration::from_secs(60), self.outbox.notified()).await;
        }
    }

    async fn send_due(&self) -> Result<()> {
        for queued in self.store.due_outgoing(now())? {
            let Ok(account) = self.store.account(&queued.account) else {
                self.store.sent(queued.id)?;
                continue;
            };
            match self.send_one(&account, &queued.draft, queued.id).await {
                Ok(()) => self.store.sent(queued.id)?,
                Err(err @ Error::Invalid(_)) => {
                    warn!("outbox {}: dropped: {err}", queued.id);
                    self.store.sent(queued.id)?;
                    self.sync_state(
                        &account.id,
                        "error",
                        &format!("a message could not be sent: {err}"),
                    )
                    .await;
                }
                Err(err) => {
                    let delay = 60_i64
                        .saturating_mul(1_i64 << queued.attempts.clamp(0, 6))
                        .min(3600);
                    self.store.send_failed(
                        queued.id,
                        &err.to_string(),
                        now().saturating_add(delay),
                    )?;
                    self.sync_state(&account.id, "error", &format!("sending: {err}"))
                        .await;
                }
            }
        }
        Ok(())
    }

    async fn send_one(&self, account: &Account, draft_json: &str, outbox_id: i64) -> Result<()> {
        let draft: Draft = serde_json::from_str(draft_json)?;
        let replied = match draft.in_reply_to.as_deref() {
            Some(id) => self.store.location(parse_id(id)?).ok(),
            None => None,
        };
        let reply = replied.as_ref().map(|loc| ReplyTo {
            message_id: loc.message_id.clone(),
            references: loc.references.clone(),
        });
        let message = smtp::build(account, &draft, reply.as_ref())?;
        let password = self.keyring.get(&account.id).await?;
        smtp::send(account, &password, &message).await?;
        info!("outbox {outbox_id}: sent");
        // A copy in Sent (servers like Gmail keep it themselves).
        if account.provider != "gmail.com"
            && let Some(sent) = self.store.mailbox_by_role(&account.id, "sent")?
        {
            let path = self.data_dir.join("sent").join(format!("{outbox_id}.eml"));
            std::fs::write(&path, message.formatted())?;
            let op = Op::Append {
                mailbox: sent.name,
                path: path.to_string_lossy().into_owned(),
            };
            self.store
                .push_pending(&account.id, &serde_json::to_string(&op)?)?;
        }
        if let Some(loc) = replied {
            let flags = Flags {
                answered: true,
                ..loc.flags
            };
            if self.store.set_flags(loc.id, flags)? {
                self.messages_changed(loc.mailbox, &[], &[], &[loc.id])
                    .await;
            }
            let op = Op::SetFlags {
                mailbox: loc.mailbox_name,
                uids: vec![loc.uid],
                add: vec!["answered".into()],
                remove: Vec::new(),
            };
            self.store
                .push_pending(&account.id, &serde_json::to_string(&op)?)?;
        }
        self.wake(&account.id).await;
        Ok(())
    }

    // Workers.

    async fn spawn_worker(self: &Arc<Self>, account: &str) {
        let (tx, rx) = mpsc::unbounded_channel();
        let engine = Arc::clone(self);
        let id = account.to_owned();
        tokio::spawn(async move { engine.run_worker(id, rx).await });
        if let Some(old) = self
            .workers
            .lock()
            .await
            .insert(account.to_owned(), Worker { wake: tx })
        {
            let _ = old.wake.send(Wake::Stop);
        }
    }

    async fn run_worker(self: Arc<Self>, id: String, mut rx: mpsc::UnboundedReceiver<Wake>) {
        let mut backoff = FIRST_BACKOFF;
        loop {
            let Ok(account) = self.store.account(&id) else {
                return;
            };
            self.sync_state(&id, "connecting", "").await;
            let session = match self.keyring.get(&id).await {
                Ok(password) => imap::connect(&account.imap, &account.username, &password).await,
                Err(err) => Err(err),
            };
            let mut session = match session {
                Ok(s) => s,
                Err(err) => {
                    self.sync_state(&id, "error", &err.to_string()).await;
                    if let Ok(Some(Wake::Stop) | None) =
                        tokio::time::timeout(backoff, rx.recv()).await
                    {
                        return;
                    }
                    backoff = (backoff * 2).min(MAX_BACKOFF);
                    continue;
                }
            };
            backoff = FIRST_BACKOFF;
            // Connected: sync, then wait for news; a failure reconnects.
            loop {
                self.sync_state(&id, "syncing", "").await;
                if let Err(err) = self.sync_account(&mut session, &id).await {
                    self.sync_state(&id, "error", &err.to_string()).await;
                    break;
                }
                self.sync_state(&id, "idle", "").await;
                match self.wait(session, &id, &mut rx).await {
                    (Some(s), Wake::Sync) => session = s,
                    (_, Wake::Stop) => return,
                    (None, Wake::Sync) => break,
                }
            }
        }
    }

    /// Waits for server news (IDLE on the inbox) or a wake-up; the session comes back if it is
    /// still usable.
    async fn wait(
        &self,
        mut session: Session,
        account: &str,
        rx: &mut mpsc::UnboundedReceiver<Wake>,
    ) -> (Option<Session>, Wake) {
        let idle_capable =
            match tokio::time::timeout(Duration::from_secs(30), session.capabilities()).await {
                Ok(Ok(caps)) => caps.has_str("IDLE"),
                _ => return (None, Wake::Sync),
            };
        let inbox = self.store.mailbox_by_role(account, "inbox").ok().flatten();
        let (Some(inbox), true) = (inbox, idle_capable) else {
            return match tokio::time::timeout(POLL, rx.recv()).await {
                Ok(Some(Wake::Stop) | None) => (Some(session), Wake::Stop),
                _ => (Some(session), Wake::Sync),
            };
        };
        if tokio::time::timeout(Duration::from_secs(60), session.select(&inbox.name))
            .await
            .is_err()
        {
            return (None, Wake::Sync);
        }
        let mut handle = session.idle();
        if tokio::time::timeout(Duration::from_secs(60), handle.init())
            .await
            .map_or(true, |r| r.is_err())
        {
            return (None, Wake::Sync);
        }
        let wake = {
            let (news, stop) = handle.wait_with_timeout(IDLE_TIMEOUT);
            tokio::pin!(news);
            tokio::select! {
                _ = &mut news => Wake::Sync,
                woken = rx.recv() => {
                    drop(stop);
                    match woken {
                        Some(Wake::Sync) => Wake::Sync,
                        Some(Wake::Stop) | None => Wake::Stop,
                    }
                }
            }
        };
        match tokio::time::timeout(Duration::from_secs(60), handle.done()).await {
            Ok(Ok(session)) => (Some(session), wake),
            _ => (None, wake),
        }
    }

    /// Runs the pending operations, then syncs mailboxes and messages.
    async fn sync_account(&self, session: &mut Session, account: &str) -> Result<()> {
        for (pending, op_json, attempts) in self.store.pending(account)? {
            let Ok(op) = serde_json::from_str::<Op>(&op_json) else {
                self.store.remove_pending(pending)?;
                continue;
            };
            match imap::run(session, &op).await {
                Ok(()) => self.store.remove_pending(pending)?,
                Err(err @ (Error::Io(_) | Error::Timeout(_))) => return Err(err),
                Err(err) => {
                    if attempts + 1 >= MAX_ATTEMPTS {
                        warn!("account {account}: giving up on {op:?}: {err}");
                        self.store.remove_pending(pending)?;
                    } else {
                        self.store.bump_pending(pending)?;
                    }
                }
            }
        }
        let caps = tokio::time::timeout(Duration::from_secs(30), session.capabilities())
            .await
            .map_err(|_| Error::Timeout("capabilities"))??;
        let condstore = caps.has_str("CONDSTORE");
        let mut changed = imap::sync_mailboxes(session, &self.store, account).await?;
        let mut boxes = self.store.mailboxes(account)?;
        boxes.sort_by_key(|m| if m.role == "inbox" { 0 } else { 1 });
        for mailbox in boxes.into_iter().filter(|m| m.selectable) {
            let changes = imap::sync_mailbox(session, &self.store, mailbox.id, condstore).await?;
            if !changes.is_empty() {
                changed = true;
                self.messages_changed(
                    mailbox.id,
                    &changes.added,
                    &changes.removed,
                    &changes.changed,
                )
                .await;
            }
        }
        if changed {
            self.mailboxes_changed(account).await;
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ids() {
        assert_eq!(parse_ids(r#"["1", 2, " 3 "]"#).unwrap(), vec![1, 2, 3]);
        assert!(parse_ids(r#"["x"]"#).is_err());
        assert!(parse_ids(r#"[true]"#).is_err());
        assert!(parse_ids("not json").is_err());
        assert_eq!(ids_json(&[4, 5]), r#"["4","5"]"#);
    }
}
