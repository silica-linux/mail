import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_mail/src/l10n.dart';
import 'package:silica_mail/src/service.dart';
import 'package:silica_mail/src/window.dart';
import 'package:silica_ui/silica_ui.dart';

import 'support.dart';

final DateTime now = DateTime(2026, 10, 14, 15, 30);

Future<void> shot(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File(
      '/dev/shm/mailw/$name.png',
    ).writeAsBytesSync(data!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    AmalfiSymbols.debugEnvironment = {
      'SILICA_ICONS_DIR': '/home/emanuele-frascella/silica/silica-icons',
    };
    final loader = FontLoader('packages/silica_ui/Inter')
      ..addFont(rootBundle.load('packages/silica_ui/fonts/Inter-Regular.ttf'))
      ..addFont(rootBundle.load('packages/silica_ui/fonts/Inter-Medium.ttf'))
      ..addFont(rootBundle.load('packages/silica_ui/fonts/Inter-SemiBold.ttf'))
      ..addFont(rootBundle.load('packages/silica_ui/fonts/Inter-Bold.ttf'));
    await loader.load();
  });

  for (final dark in [false, true]) {
    testWidgets('shots ${dark ? 'dark' : 'light'}', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = dark
          ? Brightness.dark
          : Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      final fake = FakeMailService(now: now);
      await tester.pumpWidget(
        AppLocalizationsScope(
          locale: const Locale('en'),
          child: testApp(
            RepaintBoundary(
              key: key,
              child: MailWindow(service: fake, now: () => now),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final tag = dark ? 'dark' : 'light';
      await shot(tester, key, 'inbox-$tag');
      await tester.tap(find.byKey(const ValueKey('row m0')));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      await shot(tester, key, 'selected-$tag');
      await tester.tap(find.byKey(const ValueKey('compose')));
      await tester.pumpAndSettle();
      await shot(tester, key, 'compose-$tag');
      await tester.enterText(
        find.byKey(const ValueKey('compose subject')),
        'Weekend baking plan',
      );
      await tester.enterText(
        find.byKey(const ValueKey('compose to')),
        'lena@example.org, Lemon Cake Club <lemon@example.org>, ',
      );
      await tester.pump();
      await shot(tester, key, 'compose-filled-$tag');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await shot(tester, key, 'discard-$tag');
      await tester.tap(find.text('Don’t Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mailbox drafts')));
      await tester.pumpAndSettle();
      await shot(tester, key, 'empty-$tag');
      await tester.tap(find.byKey(const ValueKey('mailbox inbox')));
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), 'lunch');
      await tester.pump();
      await shot(tester, key, 'suggest-$tag');
      await tester.tap(find.text('Subject contains: lunch'));
      await tester.pumpAndSettle();
      await shot(tester, key, 'search-$tag');
      await tapSegment(tester, 'list filter', 0);
      await tester.pumpAndSettle();
      await shot(tester, key, 'menu-$tag');
      expect(titleOf(tester), isNotEmpty);
    });
  }
}
