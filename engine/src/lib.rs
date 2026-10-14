//! `silica-mail-engine`: the mail engine of Silica. IMAP synchronization, SMTP sending, an
//! offline store with full-text search, and a D-Bus API (`dev.frascella.Mail1`) for the app.

pub mod autoconfig;
pub mod config;
pub mod dbus;
pub mod engine;
pub mod error;
pub mod http;
pub mod imap;
pub mod message;
pub mod mutf7;
pub mod net;
pub mod secrets;
pub mod smtp;
pub mod store;
