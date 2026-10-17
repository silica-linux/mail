import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_mail/src/compose.dart';
import 'package:silica_mail/src/l10n.dart';
import 'package:silica_mail/src/service.dart';
import 'package:silica_mail/src/window.dart';

import 'support.dart';

final DateTime now = DateTime(2026, 10, 14, 15, 30);

Future<FakeMailService> pump(
  WidgetTester tester, {
  List<String> initial = const [],
  Stream<List<String>>? opened,
}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final fake = FakeMailService(now: now);
  await tester.pumpWidget(
    AppLocalizationsScope(
      locale: const Locale('en'),
      child: testApp(
        MailWindow(
          service: fake,
          now: () => now,
          initialFiles: initial,
          openedFiles: opened,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  test('launch arguments become file paths', () {
    bool all(String _) => true;
    expect(
      attachmentsFromArgs([
        '--flag',
        '/home/a/My%20file.pdf',
        'file:///home/a/My%20file.pdf',
        'file:///home/a/b.txt',
        'https://example.net/x',
        '',
      ], exists: all),
      ['/home/a/My%20file.pdf', '/home/a/My file.pdf', '/home/a/b.txt'],
    );
    expect(attachmentsFromArgs(['/nope/x'], exists: (_) => false), isEmpty);
    expect(attachmentName('/home/a/b.txt'), 'b.txt');
  });

  testWidgets('files at launch open a message with them attached', (
    tester,
  ) async {
    final fake = await pump(tester, initial: ['/home/a/report.pdf']);
    expect(find.byKey(const ValueKey('composer')), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('compose attachments')))
          .data,
      'report.pdf',
    );
    await tester.enterText(
      find.byKey(const ValueKey('compose to')),
      'sam@example.net',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('compose send')));
    await tester.pumpAndSettle();
    expect(fake.sent.single.attachments, ['/home/a/report.pdf']);
  });

  testWidgets('files arriving while Mail runs open or join a message', (
    tester,
  ) async {
    final controller = StreamController<List<String>>.broadcast();
    addTearDown(controller.close);
    final fake = await pump(tester, opened: controller.stream);
    expect(find.byKey(const ValueKey('composer')), findsNothing);
    controller.add(['/home/a/one.png']);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('composer')), findsOneWidget);
    controller.add(['/home/a/two.png', '/home/a/one.png']);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('compose attachments')))
          .data,
      'one.png, two.png',
    );
    await tester.enterText(
      find.byKey(const ValueKey('compose to')),
      'sam@example.net',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('compose send')));
    await tester.pumpAndSettle();
    expect(fake.sent.single.attachments, [
      '/home/a/one.png',
      '/home/a/two.png',
    ]);
  });
}
