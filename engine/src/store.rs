//! The offline store: SQLite for accounts, mailboxes, message summaries, the search index
//! (FTS5), pending server operations and the outbox; message bodies as `.eml` files next to it.
//! Ids exposed on D-Bus are the SQLite row ids as decimal strings.

use std::path::{Path, PathBuf};
use std::sync::Mutex;

use rusqlite::{Connection, OptionalExtension, params};
use serde::Serialize;

use crate::config::Account;
use crate::error::{Error, Result};
use crate::message::{Person, Summary};

const SCHEMA: &str = "
PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;
CREATE TABLE IF NOT EXISTS accounts (
    id TEXT PRIMARY KEY,
    json TEXT NOT NULL,
    state TEXT NOT NULL DEFAULT 'idle'
);
CREATE TABLE IF NOT EXISTS mailboxes (
    id INTEGER PRIMARY KEY,
    account TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    delimiter TEXT NOT NULL DEFAULT '',
    role TEXT NOT NULL DEFAULT '',
    selectable INTEGER NOT NULL DEFAULT 1,
    uidvalidity INTEGER,
    uidnext INTEGER,
    modseq INTEGER,
    UNIQUE(account, name)
);
CREATE TABLE IF NOT EXISTS messages (
    id INTEGER PRIMARY KEY,
    mailbox INTEGER NOT NULL REFERENCES mailboxes(id) ON DELETE CASCADE,
    uid INTEGER NOT NULL,
    thread TEXT NOT NULL DEFAULT '',
    message_id TEXT NOT NULL DEFAULT '',
    refs TEXT NOT NULL DEFAULT '',
    from_name TEXT NOT NULL DEFAULT '',
    from_address TEXT NOT NULL DEFAULT '',
    to_json TEXT NOT NULL DEFAULT '[]',
    cc_json TEXT NOT NULL DEFAULT '[]',
    subject TEXT NOT NULL DEFAULT '',
    preview TEXT NOT NULL DEFAULT '',
    date INTEGER NOT NULL DEFAULT 0,
    seen INTEGER NOT NULL DEFAULT 0,
    flagged INTEGER NOT NULL DEFAULT 0,
    answered INTEGER NOT NULL DEFAULT 0,
    draft INTEGER NOT NULL DEFAULT 0,
    attachments INTEGER NOT NULL DEFAULT 0,
    size INTEGER NOT NULL DEFAULT 0,
    UNIQUE(mailbox, uid)
);
CREATE INDEX IF NOT EXISTS messages_by_date ON messages(mailbox, date DESC);
CREATE INDEX IF NOT EXISTS messages_by_mid ON messages(message_id);
CREATE VIRTUAL TABLE IF NOT EXISTS search USING fts5(
    subject, people, body, content='', contentless_delete=1, tokenize='unicode61 remove_diacritics 2'
);
CREATE TABLE IF NOT EXISTS pending (
    id INTEGER PRIMARY KEY,
    account TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    op TEXT NOT NULL,
    attempts INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS outbox (
    id INTEGER PRIMARY KEY,
    account TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    draft TEXT NOT NULL,
    attempts INTEGER NOT NULL DEFAULT 0,
    next_try INTEGER NOT NULL DEFAULT 0,
    error TEXT NOT NULL DEFAULT ''
);
";

/// A mailbox as stored.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Mailbox {
    pub id: i64,
    pub account: String,
    pub name: String,
    pub delimiter: String,
    pub role: String,
    pub selectable: bool,
    pub uidvalidity: Option<u32>,
    pub uidnext: Option<u32>,
    pub modseq: Option<u64>,
}

/// A mailbox as the app sees it (`ListMailboxes`).
#[derive(Debug, Clone, Serialize)]
pub struct MailboxView {
    pub id: String,
    pub name: String,
    pub role: String,
    pub unread: i64,
    pub total: i64,
    pub parent: String,
}

/// Flags the app sees and sets.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub struct Flags {
    pub seen: bool,
    pub flagged: bool,
    pub answered: bool,
    pub draft: bool,
}

impl Flags {
    pub fn names(self) -> Vec<&'static str> {
        let mut out = Vec::new();
        if self.seen {
            out.push("seen");
        }
        if self.flagged {
            out.push("flagged");
        }
        if self.answered {
            out.push("answered");
        }
        if self.draft {
            out.push("draft");
        }
        out
    }

    /// Applies names added and removed (`seen`, `flagged`, `answered`, `draft`).
    pub fn apply(mut self, add: &[String], remove: &[String]) -> Self {
        for (names, on) in [(remove, false), (add, true)] {
            for name in names {
                match name.as_str() {
                    "seen" => self.seen = on,
                    "flagged" => self.flagged = on,
                    "answered" => self.answered = on,
                    "draft" => self.draft = on,
                    _ => {}
                }
            }
        }
        self
    }
}

/// A message row in the list (`ListMessages`).
#[derive(Debug, Clone, Serialize)]
pub struct MessageView {
    pub id: String,
    pub thread: String,
    pub from: Person,
    pub to: Vec<Person>,
    pub subject: String,
    pub preview: String,
    pub date: i64,
    pub flags: Vec<&'static str>,
    pub attachments: i64,
}

/// Where a message lives on the server.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Location {
    pub id: i64,
    pub mailbox: i64,
    pub account: String,
    pub mailbox_name: String,
    pub role: String,
    pub uid: u32,
    pub flags: Flags,
    pub date: i64,
    pub message_id: String,
    pub references: String,
}

/// An outgoing message waiting to be sent.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Queued {
    pub id: i64,
    pub account: String,
    pub draft: String,
    pub attempts: i64,
}

pub struct Store {
    db: Mutex<Connection>,
    bodies: PathBuf,
}

fn lock_err<T>(_: T) -> Error {
    Error::Store("the store lock is poisoned".into())
}

impl Store {
    /// Opens (or creates) the store in `dir`.
    pub fn open(dir: &Path) -> Result<Store> {
        std::fs::create_dir_all(dir)?;
        let bodies = dir.join("bodies");
        std::fs::create_dir_all(&bodies)?;
        let db = Connection::open(dir.join("mail.sqlite"))?;
        db.execute_batch(SCHEMA)?;
        Ok(Store {
            db: Mutex::new(db),
            bodies,
        })
    }

    fn with<T>(&self, f: impl FnOnce(&Connection) -> rusqlite::Result<T>) -> Result<T> {
        let db = self.db.lock().map_err(lock_err)?;
        Ok(f(&db)?)
    }

    fn body_path(&self, id: i64) -> PathBuf {
        self.bodies.join(format!("{id}.eml"))
    }

    // Accounts.

    pub fn add_account(&self, account: &Account) -> Result<()> {
        let json = serde_json::to_string(account)?;
        self.with(|db| {
            db.execute(
                "INSERT OR REPLACE INTO accounts (id, json, state) VALUES (?1, ?2, 'idle')",
                params![account.id, json],
            )
        })?;
        Ok(())
    }

    pub fn accounts(&self) -> Result<Vec<(Account, String)>> {
        let rows: Vec<(String, String)> = self.with(|db| {
            let mut stmt = db.prepare("SELECT json, state FROM accounts ORDER BY rowid")?;
            let rows = stmt.query_map([], |r| Ok((r.get(0)?, r.get(1)?)))?;
            rows.collect()
        })?;
        Ok(rows
            .into_iter()
            .filter_map(|(json, state)| {
                serde_json::from_str::<Account>(&json)
                    .ok()
                    .map(|a| (a, state))
            })
            .collect())
    }

    pub fn account(&self, id: &str) -> Result<Account> {
        let json: Option<String> = self.with(|db| {
            db.query_row("SELECT json FROM accounts WHERE id = ?1", [id], |r| {
                r.get(0)
            })
            .optional()
        })?;
        let json = json.ok_or_else(|| Error::NotFound(format!("account {id}")))?;
        Ok(serde_json::from_str(&json)?)
    }

    pub fn set_account_state(&self, id: &str, state: &str) -> Result<()> {
        self.with(|db| {
            db.execute(
                "UPDATE accounts SET state = ?2 WHERE id = ?1",
                params![id, state],
            )
        })?;
        Ok(())
    }

    /// Removes an account with its mailboxes, messages, bodies, pending operations and outbox.
    pub fn remove_account(&self, id: &str) -> Result<()> {
        let messages: Vec<i64> = self.with(|db| {
            let mut stmt = db.prepare(
                "SELECT m.id FROM messages m JOIN mailboxes b ON m.mailbox = b.id WHERE b.account = ?1",
            )?;
            let rows = stmt.query_map([id], |r| r.get(0))?;
            rows.collect()
        })?;
        self.delete_messages(&messages)?;
        self.with(|db| db.execute("DELETE FROM accounts WHERE id = ?1", [id]))?;
        Ok(())
    }

    // Mailboxes.

    /// Inserts or updates a mailbox from the server's LIST; returns its id.
    pub fn upsert_mailbox(
        &self,
        account: &str,
        name: &str,
        delimiter: &str,
        role: &str,
        selectable: bool,
    ) -> Result<i64> {
        self.with(|db| {
            db.execute(
                "INSERT INTO mailboxes (account, name, delimiter, role, selectable) VALUES (?1, ?2, ?3, ?4, ?5)
                 ON CONFLICT(account, name) DO UPDATE SET delimiter = ?3, role = ?4, selectable = ?5",
                params![account, name, delimiter, role, selectable],
            )?;
            db.query_row(
                "SELECT id FROM mailboxes WHERE account = ?1 AND name = ?2",
                params![account, name],
                |r| r.get(0),
            )
        })
    }

    fn row_to_mailbox(r: &rusqlite::Row<'_>) -> rusqlite::Result<Mailbox> {
        Ok(Mailbox {
            id: r.get(0)?,
            account: r.get(1)?,
            name: r.get(2)?,
            delimiter: r.get(3)?,
            role: r.get(4)?,
            selectable: r.get(5)?,
            uidvalidity: r
                .get::<_, Option<i64>>(6)?
                .and_then(|v| u32::try_from(v).ok()),
            uidnext: r
                .get::<_, Option<i64>>(7)?
                .and_then(|v| u32::try_from(v).ok()),
            modseq: r
                .get::<_, Option<i64>>(8)?
                .and_then(|v| u64::try_from(v).ok()),
        })
    }

    pub fn mailboxes(&self, account: &str) -> Result<Vec<Mailbox>> {
        self.with(|db| {
            let mut stmt = db.prepare(
                "SELECT id, account, name, delimiter, role, selectable, uidvalidity, uidnext, modseq
                 FROM mailboxes WHERE account = ?1 ORDER BY id",
            )?;
            let rows = stmt.query_map([account], Self::row_to_mailbox)?;
            rows.collect()
        })
    }

    pub fn mailbox(&self, id: i64) -> Result<Mailbox> {
        self.with(|db| {
            db.query_row(
                "SELECT id, account, name, delimiter, role, selectable, uidvalidity, uidnext, modseq
                 FROM mailboxes WHERE id = ?1",
                [id],
                Self::row_to_mailbox,
            )
            .optional()
        })?
        .ok_or_else(|| Error::NotFound(format!("mailbox {id}")))
    }

    pub fn mailbox_by_role(&self, account: &str, role: &str) -> Result<Option<Mailbox>> {
        Ok(self
            .mailboxes(account)?
            .into_iter()
            .find(|m| m.role == role && m.selectable))
    }

    /// The mailboxes of an account with their counts, for the app.
    pub fn mailbox_views(&self, account: &str) -> Result<Vec<MailboxView>> {
        let boxes = self.mailboxes(account)?;
        let mut out = Vec::with_capacity(boxes.len());
        for b in &boxes {
            let (unread, total): (i64, i64) = self.with(|db| {
                db.query_row(
                    "SELECT COALESCE(SUM(seen = 0), 0), COUNT(*) FROM messages WHERE mailbox = ?1",
                    [b.id],
                    |r| Ok((r.get(0)?, r.get(1)?)),
                )
            })?;
            let parent = if b.delimiter.is_empty() {
                String::new()
            } else {
                b.name
                    .rsplit_once(b.delimiter.as_str())
                    .and_then(|(parent, _)| boxes.iter().find(|p| p.name == parent))
                    .map(|p| p.id.to_string())
                    .unwrap_or_default()
            };
            let name = if b.delimiter.is_empty() {
                b.name.clone()
            } else {
                b.name
                    .rsplit(b.delimiter.as_str())
                    .next()
                    .unwrap_or(&b.name)
                    .to_owned()
            };
            out.push(MailboxView {
                id: b.id.to_string(),
                name: if b.name.eq_ignore_ascii_case("INBOX") {
                    "Inbox".into()
                } else {
                    name
                },
                role: b.role.clone(),
                unread,
                total,
                parent,
            });
        }
        Ok(out)
    }

    /// Removes the mailboxes of `account` that the server no longer lists.
    pub fn remove_mailboxes_except(&self, account: &str, keep: &[String]) -> Result<Vec<i64>> {
        let gone: Vec<i64> = self
            .mailboxes(account)?
            .into_iter()
            .filter(|m| !keep.contains(&m.name))
            .map(|m| m.id)
            .collect();
        for id in &gone {
            self.clear_mailbox(*id)?;
            self.with(|db| db.execute("DELETE FROM mailboxes WHERE id = ?1", [id]))?;
        }
        Ok(gone)
    }

    pub fn set_mailbox_sync(
        &self,
        id: i64,
        uidvalidity: Option<u32>,
        uidnext: Option<u32>,
        modseq: Option<u64>,
    ) -> Result<()> {
        let modseq = modseq.and_then(|m| i64::try_from(m).ok());
        self.with(|db| {
            db.execute(
                "UPDATE mailboxes SET uidvalidity = ?2, uidnext = ?3, modseq = ?4 WHERE id = ?1",
                params![id, uidvalidity, uidnext, modseq],
            )
        })?;
        Ok(())
    }

    /// Deletes every local message of a mailbox (UIDVALIDITY changed).
    pub fn clear_mailbox(&self, id: i64) -> Result<Vec<i64>> {
        let ids: Vec<i64> = self.with(|db| {
            let mut stmt = db.prepare("SELECT id FROM messages WHERE mailbox = ?1")?;
            let rows = stmt.query_map([id], |r| r.get(0))?;
            rows.collect()
        })?;
        self.delete_messages(&ids)?;
        Ok(ids)
    }

    // Messages.

    /// Stores a fetched message (summary, flags, body file, index). Returns its id, or the
    /// existing id if the UID is already there.
    pub fn insert_message(
        &self,
        mailbox: i64,
        uid: u32,
        summary: &Summary,
        flags: Flags,
        size: u32,
        raw: &[u8],
    ) -> Result<i64> {
        let existing: Option<i64> = self.with(|db| {
            db.query_row(
                "SELECT id FROM messages WHERE mailbox = ?1 AND uid = ?2",
                params![mailbox, uid],
                |r| r.get(0),
            )
            .optional()
        })?;
        if let Some(id) = existing {
            return Ok(id);
        }
        let to = serde_json::to_string(&summary.to)?;
        let cc = serde_json::to_string(&summary.cc)?;
        let people = std::iter::once(&summary.from)
            .chain(summary.to.iter())
            .chain(summary.cc.iter())
            .map(|p| format!("{} {}", p.name, p.address))
            .collect::<Vec<_>>()
            .join(" ");
        let id = self.with(|db| {
            db.execute(
                "INSERT INTO messages (mailbox, uid, thread, message_id, refs, from_name, from_address,
                    to_json, cc_json, subject, preview, date, seen, flagged, answered, draft, attachments, size)
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16, ?17, ?18)",
                params![
                    mailbox,
                    uid,
                    summary.thread,
                    summary.message_id,
                    summary.references.join(" "),
                    summary.from.name,
                    summary.from.address,
                    to,
                    cc,
                    summary.subject,
                    summary.preview,
                    summary.date,
                    flags.seen,
                    flags.flagged,
                    flags.answered,
                    flags.draft,
                    summary.attachments,
                    size,
                ],
            )?;
            let id = db.last_insert_rowid();
            db.execute(
                "INSERT INTO search (rowid, subject, people, body) VALUES (?1, ?2, ?3, ?4)",
                params![id, summary.subject, people, summary.index_text],
            )?;
            Ok(id)
        })?;
        std::fs::write(self.body_path(id), raw)?;
        Ok(id)
    }

    /// The UIDs stored for a mailbox with their message ids.
    pub fn uids(&self, mailbox: i64) -> Result<Vec<(u32, i64, Flags)>> {
        self.with(|db| {
            let mut stmt = db.prepare(
                "SELECT uid, id, seen, flagged, answered, draft FROM messages WHERE mailbox = ?1 ORDER BY uid",
            )?;
            let rows = stmt.query_map([mailbox], |r| {
                Ok((
                    r.get::<_, u32>(0)?,
                    r.get(1)?,
                    Flags {
                        seen: r.get(2)?,
                        flagged: r.get(3)?,
                        answered: r.get(4)?,
                        draft: r.get(5)?,
                    },
                ))
            })?;
            rows.collect()
        })
    }

    pub fn delete_messages(&self, ids: &[i64]) -> Result<()> {
        for id in ids {
            self.with(|db| {
                db.execute("DELETE FROM search WHERE rowid = ?1", [id])?;
                db.execute("DELETE FROM messages WHERE id = ?1", [id])
            })?;
            match std::fs::remove_file(self.body_path(*id)) {
                Ok(()) => {}
                Err(err) if err.kind() == std::io::ErrorKind::NotFound => {}
                Err(err) => return Err(err.into()),
            }
        }
        Ok(())
    }

    /// Sets the flags of a message; true if they changed.
    pub fn set_flags(&self, id: i64, flags: Flags) -> Result<bool> {
        let changed = self.with(|db| {
            db.execute(
                "UPDATE messages SET seen = ?2, flagged = ?3, answered = ?4, draft = ?5
                 WHERE id = ?1 AND (seen != ?2 OR flagged != ?3 OR answered != ?4 OR draft != ?5)",
                params![id, flags.seen, flags.flagged, flags.answered, flags.draft],
            )
        })?;
        Ok(changed > 0)
    }

    pub fn location(&self, id: i64) -> Result<Location> {
        self.with(|db| {
            db.query_row(
                "SELECT m.id, m.mailbox, b.account, b.name, b.role, m.uid, m.seen, m.flagged, m.answered,
                        m.draft, m.date, m.message_id, m.refs
                 FROM messages m JOIN mailboxes b ON m.mailbox = b.id WHERE m.id = ?1",
                [id],
                |r| {
                    Ok(Location {
                        id: r.get(0)?,
                        mailbox: r.get(1)?,
                        account: r.get(2)?,
                        mailbox_name: r.get(3)?,
                        role: r.get(4)?,
                        uid: r.get(5)?,
                        flags: Flags {
                            seen: r.get(6)?,
                            flagged: r.get(7)?,
                            answered: r.get(8)?,
                            draft: r.get(9)?,
                        },
                        date: r.get(10)?,
                        message_id: r.get(11)?,
                        references: r.get(12)?,
                    })
                },
            )
            .optional()
        })?
        .ok_or_else(|| Error::NotFound(format!("message {id}")))
    }

    /// The raw message from its body file.
    pub fn raw(&self, id: i64) -> Result<Vec<u8>> {
        std::fs::read(self.body_path(id)).map_err(|err| {
            if err.kind() == std::io::ErrorKind::NotFound {
                Error::NotFound(format!("the body of message {id}"))
            } else {
                err.into()
            }
        })
    }

    fn row_to_view(r: &rusqlite::Row<'_>) -> rusqlite::Result<MessageView> {
        let to: String = r.get(4)?;
        Ok(MessageView {
            id: r.get::<_, i64>(0)?.to_string(),
            thread: r.get(1)?,
            from: Person {
                name: r.get(2)?,
                address: r.get(3)?,
            },
            to: serde_json::from_str(&to).unwrap_or_default(),
            subject: r.get(5)?,
            preview: r.get(6)?,
            date: r.get(7)?,
            flags: Flags {
                seen: r.get(8)?,
                flagged: r.get(9)?,
                answered: r.get(10)?,
                draft: r.get(11)?,
            }
            .names(),
            attachments: r.get(12)?,
        })
    }

    /// The messages of a mailbox, newest first; with `threads`, only the newest of each thread.
    pub fn list(
        &self,
        mailbox: i64,
        offset: usize,
        limit: usize,
        threads: bool,
    ) -> Result<Vec<MessageView>> {
        let all: Vec<MessageView> = self.with(|db| {
            let mut stmt = db.prepare(
                "SELECT id, thread, from_name, from_address, to_json, subject, preview, date,
                        seen, flagged, answered, draft, attachments
                 FROM messages WHERE mailbox = ?1 ORDER BY date DESC, id DESC",
            )?;
            let rows = stmt.query_map([mailbox], Self::row_to_view)?;
            rows.collect()
        })?;
        let mut seen_threads = std::collections::HashSet::new();
        Ok(all
            .into_iter()
            .filter(|m| !threads || m.thread.is_empty() || seen_threads.insert(m.thread.clone()))
            .skip(offset)
            .take(limit)
            .collect())
    }

    pub fn views(&self, ids: &[i64]) -> Result<Vec<MessageView>> {
        let mut out = Vec::new();
        for id in ids {
            let view = self.with(|db| {
                db.query_row(
                    "SELECT id, thread, from_name, from_address, to_json, subject, preview, date,
                            seen, flagged, answered, draft, attachments
                     FROM messages WHERE id = ?1",
                    [id],
                    Self::row_to_view,
                )
                .optional()
            })?;
            out.extend(view);
        }
        Ok(out)
    }

    /// Full-text search: every word must match (prefixes too), newest first.
    pub fn search(&self, query: &str, limit: usize) -> Result<Vec<i64>> {
        let terms: Vec<String> = query
            .split(|c: char| !c.is_alphanumeric() && c != '@' && c != '.' && c != '_' && c != '-')
            .map(|w| w.replace('"', ""))
            .filter(|w| !w.is_empty())
            .take(16)
            .map(|w| format!("\"{w}\"*"))
            .collect();
        if terms.is_empty() {
            return Ok(Vec::new());
        }
        let expr = terms.join(" ");
        let limit = i64::try_from(limit).unwrap_or(i64::MAX);
        self.with(|db| {
            let mut stmt = db.prepare(
                "SELECT m.id FROM search s JOIN messages m ON m.id = s.rowid
                 WHERE search MATCH ?1 ORDER BY m.date DESC LIMIT ?2",
            )?;
            let rows = stmt.query_map(params![expr, limit], |r| r.get(0))?;
            rows.collect()
        })
    }

    /// The local message with this `Message-ID` in an account, if any.
    pub fn find_by_message_id(&self, account: &str, message_id: &str) -> Result<Option<i64>> {
        self.with(|db| {
            db.query_row(
                "SELECT m.id FROM messages m JOIN mailboxes b ON m.mailbox = b.id
                 WHERE b.account = ?1 AND m.message_id = ?2 LIMIT 1",
                params![account, message_id],
                |r| r.get(0),
            )
            .optional()
        })
    }

    // Pending server operations.

    pub fn push_pending(&self, account: &str, op: &str) -> Result<i64> {
        self.with(|db| {
            db.execute(
                "INSERT INTO pending (account, op) VALUES (?1, ?2)",
                params![account, op],
            )?;
            Ok(db.last_insert_rowid())
        })
    }

    pub fn pending(&self, account: &str) -> Result<Vec<(i64, String, i64)>> {
        self.with(|db| {
            let mut stmt =
                db.prepare("SELECT id, op, attempts FROM pending WHERE account = ?1 ORDER BY id")?;
            let rows = stmt.query_map([account], |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?)))?;
            rows.collect()
        })
    }

    pub fn remove_pending(&self, id: i64) -> Result<()> {
        self.with(|db| db.execute("DELETE FROM pending WHERE id = ?1", [id]))?;
        Ok(())
    }

    pub fn bump_pending(&self, id: i64) -> Result<()> {
        self.with(|db| {
            db.execute(
                "UPDATE pending SET attempts = attempts + 1 WHERE id = ?1",
                [id],
            )
        })?;
        Ok(())
    }

    // Outbox.

    pub fn queue_outgoing(&self, account: &str, draft: &str) -> Result<i64> {
        self.with(|db| {
            db.execute(
                "INSERT INTO outbox (account, draft) VALUES (?1, ?2)",
                params![account, draft],
            )?;
            Ok(db.last_insert_rowid())
        })
    }

    pub fn due_outgoing(&self, now: i64) -> Result<Vec<Queued>> {
        self.with(|db| {
            let mut stmt = db.prepare(
                "SELECT id, account, draft, attempts FROM outbox WHERE next_try <= ?1 ORDER BY id",
            )?;
            let rows = stmt.query_map([now], |r| {
                Ok(Queued {
                    id: r.get(0)?,
                    account: r.get(1)?,
                    draft: r.get(2)?,
                    attempts: r.get(3)?,
                })
            })?;
            rows.collect()
        })
    }

    pub fn sent(&self, id: i64) -> Result<()> {
        self.with(|db| db.execute("DELETE FROM outbox WHERE id = ?1", [id]))?;
        Ok(())
    }

    pub fn send_failed(&self, id: i64, error: &str, next_try: i64) -> Result<()> {
        self.with(|db| {
            db.execute(
                "UPDATE outbox SET attempts = attempts + 1, next_try = ?2, error = ?3 WHERE id = ?1",
                params![id, next_try, error],
            )
        })?;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::config::{Server, Tls};

    fn account(id: &str) -> Account {
        let server = Server {
            host: "localhost".into(),
            port: 1,
            tls: Tls::None,
        };
        Account {
            id: id.into(),
            name: "Test".into(),
            address: "t@localhost".into(),
            provider: "localhost".into(),
            imap: server.clone(),
            smtp: server,
            username: "t".into(),
        }
    }

    fn summary(subject: &str, thread: &str, date: i64, body: &str) -> Summary {
        Summary {
            message_id: format!("{subject}@x"),
            thread: thread.into(),
            from: Person {
                name: "Ada".into(),
                address: "ada@example.org".into(),
            },
            subject: subject.into(),
            preview: body.into(),
            date,
            index_text: body.into(),
            ..Summary::default()
        }
    }

    #[test]
    fn mailboxes_messages_threads_search_and_removal() {
        let dir = tempfile::tempdir().unwrap();
        let store = Store::open(dir.path()).unwrap();
        store.add_account(&account("a1")).unwrap();
        let inbox = store
            .upsert_mailbox("a1", "INBOX", "/", "inbox", true)
            .unwrap();
        let child = store
            .upsert_mailbox("a1", "INBOX/Work", "/", "", true)
            .unwrap();
        assert_eq!(
            store
                .upsert_mailbox("a1", "INBOX", "/", "inbox", true)
                .unwrap(),
            inbox
        );

        let m1 = store
            .insert_message(
                inbox,
                1,
                &summary("Hello", "t1", 100, "first engine note"),
                Flags::default(),
                10,
                b"raw1",
            )
            .unwrap();
        let m2 = store
            .insert_message(
                inbox,
                2,
                &summary("Re: Hello", "t1", 200, "second note"),
                Flags {
                    seen: true,
                    ..Flags::default()
                },
                10,
                b"raw2",
            )
            .unwrap();
        store
            .insert_message(
                inbox,
                3,
                &summary("Other", "t2", 150, "café differences"),
                Flags::default(),
                10,
                b"raw3",
            )
            .unwrap();
        assert_eq!(
            store
                .insert_message(
                    inbox,
                    1,
                    &summary("dup", "t9", 1, ""),
                    Flags::default(),
                    1,
                    b""
                )
                .unwrap(),
            m1
        );

        let all = store.list(inbox, 0, 10, false).unwrap();
        assert_eq!(
            all.iter().map(|m| m.subject.as_str()).collect::<Vec<_>>(),
            ["Re: Hello", "Other", "Hello"]
        );
        let threads = store.list(inbox, 0, 10, true).unwrap();
        assert_eq!(threads.len(), 2);
        assert_eq!(store.list(inbox, 1, 1, false).unwrap()[0].subject, "Other");

        let views = store.mailbox_views("a1").unwrap();
        let inbox_view = views.iter().find(|v| v.id == inbox.to_string()).unwrap();
        assert_eq!(
            (
                inbox_view.unread,
                inbox_view.total,
                inbox_view.name.as_str()
            ),
            (2, 3, "Inbox")
        );
        let child_view = views.iter().find(|v| v.id == child.to_string()).unwrap();
        assert_eq!(
            (child_view.name.as_str(), child_view.parent.clone()),
            ("Work", inbox.to_string())
        );

        assert_eq!(store.search("engine", 10).unwrap(), vec![m1]);
        assert_eq!(store.search("NOTE", 10).unwrap(), vec![m2, m1]);
        assert_eq!(store.search("cafe", 10).unwrap().len(), 1);
        assert_eq!(store.search("ada@example.org", 10).unwrap().len(), 3);
        // FTS5 syntax in the query is never interpreted: quotes, operators, brackets.
        // "OR" is a plain word here (a prefix of "Other" and "org").
        assert_eq!(store.search("\" OR *", 10).unwrap().len(), 3);
        assert!(store.search("\"()*:^ NEAR", 10).unwrap().is_empty());

        assert!(
            store
                .set_flags(
                    m1,
                    Flags {
                        flagged: true,
                        ..Flags::default()
                    }
                )
                .unwrap()
        );
        assert!(
            !store
                .set_flags(
                    m1,
                    Flags {
                        flagged: true,
                        ..Flags::default()
                    }
                )
                .unwrap()
        );
        assert!(store.location(m1).unwrap().flags.flagged);
        assert_eq!(store.raw(m2).unwrap(), b"raw2");

        store.delete_messages(&[m2]).unwrap();
        assert!(store.raw(m2).is_err());
        assert_eq!(store.search("second", 10).unwrap(), Vec::<i64>::new());

        store.remove_account("a1").unwrap();
        assert!(store.mailboxes("a1").unwrap().is_empty());
        assert!(store.raw(m1).is_err());
    }

    #[test]
    fn outbox_and_pending() {
        let dir = tempfile::tempdir().unwrap();
        let store = Store::open(dir.path()).unwrap();
        store.add_account(&account("a1")).unwrap();
        let o = store.queue_outgoing("a1", "{}").unwrap();
        assert_eq!(store.due_outgoing(0).unwrap().len(), 1);
        store.send_failed(o, "offline", 100).unwrap();
        assert!(store.due_outgoing(50).unwrap().is_empty());
        assert_eq!(store.due_outgoing(100).unwrap()[0].attempts, 1);
        store.sent(o).unwrap();
        assert!(store.due_outgoing(1000).unwrap().is_empty());
        let p = store.push_pending("a1", "op").unwrap();
        assert_eq!(store.pending("a1").unwrap().len(), 1);
        store.remove_pending(p).unwrap();
        assert!(store.pending("a1").unwrap().is_empty());
    }

    #[test]
    fn flags_apply() {
        let f = Flags::default().apply(&["seen".into(), "flagged".into(), "bogus".into()], &[]);
        assert_eq!(f.names(), ["seen", "flagged"]);
        assert_eq!(f.apply(&[], &["seen".into()]).names(), ["flagged"]);
    }
}
