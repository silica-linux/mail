//! Passwords in the Secret Service (`org.freedesktop.secrets`, the keyring of the session):
//! one item per account in the default collection, attributes `application=silica-mail` and
//! `account=<id>`. A "plain" session is used: the secret travels only on the local session bus.
//! Without a Secret Service the engine refuses to keep a password.

use std::collections::HashMap;
use std::time::Duration;

use futures::StreamExt;
use zbus::Connection;
use zbus::zvariant::{OwnedObjectPath, OwnedValue, Value};

use crate::error::{Error, Result};

const DEST: &str = "org.freedesktop.secrets";
const SERVICE_PATH: &str = "/org/freedesktop/secrets";
const SERVICE: &str = "org.freedesktop.Secret.Service";
const COLLECTION: &str = "org.freedesktop.Secret.Collection";
const ITEM: &str = "org.freedesktop.Secret.Item";
const PROMPT: &str = "org.freedesktop.Secret.Prompt";
const DEFAULT_COLLECTION: &str = "/org/freedesktop/secrets/aliases/default";
const APPLICATION: &str = "silica-mail";
const PROMPT_TIMEOUT: Duration = Duration::from_secs(120);

/// `(session, parameters, value, content type)` as the Secret Service wants it.
type Secret = (OwnedObjectPath, Vec<u8>, Vec<u8>, String);

fn attributes(account: &str) -> HashMap<&str, &str> {
    HashMap::from([("application", APPLICATION), ("account", account)])
}

fn unavailable(err: zbus::Error) -> Error {
    Error::Secret(format!(
        "no keyring is available to keep the password safely ({err}); start one (e.g. GNOME Keyring or KeePassXC with Secret Service)"
    ))
}

/// The keyring of the session.
#[derive(Clone)]
pub struct Keyring {
    conn: Connection,
}

impl Keyring {
    pub fn new(conn: Connection) -> Self {
        Keyring { conn }
    }

    async fn call<B, R>(&self, path: &str, iface: &str, method: &str, body: &B) -> Result<R>
    where
        B: serde::Serialize + zbus::zvariant::DynamicType,
        R: for<'d> serde::Deserialize<'d> + zbus::zvariant::Type,
    {
        let reply = self
            .conn
            .call_method(Some(DEST), path, Some(iface), method, body)
            .await
            .map_err(unavailable)?;
        reply
            .body()
            .deserialize::<R>()
            .map_err(|err| Error::Secret(format!("unexpected keyring reply: {err}")))
    }

    async fn session(&self) -> Result<OwnedObjectPath> {
        let (_, session): (OwnedValue, OwnedObjectPath) = self
            .call(
                SERVICE_PATH,
                SERVICE,
                "OpenSession",
                &("plain", Value::from("")),
            )
            .await?;
        Ok(session)
    }

    /// Runs a prompt (an unlock dialog of the keyring) and waits for it to finish.
    async fn prompt(&self, prompt: &OwnedObjectPath) -> Result<()> {
        if prompt.as_str() == "/" {
            return Ok(());
        }
        let proxy = zbus::Proxy::new(&self.conn, DEST, prompt.as_str(), PROMPT)
            .await
            .map_err(unavailable)?;
        let mut completed = proxy
            .receive_signal("Completed")
            .await
            .map_err(unavailable)?;
        proxy
            .call_method("Prompt", &(""))
            .await
            .map_err(unavailable)?;
        let message = tokio::time::timeout(PROMPT_TIMEOUT, completed.next())
            .await
            .map_err(|_| Error::Timeout("keyring prompt"))?
            .ok_or_else(|| Error::Secret("the keyring prompt went away".into()))?;
        let (dismissed, _): (bool, OwnedValue) = message
            .body()
            .deserialize()
            .map_err(|err| Error::Secret(format!("unexpected prompt reply: {err}")))?;
        if dismissed {
            return Err(Error::Secret("the keyring was not unlocked".into()));
        }
        Ok(())
    }

    async fn find(&self, account: &str) -> Result<Vec<OwnedObjectPath>> {
        let (mut unlocked, locked): (Vec<OwnedObjectPath>, Vec<OwnedObjectPath>) = self
            .call(
                SERVICE_PATH,
                SERVICE,
                "SearchItems",
                &(attributes(account),),
            )
            .await?;
        if !locked.is_empty() {
            let (now_unlocked, prompt): (Vec<OwnedObjectPath>, OwnedObjectPath) = self
                .call(SERVICE_PATH, SERVICE, "Unlock", &(locked.clone(),))
                .await?;
            unlocked.extend(now_unlocked);
            self.prompt(&prompt).await?;
            if prompt.as_str() != "/" {
                unlocked.extend(locked);
            }
        }
        Ok(unlocked)
    }

    /// Stores (or replaces) the password of `account`.
    pub async fn store(&self, account: &str, label: &str, password: &str) -> Result<()> {
        let session = self.session().await?;
        let mut properties: HashMap<&str, Value<'_>> = HashMap::new();
        properties.insert(
            "org.freedesktop.Secret.Item.Label",
            Value::from(format!("Mail: {label}")),
        );
        properties.insert(
            "org.freedesktop.Secret.Item.Attributes",
            Value::from(attributes(account)),
        );
        let secret: Secret = (
            session,
            Vec::new(),
            password.as_bytes().to_vec(),
            "text/plain".to_owned(),
        );
        let (_, prompt): (OwnedObjectPath, OwnedObjectPath) = self
            .call(
                DEFAULT_COLLECTION,
                COLLECTION,
                "CreateItem",
                &(properties, secret, true),
            )
            .await?;
        self.prompt(&prompt).await
    }

    /// The password of `account`.
    pub async fn get(&self, account: &str) -> Result<String> {
        let items = self.find(account).await?;
        let first = items.first().ok_or_else(|| {
            Error::Secret("the password of this account is not in the keyring".into())
        })?;
        let session = self.session().await?;
        let secrets: HashMap<OwnedObjectPath, Secret> = self
            .call(
                SERVICE_PATH,
                SERVICE,
                "GetSecrets",
                &(vec![first.clone()], session),
            )
            .await?;
        let (_, _, value, _) = secrets
            .get(first)
            .ok_or_else(|| Error::Secret("the keyring returned no password".into()))?;
        String::from_utf8(value.clone())
            .map_err(|_| Error::Secret("the password is not text".into()))
    }

    /// Deletes the password of `account` (nothing to do if there is none).
    pub async fn delete(&self, account: &str) -> Result<()> {
        for item in self.find(account).await? {
            let prompt: OwnedObjectPath = self.call(item.as_str(), ITEM, "Delete", &()).await?;
            self.prompt(&prompt).await?;
        }
        Ok(())
    }
}
