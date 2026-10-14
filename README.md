<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset=".github/silica-logo-dark.svg">
    <img alt="Silica" src=".github/silica-logo-light.svg" width="200">
  </picture>
</p>

<h1 align="center">Mail</h1>

<p align="center">
  <b>The mail app of Silica.</b><br>
  IMAP and SMTP accounts, offline mailbox, fast search and a calm reading experience.
</p>

<p align="center">
  <img alt="Rust: engine" src="https://img.shields.io/badge/Rust-engine-b7410e?style=flat-square&logo=rust">
  <img alt="Flutter: app" src="https://img.shields.io/badge/Flutter-app-02569B?style=flat-square&logo=flutter">
  <img alt="license: MIT / Apache-2.0" src="https://img.shields.io/badge/license-MIT%20%2F%20Apache--2.0-3a3a3a?style=flat-square">
  <img alt="status: planned" src="https://img.shields.io/badge/status-planned-8a8a8a?style=flat-square">
</p>

| Part | What it does |
| --- | --- |
| `engine/` | `silica-mail-engine`, a Rust service on the session bus (`dev.frascella.Mail1`): IMAP sync, SMTP sending, offline store, search index, credentials in the Secret Service keyring |
| `app/` | the Flutter app on [`silica_ui`](https://github.com/silica-linux/silica-ui), talking to the engine over D-Bus |

App id `dev.frascella.Mail`, icon `mail` from silica-icons. Behaviors and measurements come from
observations in silica-reference (clean-room: nothing copied, texts and graphics are our own).

## License

MIT OR Apache-2.0.
