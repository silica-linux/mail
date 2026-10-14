// The data the app shows, as the engine sends it (JSON over D-Bus, see `service.dart`).
// Parsing is lenient: a missing or odd field becomes an empty value, never an exception,
// because the engine and the app evolve separately.

import 'package:flutter/foundation.dart';

String _str(Object? v) => v is String ? v : (v == null ? '' : '$v');
int _int(Object? v) => v is int ? v : (v is num ? v.toInt() : 0);
List<Object?> _list(Object? v) => v is List ? v : const [];
Map<String, Object?> _map(Object? v) =>
    v is Map ? v.map((k, v) => MapEntry('$k', v)) : const {};

/// A sender or recipient.
@immutable
class Address {
  const Address(this.address, {this.name = ''});

  factory Address.fromJson(Object? json) {
    if (json is String) return Address(json);
    final m = _map(json);
    return Address(_str(m['address']), name: _str(m['name']));
  }

  final String name;
  final String address;

  /// The name if there is one, otherwise the address.
  String get display => name.isNotEmpty ? name : address;

  Map<String, Object?> toJson() => {'name': name, 'address': address};

  @override
  bool operator ==(Object other) =>
      other is Address && other.address == address && other.name == name;

  @override
  int get hashCode => Object.hash(address, name);
}

List<Address> _addresses(Object? v) => [
  for (final a in _list(v)) Address.fromJson(a),
];

/// An account configured in the engine.
@immutable
class Account {
  const Account({required this.id, required this.name, required this.address});

  factory Account.fromJson(Object? json) {
    final m = _map(json);
    return Account(
      id: _str(m['id']),
      name: _str(m['name']),
      address: _str(m['address']),
    );
  }

  final String id;
  final String name;
  final String address;
}

/// The role of a mailbox, from the special-use attributes of the server.
enum MailboxRole { inbox, drafts, sent, archive, junk, trash, other }

MailboxRole _role(String v) => MailboxRole.values.firstWhere(
  (r) => r.name == v,
  orElse: () => MailboxRole.other,
);

/// A mailbox (folder) of an account.
@immutable
class Mailbox {
  const Mailbox({
    required this.id,
    required this.account,
    required this.name,
    this.role = MailboxRole.other,
    this.unread = 0,
    this.total = 0,
  });

  factory Mailbox.fromJson(Object? json) {
    final m = _map(json);
    return Mailbox(
      id: _str(m['id']),
      account: _str(m['account']),
      name: _str(m['name']),
      role: _role(_str(m['role'])),
      unread: _int(m['unread']),
      total: _int(m['total']),
    );
  }

  final String id;
  final String account;
  final String name;
  final MailboxRole role;
  final int unread;
  final int total;
}

/// The flags of a message.
enum MessageFlag { seen, flagged, answered, draft }

Set<MessageFlag> _flags(Object? v) => {
  for (final f in _list(v))
    for (final flag in MessageFlag.values)
      if (flag.name == f) flag,
};

/// A row of the message list.
@immutable
class MessageSummary {
  const MessageSummary({
    required this.id,
    required this.thread,
    required this.from,
    required this.to,
    required this.subject,
    required this.preview,
    required this.date,
    this.flags = const {},
    this.attachments = 0,
    this.mailbox = '',
  });

  factory MessageSummary.fromJson(Object? json) {
    final m = _map(json);
    return MessageSummary(
      id: _str(m['id']),
      thread: _str(m['thread']),
      from: Address.fromJson(m['from']),
      to: _addresses(m['to']),
      subject: _str(m['subject']),
      preview: _str(m['preview']),
      date: DateTime.fromMillisecondsSinceEpoch(_int(m['date']) * 1000),
      flags: _flags(m['flags']),
      attachments: _int(m['attachments']),
      mailbox: _str(m['mailbox']),
    );
  }

  final String id;
  final String thread;
  final Address from;
  final List<Address> to;
  final String subject;
  final String preview;
  final DateTime date;
  final Set<MessageFlag> flags;
  final int attachments;
  final String mailbox;

  bool get unread => !flags.contains(MessageFlag.seen);
  bool get flagged => flags.contains(MessageFlag.flagged);

  MessageSummary withFlags(Set<MessageFlag> flags) => MessageSummary(
    id: id,
    thread: thread,
    from: from,
    to: to,
    subject: subject,
    preview: preview,
    date: date,
    flags: flags,
    attachments: attachments,
    mailbox: mailbox,
  );
}

/// An attachment of a message.
@immutable
class Attachment {
  const Attachment({
    required this.id,
    required this.name,
    required this.mime,
    required this.size,
  });

  factory Attachment.fromJson(Object? json) {
    final m = _map(json);
    return Attachment(
      id: _str(m['id']),
      name: _str(m['name']),
      mime: _str(m['mime']),
      size: _int(m['size']),
    );
  }

  final String id;
  final String name;
  final String mime;
  final int size;
}

/// A whole message, for the reader.
@immutable
class Message {
  const Message({
    required this.id,
    required this.from,
    required this.to,
    required this.cc,
    required this.subject,
    required this.date,
    required this.text,
    this.html = '',
    this.attachments = const [],
    this.remoteContent = false,
    this.headers = const {},
  });

  factory Message.fromJson(Object? json) {
    final m = _map(json);
    return Message(
      id: _str(m['id']),
      from: Address.fromJson(m['from']),
      to: _addresses(m['to']),
      cc: _addresses(m['cc']),
      subject: _str(m['subject']),
      date: DateTime.fromMillisecondsSinceEpoch(_int(m['date']) * 1000),
      text: _str(m['text']),
      html: _str(m['html']),
      attachments: [
        for (final a in _list(m['attachments'])) Attachment.fromJson(a),
      ],
      remoteContent: m['remoteContent'] == true,
      headers: {
        for (final e in _map(m['headers']).entries) e.key: _str(e.value),
      },
    );
  }

  final String id;
  final Address from;
  final List<Address> to;
  final List<Address> cc;
  final String subject;
  final DateTime date;
  final String text;
  final String html;
  final List<Attachment> attachments;

  /// The HTML references content on the network (images, styles): it is not loaded unless
  /// the user asks.
  final bool remoteContent;
  final Map<String, String> headers;
}

/// A message being written.
@immutable
class Draft {
  const Draft({
    required this.account,
    this.to = const [],
    this.cc = const [],
    this.bcc = const [],
    this.subject = '',
    this.text = '',
    this.attachments = const [],
    this.inReplyTo,
  });

  final String account;
  final List<Address> to;
  final List<Address> cc;
  final List<Address> bcc;
  final String subject;
  final String text;

  /// Paths of the files to attach.
  final List<String> attachments;
  final String? inReplyTo;

  Map<String, Object?> toJson() => {
    'account': account,
    'to': [for (final a in to) a.toJson()],
    'cc': [for (final a in cc) a.toJson()],
    'bcc': [for (final a in bcc) a.toJson()],
    'subject': subject,
    'text': text,
    'attachments': attachments,
    'inReplyTo': ?inReplyTo,
  };
}

/// How a mail connection is secured (the engine refuses plain text over a network).
enum MailTls {
  /// Implicit TLS from the first byte (IMAP 993, SMTP 465).
  tls,

  /// Plain connection upgraded with STARTTLS (IMAP 143, SMTP 587).
  starttls;

  /// The usual security of a port: STARTTLS on 143, 25 and 587, implicit TLS otherwise.
  static MailTls forPort(int port) =>
      const {143, 25, 587}.contains(port) ? starttls : tls;

  static MailTls _parse(Object? value, int port) => switch (value) {
    'tls' => tls,
    'starttls' => starttls,
    _ => forPort(port),
  };
}

/// Who runs the servers of a configuration, when they sign in their own way.
enum SignInProvider {
  /// A plain IMAP/SMTP password works.
  password,

  /// Google: an app password works; sign-in with Google is silica-linux/mail#3.
  google,

  /// Microsoft: only sign-in with Microsoft works, not supported yet (silica-linux/mail#3).
  microsoft,
}

/// The settings found for an address (`DiscoverAccount`), completed by the user.
@immutable
class AccountConfig {
  const AccountConfig({
    required this.address,
    this.name = '',
    this.imapHost = '',
    this.imapPort = 993,
    MailTls? imapTls,
    this.smtpHost = '',
    this.smtpPort = 465,
    MailTls? smtpTls,
    this.username = '',
    this.password = '',
  }) : imapTls = imapTls ?? MailTls.tls,
       smtpTls = smtpTls ?? MailTls.tls;

  factory AccountConfig.fromJson(Object? json) {
    final m = _map(json);
    final imap = _map(m['imap']);
    final smtp = _map(m['smtp']);
    final imapPort = imap['port'] == null ? 993 : _int(imap['port']);
    final smtpPort = smtp['port'] == null ? 465 : _int(smtp['port']);
    return AccountConfig(
      address: _str(m['address']),
      name: _str(m['name']),
      imapHost: _str(imap['host']),
      imapPort: imapPort,
      imapTls: MailTls._parse(imap['tls'], imapPort),
      smtpHost: _str(smtp['host']),
      smtpPort: smtpPort,
      smtpTls: MailTls._parse(smtp['tls'], smtpPort),
      username: _str(m['username']),
    );
  }

  final String address;
  final String name;
  final String imapHost;
  final int imapPort;
  final MailTls imapTls;
  final String smtpHost;
  final int smtpPort;
  final MailTls smtpTls;
  final String username;

  /// Sent once to the engine, which keeps it in the Secret Service; never stored here.
  final String password;

  /// Who runs the servers, from their host names.
  SignInProvider get provider {
    final hosts = '${imapHost.toLowerCase()} ${smtpHost.toLowerCase()}';
    if (hosts.contains('gmail.com') || hosts.contains('googlemail.com')) {
      return SignInProvider.google;
    }
    if (hosts.contains('outlook.') ||
        hosts.contains('office365.com') ||
        hosts.contains('hotmail.') ||
        hosts.contains('live.com')) {
      return SignInProvider.microsoft;
    }
    return SignInProvider.password;
  }

  AccountConfig copyWith({
    String? name,
    String? imapHost,
    int? imapPort,
    MailTls? imapTls,
    String? smtpHost,
    int? smtpPort,
    MailTls? smtpTls,
    String? username,
    String? password,
  }) => AccountConfig(
    address: address,
    name: name ?? this.name,
    imapHost: imapHost ?? this.imapHost,
    imapPort: imapPort ?? this.imapPort,
    imapTls: imapTls ?? this.imapTls,
    smtpHost: smtpHost ?? this.smtpHost,
    smtpPort: smtpPort ?? this.smtpPort,
    smtpTls: smtpTls ?? this.smtpTls,
    username: username ?? this.username,
    password: password ?? this.password,
  );

  /// What the engine's `AddAccount` takes. The servers carry their security: the engine
  /// requires it and rejected configurations without it.
  Map<String, Object?> toJson() => {
    'address': address,
    'name': name,
    'imap': {'host': imapHost, 'port': imapPort, 'tls': imapTls.name},
    'smtp': {'host': smtpHost, 'port': smtpPort, 'tls': smtpTls.name},
    'username': username.isEmpty ? address : username,
    'password': password,
  };
}

/// The state of the synchronization of an account.
enum SyncPhase { idle, syncing, error }

@immutable
class SyncState {
  const SyncState(this.account, this.phase, [this.error = '']);
  final String account;
  final SyncPhase phase;
  final String error;
}
