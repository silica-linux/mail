//! A fake SMTP server on 127.0.0.1 without TLS, with AUTH PLAIN; it keeps what it receives.

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};

use base64::Engine as _;
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::TcpListener;

#[derive(Debug, Clone)]
pub struct Mail {
    pub from: String,
    pub to: Vec<String>,
    pub data: String,
}

pub struct FakeSmtp {
    pub port: u16,
    pub received: Arc<Mutex<Vec<Mail>>>,
    online: Arc<AtomicBool>,
}

impl FakeSmtp {
    pub async fn start(user: &str, password: &str) -> FakeSmtp {
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let port = listener.local_addr().unwrap().port();
        let received = Arc::new(Mutex::new(Vec::new()));
        let auth = format!("\0{user}\0{password}");
        let store = Arc::clone(&received);
        let online = Arc::new(AtomicBool::new(true));
        let up = Arc::clone(&online);
        tokio::spawn(async move {
            while let Ok((stream, _)) = listener.accept().await {
                let store = Arc::clone(&store);
                let online = Arc::clone(&up);
                let auth = auth.clone();
                tokio::spawn(async move {
                    let (r, mut w) = stream.into_split();
                    let mut r = BufReader::new(r);
                    if !online.load(Ordering::SeqCst) {
                        let _ = w.write_all(b"421 not available now\r\n").await;
                        return;
                    }
                    let _ = w.write_all(b"220 fake ESMTP\r\n").await;
                    let mut authed = false;
                    let mut mail = Mail {
                        from: String::new(),
                        to: Vec::new(),
                        data: String::new(),
                    };
                    loop {
                        let mut line = String::new();
                        if r.read_line(&mut line).await.unwrap_or(0) == 0 {
                            return;
                        }
                        let line = line.trim_end().to_owned();
                        let upper = line.to_ascii_uppercase();
                        let reply: String =
                            if upper.starts_with("EHLO") || upper.starts_with("HELO") {
                                "250-fake\r\n250-AUTH PLAIN\r\n250 8BITMIME\r\n".into()
                            } else if upper.starts_with("AUTH PLAIN") {
                                let given = line.get(11..).unwrap_or("").trim();
                                let decoded = base64::engine::general_purpose::STANDARD
                                    .decode(given)
                                    .unwrap_or_default();
                                if decoded == auth.as_bytes() {
                                    authed = true;
                                    "235 ok\r\n".into()
                                } else {
                                    "535 bad credentials\r\n".into()
                                }
                            } else if upper.starts_with("MAIL FROM:") {
                                if authed {
                                    mail.from = line[10..].trim().to_owned();
                                    "250 ok\r\n".into()
                                } else {
                                    "530 authentication required\r\n".into()
                                }
                            } else if upper.starts_with("RCPT TO:") {
                                mail.to.push(line[8..].trim().to_owned());
                                "250 ok\r\n".into()
                            } else if upper == "DATA" {
                                let _ = w.write_all(b"354 go on\r\n").await;
                                let mut data = String::new();
                                loop {
                                    let mut l = String::new();
                                    if r.read_line(&mut l).await.unwrap_or(0) == 0 {
                                        return;
                                    }
                                    if l == ".\r\n" {
                                        break;
                                    }
                                    data.push_str(l.strip_prefix('.').unwrap_or(&l));
                                }
                                mail.data = data;
                                store.lock().unwrap().push(mail.clone());
                                mail = Mail {
                                    from: String::new(),
                                    to: Vec::new(),
                                    data: String::new(),
                                };
                                "250 queued\r\n".into()
                            } else if upper == "QUIT" {
                                let _ = w.write_all(b"221 bye\r\n").await;
                                return;
                            } else {
                                "250 ok\r\n".into()
                            };
                        if w.write_all(reply.as_bytes()).await.is_err() {
                            return;
                        }
                    }
                });
            }
        });
        FakeSmtp {
            port,
            received,
            online,
        }
    }

    /// Off: connections are refused with a temporary error (421).
    pub fn set_online(&self, online: bool) {
        self.online.store(online, Ordering::SeqCst);
    }

    pub fn received(&self) -> Vec<Mail> {
        self.received.lock().unwrap().clone()
    }
}
