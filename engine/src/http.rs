//! A minimal HTTPS GET for account autoconfiguration: TLS only, bounded size, few redirects.
//! Nothing else in the engine talks HTTP (remote images are never fetched).

use std::time::Duration;

use tokio::io::{AsyncReadExt, AsyncWriteExt};

use crate::error::{Error, Result};
use crate::net;

const MAX_BODY: usize = 256 * 1024;
const MAX_REDIRECTS: usize = 3;
const TIMEOUT: Duration = Duration::from_secs(15);

/// An `https://host/path` URL split in parts.
#[derive(Debug, PartialEq, Eq)]
pub struct Url {
    pub host: String,
    pub path: String,
}

/// Parses `https://` URLs only (redirects to `http://` are refused).
pub fn parse_url(url: &str) -> Option<Url> {
    let rest = url.strip_prefix("https://")?;
    let (host, path) = match rest.find('/') {
        Some(i) => (rest.get(..i)?, rest.get(i..)?),
        None => (rest, "/"),
    };
    let host_ok = !host.is_empty()
        && host
            .chars()
            .all(|c| c.is_ascii_alphanumeric() || matches!(c, '.' | '-'));
    let path_ok = path.chars().all(|c| c.is_ascii_graphic());
    (host_ok && path_ok).then(|| Url {
        host: host.to_owned(),
        path: path.to_owned(),
    })
}

/// A parsed HTTP response: status, a redirect target, the body.
#[derive(Debug, PartialEq, Eq)]
pub struct Response {
    pub status: u16,
    pub location: Option<String>,
    pub body: Vec<u8>,
}

/// Parses a raw HTTP/1.1 response (content-length, chunked or until close).
pub fn parse_response(raw: &[u8]) -> Result<Response> {
    let bad = || Error::Invalid("malformed HTTP response".into());
    let split = raw
        .windows(4)
        .position(|w| w == b"\r\n\r\n")
        .ok_or_else(bad)?;
    let head = std::str::from_utf8(raw.get(..split).ok_or_else(bad)?).map_err(|_| bad())?;
    let body = raw.get(split + 4..).ok_or_else(bad)?;
    let mut lines = head.split("\r\n");
    let status_line = lines.next().ok_or_else(bad)?;
    let status = status_line
        .split_whitespace()
        .nth(1)
        .and_then(|s| s.parse::<u16>().ok())
        .ok_or_else(bad)?;
    let mut location = None;
    let mut chunked = false;
    let mut length = None;
    for line in lines {
        let Some((name, value)) = line.split_once(':') else {
            continue;
        };
        let value = value.trim();
        match name.trim().to_ascii_lowercase().as_str() {
            "location" => location = Some(value.to_owned()),
            "transfer-encoding" => chunked = value.eq_ignore_ascii_case("chunked"),
            "content-length" => length = value.parse::<usize>().ok(),
            _ => {}
        }
    }
    let body = if chunked {
        dechunk(body)?
    } else if let Some(n) = length {
        body.get(..n.min(body.len())).ok_or_else(bad)?.to_vec()
    } else {
        body.to_vec()
    };
    Ok(Response {
        status,
        location,
        body,
    })
}

fn dechunk(mut data: &[u8]) -> Result<Vec<u8>> {
    let bad = || Error::Invalid("malformed chunked body".into());
    let mut out = Vec::new();
    loop {
        let line_end = data.windows(2).position(|w| w == b"\r\n").ok_or_else(bad)?;
        let size_text =
            std::str::from_utf8(data.get(..line_end).ok_or_else(bad)?).map_err(|_| bad())?;
        let size_text = size_text.split(';').next().unwrap_or("").trim();
        let size = usize::from_str_radix(size_text, 16).map_err(|_| bad())?;
        let start = line_end + 2;
        if size == 0 {
            return Ok(out);
        }
        let end = start.checked_add(size).ok_or_else(bad)?;
        out.extend_from_slice(data.get(start..end).ok_or_else(bad)?);
        if out.len() > MAX_BODY {
            return Err(Error::Invalid("HTTP body too large".into()));
        }
        data = data.get(end + 2..).ok_or_else(bad)?;
    }
}

async fn get_once(url: &Url) -> Result<Response> {
    let mut stream = net::connect_tls(&url.host, 443).await?;
    let request = format!(
        "GET {} HTTP/1.1\r\nHost: {}\r\nUser-Agent: silica-mail-engine\r\nAccept: application/xml, text/xml\r\nConnection: close\r\n\r\n",
        url.path, url.host
    );
    stream.write_all(request.as_bytes()).await?;
    let mut raw = Vec::new();
    let mut limited = (&mut stream).take((MAX_BODY + 16 * 1024) as u64);
    limited.read_to_end(&mut raw).await?;
    parse_response(&raw)
}

/// GETs an https URL, following up to three https redirects. None on any failure or non-200.
pub async fn get(url: &str) -> Option<Vec<u8>> {
    let mut current = parse_url(url)?;
    for _ in 0..=MAX_REDIRECTS {
        let response = tokio::time::timeout(TIMEOUT, get_once(&current))
            .await
            .ok()?
            .ok()?;
        match response.status {
            200 => return Some(response.body),
            301 | 302 | 303 | 307 | 308 => {
                let next = response.location?;
                current = if next.starts_with('/') {
                    Url {
                        host: current.host,
                        path: next,
                    }
                } else {
                    parse_url(&next)?
                };
            }
            _ => return None,
        }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn urls_are_https_only() {
        assert_eq!(
            parse_url("https://autoconfig.example.org/mail/config-v1.1.xml?emailaddress=a@b.org"),
            Some(Url {
                host: "autoconfig.example.org".into(),
                path: "/mail/config-v1.1.xml?emailaddress=a@b.org".into()
            })
        );
        assert_eq!(parse_url("http://example.org/"), None);
        assert_eq!(parse_url("https://exa mple.org/"), None);
        assert_eq!(parse_url("https://example.org/a b"), None);
    }

    #[test]
    fn responses_with_length_chunks_and_redirects() {
        let r = parse_response(b"HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nhello world").unwrap();
        assert_eq!((r.status, r.body.as_slice()), (200, &b"hello"[..]));
        let r = parse_response(
            b"HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nhello\r\n6\r\n world\r\n0\r\n\r\n",
        )
        .unwrap();
        assert_eq!(r.body, b"hello world");
        let r = parse_response(b"HTTP/1.1 301 Moved\r\nLocation: https://x.org/y\r\n\r\n").unwrap();
        assert_eq!(r.location.as_deref(), Some("https://x.org/y"));
        assert!(parse_response(b"garbage").is_err());
        assert!(
            parse_response(b"HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\nzz\r\n").is_err()
        );
    }
}
