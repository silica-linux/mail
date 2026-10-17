# Changelog

## Unreleased

- UI 1.0.0 "Amalfi" (milestone 6): the window, the composer and the Add Account sheet are rebuilt
  on the Amalfi design system from the kit page `App · Mail` (silica_ui v1.0.0-alpha.5): flat
  split toolbar sections, 240 / 320 sidebar and list, card reader, Mail palette (flag, search
  highlight), light and dark. New: a Filter button (All, Unread, Flagged) and a More menu in the
  list's toolbar, search results grouped under Best Matches and All Results, a Search section in
  the sidebar, recipients as tokens, a "save as a draft?" alert when closing a changed message
  (Save waits for drafts, mail#10). The Junk toolbar button moved to the Message menu (the kit's
  triage group has three buttons); the window's minimum size is 924 × 200 (was 888 before the 36 pt toolbar controls of silica_ui 1.0.0-alpha.7).
- Menus in Silica's menu bar (silica-desktop#175): the nine menus of the reference (app, File,
  Edit, View, Mailbox, Message, Format, Window, Help) with their items, shortcuts and states,
  published with silica_ui's `SilicaMenuBar` (silica_ui 0.34.1). New Message, Reply, Reply All,
  Forward, Mark as Read / Unread, Junk, Flag, Archive, Move to, Get New Mail, Synchronize, Mark
  All as Read, Expand / Collapse All Conversations, the sidebar, Go to Mailbox and Send work
  from the bar; features Mail does not have yet are shown grayed.
- First run: with no account, the account setup opens by itself. When the settings of an
  address are not found, the servers are entered by hand. Google servers ask for an app
  password, and Microsoft servers are said not supported until sign-in through the provider
  (silica-os/mail#3).
- The engine is started through D-Bus activation. When it can't start, the window shows the
  error and a Try Again button. Sample mail appears only with `MAIL_SAMPLE_DATA=1`.
- Fixed: added accounts now carry the security (TLS or STARTTLS) of each server. The engine
  requires it, so before this fix it rejected every account added from the app.

First version of the app (silica-os/mail#2): accounts, mailboxes with unread counts, the
message list grouped by conversation, the reader with a safe HTML renderer and blocked remote
content, attachments, the composer (new, reply, reply all, forward), search, account setup,
light and dark appearance, inactive window colours, keyboard shortcuts, English and Italian.
Talks to `silica-mail-engine` over D-Bus, with sample mail when the engine is missing.
Geometry and colours are provisional until the measurements (ML-01).
