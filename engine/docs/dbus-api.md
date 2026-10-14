# The D-Bus API of `silica-mail-engine`

The engine runs on the **session bus** as `dev.frascella.Mail`, object `/dev/frascella/Mail1`,
interface `dev.frascella.Mail1`. Every argument and every return value is a string; structured
values are **JSON** in that string.

Errors come back as `org.freedesktop.DBus.Error.Failed` with a message meant to be shown to the
user (for example "the server refused the user name or the password (…)" or "no keyring is
available to keep the password safely (…)").

Identifiers are opaque strings: account ids (a UUID without dashes), mailbox ids and message ids
(decimal numbers, as strings). A message that moves to another mailbox gets a **new** id there;
the old one is reported as removed.

Times are Unix seconds (UTC). Flags are the strings `seen`, `flagged`, `answered`, `draft`.

## Methods

### `ListAccounts() → s`

```json
[{"id": "4f…", "name": "Ada Lovelace", "address": "ada@example.org", "provider": "example.org", "state": "idle"}]
```

`state` is the last sync state of the account (see `SyncState`).

### `AddAccount(s config) → s id`

```json
{
  "name": "Ada Lovelace",
  "address": "ada@example.org",
  "imap": {"host": "imap.example.org", "port": 993, "tls": "tls"},
  "smtp": {"host": "smtp.example.org", "port": 587, "tls": "starttls"},
  "username": "ada",
  "password": "…"
}
```

`tls` is `"tls"` (implicit TLS) or `"starttls"`; `"none"` is accepted only for loopback hosts
(tests). `username` may be empty: the address is used. The engine logs in to IMAP first and
fails if the server refuses; then the password goes to the Secret Service (the keyring of the
session, item attributes `application=silica-mail`, `account=<id>`). Without a Secret Service
the call fails with a message that asks to start one, and nothing is kept. The password is never
written to disk by the engine and never returned. Emits `AccountsChanged`, then the first sync
starts.

### `DiscoverAccount(s address) → s config`

Finds the servers of an address: the provider's autoconfig
(`autoconfig.<domain>`, `<domain>/.well-known/autoconfig`), Thunderbird's ISPDB, then guesses
(`imap.`/`mail.` and `smtp.` on the usual ports, probed). Returns a config like the one of
`AddAccount`, without `password`. Fails if nothing is found: the app then asks for the servers.

### `RemoveAccount(s id)`

Stops the account, deletes its password from the keyring and everything it has locally
(mailboxes, messages, queued operations, unsent messages). Emits `AccountsChanged`.

### `ListMailboxes(s account) → s`

```json
[{"id": "3", "name": "Archive/2025", "role": "", "unread": 0, "total": 12, "parent": "2"}]
```

`name` is the full decoded name (modified UTF-7 decoded). `role` is one of `inbox`, `sent`,
`drafts`, `trash`, `junk`, `archive` or `""` (from the special-use attributes, else the
usual names). `parent` is the id of the parent mailbox or `""`.

### `ListMessages(s query) → s`

Query: `{"mailbox": "1", "offset": 0, "limit": 50, "threads": false}` (`offset`, `limit` and
`threads` are optional; `limit` defaults to 50, at most 500). Newest first. With `threads`, only
the newest message of each conversation is listed.

```json
[{
  "id": "17", "thread": "root@example.org",
  "from": {"name": "Charles Babbage", "address": "charles@example.org"},
  "to": [{"name": "", "address": "ada@example.org"}],
  "subject": "Plans", "preview": "The plans are attached.", "date": 1767690000,
  "flags": ["seen"], "attachments": 1
}]
```

`thread` is the first `References` id, else `In-Reply-To`, else the message's own
`Message-ID` (lowercase, without `<>`): equal values are one conversation.

### `GetMessage(s id) → s`

```json
{
  "id": "17",
  "headers": {"from": "…", "subject": "…", "message-id": "…", "list-unsubscribe": "…"},
  "from": {"name": "…", "address": "…"}, "to": [], "cc": [],
  "subject": "Plans", "date": 1767690000,
  "text": "plain text body",
  "html": "<p>sanitized HTML</p>",
  "attachments": [{"id": "0", "name": "plans.pdf", "mime": "application/pdf", "size": 48213}],
  "remoteContent": true,
  "flags": ["seen"]
}
```

`headers` holds only a few useful headers (lowercase names). `html` is sanitized (no scripts,
event handlers, forms or frames; links get `rel="noopener noreferrer"`). Remote images and
backgrounds are **kept as URLs** and `remoteContent` says they exist: the engine never fetches
them, and the app must not load them unless the user asks. `text` or `html` may be empty.
Reading does not mark the message seen: the app calls `SetFlags`.

### `SaveAttachment(s message, s attachment, s path)`

Writes attachment `attachment` (an `id` from `GetMessage`) of `message` to the absolute file
`path` (written next to it, then renamed).

### `SetFlags(s ids, s add, s remove)`

`ids`: JSON array of message ids; `add`, `remove`: JSON arrays of flag names. Applied locally at
once (`MessagesChanged` with the ids as changed, `MailboxesChanged` for the counts), then on the
server.

### `Move(s ids, s mailbox)`

Moves messages to `mailbox` (same account). They are removed at once (`MessagesChanged`) and
appear in the target after the server has moved them (`MessagesChanged` there, with new ids).

### `Delete(s ids)`

Moves messages to the Trash; messages already in the Trash (or in an account without one) are
deleted for good.

### `Send(s draft) → s id`

```json
{
  "account": "4f…",
  "to": ["Charles <charles@example.org>", {"name": "Mary", "address": "mary@example.org"}],
  "cc": [], "bcc": [],
  "subject": "Re: Plans",
  "text": "plain text",
  "html": "<p>optional HTML alternative</p>",
  "attachments": ["/home/ada/plans.pdf"],
  "inReplyTo": "17"
}
```

Recipients are strings (`"Name <address>"` or `"address"`) or `{name, address}`. `inReplyTo` is
the id of the message answered: `In-Reply-To` and `References` are set and that message is
flagged answered. Attachments are read when the message is sent (25 MB each at most). The draft
is checked, then queued: the returned id is the outbox entry. Sending happens in the background;
when the server cannot be reached the message stays queued and is retried (1, 2, 4… minutes,
at most hourly; at once when the account reconnects or on `Sync`), and `SyncState` reports the
error. A copy goes to the Sent mailbox (except on Gmail, which keeps one itself).

### `Search(s query) → s ids`

Full-text search over the local index of all accounts (sender, recipients, subject, body text;
accents and case ignored; every word must match, as a prefix). Returns a JSON array of message
ids, newest first, at most 1000.

### `Sync(s account)`

Syncs the account now and retries its queued messages.

## Signals

- `AccountsChanged()`: an account was added or removed.
- `MailboxesChanged(s account)`: mailboxes or their counts changed.
- `MessagesChanged(s mailbox, s added, s removed, s changed)`: JSON arrays of message ids.
- `SyncState(s account, s state, s error)`: `state` is `connecting`, `syncing`, `idle` (up to date,
  waiting for news) or `error` (with a message in `error`; the engine retries by itself,
  with backoff from 15 seconds to 10 minutes).

## Running

`silica-mail-engine [--data-dir DIR]`. Data lives in `$XDG_DATA_HOME/silica-mail`
(`~/.local/share/silica-mail`): `mail.sqlite` (accounts without passwords, mailboxes, message
summaries, search index, queued operations, outbox) and `bodies/` (raw messages).
`RUST_LOG` sets the log level (stderr).
