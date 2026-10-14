//! The engine's error type. Every failure that reaches D-Bus becomes a readable message for
//! the app; nothing in here panics.

use std::fmt;

#[derive(Debug)]
pub enum Error {
    /// Network or file system.
    Io(std::io::Error),
    /// The IMAP server refused or misbehaved.
    Imap(String),
    /// The SMTP server refused or misbehaved.
    Smtp(String),
    /// The local store.
    Store(String),
    /// The Secret Service is missing, locked or refused.
    Secret(String),
    /// A configuration or request from the app is not valid.
    Invalid(String),
    /// Something asked for does not exist.
    NotFound(String),
    /// An operation took too long.
    Timeout(&'static str),
}

pub type Result<T> = std::result::Result<T, Error>;

impl fmt::Display for Error {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Error::Io(err) => write!(f, "network or file error: {err}"),
            Error::Imap(msg) => write!(f, "IMAP: {msg}"),
            Error::Smtp(msg) => write!(f, "SMTP: {msg}"),
            Error::Store(msg) => write!(f, "local store: {msg}"),
            Error::Secret(msg) => write!(f, "keyring: {msg}"),
            Error::Invalid(msg) => write!(f, "{msg}"),
            Error::NotFound(what) => write!(f, "not found: {what}"),
            Error::Timeout(what) => write!(f, "timed out: {what}"),
        }
    }
}

impl std::error::Error for Error {}

impl From<std::io::Error> for Error {
    fn from(err: std::io::Error) -> Self {
        Error::Io(err)
    }
}

impl From<rusqlite::Error> for Error {
    fn from(err: rusqlite::Error) -> Self {
        Error::Store(err.to_string())
    }
}

impl From<async_imap::error::Error> for Error {
    fn from(err: async_imap::error::Error) -> Self {
        Error::Imap(err.to_string())
    }
}

impl From<serde_json::Error> for Error {
    fn from(err: serde_json::Error) -> Self {
        Error::Invalid(format!("invalid JSON: {err}"))
    }
}

impl From<zbus::Error> for Error {
    fn from(err: zbus::Error) -> Self {
        Error::Secret(err.to_string())
    }
}

impl From<tokio::time::error::Elapsed> for Error {
    fn from(_: tokio::time::error::Elapsed) -> Self {
        Error::Timeout("network operation")
    }
}

impl From<Error> for zbus::fdo::Error {
    fn from(err: Error) -> Self {
        zbus::fdo::Error::Failed(err.to_string())
    }
}
