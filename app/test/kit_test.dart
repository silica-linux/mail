// The Mail screens against the Amalfi kit page `App · Mail`: the frames are those of the
// masters `Apps/Mail/*` of silica-design (JSON `frame`, whole points, 1 pt = 1 px) in the
// 1280 × 720 window of `Apps/Mail/Inbox`. A frame that differs from the kit on purpose says
// why next to the expectation.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_mail/src/l10n.dart';
import 'package:silica_mail/src/service.dart';
import 'package:silica_mail/src/style.dart';
import 'package:silica_mail/src/window.dart';
import 'package:silica_ui/silica_ui.dart';

import 'support.dart';

final DateTime now = DateTime(2026, 10, 14, 15, 30);

Future<FakeMailService> pump(
  WidgetTester tester, {
  FakeMailService? service,
  Brightness brightness = Brightness.light,
  Size size = const Size(1280, 720),
  Locale locale = const Locale('en'),
}) async {
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final fake = service ?? FakeMailService(now: now);
  await tester.pumpWidget(
    AppLocalizationsScope(
      locale: locale,
      child: testApp(MailWindow(service: fake, now: () => now)),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

Rect rectOf(WidgetTester tester, Finder finder) => tester.getRect(finder);

Rect at(double x, double y, double w, double h) => Rect.fromLTWH(x, y, w, h);

void main() {
  tearDown(() => useLocale(const Locale('en')));

  testWidgets('Apps/Mail/Inbox: sidebar 240 · list 320 · reader 720', (
    tester,
  ) async {
    await pump(tester);
    // Toolbar sidebar, List toolbar and Reader toolbar are 52 tall; the three columns are
    // 240, 320 and 720 wide.
    expect(
      rectOf(tester, find.byKey(const ValueKey('sidebar bar'))),
      at(0, 0, 240, 52),
    );
    expect(
      rectOf(tester, find.byKey(const ValueKey('list bar'))),
      at(240, 0, 320, 52),
    );
    expect(
      rectOf(tester, find.byKey(const ValueKey('reader bar'))),
      at(560, 0, 720, 52),
    );
    expect(
      rectOf(tester, find.byKey(const ValueKey('sidebar'))),
      at(0, 0, 240, 720),
    );
    expect(
      rectOf(tester, find.byKey(const ValueKey('message list'))),
      at(240, 52, 320, 668),
    );
  });

  testWidgets('Apps/Mail/Toolbar Reader: compose, reply, triage, search', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('row m0')));
    await tester.pumpAndSettle();
    // The kit ends the section 8 from the window's edge; components.md puts the toolbar's
    // last control 20 from it (padding 16 + piece 4), so every frame is 8 left of the kit's
    // (compose 228, reply 272, triage 390, search 508 in the reader's own coordinates).
    const shift = 8.0;
    expect(
      rectOf(tester, find.byKey(const ValueKey('compose'))),
      at(560 + 228 - shift, 8, 36, 36),
    );
    expect(
      rectOf(tester, find.byKey(const ValueKey('reply group'))),
      at(560 + 272 - shift, 8, 110, 36),
    );
    expect(
      rectOf(tester, find.byKey(const ValueKey('triage group'))),
      at(560 + 390 - shift, 8, 110, 36),
    );
    expect(
      rectOf(tester, find.byKey(const ValueKey('search field'))),
      at(560 + 508 - shift, 8, 200, 36),
    );
  });

  testWidgets('Apps/Mail/Toolbar List: title block and filter group', (
    tester,
  ) async {
    await pump(tester);
    // Mail Filter: a 73 × 36 group at x 235 of the 320 pt section, y 8.
    expect(
      rectOf(tester, find.byKey(const ValueKey('list bar'))).left + 235,
      240 + 235,
    );
    final filter = find.descendant(
      of: find.byKey(const ValueKey('list bar')),
      matching: find.byType(AmalfiActionSegments),
    );
    expect(rectOf(tester, filter), at(240 + 235, 8, 73, 36));
    // Title + Subtitle: the text block starts at x 20 (piece at 12, padding 8).
    final title = find.descendant(
      of: find.byType(AmalfiTitlePiece),
      matching: find.text('Inbox'),
    );
    expect(rectOf(tester, title).top, greaterThanOrEqualTo(8));
    expect(rectOf(tester, title).bottom, lessThanOrEqualTo(44));
  });

  testWidgets('Apps/Mail/List Row: 84 tall, text at x 24, separator, selection', (
    tester,
  ) async {
    await pump(tester);
    // Rows come at a pitch of 84 from y 52.
    final r0 = rectOf(tester, find.byKey(const ValueKey('row m0')));
    expect(r0, at(240, 52, 320, 84));
    final first = find.descendant(
      of: find.byKey(const ValueKey('row m0')),
      matching: find.byType(Text),
    );
    // Sender at (24, 8) 18 tall, date 16 tall at y 8 ending 16 from the edge, subject at
    // (24, 26) 18 tall, summary at (24, 44).
    final texts = tester.widgetList<Text>(first).toList();
    final sender = tester.getRect(first.at(0));
    expect(sender.left, 240 + 24);
    expect(sender.top, 52 + 8);
    expect(sender.height, 18);
    final date = tester.getRect(find.byKey(const ValueKey('date m0')));
    expect(date.right, 240 + 320 - 16);
    expect(date.top, 52 + 8);
    expect(date.height, 16);
    expect(texts.length, greaterThanOrEqualTo(4));
    final subject = tester.getRect(first.at(2));
    expect(subject.left, 240 + 24);
    expect(subject.top, 52 + 26);
    expect(subject.height, 18);
    final summary = tester.getRect(first.at(texts.length - 1));
    expect(summary.left, 240 + 24);
    expect(summary.top, 52 + 44);
    // The selection capsule: x 8, y 4, 304 × 76.
    await tester.tap(find.byKey(const ValueKey('row m0')));
    await tester.pumpAndSettle();
    expect(
      rectOf(tester, find.byKey(const ValueKey('selection m0'))),
      at(240 + 8, 52 + 4, 304, 76),
    );
    final selection =
        tester
                .widget<DecoratedBox>(
                  find.byKey(const ValueKey('selection m0')),
                )
                .decoration
            as ShapeDecoration;
    expect(selection.color, AmalfiColors.light.accentAmalfi);
    final border = selection.shape as AmalfiSmoothBorder;
    expect(border.radii.first, 8);
  });

  testWidgets('Apps/Mail/Reader: count, cards at x 20 with a 12 gap', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('row m0')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));
    // Count at (24, 16) 16 tall; Card 1 at (20, 40) 680 wide with a 12 radius.
    final count = rectOf(tester, find.byKey(const ValueKey('reader count')));
    expect(count.left, 560 + 24);
    expect(count.top, 52 + 16);
    expect(count.height, 16);
    final card = rectOf(tester, find.byKey(const ValueKey('card m0')));
    expect(card.left, 560 + 20);
    expect(card.top, 52 + 40);
    expect(card.width, 680);
    final second = rectOf(tester, find.byKey(const ValueKey('card m10')));
    expect(second.top - card.bottom, 12);
    final decoration =
        tester
                .widget<DecoratedBox>(find.byKey(const ValueKey('card m0')))
                .decoration
            as ShapeDecoration;
    expect(decoration.color, AmalfiColors.light.surfaceRaised);
    expect((decoration.shape as AmalfiSmoothBorder).radii.first, 12);
    // The header is 80 tall: the separator sits at y 80 of the card; the sender at (60, 12).
    final sender = tester.getRect(
      find
          .descendant(
            of: find.byKey(const ValueKey('card m0')),
            matching: find.byType(Text),
          )
          .at(1),
    );
    expect(sender.left, card.left + 60);
    expect(sender.top, card.top + 12);
    final subject = rectOf(tester, find.byKey(const ValueKey('subject m0')));
    expect(subject.top, card.top + 32);
    // The avatar: 32 across at (16, 16).
    final avatar = tester.getRect(
      find
          .descendant(
            of: find.byKey(const ValueKey('card m0')),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(avatar.size, const Size(32, 32));
    expect(avatar.topLeft - card.topLeft, const Offset(16, 16));
  });

  testWidgets('Apps/Mail/Empty Mailbox: empty list, zero messages, no message', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('mailbox drafts')));
    await tester.pumpAndSettle();
    expect(titleOf(tester), 'Drafts');
    expect(subtitleOf(tester), 'No messages');
    expect(find.byKey(const ValueKey('empty list')), findsOneWidget);
    expect(find.text('No Message Selected'), findsOneWidget);
    // Apps/Mail/Reader Empty: the title is centred in the 720 × 668 reader (Title 2).
    final empty = rectOf(tester, find.byKey(const ValueKey('no selection')));
    expect(empty.center.dx, 560 + 360);
    expect(empty.height, 26);
    expect(empty.center.dy, closeTo(52 + 316 + 13, 1));
  });

  testWidgets('Apps/Mail/Search: results grouped, matches highlighted', (
    tester,
  ) async {
    await pump(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'lunch');
    await tester.pump();
    await tester.tap(find.text('Subject contains: lunch'));
    await tester.pumpAndSettle();
    // The sidebar gains a Search section with All Mailboxes (selected, with the count) and
    // the field holds the scope token.
    expect(find.byKey(const ValueKey('all mailboxes')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('all mailboxes')),
        matching: find.byType(AmalfiSidebarBadge),
      ),
      findsOneWidget,
    );
    expect(find.byType(AmalfiToken), findsOneWidget);
    expect(titleOf(tester), 'Searching');
    // Apps/Mail/List Header: 28 tall, the title at x 24, y 8.
    final header = rectOf(
      tester,
      find.byKey(const ValueKey('list header Best Matches')),
    );
    expect(header.left, 240 + 24);
    expect(header.top, 52 + 8);
    // The matches carry the search highlight.
    final highlighted = tester
        .widgetList<RichText>(find.byType(RichText))
        .where(
          (t) =>
              t.text.toPlainText().contains('Lunch') &&
              _hasBackground(t.text, AmalfiMailColors.light.searchHighlight),
        );
    expect(highlighted, isNotEmpty);
    // The other mailboxes stay in the sidebar.
    expect(find.byKey(const ValueKey('mailbox inbox')), findsOneWidget);
  });

  testWidgets('dark appearance: Mail palette and surfaces of the kit', (
    tester,
  ) async {
    await pump(tester, brightness: Brightness.dark);
    await tester.tap(find.byKey(const ValueKey('row m2')));
    await tester.pumpAndSettle();
    final colors = AmalfiColors.dark;
    final decoration =
        tester
                .widget<DecoratedBox>(
                  find.byKey(const ValueKey('selection m2')),
                )
                .decoration
            as ShapeDecoration;
    expect(decoration.color, colors.accentAmalfi);
    // The flag of Mail's palette (App/Mail/Flag) on the flagged conversation.
    expect(MailColors.dark.flagged, AmalfiMailColors.dark.flag);
    expect(MailColors.light.flagged, AmalfiMailColors.light.flag);
    expect(MailColors.dark.reader, colors.surfaceSidebar);
    expect(MailColors.dark.content, colors.surfaceWindow);
  });

  testWidgets('the filter button shows unread or flagged messages only', (
    tester,
  ) async {
    await pump(tester, size: const Size(1280, 1100));
    int rows() => find
        .byWidgetPredicate(
          (w) =>
              w.key is ValueKey &&
              '${(w.key! as ValueKey).value}'.startsWith('row '),
        )
        .evaluate()
        .length;
    final all = rows();
    await tapSegment(tester, 'list filter', 0);
    await tester.pumpAndSettle();
    expect(find.text('All Messages'), findsOneWidget);
    await tester.tap(find.text('Unread'));
    // The menu runs the choice after its 114 ms blink.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    final dots = find
        .byWidgetPredicate(
          (w) =>
              w.key is ValueKey &&
              '${(w.key! as ValueKey).value}'.startsWith('unread dot '),
        )
        .evaluate()
        .length;
    expect(rows(), lessThan(all));
    expect(rows(), dots);
    // The filter shows in the accent while it hides messages; All Messages undoes it.
    await tapSegment(tester, 'list filter', 0);
    await tester.pumpAndSettle();
    await tester.tap(find.text('All Messages'));
    // The menu runs the choice after its 114 ms blink.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(rows(), all);
  });

  testWidgets('the more button gets mail and marks everything read', (
    tester,
  ) async {
    final fake = await pump(tester);
    await tapSegment(tester, 'list filter', 1);
    await tester.pumpAndSettle();
    expect(find.text('Get New Mail'), findsOneWidget);
    await tester.tap(find.text('Mark All Messages as Read'));
    // The menu runs the choice after its 114 ms blink.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    final rows = await fake.listMessages(const ListQuery('inbox'));
    expect(rows.where((r) => r.unread), isEmpty);
  });

  testWidgets('a narrow reader turns the search field into a button', (
    tester,
  ) async {
    await pump(tester, size: MailMetrics.minimumWindow + const Offset(0, 500));
    expect(find.byKey(const ValueKey('search field')), findsNothing);
    final button = rectOf(tester, find.byKey(const ValueKey('search')));
    expect(button.size, const Size(36, 36));
    // Searching takes the room of the reply and triage groups.
    await tester.tap(find.byKey(const ValueKey('search')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('search field')), findsOneWidget);
    expect(find.byKey(const ValueKey('reply group')), findsNothing);
    expect(find.byKey(const ValueKey('compose')), findsOneWidget);
  });

  testWidgets('the sidebar button hands the window buttons to the list bar', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('sidebar toggle')));
    await tester.pumpAndSettle();
    // The list starts at the window's edge and its section starts with the 96 pt slot of
    // the window buttons, then the sidebar button.
    expect(rectOf(tester, find.byKey(const ValueKey('list bar'))).left, 0);
    final toggle = rectOf(tester, find.byKey(const ValueKey('sidebar toggle')));
    expect(toggle, at(96 + 4, 8, 36, 36));
  });

  testWidgets('Apps/Mail/Compose: 832 × 720, rows of 40, From in the header', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('compose')));
    await tester.pumpAndSettle();
    final panel = rectOf(tester, find.byKey(const ValueKey('composer panel')));
    expect(panel.size, const Size(832, 720));
    Rect rel(Rect r) => r.shift(-panel.topLeft);
    // Toolbar Compose: controls 96 wide at x 4, Send 36 × 36 at (772, 8).
    expect(
      rel(rectOf(tester, find.byType(AmalfiControlsPiece))),
      at(4, 0, 96, 52),
    );
    expect(
      rel(rectOf(tester, find.byKey(const ValueKey('compose send')))),
      at(772, 8, 36, 36),
    );
    // Labels at x 24, rows 40 apart from y 52 (labels 16 tall at y 64, 104, 144, 184).
    for (final (label, y) in [
      ('To:', 64.0),
      ('Cc:', 104.0),
      ('Subject:', 144.0),
      ('From:', 184.0),
    ]) {
      final r = rel(rectOf(tester, find.text(label)));
      expect(r.left, 24, reason: label);
      expect(r.top, y, reason: label);
      expect(r.height, 16, reason: label);
    }
    // The values start at x 104; From is the account, read only.
    final from = rel(
      rectOf(tester, find.byKey(const ValueKey('compose from'))),
    );
    expect(from.left, 104);
    expect(from.top, 183);
    expect(from.height, 18);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('compose from'))).data,
      'Alex Rivera <alex@example.org>',
    );
  });

  testWidgets('a recipient typed with a comma becomes a token', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('compose')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('compose to')),
      'lena@example.org, sam@example.net',
    );
    await tester.pump();
    final token = tester.widget<AmalfiToken>(
      find.byKey(const ValueKey('compose to token 0')),
    );
    expect(token.label, 'lena@example.org');
    // The one still being typed is not a token yet but counts as a recipient.
    expect(find.byKey(const ValueKey('compose to token 1')), findsNothing);
    // The token's cross removes it.
    token.onRemove!();
    await tester.pump();
    expect(find.byKey(const ValueKey('compose to token 0')), findsNothing);
  });

  testWidgets('Apps/Mail/Compose Discard: a changed message asks first', (
    tester,
  ) async {
    final fake = await pump(tester);
    await tester.tap(find.byKey(const ValueKey('compose')));
    await tester.pumpAndSettle();
    // Unchanged: Escape closes at once.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('composer')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('compose')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('compose subject')),
      'Weekend baking plan',
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    // The alert is 280 wide, three buttons stacked: Save (disabled: no drafts yet),
    // Don't Save, Cancel.
    final alert = rectOf(tester, find.byKey(const ValueKey('compose discard')));
    expect(alert.width, 280);
    expect(find.text('Save this message as a draft?'), findsOneWidget);
    final save = tester.widget<AmalfiPushButton>(
      find.byKey(const ValueKey('compose discard save')),
    );
    expect(save.onPressed, isNull);
    final saveY = tester
        .getTopLeft(find.byKey(const ValueKey('compose discard save')))
        .dy;
    final dontY = tester
        .getTopLeft(find.byKey(const ValueKey('compose discard dont save')))
        .dy;
    final cancelY = tester
        .getTopLeft(find.byKey(const ValueKey('compose discard cancel')))
        .dy;
    expect(saveY, lessThan(dontY));
    expect(dontY, lessThan(cancelY));
    // Cancel keeps the message; Escape does the same.
    await tester.tap(find.byKey(const ValueKey('compose discard cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('compose discard')), findsNothing);
    expect(find.byKey(const ValueKey('composer')), findsOneWidget);
    // Don't Save discards it.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('compose discard dont save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('composer')), findsNothing);
    expect(fake.sent, isEmpty);
  });

  testWidgets('Apps/Mail/Add Account: the 528 × 416 sheet and its first step', (
    tester,
  ) async {
    await pump(tester, service: FakeMailService(now: now, sample: false));
    final sheet = rectOf(tester, find.byKey(const ValueKey('account sheet')));
    expect(sheet.size, const Size(528, 416));
    expect(sheet.center.dx, 640);
    Rect rel(Rect r) => r.shift(-sheet.topLeft);
    // Title 2 at y 40 (26 tall), the hint at y 76 (16 tall), centred.
    final title = rel(rectOf(tester, find.text('Add Account').last));
    expect(title.top, 40);
    expect(title.height, 26);
    final hint = rel(
      rectOf(
        tester,
        find.text('Enter your email address and Mail will find the settings.'),
      ),
    );
    expect(hint.top, 76);
    expect(hint.height, 16);
    // The address field at (20, 128), 488 wide; the kit stretches the Large field to 40, the
    // control scale stops at 32 (components.md).
    final address = rel(
      rectOf(tester, find.byKey(const ValueKey('setup address'))),
    );
    expect(address, at(20, 128, 488, 32));
    // Continue ends 28 from the right edge, 28 tall at y 356; Cancel is 8 before it (the kit
    // draws the two touching).
    final cont = rel(
      rectOf(tester, find.byKey(const ValueKey('setup continue'))),
    );
    expect(cont.right, 500);
    expect(cont.top, 356);
    expect(cont.height, 28);
    final cancel = rel(
      rectOf(tester, find.byKey(const ValueKey('setup cancel'))),
    );
    expect(cont.left - cancel.right, 8);
    expect(cancel.height, 28);
    // Continue stays disabled until an address is typed (kit: Primary/Regular/Disabled).
    expect(
      tester
          .widget<AmalfiPushButton>(
            find.byKey(const ValueKey('setup continue')),
          )
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.byKey(const ValueKey('setup address')),
      'robin@example.com',
    );
    await tester.pump();
    expect(
      tester
          .widget<AmalfiPushButton>(
            find.byKey(const ValueKey('setup continue')),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('Italian: the new texts are translated', (tester) async {
    await pump(tester, locale: const Locale('it'));
    expect(find.byKey(const ValueKey('list bar')), findsOneWidget);
    await tapSegment(tester, 'list filter', 0);
    await tester.pumpAndSettle();
    expect(find.text('Tutti i messaggi'), findsOneWidget);
    expect(find.text('Non letti'), findsOneWidget);
  });
}

bool _hasBackground(InlineSpan span, Color color) {
  var found = false;
  span.visitChildren((s) {
    if (s is TextSpan && s.style?.backgroundColor == color) found = true;
    return true;
  });
  return found;
}
