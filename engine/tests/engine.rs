//! End to end over D-Bus: a private bus, a fake keyring, fake IMAP and SMTP servers, and the
//! engine in between, driven the way the app drives it.

#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing
)]

mod common;

use common::imap::FakeImap;
use common::smtp::FakeSmtp;
use common::{App, Bus, eventually};
use futures::StreamExt;
use serde_json::{Value, json};

const USER: &str = "ada";
const PASSWORD: &str = "difference engine";

fn plain(id: &str, from: &str, subject: &str, date: &str, body: &str) -> Vec<u8> {
    format!(
        "From: {from}\r\nTo: Ada <ada@example.org>\r\nSubject: {subject}\r\nDate: {date}\r\n\
         Message-ID: <{id}>\r\nContent-Type: text/plain; charset=utf-8\r\n\r\n{body}\r\n"
    )
    .into_bytes()
}

fn rich(id: &str) -> Vec<u8> {
    format!(
        "From: Charles Babbage <charles@example.org>\r\nTo: ada@example.org\r\n\
         Subject: Plans with drawings\r\nDate: Tue, 06 Jan 2026 09:00:00 +0000\r\n\
         Message-ID: <{id}>\r\nMIME-Version: 1.0\r\n\
         Content-Type: multipart/mixed; boundary=\"outer\"\r\n\r\n\
         --outer\r\nContent-Type: multipart/alternative; boundary=\"inner\"\r\n\r\n\
         --inner\r\nContent-Type: text/plain\r\n\r\nThe plans are attached.\r\n\
         --inner\r\nContent-Type: text/html\r\n\r\n\
         <p onclick=\"x()\">The plans are attached.</p><script>steal()</script>\
         <img src=\"https://tracker.example/pixel.png\">\r\n\
         --inner--\r\n\
         --outer\r\nContent-Type: text/plain; name=\"plans.txt\"\r\n\
         Content-Disposition: attachment; filename=\"plans.txt\"\r\n\r\n\
         mill and store\r\n\
         --outer--\r\n"
    )
    .into_bytes()
}

fn config(imap: u16, smtp: u16, password: &str) -> String {
    json!({
        "name": "Ada Lovelace",
        "address": "ada@example.org",
        "imap": {"host": "127.0.0.1", "port": imap, "tls": "none"},
        "smtp": {"host": "127.0.0.1", "port": smtp, "tls": "none"},
        "username": USER,
        "password": password,
    })
    .to_string()
}

fn ids(list: &Value) -> Vec<String> {
    list.as_array()
        .unwrap()
        .iter()
        .map(|m| m["id"].as_str().unwrap().to_owned())
        .collect()
}

async fn mailbox_id(app: &App, account: &str, role: &str) -> String {
    eventually(&format!("the {role} mailbox"), || async {
        let boxes = app.json("ListMailboxes", &(account,)).await.unwrap();
        boxes
            .as_array()
            .unwrap()
            .iter()
            .find(|b| b["role"] == role)
            .map(|b| b["id"].as_str().unwrap().to_owned())
    })
    .await
}

async fn messages(app: &App, mailbox: &str) -> Value {
    let query = json!({"mailbox": mailbox, "offset": 0, "limit": 50, "threads": false});
    app.json("ListMessages", &(query.to_string(),))
        .await
        .unwrap()
}

async fn wait_count(app: &App, mailbox: &str, count: usize) -> Value {
    eventually(
        &format!("{count} messages in mailbox {mailbox}"),
        || async {
            let list = messages(app, mailbox).await;
            (list.as_array().unwrap().len() == count).then_some(list)
        },
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 4)]
async fn mail_end_to_end() {
    let bus = Bus::start();
    let keyring_conn = bus.connect().await;
    let vault = common::secrets::serve(&keyring_conn).await;
    let imap = FakeImap::start(
        USER,
        PASSWORD,
        &[
            ("INBOX", ""),
            ("Sent", "\\Sent"),
            ("Trash", "\\Trash"),
            ("Archive", "\\Archive"),
        ],
    )
    .await;
    imap.deliver(
        "INBOX",
        &plain(
            "notes@example.org",
            "Charles Babbage <charles@example.org>",
            "Analytical engine notes",
            "Mon, 05 Jan 2026 09:00:00 +0000",
            "Bernoulli numbers, note G.",
        ),
        &[],
    );
    imap.deliver("INBOX", &rich("plans@example.org"), &[]);
    let smtp = FakeSmtp::start(USER, PASSWORD).await;

    let data = tempfile::tempdir().unwrap();
    let engine_conn = bus.connect().await;
    let engine = silica_mail_engine::dbus::serve(&engine_conn, data.path().to_owned())
        .await
        .unwrap();
    let app_conn = bus.connect().await;
    let app = App::new(&app_conn).await;

    // A wrong password is refused and nothing is kept.
    let err = app
        .string("AddAccount", &(config(imap.port, smtp.port, "wrong"),))
        .await
        .unwrap_err();
    assert!(err.to_string().contains("refused"), "{err}");
    assert!(vault.items().is_empty());

    let mut accounts_changed = app.proxy.receive_signal("AccountsChanged").await.unwrap();
    let account = app
        .string("AddAccount", &(config(imap.port, smtp.port, PASSWORD),))
        .await
        .unwrap();
    accounts_changed.next().await.unwrap();
    let items = vault.items();
    assert_eq!(items.len(), 1);
    assert_eq!(items[0].attributes["account"], account);
    assert_eq!(items[0].secret, PASSWORD.as_bytes());

    let accounts = app.json("ListAccounts", &()).await.unwrap();
    assert_eq!(accounts[0]["id"], account.as_str());
    assert_eq!(accounts[0]["address"], "ada@example.org");
    assert_eq!(accounts[0]["name"], "Ada Lovelace");
    // The password never goes back to the app.
    assert!(!accounts.to_string().contains(PASSWORD));

    // Mailboxes and messages.
    let inbox = mailbox_id(&app, &account, "inbox").await;
    let sent = mailbox_id(&app, &account, "sent").await;
    let trash = mailbox_id(&app, &account, "trash").await;
    let archive = mailbox_id(&app, &account, "archive").await;
    let list = wait_count(&app, &inbox, 2).await;
    assert_eq!(list[0]["subject"], "Plans with drawings", "newest first");
    assert_eq!(list[0]["from"]["address"], "charles@example.org");
    assert_eq!(list[0]["attachments"], 1);
    assert_eq!(list[1]["subject"], "Analytical engine notes");
    assert_eq!(list[1]["preview"], "Bernoulli numbers, note G.");
    let plans = list[0]["id"].as_str().unwrap().to_owned();
    let notes = list[1]["id"].as_str().unwrap().to_owned();
    let boxes = app.json("ListMailboxes", &(&account,)).await.unwrap();
    let inbox_view = boxes
        .as_array()
        .unwrap()
        .iter()
        .find(|b| b["role"] == "inbox")
        .unwrap();
    assert_eq!(inbox_view["total"], 2);
    assert_eq!(inbox_view["unread"], 2);

    // Reading: sanitized HTML, remote content reported, attachments listed and saved.
    let message = app.json("GetMessage", &(&plans,)).await.unwrap();
    let html = message["html"].as_str().unwrap();
    assert!(html.contains("The plans are attached."));
    assert!(!html.contains("<script"), "{html}");
    assert!(!html.contains("onclick"), "{html}");
    // Remote images stay as URLs (the engine never fetches them) and are reported.
    assert_eq!(message["remoteContent"], true);
    assert_eq!(
        message["text"].as_str().unwrap().trim(),
        "The plans are attached."
    );
    assert_eq!(message["attachments"][0]["name"], "plans.txt");
    let attachment = message["attachments"][0]["id"].as_str().unwrap().to_owned();
    let saved = data.path().join("saved-plans.txt");
    app.unit(
        "SaveAttachment",
        &(&plans, &attachment, saved.to_str().unwrap()),
    )
    .await
    .unwrap();
    assert_eq!(
        std::fs::read_to_string(&saved).unwrap().trim(),
        "mill and store"
    );
    assert!(app.json("GetMessage", &("99999",)).await.is_err());

    // Search over the offline index.
    let found: Vec<String> =
        serde_json::from_str(&app.string("Search", &("bernoulli",)).await.unwrap()).unwrap();
    assert_eq!(found, vec![notes.clone()]);

    // Flags: local at once, then on the server.
    app.unit(
        "SetFlags",
        &(json!([&notes]).to_string(), r#"["seen","flagged"]"#, "[]"),
    )
    .await
    .unwrap();
    let list = messages(&app, &inbox).await;
    let flags = list[1]["flags"].as_array().unwrap();
    assert!(flags.contains(&json!("seen")) && flags.contains(&json!("flagged")));
    eventually("flags on the server", || async {
        let msgs = imap.messages("INBOX");
        let f = &msgs[0].flags;
        (f.contains("\\Seen") && f.contains("\\Flagged")).then_some(())
    })
    .await;

    // New mail arrives while the engine idles on the inbox.
    let mut changed = app.proxy.receive_signal("MessagesChanged").await.unwrap();
    imap.deliver(
        "INBOX",
        &plain(
            "late@example.org",
            "Mary Somerville <mary@example.org>",
            "Introduction",
            "Wed, 07 Jan 2026 09:00:00 +0000",
            "May I introduce Mr Babbage?",
        ),
        &[],
    );
    let list = wait_count(&app, &inbox, 3).await;
    let late = list[0]["id"].as_str().unwrap().to_owned();
    let signal = changed.next().await.unwrap();
    let (mailbox, added, _, _): (String, String, String, String) =
        signal.body().deserialize().unwrap();
    assert_eq!(mailbox, inbox);
    assert!(added.contains(&late), "{added}");

    // Move to the archive.
    app.unit("Move", &(json!([&notes]).to_string(), &archive))
        .await
        .unwrap();
    assert!(!ids(&messages(&app, &inbox).await).contains(&notes));
    let archived = wait_count(&app, &archive, 1).await;
    assert_eq!(archived[0]["subject"], "Analytical engine notes");
    assert_eq!(imap.messages("Archive").len(), 1);
    assert_eq!(imap.messages("INBOX").len(), 2);

    // Delete: to the trash first, then for good.
    app.unit("Delete", &(json!([&late]).to_string(),))
        .await
        .unwrap();
    let trashed = wait_count(&app, &trash, 1).await;
    assert_eq!(imap.messages("Trash").len(), 1);
    app.unit("Delete", &(json!(ids(&trashed)).to_string(),))
        .await
        .unwrap();
    eventually("the trash emptied on the server", || async {
        imap.messages("Trash").is_empty().then_some(())
    })
    .await;
    wait_count(&app, &trash, 0).await;

    // Offline: the message waits in the outbox, the error is reported, a sync retries it.
    let mut states = app.proxy.receive_signal("SyncState").await.unwrap();
    smtp.set_online(false);
    let note = json!({"account": account, "to": ["mary@example.org"], "subject": "Tomorrow", "text": "At ten."});
    app.string("Send", &(note.to_string(),)).await.unwrap();
    loop {
        let signal = states.next().await.unwrap();
        let (_, state, error): (String, String, String) = signal.body().deserialize().unwrap();
        if state == "error" {
            assert!(error.contains("sending"), "{error}");
            break;
        }
    }
    assert!(smtp.received().is_empty());
    smtp.set_online(true);
    app.unit("Sync", &(&account,)).await.unwrap();
    eventually("the queued message sent", || async {
        (smtp.received().len() == 1).then_some(())
    })
    .await;
    wait_count(&app, &sent, 1).await;

    // Sending a reply: through SMTP, a copy in Sent, the original marked answered.
    let draft = json!({
        "account": account,
        "to": [{"name": "Charles Babbage", "address": "charles@example.org"}],
        "cc": ["Mary Somerville <mary@example.org>"],
        "bcc": ["archive@example.org"],
        "subject": "Re: Plans with drawings",
        "text": "Wonderful, thank you.",
        "attachments": [saved.to_str().unwrap()],
        "inReplyTo": plans,
    });
    app.string("Send", &(draft.to_string(),)).await.unwrap();
    let mail = eventually("the message at the SMTP server", || async {
        smtp.received()
            .into_iter()
            .find(|m| m.data.contains("Subject: Re: Plans"))
    })
    .await;
    assert_eq!(mail.from, "<ada@example.org>");
    assert_eq!(mail.to.len(), 3);
    assert!(mail.data.contains("In-Reply-To: <plans@example.org>"));
    assert!(
        !mail.data.contains("archive@example.org"),
        "Bcc is not in the headers"
    );
    assert!(mail.data.contains("plans.txt"));
    let sent_list = wait_count(&app, &sent, 2).await;
    let reply = sent_list
        .as_array()
        .unwrap()
        .iter()
        .find(|m| m["subject"] == "Re: Plans with drawings")
        .unwrap();
    let inbox_list = messages(&app, &inbox).await;
    let original = inbox_list
        .as_array()
        .unwrap()
        .iter()
        .find(|m| m["id"] == plans.as_str())
        .unwrap();
    assert_eq!(reply["thread"], original["thread"]);
    assert!(
        original["flags"]
            .as_array()
            .unwrap()
            .contains(&json!("answered"))
    );
    eventually("answered on the server", || async {
        imap.messages("INBOX")
            .iter()
            .any(|m| m.flags.contains("\\Answered"))
            .then_some(())
    })
    .await;
    assert!(
        imap.messages("Sent")
            .iter()
            .all(|m| m.flags.contains("\\Seen"))
    );

    // Bad input comes back as an error, not a crash.
    assert!(app.json("ListMessages", &("not json",)).await.is_err());
    assert!(
        app.string("Send", &(r#"{"account":"x","to":[]}"#,))
            .await
            .is_err()
    );
    assert!(app.unit("Sync", &("nope",)).await.is_err());
    app.unit("Sync", &(&account,)).await.unwrap();

    // Removing the account forgets the password too.
    app.unit("RemoveAccount", &(&account,)).await.unwrap();
    assert!(vault.items().is_empty());
    assert_eq!(app.json("ListAccounts", &()).await.unwrap(), json!([]));
    engine.shutdown().await;
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn without_a_keyring_the_password_is_not_kept() {
    let bus = Bus::start();
    let imap = FakeImap::start(USER, PASSWORD, &[("INBOX", "")]).await;
    let data = tempfile::tempdir().unwrap();
    let engine_conn = bus.connect().await;
    let engine = silica_mail_engine::dbus::serve(&engine_conn, data.path().to_owned())
        .await
        .unwrap();
    let app_conn = bus.connect().await;
    let app = App::new(&app_conn).await;
    let err = app
        .string("AddAccount", &(config(imap.port, 1, PASSWORD),))
        .await
        .unwrap_err();
    assert!(err.to_string().contains("keyring"), "{err}");
    assert_eq!(app.json("ListAccounts", &()).await.unwrap(), json!([]));
    engine.shutdown().await;
}
