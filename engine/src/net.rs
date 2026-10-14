//! Connections: TCP with implicit TLS, STARTTLS upgrades and (loopback only) plain text, behind
//! one stream type, with timeouts on everything.

use std::pin::Pin;
use std::sync::Arc;
use std::task::{Context, Poll};
use std::time::Duration;

use tokio::io::{AsyncRead, AsyncWrite, ReadBuf};
use tokio::net::TcpStream;
use tokio_rustls::TlsConnector;
use tokio_rustls::client::TlsStream;
use tokio_rustls::rustls::pki_types::ServerName;
use tokio_rustls::rustls::{ClientConfig, RootCertStore};

use crate::error::{Error, Result};

/// How long to wait for a connection or a TLS handshake.
pub const CONNECT_TIMEOUT: Duration = Duration::from_secs(20);

/// A connection to a mail server, encrypted or (loopback only) plain.
#[derive(Debug)]
pub enum MailStream {
    Plain(TcpStream),
    Tls(Box<TlsStream<TcpStream>>),
}

impl AsyncRead for MailStream {
    fn poll_read(
        self: Pin<&mut Self>,
        cx: &mut Context<'_>,
        buf: &mut ReadBuf<'_>,
    ) -> Poll<std::io::Result<()>> {
        match self.get_mut() {
            MailStream::Plain(s) => Pin::new(s).poll_read(cx, buf),
            MailStream::Tls(s) => Pin::new(s.as_mut()).poll_read(cx, buf),
        }
    }
}

impl AsyncWrite for MailStream {
    fn poll_write(
        self: Pin<&mut Self>,
        cx: &mut Context<'_>,
        buf: &[u8],
    ) -> Poll<std::io::Result<usize>> {
        match self.get_mut() {
            MailStream::Plain(s) => Pin::new(s).poll_write(cx, buf),
            MailStream::Tls(s) => Pin::new(s.as_mut()).poll_write(cx, buf),
        }
    }

    fn poll_flush(self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<std::io::Result<()>> {
        match self.get_mut() {
            MailStream::Plain(s) => Pin::new(s).poll_flush(cx),
            MailStream::Tls(s) => Pin::new(s.as_mut()).poll_flush(cx),
        }
    }

    fn poll_shutdown(self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<std::io::Result<()>> {
        match self.get_mut() {
            MailStream::Plain(s) => Pin::new(s).poll_shutdown(cx),
            MailStream::Tls(s) => Pin::new(s.as_mut()).poll_shutdown(cx),
        }
    }
}

/// The TLS client configuration with the system's root certificates.
pub fn tls_config() -> Result<Arc<ClientConfig>> {
    let mut roots = RootCertStore::empty();
    let found = rustls_native_certs::load_native_certs();
    for cert in found.certs {
        // A single unreadable certificate does not stop the others.
        let _ = roots.add(cert);
    }
    if roots.is_empty() {
        return Err(Error::Invalid(
            "no system certificates found: cannot verify mail servers".into(),
        ));
    }
    let provider = Arc::new(tokio_rustls::rustls::crypto::ring::default_provider());
    let config = ClientConfig::builder_with_provider(provider)
        .with_safe_default_protocol_versions()
        .map_err(|err| Error::Invalid(format!("TLS setup: {err}")))?
        .with_root_certificates(roots)
        .with_no_client_auth();
    Ok(Arc::new(config))
}

/// Opens a TCP connection with a timeout.
pub async fn tcp(host: &str, port: u16) -> Result<TcpStream> {
    let host_only = host.trim_start_matches('[').trim_end_matches(']');
    let stream = tokio::time::timeout(CONNECT_TIMEOUT, TcpStream::connect((host_only, port)))
        .await
        .map_err(|_| Error::Timeout("connecting to the server"))??;
    stream.set_nodelay(true)?;
    Ok(stream)
}

/// Wraps an open connection in TLS, verifying `host`.
pub async fn upgrade(stream: TcpStream, host: &str) -> Result<MailStream> {
    let host_only = host.trim_start_matches('[').trim_end_matches(']');
    let name = ServerName::try_from(host_only.to_owned())
        .map_err(|_| Error::Invalid(format!("server name \"{host}\" is not valid")))?;
    let connector = TlsConnector::from(tls_config()?);
    let tls = tokio::time::timeout(CONNECT_TIMEOUT, connector.connect(name, stream))
        .await
        .map_err(|_| Error::Timeout("TLS handshake"))??;
    Ok(MailStream::Tls(Box::new(tls)))
}

/// Connects with implicit TLS.
pub async fn connect_tls(host: &str, port: u16) -> Result<MailStream> {
    let stream = tcp(host, port).await?;
    upgrade(stream, host).await
}
