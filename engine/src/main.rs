//! `silica-mail-engine`: runs the mail service on the session bus until SIGTERM or SIGINT.
//!
//! Data lives in `$XDG_DATA_HOME/silica-mail` (`~/.local/share/silica-mail`), or in the
//! directory given with `--data-dir <dir>`.

use std::path::PathBuf;
use std::process::ExitCode;

use tokio::signal::unix::{SignalKind, signal};
use tracing::{error, info};

fn data_dir() -> Option<PathBuf> {
    let mut args = std::env::args().skip(1);
    while let Some(arg) = args.next() {
        if arg == "--data-dir" {
            return args.next().map(PathBuf::from);
        }
    }
    if let Some(dir) = std::env::var_os("XDG_DATA_HOME").filter(|d| !d.is_empty()) {
        return Some(PathBuf::from(dir).join("silica-mail"));
    }
    std::env::var_os("HOME").map(|home| PathBuf::from(home).join(".local/share/silica-mail"))
}

async fn run() -> silica_mail_engine::error::Result<()> {
    let dir = data_dir().ok_or_else(|| {
        silica_mail_engine::error::Error::Invalid(
            "no data directory: set HOME or --data-dir".into(),
        )
    })?;
    let conn = zbus::Connection::session().await?;
    let engine = silica_mail_engine::dbus::serve(&conn, dir.clone()).await?;
    info!(
        "serving {} from {}",
        silica_mail_engine::dbus::BUS_NAME,
        dir.display()
    );
    let mut term = signal(SignalKind::terminate())?;
    let mut int = signal(SignalKind::interrupt())?;
    tokio::select! {
        _ = term.recv() => {}
        _ = int.recv() => {}
    }
    engine.shutdown().await;
    info!("stopped");
    Ok(())
}

#[tokio::main]
async fn main() -> ExitCode {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| tracing_subscriber::EnvFilter::new("info")),
        )
        .with_writer(std::io::stderr)
        .init();
    match run().await {
        Ok(()) => ExitCode::SUCCESS,
        Err(err) => {
            error!("{err}");
            ExitCode::FAILURE
        }
    }
}
