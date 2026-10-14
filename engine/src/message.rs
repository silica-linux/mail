//! Reading messages: the fields the store keeps (sender, recipients, subject, preview, thread),
//! the text for the search index, and the full view for `GetMessage` with sanitized HTML.

use std::collections::BTreeMap;
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};

use mail_parser::{Address, HeaderValue, Message, MessageParser, MimeHeaders};
use serde::{Deserialize, Serialize};

/// The longest preview shown in the message list.
pub const PREVIEW_CHARS: usize = 200;
/// The most body text put in the search index per message.
const INDEX_CHARS: usize = 64 * 1024;

#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct Person {
    pub name: String,
    pub address: String,
}

/// What the store needs from a message.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct Summary {
    pub message_id: String,
    pub references: Vec<String>,
    pub thread: String,
    pub from: Person,
    pub to: Vec<Person>,
    pub cc: Vec<Person>,
    pub subject: String,
    pub preview: String,
    pub date: i64,
    pub attachments: u32,
    /// Plain text of the body for the search index.
    pub index_text: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct Attachment {
    pub id: String,
    pub name: String,
    pub mime: String,
    pub size: usize,
}

/// The full message for the reader.
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct Detail {
    pub headers: BTreeMap<String, String>,
    pub from: Person,
    pub to: Vec<Person>,
    pub cc: Vec<Person>,
    pub subject: String,
    pub date: i64,
    pub text: String,
    pub html: String,
    pub attachments: Vec<Attachment>,
    #[serde(rename = "remoteContent")]
    pub remote_content: bool,
}

fn clean(text: &str, max: usize) -> String {
    text.chars()
        .map(|c| if c.is_control() && c != '\n' { ' ' } else { c })
        .take(max)
        .collect()
}

fn people(address: Option<&Address<'_>>) -> Vec<Person> {
    address
        .map(|a| {
            a.iter()
                .take(500)
                .map(|addr| Person {
                    name: clean(addr.name().unwrap_or(""), 256),
                    address: clean(addr.address().unwrap_or(""), 320),
                })
                .collect()
        })
        .unwrap_or_default()
}

fn normalize_id(id: &str) -> String {
    id.trim()
        .trim_start_matches('<')
        .trim_end_matches('>')
        .to_ascii_lowercase()
}

fn ids(value: &HeaderValue<'_>) -> Vec<String> {
    let list: Vec<String> = match value {
        HeaderValue::Text(t) => vec![t.to_string()],
        HeaderValue::TextList(l) => l.iter().map(|t| t.to_string()).collect(),
        _ => Vec::new(),
    };
    list.iter()
        .flat_map(|s| s.split_whitespace().map(normalize_id).collect::<Vec<_>>())
        .filter(|s| !s.is_empty() && s.len() <= 998)
        .take(100)
        .collect()
}

/// Collapses whitespace for previews and the index.
fn squash(text: &str, max: usize) -> String {
    let mut out = String::new();
    for word in text.split_whitespace() {
        if !out.is_empty() {
            out.push(' ');
        }
        out.push_str(word);
        if out.chars().count() >= max {
            break;
        }
    }
    out.chars().take(max).collect()
}

/// Text from HTML for previews and the index (tags removed, entities left as they are).
fn html_to_text(html: &str) -> String {
    let mut out = String::with_capacity(html.len() / 2);
    let mut in_tag = false;
    let mut skip_until: Option<&str> = None;
    let lower = html.to_ascii_lowercase();
    let mut i = 0;
    let bytes = html.as_bytes();
    while i < bytes.len() {
        if let Some(end) = skip_until {
            match lower.get(i..).and_then(|rest| rest.find(end)) {
                Some(pos) => {
                    i += pos + end.len();
                    skip_until = None;
                }
                None => break,
            }
            continue;
        }
        let c = bytes.get(i).copied().unwrap_or(b' ');
        if c == b'<' {
            if lower.get(i..).is_some_and(|r| r.starts_with("<style")) {
                skip_until = Some("</style>");
                continue;
            }
            if lower.get(i..).is_some_and(|r| r.starts_with("<script")) {
                skip_until = Some("</script>");
                continue;
            }
            in_tag = true;
            out.push(' ');
        } else if c == b'>' {
            in_tag = false;
        } else if !in_tag {
            // Copy whole UTF-8 characters.
            let ch_len = html
                .get(i..)
                .and_then(|r| r.chars().next())
                .map_or(1, char::len_utf8);
            if let Some(s) = html.get(i..i + ch_len) {
                out.push_str(s);
            }
            i += ch_len;
            continue;
        }
        i += 1;
    }
    out.replace("&nbsp;", " ")
        .replace("&amp;", "&")
        .replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&quot;", "\"")
}

fn body_text(message: &Message<'_>) -> String {
    if let Some(text) = message.body_text(0) {
        return text.into_owned();
    }
    message
        .body_html(0)
        .map(|html| html_to_text(&html))
        .unwrap_or_default()
}

/// The thread a message belongs to: the first reference (the root of the conversation), else
/// the message it replies to, else itself.
fn thread_of(message_id: &str, references: &[String], in_reply_to: &[String]) -> String {
    references
        .first()
        .or_else(|| in_reply_to.first())
        .cloned()
        .unwrap_or_else(|| message_id.to_owned())
}

/// Parses a raw message; None if it is not a message at all.
pub fn parse(raw: &[u8]) -> Option<Message<'_>> {
    MessageParser::default().parse(raw)
}

/// The summary of a raw message for the store.
pub fn summarize(raw: &[u8], fallback_date: i64) -> Summary {
    let Some(message) = parse(raw) else {
        return Summary {
            date: fallback_date,
            ..Summary::default()
        };
    };
    let message_id = message.message_id().map(normalize_id).unwrap_or_default();
    let references = ids(message.references());
    let in_reply_to = ids(message.in_reply_to());
    let text = body_text(&message);
    let date = message
        .date()
        .map(mail_parser::DateTime::to_timestamp)
        .filter(|d| *d > 0)
        .unwrap_or(fallback_date);
    Summary {
        thread: thread_of(&message_id, &references, &in_reply_to),
        message_id,
        references,
        from: people(message.from())
            .into_iter()
            .next()
            .unwrap_or_default(),
        to: people(message.to()),
        cc: people(message.cc()),
        subject: clean(message.subject().unwrap_or(""), 998),
        preview: squash(&text, PREVIEW_CHARS),
        date,
        attachments: u32::try_from(message.attachment_count()).unwrap_or(u32::MAX),
        index_text: squash(&text, INDEX_CHARS),
    }
}

/// Sanitizes HTML for display: no scripts, styles kept inline, links and images kept as URLs
/// (the engine never fetches them; the app decides). Returns the HTML and whether it refers to
/// remote content.
pub fn sanitize_html(html: &str) -> (String, bool) {
    let remote = Arc::new(AtomicBool::new(false));
    let seen = Arc::clone(&remote);
    let mut builder = ammonia::Builder::default();
    builder
        .add_generic_attributes([
            "style", "align", "valign", "width", "height", "bgcolor", "color",
        ])
        .add_tags(["font", "center"])
        .add_tag_attributes("img", ["src", "alt", "width", "height"])
        .url_schemes(
            ["http", "https", "mailto", "cid", "data"]
                .into_iter()
                .collect(),
        )
        .link_rel(Some("noopener noreferrer"))
        .attribute_filter(move |element, attribute, value| {
            let is_url = matches!(attribute, "src" | "background")
                || (attribute == "style" && value.contains("url("));
            let lower = value.to_ascii_lowercase();
            if is_url
                && (lower.contains("http:") || lower.contains("https:") || lower.contains("//"))
                && element != "a"
            {
                seen.store(true, Ordering::Relaxed);
            }
            Some(value.into())
        });
    let cleaned = builder.clean(html).to_string();
    (cleaned, remote.load(Ordering::Relaxed))
}

/// The full view of a raw message.
pub fn detail(raw: &[u8], fallback_date: i64) -> Option<Detail> {
    let message = parse(raw)?;
    let mut headers = BTreeMap::new();
    for (name, value) in message.headers_raw().take(200) {
        let key = name.to_ascii_lowercase();
        if matches!(
            key.as_str(),
            "from"
                | "to"
                | "cc"
                | "reply-to"
                | "subject"
                | "date"
                | "message-id"
                | "in-reply-to"
                | "references"
                | "list-unsubscribe"
                | "list-id"
                | "sender"
        ) {
            headers.insert(key, clean(value.trim(), 4096));
        }
    }
    let html = message
        .body_html(0)
        .map(|h| h.into_owned())
        .unwrap_or_default();
    let (html, remote_content) = if html.is_empty() {
        (String::new(), false)
    } else {
        sanitize_html(&html)
    };
    let attachments = message
        .attachments()
        .enumerate()
        .take(1000)
        .map(|(i, part)| Attachment {
            id: i.to_string(),
            name: clean(part.attachment_name().unwrap_or("attachment"), 255),
            mime: part
                .content_type()
                .map(|ct| match ct.subtype() {
                    Some(sub) => format!("{}/{}", ct.ctype(), sub),
                    None => ct.ctype().to_owned(),
                })
                .unwrap_or_else(|| "application/octet-stream".to_owned()),
            size: part.contents().len(),
        })
        .collect();
    Some(Detail {
        headers,
        from: people(message.from())
            .into_iter()
            .next()
            .unwrap_or_default(),
        to: people(message.to()),
        cc: people(message.cc()),
        subject: clean(message.subject().unwrap_or(""), 998),
        date: message
            .date()
            .map(mail_parser::DateTime::to_timestamp)
            .filter(|d| *d > 0)
            .unwrap_or(fallback_date),
        text: message
            .body_text(0)
            .map(|t| t.into_owned())
            .unwrap_or_default(),
        html,
        attachments,
        remote_content,
    })
}

/// The bytes and name of attachment number `index` of a raw message.
pub fn attachment(raw: &[u8], index: usize) -> Option<(String, Vec<u8>)> {
    let message = parse(raw)?;
    let part = message.attachments().nth(index)?;
    Some((
        part.attachment_name().unwrap_or("attachment").to_owned(),
        part.contents().to_vec(),
    ))
}

#[cfg(test)]
mod tests {
    use super::*;

    const MAIL: &[u8] = b"From: Ada Lovelace <ada@example.org>\r\n\
To: Charles <charles@example.org>, team@example.org\r\n\
Subject: Notes on the engine\r\n\
Date: Wed, 14 Oct 2026 10:00:00 +0000\r\n\
Message-ID: <Reply-1@example.org>\r\n\
In-Reply-To: <root@example.org>\r\n\
References: <ROOT@example.org> <reply-0@example.org>\r\n\
MIME-Version: 1.0\r\n\
Content-Type: multipart/mixed; boundary=b\r\n\
\r\n\
--b\r\n\
Content-Type: text/plain; charset=utf-8\r\n\
\r\n\
Hello   Charles,\r\nthe analytical engine works.\r\n\
--b\r\n\
Content-Type: text/plain; name=notes.txt\r\n\
Content-Disposition: attachment; filename=notes.txt\r\n\
\r\n\
numbers\r\n\
--b--\r\n";

    #[test]
    fn summary_fields_thread_and_preview() {
        let s = summarize(MAIL, 0);
        assert_eq!(
            s.from,
            Person {
                name: "Ada Lovelace".into(),
                address: "ada@example.org".into()
            }
        );
        assert_eq!(s.to.len(), 2);
        assert_eq!(s.subject, "Notes on the engine");
        assert_eq!(s.message_id, "reply-1@example.org");
        assert_eq!(s.thread, "root@example.org");
        assert_eq!(s.preview, "Hello Charles, the analytical engine works.");
        assert_eq!(s.attachments, 1);
        assert_eq!(s.date, 1_791_972_000);
    }

    #[test]
    fn detail_and_attachment() {
        let d = detail(MAIL, 0).unwrap();
        assert_eq!(d.attachments.len(), 1);
        assert_eq!(d.attachments[0].name, "notes.txt");
        assert!(d.text.contains("analytical engine"));
        let (name, bytes) = attachment(MAIL, 0).unwrap();
        assert_eq!(
            (name.as_str(), bytes.as_slice()),
            ("notes.txt", &b"numbers"[..])
        );
        assert!(attachment(MAIL, 5).is_none());
    }

    #[test]
    fn html_is_sanitized_and_remote_content_detected() {
        let (html, remote) = sanitize_html(
            r#"<p onclick="evil()">Hi<script>alert(1)</script><img src="https://tracker.example/p.gif"></p><a href="javascript:x">x</a>"#,
        );
        assert!(!html.contains("script"));
        assert!(!html.contains("onclick"));
        assert!(!html.contains("javascript"));
        assert!(remote);
        let (_, remote) = sanitize_html(r#"<p>Hi <a href="https://example.org">link</a></p>"#);
        assert!(!remote);
    }

    #[test]
    fn garbage_and_html_only() {
        let s = summarize(b"\x00\x01 not a message", 42);
        assert_eq!(s.date, 42);
        let html_only = b"Subject: x\r\nContent-Type: text/html\r\n\r\n<style>p{}</style><p>Hello <b>world</b></p>";
        assert_eq!(summarize(html_only, 0).preview, "Hello world");
    }
}
