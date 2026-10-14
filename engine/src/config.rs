//! Account configuration as the app sends it (`AddAccount`) and as the engine stores it (the
//! password never: it lives in the Secret Service).

use serde::{Deserialize, Serialize};

use crate::error::{Error, Result};

/// How a connection is secured. `None` is accepted only for loopback hosts (tests and local
/// development): mail credentials never travel in clear over a network.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Tls {
    /// Implicit TLS from the first byte (IMAP 993, SMTP 465).
    Tls,
    /// Plain connection upgraded with STARTTLS (IMAP 143, SMTP 587).
    Starttls,
    /// No encryption: loopback hosts only.
    None,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Server {
    pub host: String,
    pub port: u16,
    pub tls: Tls,
}

/// The configuration received from the app; `password` is taken out before storing.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct AccountConfig {
    #[serde(default)]
    pub name: String,
    pub address: String,
    pub imap: Option<Server>,
    pub smtp: Option<Server>,
    #[serde(default)]
    pub username: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub password: Option<String>,
}

/// What the store keeps for an account.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Account {
    pub id: String,
    pub name: String,
    pub address: String,
    pub provider: String,
    pub imap: Server,
    pub smtp: Server,
    pub username: String,
}

const MAX_FIELD: usize = 512;

fn check_text(what: &str, value: &str) -> Result<()> {
    if value.len() > MAX_FIELD || value.chars().any(|c| c.is_control()) {
        return Err(Error::Invalid(format!("{what} is not valid")));
    }
    Ok(())
}

/// A host name that is safe to put in a connection and in IMAP/SMTP commands.
fn check_host(host: &str) -> Result<()> {
    let ok = !host.is_empty()
        && host.len() <= 253
        && host
            .chars()
            .all(|c| c.is_ascii_alphanumeric() || matches!(c, '.' | '-' | ':' | '[' | ']'));
    if ok {
        Ok(())
    } else {
        Err(Error::Invalid(format!(
            "server name \"{host}\" is not valid"
        )))
    }
}

/// Whether `host` is the local machine (where an unencrypted connection is tolerated).
pub fn is_loopback(host: &str) -> bool {
    let trimmed = host.trim_start_matches('[').trim_end_matches(']');
    trimmed == "localhost"
        || trimmed
            .parse::<std::net::IpAddr>()
            .is_ok_and(|ip| ip.is_loopback())
}

fn check_server(what: &str, server: &Server) -> Result<()> {
    check_host(&server.host)?;
    if server.port == 0 {
        return Err(Error::Invalid(format!("{what} port is not valid")));
    }
    if server.tls == Tls::None && !is_loopback(&server.host) {
        return Err(Error::Invalid(format!(
            "{what} without encryption is allowed only on this computer"
        )));
    }
    Ok(())
}

/// A plausible e-mail address: local part, one `@`, a domain with a dot (or `localhost`).
pub fn check_address(address: &str) -> Result<()> {
    check_text("the address", address)?;
    let Some((local, domain)) = address.rsplit_once('@') else {
        return Err(Error::Invalid(format!(
            "\"{address}\" is not an e-mail address"
        )));
    };
    let domain_ok = domain == "localhost" || (domain.contains('.') && !domain.starts_with('.'));
    if local.is_empty() || !domain_ok || address.chars().any(char::is_whitespace) {
        return Err(Error::Invalid(format!(
            "\"{address}\" is not an e-mail address"
        )));
    }
    check_host(domain)
}

impl AccountConfig {
    /// Validates a configuration from the app.
    pub fn validate(&self) -> Result<(&Server, &Server)> {
        check_address(&self.address)?;
        check_text("the name", &self.name)?;
        check_text("the user name", &self.username)?;
        let imap = self
            .imap
            .as_ref()
            .ok_or_else(|| Error::Invalid("the incoming (IMAP) server is missing".into()))?;
        let smtp = self
            .smtp
            .as_ref()
            .ok_or_else(|| Error::Invalid("the outgoing (SMTP) server is missing".into()))?;
        check_server("the incoming server", imap)?;
        check_server("the outgoing server", smtp)?;
        if let Some(password) = &self.password
            && password.len() > 4096
        {
            return Err(Error::Invalid("the password is too long".into()));
        }
        Ok((imap, smtp))
    }

    /// The user name to log in with: the configured one, or the address.
    pub fn login_name(&self) -> &str {
        if self.username.is_empty() {
            &self.address
        } else {
            &self.username
        }
    }
}

/// A short provider label from the server host (`imap.gmail.com` → `gmail.com`).
pub fn provider_of(host: &str) -> String {
    let parts: Vec<&str> = host.split('.').filter(|p| !p.is_empty()).collect();
    match parts.len() {
        0 => String::new(),
        1 => host.to_owned(),
        n => parts
            .get(n.saturating_sub(2)..)
            .map_or_else(String::new, |p| p.join(".")),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn config(tls: Tls, host: &str) -> AccountConfig {
        AccountConfig {
            name: "Ada".into(),
            address: "ada@example.org".into(),
            imap: Some(Server {
                host: host.into(),
                port: 993,
                tls,
            }),
            smtp: Some(Server {
                host: host.into(),
                port: 465,
                tls,
            }),
            username: String::new(),
            password: Some("secret".into()),
        }
    }

    #[test]
    fn plain_text_only_on_loopback() {
        assert!(config(Tls::Tls, "imap.example.org").validate().is_ok());
        assert!(config(Tls::None, "imap.example.org").validate().is_err());
        assert!(config(Tls::None, "127.0.0.1").validate().is_ok());
        assert!(config(Tls::None, "localhost").validate().is_ok());
        assert!(config(Tls::None, "[::1]").validate().is_ok());
    }

    #[test]
    fn hostile_values_are_refused() {
        assert!(
            config(Tls::Tls, "imap.example.org\r\nRCPT")
                .validate()
                .is_err()
        );
        assert!(config(Tls::Tls, "").validate().is_err());
        let mut bad = config(Tls::Tls, "imap.example.org");
        bad.address = "not an address".into();
        assert!(bad.validate().is_err());
        bad.address = "a@b".into();
        assert!(bad.validate().is_err());
        assert!(check_address("ada@example.org").is_ok());
    }

    #[test]
    fn login_name_and_provider() {
        let c = config(Tls::Tls, "imap.mail.example.org");
        assert_eq!(c.login_name(), "ada@example.org");
        assert_eq!(provider_of("imap.gmail.com"), "gmail.com");
        assert_eq!(provider_of("localhost"), "localhost");
    }
}
