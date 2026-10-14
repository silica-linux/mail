//! Test fixtures: a private D-Bus daemon, a fake Secret Service, fake IMAP and SMTP servers on
//! loopback, and a client for the engine's D-Bus API.

#![allow(
    dead_code,
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing
)]

pub mod imap;
pub mod secrets;
pub mod smtp;

use std::future::Future;
use std::io::{BufRead, BufReader};
use std::process::{Child, Command, Stdio};
use std::time::{Duration, Instant};

use serde::Serialize;
use zbus::Connection;
use zbus::zvariant::DynamicType;

/// A private session bus that lives as long as the value.
pub struct Bus {
    child: Child,
    address: String,
    _dir: tempfile::TempDir,
}

impl Bus {
    pub fn start() -> Bus {
        let dir = tempfile::tempdir().unwrap();
        let config = dir.path().join("bus.conf");
        std::fs::write(
            &config,
            format!(
                r#"<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-Bus Bus Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>
  <type>session</type>
  <listen>unix:path={}/bus</listen>
  <policy context="default">
    <allow send_destination="*" eavesdrop="true"/>
    <allow eavesdrop="true"/>
    <allow own="*"/>
  </policy>
</busconfig>
"#,
                dir.path().display()
            ),
        )
        .unwrap();
        let mut child = Command::new("dbus-daemon")
            .arg(format!("--config-file={}", config.display()))
            .arg("--nofork")
            .arg("--print-address")
            .stdout(Stdio::piped())
            .spawn()
            .expect("dbus-daemon is needed by the integration tests");
        let mut address = String::new();
        BufReader::new(child.stdout.take().unwrap())
            .read_line(&mut address)
            .unwrap();
        Bus {
            child,
            address: address.trim().to_owned(),
            _dir: dir,
        }
    }

    pub async fn connect(&self) -> Connection {
        zbus::connection::Builder::address(self.address.as_str())
            .unwrap()
            .build()
            .await
            .unwrap()
    }
}

impl Drop for Bus {
    fn drop(&mut self) {
        let _ = self.child.kill();
        let _ = self.child.wait();
    }
}

/// The app's side of the D-Bus API.
pub struct App {
    pub proxy: zbus::Proxy<'static>,
}

impl App {
    pub async fn new(conn: &Connection) -> App {
        let proxy = zbus::Proxy::new(
            conn,
            "dev.frascella.Mail",
            "/dev/frascella/Mail1",
            "dev.frascella.Mail1",
        )
        .await
        .unwrap();
        App { proxy }
    }

    /// A method that returns JSON, parsed.
    pub async fn json<B>(&self, method: &str, body: &B) -> zbus::Result<serde_json::Value>
    where
        B: Serialize + DynamicType,
    {
        let text: String = self.proxy.call(method, body).await?;
        Ok(serde_json::from_str(&text).unwrap())
    }

    pub async fn string<B>(&self, method: &str, body: &B) -> zbus::Result<String>
    where
        B: Serialize + DynamicType,
    {
        self.proxy.call(method, body).await
    }

    pub async fn unit<B>(&self, method: &str, body: &B) -> zbus::Result<()>
    where
        B: Serialize + DynamicType,
    {
        self.proxy.call(method, body).await
    }
}

/// Polls `f` until it gives a value (30 s at most).
pub async fn eventually<T, F, Fut>(what: &str, mut f: F) -> T
where
    F: FnMut() -> Fut,
    Fut: Future<Output = Option<T>>,
{
    let deadline = Instant::now() + Duration::from_secs(30);
    loop {
        if let Some(value) = f().await {
            return value;
        }
        if Instant::now() > deadline {
            panic!("timed out waiting for {what}");
        }
        tokio::time::sleep(Duration::from_millis(50)).await;
    }
}
