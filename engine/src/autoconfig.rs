//! Finding the servers of an address (`DiscoverAccount`): the provider's autoconfig file
//! (Mozilla ISPDB format) at `autoconfig.<domain>`, the domain's well-known path and the
//! public ISPDB, then common host names probed with a quick connection. Plain-text servers are
//! ignored.

use std::time::Duration;

use crate::config::{AccountConfig, Server, Tls};
use crate::error::{Error, Result};
use crate::{http, net};

/// The autoconfig URLs to try for `address`, in order.
pub fn candidate_urls(address: &str, domain: &str) -> Vec<String> {
    vec![
        format!("https://autoconfig.{domain}/mail/config-v1.1.xml?emailaddress={address}"),
        format!("https://{domain}/.well-known/autoconfig/mail/config-v1.1.xml"),
        format!("https://autoconfig.thunderbird.net/v1.1/{domain}"),
    ]
}

fn substitute(template: &str, address: &str) -> String {
    let local = address.split('@').next().unwrap_or(address);
    let domain = address.rsplit('@').next().unwrap_or("");
    template
        .replace("%EMAILADDRESS%", address)
        .replace("%EMAILLOCALPART%", local)
        .replace("%EMAILDOMAIN%", domain)
}

fn server_of(node: roxmltree::Node<'_, '_>, address: &str) -> Option<(Server, String)> {
    let text = |tag: &str| {
        node.children()
            .find(|c| c.has_tag_name(tag))
            .and_then(|c| c.text())
            .map(str::trim)
    };
    let tls = match text("socketType")? {
        "SSL" | "TLS" => Tls::Tls,
        "STARTTLS" => Tls::Starttls,
        _ => return None,
    };
    let host = substitute(text("hostname")?, address);
    let port = text("port")?.parse::<u16>().ok()?;
    let username = text("username")
        .map(|u| substitute(u, address))
        .unwrap_or_default();
    Some((Server { host, port, tls }, username))
}

/// Reads an ISPDB `clientConfig` document. Prefers implicit TLS over STARTTLS; ignores plain.
pub fn parse_ispdb(xml: &str, address: &str) -> Option<AccountConfig> {
    let doc = roxmltree::Document::parse(xml).ok()?;
    let provider = doc
        .descendants()
        .find(|n| n.has_tag_name("emailProvider"))?;
    let pick = |tag: &str, kind: &str| {
        let mut found: Vec<(Server, String)> = provider
            .children()
            .filter(|n| n.has_tag_name(tag) && n.attribute("type") == Some(kind))
            .filter_map(|n| server_of(n, address))
            .collect();
        found.sort_by_key(|(s, _)| if s.tls == Tls::Tls { 0 } else { 1 });
        found.into_iter().next()
    };
    let (imap, username) = pick("incomingServer", "imap")?;
    let (smtp, _) = pick("outgoingServer", "smtp")?;
    let name = provider
        .children()
        .find(|c| c.has_tag_name("displayName"))
        .and_then(|c| c.text())
        .unwrap_or("")
        .trim()
        .to_owned();
    Some(AccountConfig {
        name,
        address: address.to_owned(),
        imap: Some(imap),
        smtp: Some(smtp),
        username,
        password: None,
    })
}

async fn reachable(host: &str, port: u16) -> bool {
    tokio::time::timeout(Duration::from_secs(5), net::tcp(host, port))
        .await
        .is_ok_and(|r| r.is_ok())
}

async fn guess(address: &str, domain: &str) -> Option<AccountConfig> {
    let mut imap = None;
    for (host, port, tls) in [
        (format!("imap.{domain}"), 993, Tls::Tls),
        (format!("mail.{domain}"), 993, Tls::Tls),
        (format!("imap.{domain}"), 143, Tls::Starttls),
    ] {
        if reachable(&host, port).await {
            imap = Some(Server { host, port, tls });
            break;
        }
    }
    let mut smtp = None;
    for (host, port, tls) in [
        (format!("smtp.{domain}"), 465, Tls::Tls),
        (format!("smtp.{domain}"), 587, Tls::Starttls),
        (format!("mail.{domain}"), 465, Tls::Tls),
        (format!("mail.{domain}"), 587, Tls::Starttls),
    ] {
        if reachable(&host, port).await {
            smtp = Some(Server { host, port, tls });
            break;
        }
    }
    Some(AccountConfig {
        name: String::new(),
        address: address.to_owned(),
        imap: Some(imap?),
        smtp: Some(smtp?),
        username: address.to_owned(),
        password: None,
    })
}

/// Finds the configuration of `address`, or an error the app can show.
pub async fn discover(address: &str) -> Result<AccountConfig> {
    crate::config::check_address(address)?;
    let domain = address
        .rsplit_once('@')
        .map(|(_, d)| d.to_ascii_lowercase())
        .unwrap_or_default();
    for url in candidate_urls(address, &domain) {
        if let Some(body) = http::get(&url).await
            && let Ok(text) = std::str::from_utf8(&body)
            && let Some(config) = parse_ispdb(text, address)
        {
            return Ok(config);
        }
    }
    guess(address, &domain)
        .await
        .ok_or_else(|| Error::NotFound(format!("mail servers for {domain}")))
}

#[cfg(test)]
mod tests {
    use super::*;

    const XML: &str = r#"<?xml version="1.0"?>
<clientConfig version="1.1">
  <emailProvider id="example.org">
    <domain>example.org</domain>
    <displayName>Example Mail</displayName>
    <incomingServer type="pop3">
      <hostname>pop.example.org</hostname><port>995</port><socketType>SSL</socketType>
      <username>%EMAILADDRESS%</username>
    </incomingServer>
    <incomingServer type="imap">
      <hostname>imap.example.org</hostname><port>143</port><socketType>STARTTLS</socketType>
      <username>%EMAILLOCALPART%</username>
    </incomingServer>
    <incomingServer type="imap">
      <hostname>imap.example.org</hostname><port>993</port><socketType>SSL</socketType>
      <username>%EMAILADDRESS%</username>
    </incomingServer>
    <outgoingServer type="smtp">
      <hostname>smtp.example.org</hostname><port>25</port><socketType>plain</socketType>
    </outgoingServer>
    <outgoingServer type="smtp">
      <hostname>smtp.example.org</hostname><port>587</port><socketType>STARTTLS</socketType>
    </outgoingServer>
  </emailProvider>
</clientConfig>"#;

    #[test]
    fn ispdb_prefers_tls_and_skips_plain() {
        let c = parse_ispdb(XML, "ada@example.org").unwrap();
        assert_eq!(c.name, "Example Mail");
        let imap = c.imap.unwrap();
        assert_eq!(
            (imap.host.as_str(), imap.port, imap.tls),
            ("imap.example.org", 993, Tls::Tls)
        );
        let smtp = c.smtp.unwrap();
        assert_eq!((smtp.port, smtp.tls), (587, Tls::Starttls));
        assert_eq!(c.username, "ada@example.org");
    }

    #[test]
    fn ispdb_hostile_or_incomplete() {
        assert!(parse_ispdb("<not xml", "a@b.org").is_none());
        assert!(parse_ispdb("<clientConfig/>", "a@b.org").is_none());
        let only_plain = XML.replace("SSL", "plain").replace("STARTTLS", "plain");
        assert!(parse_ispdb(&only_plain, "a@b.org").is_none());
    }

    #[test]
    fn urls() {
        let urls = candidate_urls("ada@example.org", "example.org");
        assert_eq!(urls.len(), 3);
        assert!(urls.iter().all(|u| http::parse_url(u).is_some()));
    }
}
