//! Sending: building the message from a draft (lettre) and handing it to the SMTP server with
//! implicit TLS or STARTTLS (plain text only on loopback).

use std::time::Duration;

use lettre::message::header::ContentType;
use lettre::message::{Attachment, Mailbox, MultiPart, SinglePart};
use lettre::transport::smtp::authentication::Credentials;
use lettre::{AsyncSmtpTransport, AsyncTransport, Message, Tokio1Executor};
use serde::Deserialize;

use crate::config::{Account, Tls};
use crate::error::{Error, Result};

const SEND_TIMEOUT: Duration = Duration::from_secs(120);
const MAX_ATTACHMENT: u64 = 25 * 1024 * 1024;
const MAX_RECIPIENTS: usize = 500;

/// A recipient: `"Ada <ada@example.org>"`, `"ada@example.org"` or `{name, address}`.
#[derive(Debug, Clone, PartialEq, Eq, Deserialize)]
#[serde(untagged)]
pub enum Recipient {
    Text(String),
    Person {
        #[serde(default)]
        name: String,
        address: String,
    },
}

impl Recipient {
    fn mailbox(&self) -> Result<Mailbox> {
        let parsed = match self {
            Recipient::Text(text) => text.trim().parse::<Mailbox>(),
            Recipient::Person { name, address } => address
                .trim()
                .parse()
                .map(|addr| Mailbox::new((!name.is_empty()).then(|| name.clone()), addr)),
        };
        parsed.map_err(|_| Error::Invalid(format!("{self:?} is not a valid recipient")))
    }
}

/// A message to send (`Send`).
#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Draft {
    pub account: String,
    #[serde(default)]
    pub to: Vec<Recipient>,
    #[serde(default)]
    pub cc: Vec<Recipient>,
    #[serde(default)]
    pub bcc: Vec<Recipient>,
    #[serde(default)]
    pub subject: String,
    #[serde(default)]
    pub text: String,
    #[serde(default)]
    pub html: Option<String>,
    #[serde(default)]
    pub attachments: Vec<String>,
    /// The engine id of the message this replies to.
    #[serde(default)]
    pub in_reply_to: Option<String>,
}

impl Draft {
    pub fn validate(&self) -> Result<()> {
        let count = self.to.len() + self.cc.len() + self.bcc.len();
        if count == 0 {
            return Err(Error::Invalid("the message has no recipients".into()));
        }
        if count > MAX_RECIPIENTS {
            return Err(Error::Invalid("the message has too many recipients".into()));
        }
        for r in self.to.iter().chain(&self.cc).chain(&self.bcc) {
            r.mailbox()?;
        }
        if self.subject.chars().any(|c| c == '\r' || c == '\n') {
            return Err(Error::Invalid("the subject has a line break".into()));
        }
        for path in &self.attachments {
            let meta = std::fs::metadata(path)
                .map_err(|_| Error::Invalid(format!("attachment {path} cannot be read")))?;
            if !meta.is_file() || meta.len() > MAX_ATTACHMENT {
                return Err(Error::Invalid(format!(
                    "attachment {path} is not a file or is larger than 25 MB"
                )));
            }
        }
        Ok(())
    }
}

/// The headers of the message a reply answers: its `Message-ID` and `References`.
#[derive(Debug, Clone, Default)]
pub struct ReplyTo {
    pub message_id: String,
    pub references: String,
}

fn guess_mime(path: &str) -> ContentType {
    let ext = path.rsplit('.').next().unwrap_or("").to_ascii_lowercase();
    let mime = match ext.as_str() {
        "pdf" => "application/pdf",
        "png" => "image/png",
        "jpg" | "jpeg" => "image/jpeg",
        "gif" => "image/gif",
        "txt" => "text/plain",
        "zip" => "application/zip",
        _ => "application/octet-stream",
    };
    ContentType::parse(mime).unwrap_or(ContentType::TEXT_PLAIN)
}

/// Builds the message of a draft.
pub fn build(account: &Account, draft: &Draft, reply: Option<&ReplyTo>) -> Result<Message> {
    draft.validate()?;
    let from_address = account
        .address
        .parse()
        .map_err(|_| Error::Invalid("the account address is not valid".into()))?;
    let from = Mailbox::new(
        (!account.name.is_empty()).then(|| account.name.clone()),
        from_address,
    );
    let mut builder = Message::builder()
        .from(from)
        .subject(&draft.subject)
        .date_now();
    for r in &draft.to {
        builder = builder.to(r.mailbox()?);
    }
    for r in &draft.cc {
        builder = builder.cc(r.mailbox()?);
    }
    for r in &draft.bcc {
        builder = builder.bcc(r.mailbox()?);
    }
    if let Some(reply) = reply
        && !reply.message_id.is_empty()
    {
        let id = format!("<{}>", reply.message_id);
        let refs = reply
            .references
            .split_whitespace()
            .map(|r| format!("<{r}>"))
            .chain(std::iter::once(id.clone()))
            .collect::<Vec<_>>()
            .join(" ");
        builder = builder.in_reply_to(id).references(refs);
    }
    let html = draft.html.as_deref().unwrap_or("");
    let message = if draft.attachments.is_empty() && html.is_empty() {
        builder.singlepart(SinglePart::plain(draft.text.clone()))
    } else {
        let text = SinglePart::plain(draft.text.clone());
        let body = if html.is_empty() {
            MultiPart::mixed().singlepart(text)
        } else {
            MultiPart::alternative()
                .singlepart(text)
                .singlepart(SinglePart::html(html.to_owned()))
        };
        let mut mixed = MultiPart::mixed().multipart(body);
        for path in &draft.attachments {
            let bytes = std::fs::read(path)?;
            let name = std::path::Path::new(path)
                .file_name()
                .map(|n| n.to_string_lossy().into_owned())
                .unwrap_or_else(|| "attachment".into());
            mixed = mixed.singlepart(Attachment::new(name).body(bytes, guess_mime(path)));
        }
        builder.multipart(mixed)
    };
    message.map_err(|err| Error::Invalid(format!("the message cannot be built: {err}")))
}

/// Sends a built message.
pub async fn send(account: &Account, password: &str, message: &Message) -> Result<()> {
    let server = &account.smtp;
    let smtp_err = |err: lettre::transport::smtp::Error| Error::Smtp(err.to_string());
    let builder = match server.tls {
        Tls::Tls => AsyncSmtpTransport::<Tokio1Executor>::relay(&server.host).map_err(smtp_err)?,
        Tls::Starttls => {
            AsyncSmtpTransport::<Tokio1Executor>::starttls_relay(&server.host).map_err(smtp_err)?
        }
        Tls::None => AsyncSmtpTransport::<Tokio1Executor>::builder_dangerous(&server.host),
    };
    let user = if account.username.is_empty() {
        account.address.clone()
    } else {
        account.username.clone()
    };
    let transport = builder
        .port(server.port)
        .credentials(Credentials::new(user, password.to_owned()))
        .timeout(Some(SEND_TIMEOUT))
        .build();
    tokio::time::timeout(SEND_TIMEOUT, transport.send(message.clone()))
        .await
        .map_err(|_| Error::Timeout("sending the message"))?
        .map_err(smtp_err)?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::config::Server;

    fn account() -> Account {
        let server = Server {
            host: "localhost".into(),
            port: 1,
            tls: Tls::None,
        };
        Account {
            id: "a".into(),
            name: "Ada Lovelace".into(),
            address: "ada@example.org".into(),
            provider: String::new(),
            imap: server.clone(),
            smtp: server,
            username: String::new(),
        }
    }

    fn draft(json: &str) -> Draft {
        serde_json::from_str(json).unwrap()
    }

    #[test]
    fn builds_plain_and_reply() {
        let d = draft(
            r#"{"account":"a","to":["Charles <charles@example.org>",{"name":"Team","address":"team@example.org"}],"subject":"Engine","text":"Hello"}"#,
        );
        let reply = ReplyTo {
            message_id: "root@x".into(),
            references: "a@x b@x".into(),
        };
        let m = build(&account(), &d, Some(&reply)).unwrap();
        let raw = String::from_utf8(m.formatted()).unwrap();
        assert!(raw.contains("From: \"Ada Lovelace\" <ada@example.org>"));
        assert!(raw.contains("charles@example.org"));
        assert!(raw.contains("In-Reply-To: <root@x>"));
        assert!(raw.contains("References: <a@x> <b@x> <root@x>"));
        assert!(raw.contains("Hello"));
    }

    #[test]
    fn attachments_and_html() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("notes.txt");
        std::fs::write(&path, "numbers").unwrap();
        let json = format!(
            r#"{{"account":"a","to":["c@example.org"],"subject":"x","text":"t","html":"<p>t</p>","attachments":[{:?}]}}"#,
            path.to_string_lossy()
        );
        let raw =
            String::from_utf8(build(&account(), &draft(&json), None).unwrap().formatted()).unwrap();
        assert!(raw.contains("multipart/mixed"));
        assert!(raw.contains("multipart/alternative"));
        assert!(raw.contains("notes.txt"));
    }

    #[test]
    fn invalid_drafts() {
        assert!(
            draft(r#"{"account":"a","subject":"x"}"#)
                .validate()
                .is_err()
        );
        assert!(
            draft(r#"{"account":"a","to":["not an address"]}"#)
                .validate()
                .is_err()
        );
        assert!(
            draft(r#"{"account":"a","to":["c@example.org"],"subject":"a\r\nBcc: x"}"#)
                .validate()
                .is_err()
        );
        assert!(
            draft(r#"{"account":"a","to":["c@example.org"],"attachments":["/nonexistent"]}"#)
                .validate()
                .is_err()
        );
        assert!(
            draft(r#"{"account":"a","to":["c@example.org"],"attachments":["/"]}"#)
                .validate()
                .is_err()
        );
    }
}
