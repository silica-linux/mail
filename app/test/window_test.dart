import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_mail/src/l10n.dart';
import 'package:silica_mail/src/model.dart';
import 'package:silica_mail/src/service.dart';
import 'package:silica_mail/src/window.dart';

final DateTime now = DateTime(2026, 10, 14, 15, 30);

Future<FakeMailService> pump(
  WidgetTester tester, {
  FakeMailService? service,
  Locale locale = const Locale('en'),
  List<String>? opened,
}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final fake = service ?? FakeMailService(now: now);
  await tester.pumpWidget(
    AppLocalizationsScope(
      locale: locale,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: MailWindow(service: fake, now: () => now, openUrl: opened?.add),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

Future<void> tapRow(WidgetTester tester, String id) async {
  await tester.tap(find.byKey(ValueKey('row $id')));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => useLocale(const Locale('en')));

  testWidgets('the inbox lists conversations, newest first, with unread dots', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byKey(const ValueKey('title')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('title'))).data,
      'Inbox',
    );
    // 20 messages in 10 threads (t0…t9).
    expect(find.text('10 messages'), findsOneWidget);
    expect(find.byKey(const ValueKey('unread dot m0')), findsOneWidget);
    expect(find.byKey(const ValueKey('no selection')), findsOneWidget);
    // The unread count of the inbox in the sidebar.
    expect(find.byKey(const ValueKey('unread inbox')), findsOneWidget);
  });

  testWidgets('selecting opens the conversation and marks it read', (
    tester,
  ) async {
    final fake = await pump(tester);
    await tapRow(tester, 'm0');
    expect(find.byKey(const ValueKey('reader')), findsOneWidget);
    expect(find.byKey(const ValueKey('subject m0')), findsOneWidget);
    // m0 and m10 share thread t0: both in the reader.
    expect(find.byKey(const ValueKey('subject m10')), findsOneWidget);
    final row = (await fake.listMessages(
      const ListQuery('inbox'),
    )).firstWhere((r) => r.id == 'm0');
    expect(row.unread, isFalse);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('unread dot m0')), findsNothing);
  });

  testWidgets('remote content stays blocked until the user loads it', (
    tester,
  ) async {
    final opened = <String>[];
    await pump(tester, opened: opened);
    // m1 has HTML with a remote image (thread t1, with m11).
    await tapRow(tester, 'm1');
    expect(find.byKey(const ValueKey('remote banner m1')), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    await tester.tap(find.byKey(const ValueKey('load remote m1')));
    await tester.pump();
    expect(find.byKey(const ValueKey('remote banner m1')), findsNothing);
  });

  testWidgets('search lists the matching messages; Escape goes back', (
    tester,
  ) async {
    await pump(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('search field')), findsOneWidget);
    await tester.enterText(find.byType(EditableText), 'lunch');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('title'))).data,
      'Results for “lunch”',
    );
    expect(find.text('Lunch on Friday?'), findsWidgets);
    expect(find.text('Notes from Tuesday'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('title'))).data,
      'Inbox',
    );
  });

  testWidgets('reply is prefilled and sends through the engine', (
    tester,
  ) async {
    final fake = await pump(tester);
    await tapRow(tester, 'm2');
    await tester.tap(find.byKey(const ValueKey('reply')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('composer')), findsOneWidget);
    final to = tester.widget<EditableText>(
      find.byKey(const ValueKey('compose to')),
    );
    expect(to.controller.text, 'Lena Fischer <lena@example.org>');
    final subject = tester.widget<EditableText>(
      find.byKey(const ValueKey('compose subject')),
    );
    expect(subject.controller.text, 'Re: Lunch on Friday?');
    final body = tester.widget<EditableText>(
      find.byKey(const ValueKey('compose body')),
    );
    expect(body.controller.text, contains('Lena Fischer wrote:'));
    expect(body.controller.text, contains('> Hi Alex,'));
    await tester.tap(find.byKey(const ValueKey('compose send')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('composer')), findsNothing);
    expect(fake.sent.single.subject, 'Re: Lunch on Friday?');
    expect(fake.sent.single.inReplyTo, isNotNull);
  });

  testWidgets('a new message without recipients is not sent', (tester) async {
    final fake = await pump(tester);
    await tester.tap(find.byKey(const ValueKey('compose')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('compose send')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('compose error')), findsOneWidget);
    expect(fake.sent, isEmpty);
  });

  testWidgets('delete moves the message to the Trash and selects the next', (
    tester,
  ) async {
    final fake = await pump(tester);
    await tapRow(tester, 'm3');
    await tester.tap(find.byKey(const ValueKey('delete')));
    await tester.pumpAndSettle();
    final trash = await fake.listMessages(const ListQuery('trash'));
    expect(trash.map((r) => r.id), contains('m3'));
    expect(find.byKey(const ValueKey('row m3')), findsNothing);
    expect(find.byKey(const ValueKey('reader')), findsOneWidget);
  });

  testWidgets('without accounts the window offers to add one', (tester) async {
    final fake = FakeMailService(now: now, sample: false);
    await pump(tester, service: fake);
    expect(find.byKey(const ValueKey('no accounts')), findsOneWidget);
    await tester.tap(find.text('Add Account').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('account setup')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('setup name')), 'Robin');
    await tester.enterText(
      find.byKey(const ValueKey('setup address')),
      'robin@example.com',
    );
    await tester.tap(find.byKey(const ValueKey('setup continue')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('setup imap'))).data,
      'Incoming server: imap.example.com:993',
    );
    await tester.enterText(
      find.byKey(const ValueKey('setup password')),
      'secret',
    );
    await tester.tap(find.byKey(const ValueKey('setup continue')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('account setup')), findsNothing);
    expect((await fake.listAccounts()).single.address, 'robin@example.com');
  });

  testWidgets('Italian: mailboxes and texts in Italian', (tester) async {
    await pump(tester, locale: const Locale('it'));
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('title'))).data,
      'In arrivo',
    );
    expect(find.text('10 messaggi'), findsOneWidget);
    expect(find.text('Nessun messaggio scelto'), findsOneWidget);
    expect(find.text('Cestino'), findsOneWidget);
  });

  testWidgets('dark appearance and inactive window use their colours', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await pump(tester);
    await tapRow(tester, 'm0');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    final row = tester.widget<Container>(
      find
          .descendant(
            of: find.byKey(const ValueKey('row m0')),
            matching: find.byType(Container),
          )
          .first,
    );
    expect((row.decoration! as BoxDecoration).color, const Color(0xFF464646));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    final active = tester.widget<Container>(
      find
          .descendant(
            of: find.byKey(const ValueKey('row m0')),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(
      (active.decoration! as BoxDecoration).color,
      const Color(0xFF0059D1),
    );
    expect(MailFlagCheck.ok, isTrue);
  });
}

/// Keeps the model import used (flags are checked through the fake above).
abstract final class MailFlagCheck {
  static bool get ok => MessageFlag.values.length == 4;
}
