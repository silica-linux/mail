# Mail · specification

What the app does and how it behaves. Measured values come from silica-reference (ML-01); until
the measurements arrive, geometry and colours are provisional (`lib/src/style.dart`,
[`parity.md`](parity.md)).

## Engine

The app talks only to `silica-mail-engine` (`engine/`), on the session bus: name
`dev.frascella.Mail`, object `/dev/frascella/Mail1`, interface `dev.frascella.Mail1`, every
argument and reply a JSON string.

| Method | Arguments → reply |
| --- | --- |
| `ListAccounts` | → `[{id, name, address}]` |
| `DiscoverAccount` | `address` → `{address, name, imap{host,port}, smtp{host,port}, username}` |
| `AddAccount` | config with `password` → `id` (the engine keeps the password in the Secret Service) |
| `RemoveAccount` | `id` |
| `ListMailboxes` | `account` → `[{id, account, name, role, unread, total}]` |
| `ListMessages` | `{mailbox, offset, limit, threads, ids?}` → rows `[{id, thread, from, to, subject, preview, date, flags, attachments}]` |
| `GetMessage` | `id` → `{headers, from, to, cc, subject, date, text, html, attachments, remoteContent}` |
| `SaveAttachment` | `message`, `attachment`, `path` |
| `SetFlags` | `ids`, `add`, `remove` (`seen`, `flagged`, `answered`, `draft`) |
| `Move`, `Delete` | `ids` (+ `mailbox`) |
| `Send` | draft `{account, to, cc, bcc, subject, text, html?, attachments, inReplyTo?}` → `id` |
| `Search` | `{text, mailbox?}` → `[id]` |
| `Sync` | `account` |

Signals: `AccountsChanged`, `MailboxesChanged(account)`, `MessagesChanged(mailbox, added,
removed, changed)`, `SyncState(account, state, error)`.

`ids` in the `ListMessages` query is an addition of the app: it returns the rows of the given
messages in any mailbox (the results of `Search`).

Without the engine (not installed, outside Silica) the app shows generated sample mail and a
banner says so.

## Window

- **Sidebar** (220 pt, provisional): the top 52 pt moves the window; then, per account, a heading
  and its mailboxes (role names translated: Inbox, Drafts, Sent, Archive, Junk, Trash; other
  folders by their server name) with the unread count.
- **Toolbar** (52 pt, unified with the window): mailbox title and message count; New Message;
  Reply, Reply All, Forward; Archive, Delete, Flag; Search (the capsule becomes a field). Inactive
  window: dim title and glyphs. The toolbar is an overlay; the content starts under it, ready for
  the shared glass toolbar (silica-linux/silica-ui#2).
- **List** (360 pt): one row per conversation, newest first: sender (semibold when unread),
  date (time today, Yesterday, then the date), count of messages in the conversation, flag and
  attachment marks, subject, two lines of preview, an unread dot on the left. Selection fill:
  accent when the window is active, grey when inactive.
- **Reader**: the whole conversation, newest first; for each message the sender, date and time,
  subject, To and Cc, the body and the attachments (click: saved in Downloads by the engine).
- Selecting a conversation marks its unread messages read.

## Safety

- HTML: no scripts, styles, forms or frames; text, links, emphasis, headings, lists, quotes and
  preformatted text are kept.
- Remote content (images, backgrounds, stylesheets on the network) is not loaded until the user
  clicks Load Content for that message.
- Links open with the system handler (`xdg-open`) and only for `http`, `https` and `mailto`.
- The password goes to the engine once and is never stored by the app.

## Commands and shortcuts

| Command | Shortcut |
| --- | --- |
| New message | ⌘N |
| Reply / Reply all / Forward | ⌘R / ⌘⇧R / ⌘⇧F |
| Delete (to the Trash; from the Trash, for good) | Delete, Backspace |
| Search / end search | ⌘F / Escape |
| Previous / next conversation | ↑ / ↓ |
| Send / close the composer | ⌘⇧Enter / Escape |

## Not yet

- Measured layout (ML-01), glass toolbar (silica-ui#2).
- Moving messages to any mailbox by drag and drop, multiple selection, rules, signatures, rich
  text composing, attachments in the composer, `mailto:` links, notifications of new mail,
  OAuth2 accounts (mail#3).
