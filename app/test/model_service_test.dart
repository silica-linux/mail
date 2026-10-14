import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_mail/src/compose.dart';
import 'package:silica_mail/src/dbus.dart';
import 'package:silica_mail/src/l10n.dart';
import 'package:silica_mail/src/model.dart';
import 'package:silica_mail/src/service.dart';

void main() {
  test('rows parse leniently: odd fields become empty values', () {
    final row = MessageSummary.fromJson({
      'id': 'x1',
      'from': 'plain@example.org',
      'to': 'not a list',
      'subject': 7,
      'date': 1760000000,
      'flags': ['seen', 'unknown', 3],
      'attachments': '2',
    });
    expect(row.from.address, 'plain@example.org');
    expect(row.to, isEmpty);
    expect(row.subject, '7');
    expect(row.flags, {MessageFlag.seen});
    expect(row.unread, isFalse);
    expect(row.attachments, 0);
    expect(MessageSummary.fromJson(null).id, '');
    expect(Mailbox.fromJson({'role': 'trash'}).role, MailboxRole.trash);
    expect(Mailbox.fromJson({'role': 'weird'}).role, MailboxRole.other);
  });

  test('addresses: parsing and formatting round trip', () {
    final list = parseAddresses(
      'Sam Chen <sam@example.net>; lena@example.org, ,"Noor" <n@x.y>',
    );
    expect(list, const [
      Address('sam@example.net', name: 'Sam Chen'),
      Address('lena@example.org'),
      Address('n@x.y', name: 'Noor'),
    ]);
    expect(parseAddresses(formatAddresses(list)), list);
  });

  test('dates and sizes follow the language', () {
    useLocale(const Locale('en'));
    final now = DateTime(2026, 10, 14, 15, 30);
    expect(listDate(DateTime(2026, 10, 14, 9, 5), now), '09:05');
    expect(listDate(DateTime(2026, 10, 13, 9, 5), now), 'Yesterday');
    expect(listDate(DateTime(2026, 3, 2, 9, 5), now), 'Mar 2, 2026');
    expect(fileSize(48213), '48 KB');
    expect(fileSize(4821), '4.8 KB');
    useLocale(const Locale('it'));
    expect(listDate(DateTime(2026, 10, 13, 9, 5), now), 'Ieri');
    expect(listDate(DateTime(2026, 3, 2, 9, 5), now), '2 mar 2026');
    expect(fileSize(4821), '4,8 KB');
    expect(readerDate(DateTime(2026, 10, 14, 9, 5), now), 'Oggi alle 09:05');
    useLocale(const Locale('en'));
  });

  group('fake engine', () {
    test(
      'lists, flags, moves, deletes, sends and searches with events',
      () async {
        final fake = FakeMailService();
        final events = <MailEvent>[];
        final sub = fake.events.listen(events.add);
        final accounts = await fake.listAccounts();
        expect(accounts.single.address, 'alex@example.org');
        final boxes = await fake.listMailboxes(accounts.single.id);
        final inbox = boxes.firstWhere((b) => b.role == MailboxRole.inbox);
        expect(inbox.total, 20);
        expect(inbox.unread, greaterThan(0));
        final rows = await fake.listMessages(const ListQuery('inbox'));
        expect(rows.first.date.isAfter(rows.last.date), isTrue);
        final first = rows.first.id;
        await fake.setFlags([first], add: {MessageFlag.flagged});
        expect(
          (await fake.listMessages(
            const ListQuery('inbox'),
          )).firstWhere((r) => r.id == first).flagged,
          isTrue,
        );
        await fake.delete([first]);
        expect(
          (await fake.listMessages(const ListQuery('trash'))).single.id,
          first,
        );
        await fake.delete([first]);
        expect(await fake.listMessages(const ListQuery('trash')), isEmpty);
        await expectLater(
          fake.send(const Draft(account: 'acc-1')),
          throwsA(isA<MailError>()),
        );
        await fake.send(
          const Draft(
            account: 'acc-1',
            to: [Address('sam@example.net')],
            subject: 'Hi',
          ),
        );
        expect(
          (await fake.listMessages(const ListQuery('sent'))).single.subject,
          'Hi',
        );
        final found = await fake.search('glass shader');
        expect(found, isNotEmpty);
        final rowsOf = await fake.listMessages(ListQuery('', ids: found));
        expect(rowsOf.every((r) => r.subject == 'Glass shader review'), isTrue);
        await Future<void>.delayed(Duration.zero);
        expect(events.whereType<MessagesChanged>(), isNotEmpty);
        await sub.cancel();
      },
    );
  });

  group('D-Bus engine', () {
    late List<MethodCall> calls;
    late Object? reply;

    setUp(() {
      calls = [];
      reply = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(DBus.channel, (call) async {
            calls.add(call);
            return [reply];
          });
    });

    test('calls carry JSON strings with an s signature per argument', () async {
      final service = DBusMailService();
      reply = jsonEncode([
        {'id': 'a', 'name': 'Alex', 'address': 'alex@example.org'},
      ]);
      final accounts = await service.listAccounts();
      expect(accounts.single.name, 'Alex');
      final args = calls.single.arguments as Map;
      expect(args['destination'], 'dev.frascella.Mail');
      expect(args['path'], '/dev/frascella/Mail1');
      expect(args['interface'], 'dev.frascella.Mail1');
      expect(args['method'], 'ListAccounts');
      expect(args['signature'], '');

      reply = jsonEncode(['m1', 'm2']);
      await service.setFlags(['m1'], add: {MessageFlag.seen});
      final flags = calls.last.arguments as Map;
      expect(flags['signature'], 'sss');
      expect(flags['args'], [
        jsonEncode(['m1']),
        jsonEncode(['seen']),
        jsonEncode([]),
      ]);

      reply = jsonEncode(['m1', 'm2']);
      expect(await service.search('hello'), ['m1', 'm2']);
      expect(jsonDecode((calls.last.arguments as Map)['args'][0] as String), {
        'text': 'hello',
      });
    });

    test('a D-Bus error becomes a MailError', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(DBus.channel, (call) async {
            throw PlatformException(
              code: 'org.freedesktop.DBus.Error.ServiceUnknown',
              message: 'no engine',
            );
          });
      await expectLater(
        DBusMailService().listAccounts(),
        throwsA(
          isA<MailError>().having((e) => e.message, 'message', 'no engine'),
        ),
      );
    });
  });
}
