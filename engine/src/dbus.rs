//! The D-Bus service `dev.frascella.Mail` (see `docs/dbus-api.md`). Every payload is JSON in a
//! string; errors come back as `org.freedesktop.DBus.Error.Failed` with a message to show.

use std::path::PathBuf;
use std::sync::Arc;

use zbus::Connection;
use zbus::fdo;
use zbus::object_server::SignalEmitter;

use crate::engine::Engine;
use crate::error::Result;

pub const BUS_NAME: &str = "dev.frascella.Mail";
pub const OBJECT_PATH: &str = "/dev/frascella/Mail1";

pub struct MailService {
    engine: Arc<Engine>,
}

#[zbus::interface(name = "dev.frascella.Mail1")]
impl MailService {
    fn list_accounts(&self) -> fdo::Result<String> {
        Ok(self.engine.list_accounts()?)
    }

    async fn add_account(&self, config: String) -> fdo::Result<String> {
        Ok(self.engine.add_account(&config).await?)
    }

    async fn discover_account(&self, address: String) -> fdo::Result<String> {
        Ok(self.engine.discover(&address).await?)
    }

    async fn remove_account(&self, id: String) -> fdo::Result<()> {
        Ok(self.engine.remove_account(&id).await?)
    }

    fn list_mailboxes(&self, account: String) -> fdo::Result<String> {
        Ok(self.engine.list_mailboxes(&account)?)
    }

    fn list_messages(&self, query: String) -> fdo::Result<String> {
        Ok(self.engine.list_messages(&query)?)
    }

    fn get_message(&self, id: String) -> fdo::Result<String> {
        Ok(self.engine.get_message(&id)?)
    }

    fn save_attachment(
        &self,
        message: String,
        attachment: String,
        path: String,
    ) -> fdo::Result<()> {
        Ok(self.engine.save_attachment(&message, &attachment, &path)?)
    }

    async fn set_flags(&self, ids: String, add: String, remove: String) -> fdo::Result<()> {
        Ok(self.engine.set_flags(&ids, &add, &remove).await?)
    }

    #[zbus(name = "Move")]
    async fn move_messages(&self, ids: String, mailbox: String) -> fdo::Result<()> {
        Ok(self.engine.move_messages(&ids, &mailbox).await?)
    }

    async fn delete(&self, ids: String) -> fdo::Result<()> {
        Ok(self.engine.delete(&ids).await?)
    }

    async fn send(&self, draft: String) -> fdo::Result<String> {
        Ok(self.engine.send(&draft).await?)
    }

    fn search(&self, query: String) -> fdo::Result<String> {
        Ok(self.engine.search(&query)?)
    }

    async fn sync(&self, account: String) -> fdo::Result<()> {
        Ok(self.engine.sync(&account).await?)
    }

    #[zbus(signal)]
    pub async fn accounts_changed(emitter: &SignalEmitter<'_>) -> zbus::Result<()>;

    #[zbus(signal)]
    pub async fn mailboxes_changed(emitter: &SignalEmitter<'_>, account: &str) -> zbus::Result<()>;

    #[zbus(signal)]
    pub async fn messages_changed(
        emitter: &SignalEmitter<'_>,
        mailbox: &str,
        added: &str,
        removed: &str,
        changed: &str,
    ) -> zbus::Result<()>;

    #[zbus(signal)]
    pub async fn sync_state(
        emitter: &SignalEmitter<'_>,
        account: &str,
        state: &str,
        error: &str,
    ) -> zbus::Result<()>;
}

/// Opens the store in `data_dir`, exports the service on `conn`, takes the bus name and starts
/// the workers.
pub async fn serve(conn: &Connection, data_dir: PathBuf) -> Result<Arc<Engine>> {
    let engine = Arc::new(Engine::new(conn.clone(), data_dir)?);
    conn.object_server()
        .at(
            OBJECT_PATH,
            MailService {
                engine: Arc::clone(&engine),
            },
        )
        .await?;
    conn.request_name(BUS_NAME).await?;
    engine.start().await?;
    Ok(engine)
}
