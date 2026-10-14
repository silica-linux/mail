//! A fake IMAP server on 127.0.0.1 without TLS: just the commands the engine uses (LOGIN,
//! CAPABILITY, LIST, SELECT, UID SEARCH/FETCH/STORE/MOVE/EXPUNGE, APPEND, IDLE, LOGOUT).

use std::collections::{BTreeMap, BTreeSet};
use std::sync::{Arc, Mutex};

use tokio::io::{AsyncBufReadExt, AsyncReadExt, AsyncWriteExt, BufReader};
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::watch;

#[derive(Debug, Clone)]
pub struct Msg {
    pub uid: u32,
    pub flags: BTreeSet<String>,
    pub raw: Vec<u8>,
}

#[derive(Debug, Clone)]
pub struct Folder {
    pub attributes: String,
    pub uidnext: u32,
    pub messages: Vec<Msg>,
}

pub struct FakeImap {
    pub port: u16,
    pub folders: Arc<Mutex<BTreeMap<String, Folder>>>,
    news: watch::Sender<u64>,
}

impl FakeImap {
    /// Starts a server with the given folders (`(name, special-use attribute)`).
    pub async fn start(user: &str, password: &str, folders: &[(&str, &str)]) -> FakeImap {
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let port = listener.local_addr().unwrap().port();
        let map = folders
            .iter()
            .map(|(name, attr)| {
                (
                    (*name).to_owned(),
                    Folder {
                        attributes: (*attr).to_owned(),
                        uidnext: 1,
                        messages: Vec::new(),
                    },
                )
            })
            .collect();
        let folders = Arc::new(Mutex::new(map));
        let (news, _) = watch::channel(0);
        let server = FakeImap {
            port,
            folders: Arc::clone(&folders),
            news: news.clone(),
        };
        let credentials = (user.to_owned(), password.to_owned());
        tokio::spawn(async move {
            while let Ok((stream, _)) = listener.accept().await {
                let session = Session {
                    folders: Arc::clone(&folders),
                    news: news.clone(),
                    credentials: credentials.clone(),
                    selected: None,
                };
                let rx = news.subscribe();
                tokio::spawn(session.run(stream, rx));
            }
        });
        server
    }

    /// Delivers a message to a folder (and tells idling clients).
    pub fn deliver(&self, folder: &str, raw: &[u8], flags: &[&str]) -> u32 {
        let uid = add(
            &mut self.folders.lock().unwrap(),
            folder,
            raw.to_vec(),
            flags.iter().map(|f| (*f).to_owned()).collect(),
        );
        self.news.send_modify(|n| *n += 1);
        uid
    }

    pub fn messages(&self, folder: &str) -> Vec<Msg> {
        self.folders.lock().unwrap()[folder].messages.clone()
    }
}

fn add(
    folders: &mut BTreeMap<String, Folder>,
    folder: &str,
    raw: Vec<u8>,
    flags: BTreeSet<String>,
) -> u32 {
    let folder = folders.get_mut(folder).unwrap();
    let uid = folder.uidnext;
    folder.uidnext += 1;
    folder.messages.push(Msg { uid, flags, raw });
    uid
}

/// Words of a command line: atoms and quoted strings.
fn words(s: &str) -> Vec<String> {
    let mut out = Vec::new();
    let mut chars = s.chars().peekable();
    while let Some(&c) = chars.peek() {
        if c == ' ' {
            chars.next();
        } else if c == '"' {
            chars.next();
            let mut word = String::new();
            while let Some(c) = chars.next() {
                match c {
                    '\\' => word.extend(chars.next()),
                    '"' => break,
                    c => word.push(c),
                }
            }
            out.push(word);
        } else {
            let mut word = String::new();
            while let Some(&c) = chars.peek() {
                if c == ' ' {
                    break;
                }
                word.push(c);
                chars.next();
            }
            out.push(word);
        }
    }
    out
}

/// Whether `uid` is in an IMAP sequence set like `1:3,7,9:*`.
fn in_set(set: &str, uid: u32) -> bool {
    let num = |s: &str| {
        if s == "*" {
            u32::MAX
        } else {
            s.parse().unwrap_or(0)
        }
    };
    set.split(',').any(|part| match part.split_once(':') {
        Some((a, b)) => {
            let (a, b) = (num(a), num(b));
            (a.min(b)..=a.max(b)).contains(&uid)
        }
        None => num(part) == uid,
    })
}

fn flag_list(flags: &BTreeSet<String>) -> String {
    flags.iter().cloned().collect::<Vec<_>>().join(" ")
}

fn parse_flags(s: &str) -> BTreeSet<String> {
    s.trim_matches(|c| c == '(' || c == ')')
        .split_whitespace()
        .map(str::to_owned)
        .collect()
}

struct Session {
    folders: Arc<Mutex<BTreeMap<String, Folder>>>,
    news: watch::Sender<u64>,
    credentials: (String, String),
    selected: Option<String>,
}

impl Session {
    async fn run(mut self, stream: TcpStream, mut news: watch::Receiver<u64>) {
        let (r, mut w) = stream.into_split();
        let mut r = BufReader::new(r);
        if w.write_all(b"* OK fake IMAP ready\r\n").await.is_err() {
            return;
        }
        let mut buf = Vec::new();
        loop {
            buf.clear();
            if r.read_until(b'\n', &mut buf).await.unwrap_or(0) == 0 {
                return;
            }
            let line = String::from_utf8_lossy(&buf).trim_end().to_owned();
            let Some((tag, rest)) = line.split_once(' ') else {
                continue;
            };
            let tag = tag.to_owned();
            let (command, args) = rest.split_once(' ').unwrap_or((rest, ""));
            let command = command.to_ascii_uppercase();
            let out: Vec<u8> = match command.as_str() {
                "CAPABILITY" => {
                    format!("* CAPABILITY IMAP4rev1 IDLE MOVE UIDPLUS\r\n{tag} OK done\r\n")
                        .into_bytes()
                }
                "NOOP" => format!("{tag} OK done\r\n").into_bytes(),
                "LOGOUT" => {
                    let _ = w
                        .write_all(format!("* BYE bye\r\n{tag} OK done\r\n").as_bytes())
                        .await;
                    return;
                }
                "LOGIN" => {
                    let w2 = words(args);
                    if w2.first() == Some(&self.credentials.0)
                        && w2.get(1) == Some(&self.credentials.1)
                    {
                        format!("{tag} OK logged in\r\n").into_bytes()
                    } else {
                        format!("{tag} NO [AUTHENTICATIONFAILED] invalid credentials\r\n")
                            .into_bytes()
                    }
                }
                "LIST" => {
                    let mut out = String::new();
                    for (name, folder) in self.folders.lock().unwrap().iter() {
                        let attrs = format!("\\HasNoChildren {}", folder.attributes);
                        out.push_str(&format!("* LIST ({}) \"/\" \"{name}\"\r\n", attrs.trim()));
                    }
                    out.push_str(&format!("{tag} OK done\r\n"));
                    out.into_bytes()
                }
                "SELECT" | "EXAMINE" => {
                    let name = words(args).into_iter().next().unwrap_or_default();
                    let folders = self.folders.lock().unwrap();
                    match folders.get(&name) {
                        Some(folder) => {
                            self.selected = Some(name.clone());
                            format!(
                                "* FLAGS (\\Answered \\Flagged \\Deleted \\Seen \\Draft)\r\n\
                                 * {} EXISTS\r\n* 0 RECENT\r\n\
                                 * OK [UIDVALIDITY 1] valid\r\n* OK [UIDNEXT {}] next\r\n\
                                 {tag} OK [READ-WRITE] selected\r\n",
                                folder.messages.len(),
                                folder.uidnext
                            )
                            .into_bytes()
                        }
                        None => format!("{tag} NO no such mailbox\r\n").into_bytes(),
                    }
                }
                "APPEND" => {
                    let open = args.rfind('{').unwrap();
                    let size: usize = args[open + 1..]
                        .trim_end_matches('}')
                        .trim_end_matches('+')
                        .parse()
                        .unwrap();
                    let head = &args[..open];
                    let name = words(head).into_iter().next().unwrap_or_default();
                    let flags = head
                        .find('(')
                        .map(|i| parse_flags(&head[i..head.rfind(')').unwrap() + 1]))
                        .unwrap_or_default();
                    if !args.ends_with("+}") && w.write_all(b"+ ready\r\n").await.is_err() {
                        return;
                    }
                    let mut raw = vec![0; size];
                    if r.read_exact(&mut raw).await.is_err() {
                        return;
                    }
                    buf.clear();
                    let _ = r.read_until(b'\n', &mut buf).await;
                    let known = self.folders.lock().unwrap().contains_key(&name);
                    if known {
                        let uid = add(&mut self.folders.lock().unwrap(), &name, raw, flags);
                        self.news.send_modify(|n| *n += 1);
                        format!("{tag} OK [APPENDUID 1 {uid}] appended\r\n").into_bytes()
                    } else {
                        format!("{tag} NO [TRYCREATE] no such mailbox\r\n").into_bytes()
                    }
                }
                "IDLE" => {
                    if w.write_all(b"+ idling\r\n").await.is_err() {
                        return;
                    }
                    let mut line = Vec::new();
                    loop {
                        tokio::select! {
                            n = r.read_until(b'\n', &mut line) => {
                                if n.unwrap_or(0) == 0 {
                                    return;
                                }
                                if line.ends_with(b"\n") {
                                    break;
                                }
                            }
                            changed = news.changed() => {
                                if changed.is_err() {
                                    return;
                                }
                                let exists = self.exists();
                                if w.write_all(format!("* {exists} EXISTS\r\n").as_bytes()).await.is_err() {
                                    return;
                                }
                            }
                        }
                    }
                    format!("{tag} OK idle done\r\n").into_bytes()
                }
                "UID" => self.uid(&tag, args, &mut news),
                _ => format!("{tag} BAD unknown command\r\n").into_bytes(),
            };
            if w.write_all(&out).await.is_err() {
                return;
            }
        }
    }

    fn exists(&self) -> usize {
        let folders = self.folders.lock().unwrap();
        self.selected
            .as_ref()
            .and_then(|s| folders.get(s))
            .map(|f| f.messages.len())
            .unwrap_or(0)
    }

    fn uid(&mut self, tag: &str, args: &str, news: &mut watch::Receiver<u64>) -> Vec<u8> {
        let (command, rest) = args.split_once(' ').unwrap_or((args, ""));
        let command = command.to_ascii_uppercase();
        let Some(selected) = self.selected.clone() else {
            return format!("{tag} BAD no mailbox selected\r\n").into_bytes();
        };
        let mut folders = self.folders.lock().unwrap();
        let mut out: Vec<u8> = Vec::new();
        match command.as_str() {
            "SEARCH" => {
                news.borrow_and_update();
                let uids: Vec<String> = folders[&selected]
                    .messages
                    .iter()
                    .map(|m| m.uid.to_string())
                    .collect();
                out.extend(format!("* SEARCH {}\r\n", uids.join(" ")).bytes());
            }
            "FETCH" => {
                let (set, items) = rest.split_once(' ').unwrap_or((rest, ""));
                let items = items.to_ascii_uppercase();
                for (seq, m) in folders[&selected].messages.iter().enumerate() {
                    if !in_set(set, m.uid) {
                        continue;
                    }
                    out.extend(
                        format!(
                            "* {} FETCH (UID {} FLAGS ({})",
                            seq + 1,
                            m.uid,
                            flag_list(&m.flags)
                        )
                        .bytes(),
                    );
                    if items.contains("RFC822.SIZE") {
                        out.extend(format!(" RFC822.SIZE {}", m.raw.len()).bytes());
                    }
                    if items.contains("INTERNALDATE") {
                        out.extend(b" INTERNALDATE \"01-Jan-2026 10:00:00 +0000\"");
                    }
                    if items.contains("BODY.PEEK[HEADER]") {
                        let end = m
                            .raw
                            .windows(4)
                            .position(|w| w == b"\r\n\r\n")
                            .map(|p| p + 4)
                            .unwrap_or(m.raw.len());
                        out.extend(format!(" BODY[HEADER] {{{end}}}\r\n").bytes());
                        out.extend(&m.raw[..end]);
                    } else if items.contains("BODY.PEEK[]") {
                        out.extend(format!(" BODY[] {{{}}}\r\n", m.raw.len()).bytes());
                        out.extend(&m.raw);
                    }
                    out.extend(b")\r\n");
                }
            }
            "STORE" => {
                let mut parts = rest.splitn(3, ' ');
                let set = parts.next().unwrap_or("");
                let mode = parts.next().unwrap_or("").to_ascii_uppercase();
                let flags = parse_flags(parts.next().unwrap_or(""));
                for m in folders.get_mut(&selected).unwrap().messages.iter_mut() {
                    if !in_set(set, m.uid) {
                        continue;
                    }
                    if mode.starts_with('+') {
                        m.flags.extend(flags.iter().cloned());
                    } else if mode.starts_with('-') {
                        m.flags.retain(|f| !flags.contains(f));
                    } else {
                        m.flags = flags.clone();
                    }
                }
            }
            "MOVE" | "COPY" => {
                let w = words(rest);
                let (set, target) = (w[0].clone(), w[1].clone());
                if !folders.contains_key(&target) {
                    return format!("{tag} NO [TRYCREATE] no such mailbox\r\n").into_bytes();
                }
                let source = folders.get_mut(&selected).unwrap();
                let picked: Vec<Msg> = source
                    .messages
                    .iter()
                    .filter(|m| in_set(&set, m.uid))
                    .cloned()
                    .collect();
                if command == "MOVE" {
                    source.messages.retain(|m| !in_set(&set, m.uid));
                }
                for m in picked {
                    add(&mut folders, &target, m.raw, m.flags);
                }
                drop(folders);
                self.news.send_modify(|n| *n += 1);
                return format!("{tag} OK done\r\n").into_bytes();
            }
            "EXPUNGE" => {
                let set = rest.trim();
                folders
                    .get_mut(&selected)
                    .unwrap()
                    .messages
                    .retain(|m| !(in_set(set, m.uid) && m.flags.contains("\\Deleted")));
            }
            _ => return format!("{tag} BAD unknown UID command\r\n").into_bytes(),
        }
        out.extend(format!("{tag} OK done\r\n").bytes());
        out
    }
}
