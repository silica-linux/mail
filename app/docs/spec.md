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
  the shared glass toolbar (silica-os/silica-ui#2).
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
| Search / end search | ⌘F or ⌥⌘F / Escape |
| Previous / next conversation | ↑ / ↓ |
| Send / close the composer | ⌘⇧Enter or ⌘⇧D / Escape or ⌘W |

## Menus

Mail publishes nine menus to Silica's menu bar (silica-ui `SilicaMenuBar`, silica-desktop#175;
`lib/src/menus.dart`), as measured in ML-01 (MENU-01): the app menu, File, Edit, View, Mailbox,
Message, Format, Window and Help, with the measured items, separators and shortcuts. The ⌘
shortcuts are the menu bar's. Items keep their place in every state; only the enabled state,
the checkmarks and a few labels change. An item for a feature Mail does not have is shown
grayed, never hidden and never wired to something else.

Working items, by menu:

- **Mail**: Accounts… and Add Account… (the account setup), Services, Hide, Hide Others, Show
  All and Quit (the bar's).
- **File**: New Message ⌘N; Close ⌘W (the composer while it is open, the window otherwise).
- **Edit**: Undo, Redo, Cut, Copy, Paste and Select All act on the text field with the
  keyboard (the composer, the search field); Delete ⌘⌫ deletes the selected message; Mailbox
  Search ⌥⌘F and Find… ⌘F start the mailbox search (a search inside one message does not exist
  yet).
- **View**: Hide / Show Sidebar ⌃⌘S, Expand All and Collapse All Conversations, Enter Full
  Screen. Sort By shows Date and Newest Message on Top checked, Organize by Conversation
  checked: that is how the list always works.
- **Mailbox**: Get New Mail ⇧⌘N and Synchronize "account" (sync), Mark All Messages as Read,
  Go to Favorite Mailbox ⌘1 Inbox, ⌘2 Sent, Move to Favorite Mailbox ⌃⌘1 / ⌃⌘2 (of the
  shown account), Go to Previous / Next Mailbox ⌃⌘[ / ⌃⌘] (the sidebar's order).
- **Message**: in the viewer Reply ⌘R, Reply All ⇧⌘R, Forward ⇧⌘F, Mark as Unread / Mark as
  Read ⇧⌘U, Move to Junk ⇧⌘J, Flag › Orange (the flag), Clear Flag and Toggle Flag ⇧⌘L,
  Archive ⌃⌘A, Move to › (any mailbox of any account); with the composer open the first slot is
  Send ⇧⌘D (grayed until there is a recipient) instead of Send Again, and the viewer's actions
  are grayed.
- **Window**: the bar's part (Minimize, Fill, Move & Resize, Full screen, Bring All to Front,
  the list of windows) is added after Mail's own items, which therefore come first, not last
  as measured (the bar owns the order).

Grayed for now (features that do not exist): About and Settings; New Viewer Window, Open
Message, Save, Save As, Attach Files, Save Attachments, Quick Look, Import and Export
Mailboxes, Export as PDF, Print; Complete, Paste as Quotation, Add Link, the attachment
preferences, Find Next / Previous, the writing, spelling, substitution, speech, AutoFill,
dictation and emoji items; tabs, the message filter, sorting and layout choices, the
categories and priority items, the Cc / Bcc / Reply-To / Priority fields, the message source
and headers, the toolbar items; Erase Deleted Items and Junk, mailbox management, Rebuild;
Send Again, Send Later, Forward as Attachment, Redirect, reminders, Mute, the other flag
colours, Set Priority, Move to Predicted Mailbox, Copy to, Move Again, Apply Rules, Add Sender
to Contacts, Categorize Sender, Remove Attachments; the whole Format menu; Message Viewer,
Photo Browser, Previous Recipients, Activity, Connection Doctor; Mail Help and What's New. The
alternate items (⌥ variants such as Quit and Keep Windows or Close All) are not offered, and
neither are the insert-from-device item (a feature of another system) and the favourites' per
account children.

## Not yet

- Measured layout (ML-01), glass toolbar (silica-ui#2).
- Moving messages to any mailbox by drag and drop, multiple selection, rules, signatures, rich
  text composing, attachments in the composer, `mailto:` links, notifications of new mail,
  OAuth2 accounts (mail#3).
