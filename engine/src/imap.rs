//! IMAP: connecting (TLS, STARTTLS, loopback plain), listing mailboxes, incremental sync
//! (UIDVALIDITY/UIDNEXT, CONDSTORE when the server has it), and the operations the app asks for
//! (flags, move, delete, append). Every network step has a timeout; servers are not trusted
//! (sizes are bounded, names are quoted, nothing panics).

use std::collections::{HashMap, HashSet};
use std::time::Duration;

use async_imap::types::{Fetch, Flag, NameAttribute};
use async_imap::{Client, Session as ImapSession};
use futures::TryStreamExt;
use serde::{Deserialize, Serialize};

use crate::config::{Server, Tls};
use crate::error::{Error, Result};
use crate::message;
use crate::net::{self, MailStream};
use crate::store::{Flags, Store};

pub type Session = ImapSession<MailStream>;

/// One IMAP command (or one batch of fetches).
const COMMAND_TIMEOUT: Duration = Duration::from_secs(120);
/// Messages fetched per batch.
const FETCH_BATCH: usize = 25;
/// Messages bigger than this keep only their headers locally.
const MAX_MESSAGE: u32 = 32 * 1024 * 1024;
/// On the first sync of a mailbox only the newest messages are fetched.
const FIRST_SYNC: usize = 2000;

async fn timed<T>(
    what: &'static str,
    fut: impl std::future::Future<Output = Result<T>>,
) -> Result<T> {
    tokio::time::timeout(COMMAND_TIMEOUT, fut)
        .await
        .map_err(|_| Error::Timeout(what))?
}

/// Quotes a mailbox name for a command; refuses names that cannot be quoted safely.
pub fn quote(name: &str) -> Result<String> {
    if name.chars().any(|c| c == '\r' || c == '\n' || c == '\0') || name.len() > 1024 {
        return Err(Error::Invalid(format!(
            "mailbox name {name:?} is not valid"
        )));
    }
    Ok(format!(
        "\"{}\"",
        name.replace('\\', "\\\\").replace('"', "\\\"")
    ))
}

/// A UID set in IMAP syntax, with ranges: `[1, 2, 3, 7]` → `1:3,7`.
pub fn uid_set(uids: &[u32]) -> String {
    let mut sorted: Vec<u32> = uids.to_vec();
    sorted.sort_unstable();
    sorted.dedup();
    let mut parts: Vec<String> = Vec::new();
    let mut iter = sorted.into_iter();
    let Some(mut start) = iter.next() else {
        return String::new();
    };
    let mut end = start;
    for uid in iter {
        if Some(uid) == end.checked_add(1) {
            end = uid;
        } else {
            parts.push(if start == end {
                start.to_string()
            } else {
                format!("{start}:{end}")
            });
            start = uid;
            end = uid;
        }
    }
    parts.push(if start == end {
        start.to_string()
    } else {
        format!("{start}:{end}")
    });
    parts.join(",")
}

/// Connects and logs in.
pub async fn connect(server: &Server, user: &str, password: &str) -> Result<Session> {
    let client = match server.tls {
        Tls::Tls => {
            let mut client = Client::new(net::connect_tls(&server.host, server.port).await?);
            greeting(&mut client).await?;
            client
        }
        Tls::None => {
            let mut client = Client::new(MailStream::Plain(
                net::tcp(&server.host, server.port).await?,
            ));
            greeting(&mut client).await?;
            client
        }
        Tls::Starttls => {
            let mut plain = Client::new(MailStream::Plain(
                net::tcp(&server.host, server.port).await?,
            ));
            greeting(&mut plain).await?;
            timed("STARTTLS", async {
                plain
                    .run_command_and_check_ok("STARTTLS", None)
                    .await
                    .map_err(Error::from)
            })
            .await?;
            let MailStream::Plain(tcp) = plain.into_inner() else {
                return Err(Error::Imap("unexpected stream".into()));
            };
            Client::new(net::upgrade(tcp, &server.host).await?)
        }
    };
    tokio::time::timeout(COMMAND_TIMEOUT, client.login(user, password))
        .await
        .map_err(|_| Error::Timeout("logging in"))?
        .map_err(|(err, _)| match err {
            async_imap::error::Error::No(msg) => Error::Imap(format!(
                "the server refused the user name or the password ({msg})"
            )),
            other => Error::from(other),
        })
}

async fn greeting(client: &mut Client<MailStream>) -> Result<()> {
    match tokio::time::timeout(net::CONNECT_TIMEOUT, client.read_response()).await {
        Ok(Some(Ok(_))) => Ok(()),
        Ok(Some(Err(err))) => Err(err.into()),
        Ok(None) => Err(Error::Imap("the server closed the connection".into())),
        Err(_) => Err(Error::Timeout("waiting for the server greeting")),
    }
}

/// Throws away the unsolicited responses collected so far (the channel is bounded).
pub fn drain(session: &Session) {
    while session.unsolicited_responses.try_recv().is_ok() {}
}

/// The role of a mailbox from its special-use attribute or, failing that, its name.
pub fn role_of(name: &str, delimiter: &str, attributes: &[NameAttribute<'_>]) -> &'static str {
    for attribute in attributes {
        match attribute {
            NameAttribute::Sent => return "sent",
            NameAttribute::Drafts => return "drafts",
            NameAttribute::Trash => return "trash",
            NameAttribute::Junk => return "junk",
            NameAttribute::Archive => return "archive",
            _ => {}
        }
    }
    if name.eq_ignore_ascii_case("INBOX") {
        return "inbox";
    }
    let leaf = if delimiter.is_empty() {
        name
    } else {
        name.rsplit(delimiter).next().unwrap_or(name)
    };
    match crate::mutf7::decode(leaf).to_lowercase().as_str() {
        "sent" | "sent items" | "sent mail" | "sent messages" | "inviata" | "posta inviata" => {
            "sent"
        }
        "drafts" | "draft" | "bozze" => "drafts",
        "trash" | "deleted items" | "deleted messages" | "bin" | "cestino" => "trash",
        "junk" | "spam" | "junk e-mail" | "posta indesiderata" => "junk",
        "archive" | "archives" | "archivio" => "archive",
        _ => "",
    }
}

/// Lists the mailboxes and updates the store; true if anything changed.
pub async fn sync_mailboxes(session: &mut Session, store: &Store, account: &str) -> Result<bool> {
    let before: Vec<(String, String, bool)> = store
        .mailboxes(account)?
        .into_iter()
        .map(|m| (m.name, m.role, m.selectable))
        .collect();
    let names = timed("listing mailboxes", async {
        let stream = session.list(Some(""), Some("*")).await?;
        stream.try_collect::<Vec<_>>().await.map_err(Error::from)
    })
    .await?;
    let mut kept = Vec::new();
    for name in names.iter().take(10_000) {
        let delimiter = name.delimiter().unwrap_or("");
        let selectable = !name.attributes().contains(&NameAttribute::NoSelect);
        let role = role_of(name.name(), delimiter, name.attributes());
        store.upsert_mailbox(account, name.name(), delimiter, role, selectable)?;
        kept.push(name.name().to_owned());
    }
    store.remove_mailboxes_except(account, &kept)?;
    drain(session);
    let after: Vec<(String, String, bool)> = store
        .mailboxes(account)?
        .into_iter()
        .map(|m| (m.name, m.role, m.selectable))
        .collect();
    Ok(before != after)
}

fn flags_of(fetch: &Fetch) -> Flags {
    let mut flags = Flags::default();
    for flag in fetch.flags() {
        match flag {
            Flag::Seen => flags.seen = true,
            Flag::Flagged => flags.flagged = true,
            Flag::Answered => flags.answered = true,
            Flag::Draft => flags.draft = true,
            _ => {}
        }
    }
    flags
}

fn flag_names(names: &[String]) -> String {
    let flags: Vec<&str> = names
        .iter()
        .filter_map(|n| match n.as_str() {
            "seen" => Some("\\Seen"),
            "flagged" => Some("\\Flagged"),
            "answered" => Some("\\Answered"),
            "draft" => Some("\\Draft"),
            _ => None,
        })
        .collect();
    flags.join(" ")
}

/// What a sync changed in a mailbox (message ids).
#[derive(Debug, Default, Clone, PartialEq, Eq)]
pub struct Changes {
    pub added: Vec<i64>,
    pub removed: Vec<i64>,
    pub changed: Vec<i64>,
}

impl Changes {
    pub fn is_empty(&self) -> bool {
        self.added.is_empty() && self.removed.is_empty() && self.changed.is_empty()
    }
}

/// Synchronizes one mailbox: new messages, removed ones, flag changes.
pub async fn sync_mailbox(
    session: &mut Session,
    store: &Store,
    mailbox: i64,
    condstore: bool,
) -> Result<Changes> {
    let stored = store.mailbox(mailbox)?;
    let mut changes = Changes::default();
    if !stored.selectable {
        return Ok(changes);
    }
    let selected = timed("selecting a mailbox", async {
        let command = if condstore {
            session.select_condstore(&stored.name).await
        } else {
            session.select(&stored.name).await
        };
        command.map_err(Error::from)
    })
    .await?;
    if stored.uidvalidity.is_some() && stored.uidvalidity != selected.uid_validity {
        changes.removed = store.clear_mailbox(mailbox)?;
    }
    let known: HashMap<u32, (i64, Flags)> = store
        .uids(mailbox)?
        .into_iter()
        .map(|(uid, id, flags)| (uid, (id, flags)))
        .collect();

    let on_server: HashSet<u32> = if selected.exists == 0 {
        HashSet::new()
    } else {
        timed("listing messages", async {
            session.uid_search("ALL").await.map_err(Error::from)
        })
        .await?
    };

    // Removed on the server.
    let gone: Vec<i64> = known
        .iter()
        .filter(|(uid, _)| !on_server.contains(uid))
        .map(|(_, (id, _))| *id)
        .collect();
    store.delete_messages(&gone)?;
    changes.removed.extend(gone);

    // New on the server, newest first; the first sync takes only the newest ones.
    let mut new: Vec<u32> = on_server
        .iter()
        .copied()
        .filter(|uid| !known.contains_key(uid))
        .collect();
    new.sort_unstable_by(|a, b| b.cmp(a));
    if known.is_empty() {
        new.truncate(FIRST_SYNC);
    }
    for batch in new.chunks(FETCH_BATCH) {
        let added = fetch_batch(session, store, mailbox, batch).await?;
        changes.added.extend(added);
    }

    // Flags of the messages we already had.
    let still: Vec<u32> = known
        .keys()
        .copied()
        .filter(|uid| on_server.contains(uid))
        .collect();
    let since = if condstore && stored.uidvalidity == selected.uid_validity {
        stored.modseq
    } else {
        None
    };
    let updates: Vec<(u32, Flags)> = if still.is_empty() {
        Vec::new()
    } else if let Some(modseq) = since {
        timed("fetching flag changes", async {
            let fetches: Vec<Fetch> = session
                .uid_fetch("1:*", format!("(UID FLAGS) (CHANGEDSINCE {modseq})"))
                .await?
                .try_collect()
                .await?;
            Ok(fetches
                .iter()
                .filter_map(|f| f.uid.map(|uid| (uid, flags_of(f))))
                .collect())
        })
        .await?
    } else {
        let mut all = Vec::new();
        for chunk in still.chunks(500) {
            let set = uid_set(chunk);
            let part: Vec<(u32, Flags)> = timed("fetching flags", async {
                let fetches: Vec<Fetch> = session
                    .uid_fetch(&set, "(UID FLAGS)")
                    .await?
                    .try_collect()
                    .await?;
                Ok(fetches
                    .iter()
                    .filter_map(|f| f.uid.map(|uid| (uid, flags_of(f))))
                    .collect())
            })
            .await?;
            all.extend(part);
        }
        all
    };
    for (uid, flags) in updates {
        if let Some((id, old)) = known.get(&uid)
            && *old != flags
            && store.set_flags(*id, flags)?
        {
            changes.changed.push(*id);
        }
    }
    store.set_mailbox_sync(
        mailbox,
        selected.uid_validity,
        selected.uid_next,
        selected.highest_modseq,
    )?;
    drain(session);
    Ok(changes)
}

async fn fetch_batch(
    session: &mut Session,
    store: &Store,
    mailbox: i64,
    uids: &[u32],
) -> Result<Vec<i64>> {
    let set = uid_set(uids);
    // Sizes first: very large messages keep only their headers.
    let sizes: Vec<(u32, u32)> = timed("fetching sizes", async {
        let fetches: Vec<Fetch> = session
            .uid_fetch(&set, "(UID RFC822.SIZE)")
            .await?
            .try_collect()
            .await?;
        Ok(fetches
            .iter()
            .filter_map(|f| Some((f.uid?, f.size.unwrap_or(0))))
            .collect())
    })
    .await?;
    type Sizes = Vec<(u32, u32)>;
    let (big, small): (Sizes, Sizes) = sizes.into_iter().partition(|(_, size)| *size > MAX_MESSAGE);
    let mut added = Vec::new();
    for (list, query) in [
        (small, "(UID FLAGS RFC822.SIZE INTERNALDATE BODY.PEEK[])"),
        (
            big,
            "(UID FLAGS RFC822.SIZE INTERNALDATE BODY.PEEK[HEADER])",
        ),
    ] {
        if list.is_empty() {
            continue;
        }
        let set = uid_set(&list.iter().map(|(uid, _)| *uid).collect::<Vec<_>>());
        let fetches: Vec<Fetch> = timed("fetching messages", async {
            session
                .uid_fetch(&set, query)
                .await?
                .try_collect()
                .await
                .map_err(Error::from)
        })
        .await?;
        for fetch in &fetches {
            let Some(uid) = fetch.uid else { continue };
            let raw = fetch.body().or_else(|| fetch.header()).unwrap_or(b"");
            let date = fetch.internal_date().map(|d| d.timestamp()).unwrap_or(0);
            let summary = message::summarize(raw, date);
            let size = fetch
                .size
                .unwrap_or(u32::try_from(raw.len()).unwrap_or(u32::MAX));
            added.push(store.insert_message(mailbox, uid, &summary, flags_of(fetch), size, raw)?);
        }
    }
    Ok(added)
}

/// A server operation waiting to be done (kept in the store until it succeeds).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "op", rename_all = "camelCase")]
pub enum Op {
    SetFlags {
        mailbox: String,
        uids: Vec<u32>,
        add: Vec<String>,
        remove: Vec<String>,
    },
    Move {
        mailbox: String,
        uids: Vec<u32>,
        to: String,
    },
    /// Delete for good (`\Deleted` and expunge).
    Expunge { mailbox: String, uids: Vec<u32> },
    /// Copy a sent message (a file of the engine) into a mailbox.
    Append { mailbox: String, path: String },
}

/// Runs one operation on the server.
pub async fn run(session: &mut Session, op: &Op) -> Result<()> {
    let has = |cap: &str, caps: &async_imap::types::Capabilities| caps.has_str(cap);
    let caps = timed("capabilities", async {
        session.capabilities().await.map_err(Error::from)
    })
    .await?;
    match op {
        Op::SetFlags {
            mailbox,
            uids,
            add,
            remove,
        } => {
            timed("selecting", async {
                session
                    .select(mailbox)
                    .await
                    .map(|_| ())
                    .map_err(Error::from)
            })
            .await?;
            let set = uid_set(uids);
            for (sign, names) in [("+", add), ("-", remove)] {
                let flags = flag_names(names);
                if flags.is_empty() || set.is_empty() {
                    continue;
                }
                timed("storing flags", async {
                    let _: Vec<Fetch> = session
                        .uid_store(&set, format!("{sign}FLAGS.SILENT ({flags})"))
                        .await?
                        .try_collect()
                        .await?;
                    Ok(())
                })
                .await?;
            }
        }
        Op::Move { mailbox, uids, to } => {
            timed("selecting", async {
                session
                    .select(mailbox)
                    .await
                    .map(|_| ())
                    .map_err(Error::from)
            })
            .await?;
            let set = uid_set(uids);
            if set.is_empty() {
                return Ok(());
            }
            if has("MOVE", &caps) {
                timed("moving", async {
                    session.uid_mv(&set, to).await.map_err(Error::from)
                })
                .await?;
            } else {
                let target = quote(to)?;
                timed("copying", async {
                    session.uid_copy(&set, &target).await.map_err(Error::from)
                })
                .await?;
                expunge(session, &set, has("UIDPLUS", &caps)).await?;
            }
        }
        Op::Expunge { mailbox, uids } => {
            timed("selecting", async {
                session
                    .select(mailbox)
                    .await
                    .map(|_| ())
                    .map_err(Error::from)
            })
            .await?;
            let set = uid_set(uids);
            if !set.is_empty() {
                expunge(session, &set, has("UIDPLUS", &caps)).await?;
            }
        }
        Op::Append { mailbox, path } => {
            if mailbox.contains(['"', '\\', '\r', '\n']) {
                return Err(Error::Invalid(format!("cannot append to {mailbox:?}")));
            }
            let raw = match std::fs::read(path) {
                Ok(raw) => raw,
                // Already appended and cleaned up.
                Err(err) if err.kind() == std::io::ErrorKind::NotFound => return Ok(()),
                Err(err) => return Err(err.into()),
            };
            timed("appending", async {
                session
                    .append(mailbox, Some("(\\Seen)"), None, &raw)
                    .await
                    .map_err(Error::from)
            })
            .await?;
            match std::fs::remove_file(path) {
                Ok(()) => {}
                Err(err) if err.kind() == std::io::ErrorKind::NotFound => {}
                Err(err) => return Err(err.into()),
            }
        }
    }
    drain(session);
    Ok(())
}

async fn expunge(session: &mut Session, set: &str, uidplus: bool) -> Result<()> {
    timed("marking deleted", async {
        let _: Vec<Fetch> = session
            .uid_store(set, "+FLAGS.SILENT (\\Deleted)")
            .await?
            .try_collect()
            .await?;
        Ok(())
    })
    .await?;
    timed("expunging", async {
        if uidplus {
            let _: Vec<u32> = session.uid_expunge(set).await?.try_collect().await?;
        } else {
            let _: Vec<u32> = session.expunge().await?.try_collect().await?;
        }
        Ok(())
    })
    .await
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn uid_sets() {
        assert_eq!(uid_set(&[]), "");
        assert_eq!(uid_set(&[5]), "5");
        assert_eq!(uid_set(&[3, 1, 2, 7, 9, 8, 2]), "1:3,7:9");
        assert_eq!(uid_set(&[u32::MAX, 1]), "1,4294967295");
    }

    #[test]
    fn quoting() {
        assert_eq!(quote("Sent").unwrap(), "\"Sent\"");
        assert_eq!(quote("a\"b\\c").unwrap(), "\"a\\\"b\\\\c\"");
        assert!(quote("a\r\nb").is_err());
    }

    #[test]
    fn roles() {
        assert_eq!(role_of("INBOX", "/", &[]), "inbox");
        assert_eq!(role_of("[Gmail]/Sent Mail", "/", &[]), "sent");
        assert_eq!(role_of("Whatever", "/", &[NameAttribute::Trash]), "trash");
        assert_eq!(role_of("Posta inviata", ".", &[]), "sent");
        assert_eq!(role_of("Projects", "/", &[]), "");
    }

    #[test]
    fn ops_round_trip_as_json() {
        let op = Op::Move {
            mailbox: "INBOX".into(),
            uids: vec![1, 2],
            to: "Archive".into(),
        };
        let json = serde_json::to_string(&op).unwrap();
        assert_eq!(
            json,
            r#"{"op":"move","mailbox":"INBOX","uids":[1,2],"to":"Archive"}"#
        );
        assert_eq!(serde_json::from_str::<Op>(&json).unwrap(), op);
    }
}
