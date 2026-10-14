import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_ui/silica_ui.dart';
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
    // 20 messages in 10 threads (t0…t9); the subtitle counts messages and unread ones.
    final subtitle = tester
        .widget<Text>(find.byKey(const ValueKey('subtitle')))
        .data!;
    expect(subtitle, startsWith('20 messages'));
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
      'Searching',
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('subtitle'))).data,
      startsWith('All Mailboxes, '),
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

  testWidgets('the composer is 836 × 779 and Send waits for a recipient', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('compose')));
    await tester.pumpAndSettle();
    final panel = find.byKey(const ValueKey('composer panel'));
    expect(tester.getSize(panel), const Size(836, 779));
    double sendOpacity() => tester
        .widget<Opacity>(
          find.descendant(
            of: find.byKey(const ValueKey('compose send')),
            matching: find.byType(Opacity),
          ),
        )
        .opacity;
    expect(sendOpacity(), 0.4);
    await tester.enterText(
      find.byKey(const ValueKey('compose to')),
      'sam@example.net',
    );
    await tester.pump();
    expect(sendOpacity(), 1);
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
    // The address enables Continue on the next frame.
    await tester.pump();
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
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('subtitle'))).data,
      startsWith('20 messaggi'),
    );
    expect(find.text('Nessun messaggio scelto'), findsOneWidget);
    expect(find.text('Cestino'), findsOneWidget);
  });

  testWidgets('list rows follow ML-01: 80 pt rows in a 325 pt list', (
    tester,
  ) async {
    await pump(tester);
    expect(tester.getSize(find.byKey(const ValueKey('row m0'))).height, 80);
    expect(tester.getSize(find.byKey(const ValueKey('sidebar'))).width, 208);
    expect(
      tester.getSize(find.byKey(const ValueKey('message list'))).width,
      325,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('unread dot m0'))),
      const Size(10, 10),
    );
  });

  testWidgets('a thread expands with Right and collapses with Left', (
    tester,
  ) async {
    await pump(tester);
    await tapRow(tester, 'm0');
    expect(find.byKey(const ValueKey('row m10')), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('thread block m0')), findsOneWidget);
    expect(tester.getSize(find.byKey(const ValueKey('row m10'))).height, 45);
    // The child opens only its message.
    await tapRow(tester, 'm10');
    expect(find.byKey(const ValueKey('subject m10')), findsOneWidget);
    expect(find.byKey(const ValueKey('subject m0')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('thread count m0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('row m10')), findsNothing);
  });

  testWidgets('the sidebar button hides and shows the sidebar', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('sidebar toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sidebar')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('sidebar toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sidebar')), findsOneWidget);
  });

  testWidgets('a subject suggestion searches the subject with a token', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('search field')));
    await tester.pump();
    await tester.enterText(find.byType(EditableText), 'lunch');
    await tester.pump();
    expect(find.byKey(const ValueKey('search suggestions')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('suggest subject')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('search token')), findsOneWidget);
    expect(find.byKey(const ValueKey('search suggestions')), findsNothing);
    expect(find.text('Lunch on Friday?'), findsWidgets);
  });

  test('scope filters match the sender or the subject', () {
    final rows = [
      MessageSummary(
        id: 'a',
        thread: '',
        from: const Address('anna@example.com', name: 'Anna'),
        to: const [],
        subject: 'Plans',
        preview: '',
        date: now,
      ),
      MessageSummary(
        id: 'b',
        thread: '',
        from: const Address('marco@example.com', name: 'Marco'),
        to: const [],
        subject: 'Anna’s party',
        preview: '',
        date: now,
      ),
    ];
    expect(filterByScope(rows, 'anna', SearchScope.sender).map((r) => r.id), [
      'a',
    ]);
    expect(filterByScope(rows, 'anna', SearchScope.subject).map((r) => r.id), [
      'b',
    ]);
    expect(filterByScope(rows, 'anna', SearchScope.all), hasLength(2));
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
    Color selection() =>
        (tester
                    .widget<DecoratedBox>(
                      find.byKey(const ValueKey('selection m0')),
                    )
                    .decoration
                as BoxDecoration)
            .color!;
    expect(selection(), const Color(0xFF464646));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(selection(), const Color(0xFF026ED1));
    expect(MailFlagCheck.ok, isTrue);
  });

  testWidgets('the list scrolls under the glass toolbar; its line follows it', (
    tester,
  ) async {
    await pump(tester);
    tester.view.physicalSize = const Size(1280, 500);
    await tester.pumpAndSettle();
    expect(find.byType(ScrollUnderToolbar), findsOneWidget);
    expect(find.byKey(const ValueKey('list line')), findsNothing);
    expect(find.byKey(const ValueKey('reader line')), findsNothing);
    // The first row starts below the 52 pt band...
    expect(
      tester.getRect(find.byKey(const ValueKey('row m0'))).top,
      greaterThanOrEqualTo(toolbarHeight),
    );
    // ...and goes under it once the list scrolls; only the list's column gets the line.
    await tester.drag(
      find.byKey(const ValueKey('message list')),
      const Offset(0, -60),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const ValueKey('row m0'))).top,
      lessThan(toolbarHeight),
    );
    expect(find.byKey(const ValueKey('list line')), findsOneWidget);
    expect(find.byKey(const ValueKey('reader line')), findsNothing);
    expect(
      tester.getRect(find.byKey(const ValueKey('list line'))).top,
      toolbarHeight,
    );
  });

  testWidgets('an inactive window keeps the lines under the band', (
    tester,
  ) async {
    await pump(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.byKey(const ValueKey('list line')), findsOneWidget);
    expect(find.byKey(const ValueKey('reader line')), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byKey(const ValueKey('list line')), findsNothing);
  });
}

/// Keeps the model import used (flags are checked through the fake above).
abstract final class MailFlagCheck {
  static bool get ok => MessageFlag.values.length == 4;
}
