# Changelog

## Unreleased

- Menus in Silica's menu bar (silica-desktop#175): the nine menus of the reference (app, File,
  Edit, View, Mailbox, Message, Format, Window, Help) with their items, shortcuts and states,
  published with silica_ui's `SilicaMenuBar` (silica_ui 0.34.1). New Message, Reply, Reply All,
  Forward, Mark as Read / Unread, Junk, Flag, Archive, Move to, Get New Mail, Synchronize, Mark
  All as Read, Expand / Collapse All Conversations, the sidebar, Go to Mailbox and Send work
  from the bar; features Mail does not have yet are shown grayed.
- First run: with no account, the account setup opens by itself. When the settings of an
  address are not found, the servers are entered by hand. Google servers ask for an app
  password, and Microsoft servers are said not supported until sign-in through the provider
  (silica-linux/mail#3).
- The engine is started through D-Bus activation. When it can't start, the window shows the
  error and a Try Again button. Sample mail appears only with `MAIL_SAMPLE_DATA=1`.
- Fixed: added accounts now carry the security (TLS or STARTTLS) of each server. The engine
  requires it, so before this fix it rejected every account added from the app.

First version of the app (silica-linux/mail#2): accounts, mailboxes with unread counts, the
message list grouped by conversation, the reader with a safe HTML renderer and blocked remote
content, attachments, the composer (new, reply, reply all, forward), search, account setup,
light and dark appearance, inactive window colours, keyboard shortcuts, English and Italian.
Talks to `silica-mail-engine` over D-Bus, with sample mail when the engine is missing.
Geometry and colours are provisional until the measurements (ML-01).
