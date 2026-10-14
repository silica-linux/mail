//! A fake Secret Service (`org.freedesktop.secrets`): an in-memory default collection, plain
//! sessions, no locking.

use std::collections::HashMap;
use std::sync::{Arc, Mutex};

use zbus::object_server::ObjectServer;
use zbus::zvariant::{OwnedObjectPath, OwnedValue, Value};
use zbus::{Connection, fdo};

type Secret = (OwnedObjectPath, Vec<u8>, Vec<u8>, String);

#[derive(Debug, Clone)]
pub struct Item {
    pub path: String,
    pub label: String,
    pub attributes: HashMap<String, String>,
    pub secret: Vec<u8>,
}

#[derive(Default)]
pub struct Vault {
    pub items: Mutex<Vec<Item>>,
    next: Mutex<u32>,
}

impl Vault {
    pub fn items(&self) -> Vec<Item> {
        self.items.lock().unwrap().clone()
    }
}

fn path(p: &str) -> OwnedObjectPath {
    OwnedObjectPath::try_from(p.to_owned()).unwrap()
}

struct Service(Arc<Vault>);

#[zbus::interface(name = "org.freedesktop.Secret.Service")]
impl Service {
    fn open_session(
        &self,
        _algorithm: &str,
        _input: OwnedValue,
    ) -> (Value<'static>, OwnedObjectPath) {
        (Value::from(""), path("/org/freedesktop/secrets/session/1"))
    }

    fn search_items(
        &self,
        attributes: HashMap<String, String>,
    ) -> (Vec<OwnedObjectPath>, Vec<OwnedObjectPath>) {
        let found = self
            .0
            .items()
            .into_iter()
            .filter(|item| {
                attributes
                    .iter()
                    .all(|(k, v)| item.attributes.get(k) == Some(v))
            })
            .map(|item| path(&item.path))
            .collect();
        (found, Vec::new())
    }

    fn get_secrets(
        &self,
        items: Vec<OwnedObjectPath>,
        session: OwnedObjectPath,
    ) -> HashMap<OwnedObjectPath, Secret> {
        self.0
            .items()
            .into_iter()
            .filter(|item| items.iter().any(|p| p.as_str() == item.path))
            .map(|item| {
                (
                    path(&item.path),
                    (
                        session.clone(),
                        Vec::new(),
                        item.secret,
                        "text/plain".into(),
                    ),
                )
            })
            .collect()
    }
}

struct Collection(Arc<Vault>);

#[zbus::interface(name = "org.freedesktop.Secret.Collection")]
impl Collection {
    async fn create_item(
        &self,
        properties: HashMap<String, OwnedValue>,
        secret: Secret,
        replace: bool,
        #[zbus(object_server)] server: &ObjectServer,
    ) -> fdo::Result<(OwnedObjectPath, OwnedObjectPath)> {
        let attributes: HashMap<String, String> = properties
            .get("org.freedesktop.Secret.Item.Attributes")
            .map(|v| HashMap::try_from(v.try_clone().unwrap()).unwrap())
            .unwrap_or_default();
        let label: String = properties
            .get("org.freedesktop.Secret.Item.Label")
            .map(|v| String::try_from(v.try_clone().unwrap()).unwrap())
            .unwrap_or_default();
        let item_path = {
            let mut next = self.0.next.lock().unwrap();
            *next += 1;
            format!("/org/freedesktop/secrets/collection/login/{next}")
        };
        {
            let mut items = self.0.items.lock().unwrap();
            if replace {
                items.retain(|item| item.attributes != attributes);
            }
            items.push(Item {
                path: item_path.clone(),
                label,
                attributes,
                secret: secret.2,
            });
        }
        server
            .at(
                item_path.as_str(),
                ItemObject {
                    vault: Arc::clone(&self.0),
                    path: item_path.clone(),
                },
            )
            .await?;
        Ok((path(&item_path), path("/")))
    }
}

struct ItemObject {
    vault: Arc<Vault>,
    path: String,
}

#[zbus::interface(name = "org.freedesktop.Secret.Item")]
impl ItemObject {
    fn delete(&self) -> OwnedObjectPath {
        self.vault
            .items
            .lock()
            .unwrap()
            .retain(|item| item.path != self.path);
        path("/")
    }
}

/// Serves a fake Secret Service on `conn` (which must stay alive).
pub async fn serve(conn: &Connection) -> Arc<Vault> {
    let vault = Arc::new(Vault::default());
    conn.object_server()
        .at("/org/freedesktop/secrets", Service(Arc::clone(&vault)))
        .await
        .unwrap();
    conn.object_server()
        .at(
            "/org/freedesktop/secrets/aliases/default",
            Collection(Arc::clone(&vault)),
        )
        .await
        .unwrap();
    conn.request_name("org.freedesktop.secrets").await.unwrap();
    vault
}
