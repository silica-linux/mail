// The engine as the app sees it. `silica-mail-engine` (the `engine/` directory of this
// repository) is a service on the session bus:
//
//   name `dev.frascella.Mail`, object `/dev/frascella/Mail1`, interface `dev.frascella.Mail1`,
//   every argument and reply a JSON string.
//
// Methods: ListAccounts() → s; DiscoverAccount(s address) → s config; AddAccount(s config) →
// s id; RemoveAccount(s id); ListMailboxes(s account) → s; ListMessages(s query) → s;
// GetMessage(s id) → s; SaveAttachment(s msg, s att, s path); SetFlags(s ids, s add,
// s remove); Move(s ids, s mailbox); Delete(s ids); Send(s draft) → s id; Search(s query) →
// s ids; Sync(s account). Signals: AccountsChanged, MailboxesChanged(account),
// MessagesChanged(mailbox, added, removed, changed), SyncState(account, state, error).
//
// The app talks to it only through [MailService]: [DBusMailService] in Silica, [FakeMailService]
// in tests and, for development only, with `MAIL_SAMPLE_DATA=1`.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'dbus.dart';
import 'model.dart';

/// A change announced by the engine.
@immutable
sealed class MailEvent {
  const MailEvent();
}

class AccountsChanged extends MailEvent {
  const AccountsChanged();
}

class MailboxesChanged extends MailEvent {
  const MailboxesChanged(this.account);
  final String account;
}

class MessagesChanged extends MailEvent {
  const MessagesChanged(
    this.mailbox, {
    this.added = const [],
    this.removed = const [],
    this.changed = const [],
  });
  final String mailbox;
  final List<String> added;
  final List<String> removed;
  final List<String> changed;
}

class SyncStateChanged extends MailEvent {
  const SyncStateChanged(this.state);
  final SyncState state;
}

/// A query of the message list.
@immutable
class ListQuery {
  const ListQuery(
    this.mailbox, {
    this.offset = 0,
    this.limit = 200,
    this.threads = true,
    this.ids,
  });
  final String mailbox;
  final int offset;
  final int limit;
  final bool threads;

  /// Only these messages, in any mailbox (the rows of search results). An addition to the
  /// engine API: `{"ids": [...]}` in the ListMessages query.
  final List<String>? ids;

  Map<String, Object?> toJson() => {
    'mailbox': mailbox,
    'offset': offset,
    'limit': limit,
    'threads': threads,
    'ids': ?ids,
  };
}

/// The engine could not do what was asked (no engine, a server error, a bad answer).
class MailError implements Exception {
  const MailError(this.message);
  final String message;
  @override
  String toString() => 'MailError: $message';
}

abstract class MailService {
  Stream<MailEvent> get events;

  /// Makes sure the engine runs (D-Bus activation of `silica-mail-engine`); a [MailError]
  /// says why it can't.
  Future<void> start();
  Future<List<Account>> listAccounts();
  Future<AccountConfig> discoverAccount(String address);
  Future<String> addAccount(AccountConfig config);
  Future<void> removeAccount(String id);
  Future<List<Mailbox>> listMailboxes(String account);
  Future<List<MessageSummary>> listMessages(ListQuery query);
  Future<Message> getMessage(String id);
  Future<void> saveAttachment(String message, String attachment, String path);
  Future<void> setFlags(
    List<String> ids, {
    Set<MessageFlag> add = const {},
    Set<MessageFlag> remove = const {},
  });
  Future<void> move(List<String> ids, String mailbox);
  Future<void> delete(List<String> ids);
  Future<String> send(Draft draft);
  Future<List<String>> search(String text, {String? mailbox});
  Future<void> sync(String account);
}

Object? _decode(Object? reply) {
  if (reply is! String) return null;
  try {
    return jsonDecode(reply);
  } on FormatException {
    return null;
  }
}

List<Object?> _list(Object? v) => v is List ? v : const [];

/// The engine on the session bus, through the embedder's `silica/dbus` channel.
class DBusMailService implements MailService {
  DBusMailService({DBus? dbus}) : _dbus = dbus ?? DBus.instance;

  static const String name = 'dev.frascella.Mail';
  static const String path = '/dev/frascella/Mail1';
  static const String interface = 'dev.frascella.Mail1';

  final DBus _dbus;

  Future<Object?> _call(String method, [List<Object?> args = const []]) async {
    try {
      final reply = await _dbus.call(
        destination: name,
        path: path,
        interface: interface,
        method: method,
        signature: 's' * args.length,
        args: [for (final a in args) a is String ? a : jsonEncode(a)],
      );
      return reply.isEmpty ? null : _decode(reply.first) ?? reply.first;
    } on PlatformException catch (e) {
      throw MailError(e.message ?? e.code);
    } on MissingPluginException {
      throw const MailError('no D-Bus channel (outside Silica)');
    }
  }

  @override
  Stream<MailEvent> get events => _dbus
      .signals(sender: name, path: path, interface: interface)
      .map(_event)
      .where((e) => e != null)
      .cast<MailEvent>()
      .handleError((Object _) {});

  static MailEvent? _event(DBusSignal s) {
    String arg(int i) => i < s.args.length ? '${s.args[i] ?? ''}' : '';
    List<String> ids(int i) => [for (final v in _list(_decode(arg(i)))) '$v'];
    return switch (s.member) {
      'AccountsChanged' => const AccountsChanged(),
      'MailboxesChanged' => MailboxesChanged(arg(0)),
      'MessagesChanged' => MessagesChanged(
        arg(0),
        added: ids(1),
        removed: ids(2),
        changed: ids(3),
      ),
      'SyncState' => SyncStateChanged(
        SyncState(
          arg(0),
          SyncPhase.values.firstWhere(
            (p) => p.name == arg(1),
            orElse: () => SyncPhase.idle,
          ),
          arg(2),
        ),
      ),
      _ => null,
    };
  }

  /// Asks the bus to start the engine from its service file
  /// (`dev.frascella.Mail.service`, installed with the engine). Already running is fine.
  @override
  Future<void> start() async {
    try {
      await _dbus.call(
        destination: 'org.freedesktop.DBus',
        path: '/org/freedesktop/DBus',
        interface: 'org.freedesktop.DBus',
        method: 'StartServiceByName',
        signature: 'su',
        args: const [name, 0],
      );
    } on PlatformException catch (e) {
      throw MailError(e.message ?? e.code);
    } on MissingPluginException {
      throw const MailError('no D-Bus channel (outside Silica)');
    }
  }

  @override
  Future<List<Account>> listAccounts() async => [
    for (final a in _list(await _call('ListAccounts'))) Account.fromJson(a),
  ];

  @override
  Future<AccountConfig> discoverAccount(String address) async =>
      AccountConfig.fromJson(await _call('DiscoverAccount', [address]));

  @override
  Future<String> addAccount(AccountConfig config) async =>
      '${await _call('AddAccount', [config.toJson()]) ?? ''}';

  @override
  Future<void> removeAccount(String id) => _call('RemoveAccount', [id]);

  @override
  Future<List<Mailbox>> listMailboxes(String account) async => [
    for (final m in _list(await _call('ListMailboxes', [account])))
      Mailbox.fromJson(m),
  ];

  @override
  Future<List<MessageSummary>> listMessages(ListQuery query) async => [
    for (final m in _list(await _call('ListMessages', [query.toJson()])))
      MessageSummary.fromJson(m),
  ];

  @override
  Future<Message> getMessage(String id) async =>
      Message.fromJson(await _call('GetMessage', [id]));

  @override
  Future<void> saveAttachment(String message, String attachment, String path) =>
      _call('SaveAttachment', [message, attachment, path]);

  @override
  Future<void> setFlags(
    List<String> ids, {
    Set<MessageFlag> add = const {},
    Set<MessageFlag> remove = const {},
  }) => _call('SetFlags', [
    ids,
    [for (final f in add) f.name],
    [for (final f in remove) f.name],
  ]);

  @override
  Future<void> move(List<String> ids, String mailbox) =>
      _call('Move', [ids, mailbox]);

  @override
  Future<void> delete(List<String> ids) => _call('Delete', [ids]);

  @override
  Future<String> send(Draft draft) async =>
      '${await _call('Send', [draft.toJson()]) ?? ''}';

  @override
  Future<List<String>> search(String text, {String? mailbox}) async => [
    for (final id in _list(
      await _call('Search', [
        {'text': text, 'mailbox': ?mailbox},
      ]),
    ))
      '$id',
  ];

  @override
  Future<void> sync(String account) => _call('Sync', [account]);
}

/// An engine in memory with generated mail: tests, and the sample data of `MAIL_SAMPLE_DATA=1`
/// for development. Nothing leaves the process.
class FakeMailService implements MailService {
  FakeMailService({DateTime? now, bool sample = true, this.unavailable})
    : _now = now ?? DateTime(2026, 10, 14, 15, 30) {
    if (sample) _populate();
  }

  /// While set, the engine "can't start" with this error (tests of the unavailable state).
  String? unavailable;

  /// Addresses whose settings can't be found (tests of the manual setup).
  final Set<String> undiscoverable = {};

  final DateTime _now;
  final List<Account> _accounts = [];
  final List<Mailbox> _mailboxes = [];
  final Map<String, MessageSummary> _rows = {};
  final Map<String, Message> _messages = {};
  final List<Draft> sent = [];
  final StreamController<MailEvent> _events = StreamController.broadcast();
  int _next = 0;

  @override
  Stream<MailEvent> get events => _events.stream;

  void _populate() {
    const account = 'acc-1';
    _accounts.add(
      const Account(
        id: account,
        name: 'Alex Rivera',
        address: 'alex@example.org',
      ),
    );
    for (final (id, name, role) in const [
      ('inbox', 'Inbox', MailboxRole.inbox),
      ('drafts', 'Drafts', MailboxRole.drafts),
      ('sent', 'Sent', MailboxRole.sent),
      ('archive', 'Archive', MailboxRole.archive),
      ('junk', 'Junk', MailboxRole.junk),
      ('trash', 'Trash', MailboxRole.trash),
      ('projects', 'Projects', MailboxRole.other),
    ]) {
      _mailboxes.add(Mailbox(id: id, account: account, name: name, role: role));
    }
    const people = [
      Address('sam@example.net', name: 'Sam Chen'),
      Address('noor@example.com', name: 'Noor Haddad'),
      Address('lena@example.org', name: 'Lena Fischer'),
      Address('team@example.com', name: 'Build Team'),
      Address('marco@example.it', name: 'Marco Bianchi'),
    ];
    const subjects = [
      'Notes from Tuesday',
      'Glass shader review',
      'Lunch on Friday?',
      'Nightly build passed',
      'Photos from the trip',
      'Invoice October',
      'Design sync agenda',
      'Re: icon sizes',
    ];
    for (var i = 0; i < 24; i++) {
      final from = people[i % people.length];
      final subject = subjects[i % subjects.length];
      final id = 'm$i';
      final date = _now.subtract(Duration(hours: i * 7 + i * i));
      final flags = <MessageFlag>{
        if (i % 3 != 0) MessageFlag.seen,
        if (i % 7 == 2) MessageFlag.flagged,
        if (i % 5 == 4) MessageFlag.answered,
      };
      final body =
          'Hi Alex,\n\nThis is sample message ${i + 1}, generated for testing. '
          'It talks about "${subject.toLowerCase()}".\n\nSee you,\n${from.name}';
      final html = i % 4 == 1
          ? '<p>Hi Alex,</p><p>This is <b>sample message ${i + 1}</b> with '
                '<a href="https://example.org/notes">a link</a> and an image '
                '<img src="https://example.org/pixel.png">.</p>'
                '<blockquote>Quoted text from before.</blockquote>'
          : '';
      _rows[id] = MessageSummary(
        id: id,
        thread: 't${i % 10}',
        from: from,
        to: const [Address('alex@example.org', name: 'Alex Rivera')],
        subject: subject,
        preview: body.replaceAll('\n', ' ').substring(10, 80),
        date: date,
        flags: flags,
        attachments: i % 6 == 5 ? 1 : 0,
        mailbox: i < 20 ? 'inbox' : 'archive',
      );
      _messages[id] = Message(
        id: id,
        from: from,
        to: const [Address('alex@example.org', name: 'Alex Rivera')],
        cc: const [],
        subject: subject,
        date: date,
        text: body,
        html: html,
        remoteContent: html.contains('https://example.org/pixel.png'),
        attachments: i % 6 == 5
            ? const [
                Attachment(
                  id: 'a1',
                  name: 'report.pdf',
                  mime: 'application/pdf',
                  size: 48213,
                ),
              ]
            : const [],
      );
    }
  }

  void _changed(
    String mailbox, {
    List<String> added = const [],
    List<String> removed = const [],
    List<String> changed = const [],
  }) => _events.add(
    MessagesChanged(mailbox, added: added, removed: removed, changed: changed),
  );

  @override
  Future<void> start() async {
    if (unavailable case final error?) throw MailError(error);
  }

  @override
  Future<List<Account>> listAccounts() async {
    if (unavailable case final error?) throw MailError(error);
    return List.of(_accounts);
  }

  /// Every account added, with the configuration it was added with (tests).
  final List<AccountConfig> added = [];

  @override
  Future<AccountConfig> discoverAccount(String address) async {
    final at = address.lastIndexOf('@');
    if (at <= 0 || at == address.length - 1) {
      throw const MailError('not an address');
    }
    if (undiscoverable.contains(address)) {
      throw MailError(
        'not found: mail servers for ${address.substring(at + 1)}',
      );
    }
    final domain = address.substring(at + 1);
    return AccountConfig(
      address: address,
      imapHost: 'imap.$domain',
      smtpHost: 'smtp.$domain',
      username: address,
    );
  }

  @override
  Future<String> addAccount(AccountConfig config) async {
    if (config.password.isEmpty) throw const MailError('password required');
    added.add(config);
    final id = 'acc-${_accounts.length + 1}';
    _accounts.add(Account(id: id, name: config.name, address: config.address));
    _mailboxes.add(
      Mailbox(
        id: '$id-inbox',
        account: id,
        name: 'Inbox',
        role: MailboxRole.inbox,
      ),
    );
    _events.add(const AccountsChanged());
    return id;
  }

  @override
  Future<void> removeAccount(String id) async {
    _accounts.removeWhere((a) => a.id == id);
    _mailboxes.removeWhere((m) => m.account == id);
    _events.add(const AccountsChanged());
  }

  @override
  Future<List<Mailbox>> listMailboxes(String account) async => [
    for (final m in _mailboxes)
      if (m.account == account)
        Mailbox(
          id: m.id,
          account: m.account,
          name: m.name,
          role: m.role,
          unread: _rows.values
              .where((r) => r.mailbox == m.id && r.unread)
              .length,
          total: _rows.values.where((r) => r.mailbox == m.id).length,
        ),
  ];

  @override
  Future<List<MessageSummary>> listMessages(ListQuery query) async {
    final ids = query.ids?.toSet();
    final rows =
        _rows.values
            .where(
              (r) =>
                  ids != null ? ids.contains(r.id) : r.mailbox == query.mailbox,
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    return rows.skip(query.offset).take(query.limit).toList();
  }

  @override
  Future<Message> getMessage(String id) async {
    final m = _messages[id];
    if (m == null) throw MailError('no message $id');
    return m;
  }

  @override
  Future<void> saveAttachment(
    String message,
    String attachment,
    String path,
  ) async {}

  @override
  Future<void> setFlags(
    List<String> ids, {
    Set<MessageFlag> add = const {},
    Set<MessageFlag> remove = const {},
  }) async {
    final boxes = <String>{};
    for (final id in ids) {
      final r = _rows[id];
      if (r == null) continue;
      _rows[id] = r.withFlags({...r.flags, ...add}..removeAll(remove));
      boxes.add(r.mailbox);
    }
    for (final b in boxes) {
      _changed(b, changed: ids);
    }
  }

  @override
  Future<void> move(List<String> ids, String mailbox) async {
    final from = <String>{};
    for (final id in ids) {
      final r = _rows[id];
      if (r == null) continue;
      from.add(r.mailbox);
      _rows[id] = MessageSummary(
        id: r.id,
        thread: r.thread,
        from: r.from,
        to: r.to,
        subject: r.subject,
        preview: r.preview,
        date: r.date,
        flags: r.flags,
        attachments: r.attachments,
        mailbox: mailbox,
      );
    }
    for (final b in from) {
      _changed(b, removed: ids);
    }
    _changed(mailbox, added: ids);
  }

  @override
  Future<void> delete(List<String> ids) async {
    final inTrash = ids.where((id) => _rows[id]?.mailbox == 'trash').toList();
    final others = ids.where((id) => !inTrash.contains(id)).toList();
    for (final id in inTrash) {
      _rows.remove(id);
      _messages.remove(id);
    }
    if (inTrash.isNotEmpty) _changed('trash', removed: inTrash);
    if (others.isNotEmpty) await move(others, 'trash');
  }

  @override
  Future<String> send(Draft draft) async {
    if (draft.to.isEmpty) throw const MailError('no recipients');
    sent.add(draft);
    final id = 's${_next++}';
    _rows[id] = MessageSummary(
      id: id,
      thread: draft.inReplyTo ?? id,
      from: Address(
        _accounts.firstOrNull?.address ?? '',
        name: _accounts.firstOrNull?.name ?? '',
      ),
      to: draft.to,
      subject: draft.subject,
      preview: draft.text,
      date: _now,
      flags: const {MessageFlag.seen},
      mailbox: 'sent',
    );
    _changed('sent', added: [id]);
    return id;
  }

  @override
  Future<List<String>> search(String text, {String? mailbox}) async {
    final q = text.toLowerCase().trim();
    if (q.isEmpty) return const [];
    return [
      for (final r in _rows.values)
        if ((mailbox == null || r.mailbox == mailbox) &&
            ('${r.subject} ${r.from.display} ${r.from.address} ${r.preview}')
                .toLowerCase()
                .contains(q))
          r.id,
    ];
  }

  @override
  Future<void> sync(String account) async {
    _events
      ..add(SyncStateChanged(SyncState(account, SyncPhase.syncing)))
      ..add(SyncStateChanged(SyncState(account, SyncPhase.idle)));
  }
}
