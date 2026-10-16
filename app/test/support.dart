import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_ui/silica_ui.dart';

/// The texts of the list's title block: the title, then the subtitle.
List<String> _titleTexts(WidgetTester tester) => [
  for (final t in tester.widgetList<Text>(
    find.descendant(
      of: find.byType(AmalfiTitlePiece),
      matching: find.byType(Text),
    ),
  ))
    t.data ?? '',
];

/// The title of the list's toolbar section (the mailbox, or "Searching").
String titleOf(WidgetTester tester) => _titleTexts(tester).first;

/// The line under the title (the counts, or the search scope).
String subtitleOf(WidgetTester tester) => _titleTexts(tester)[1];

/// Presses segment `index` of the action group with the key `group` (the segments are
/// 32 pt squares side by side).
Future<void> tapSegment(WidgetTester tester, String group, int index) async {
  final rect = tester.getRect(find.byKey(ValueKey(group)));
  await tester.tapAt(Offset(rect.left + 16 + 32.0 * index, rect.center.dy));
}

/// The app's root as `main` builds it: a `WidgetsApp` (the overlay of menus and tooltips, the
/// text-editing shortcuts) around the window.
Widget testApp(Widget home) => WidgetsApp(
  color: AmalfiColors.light.accentAmalfi,
  debugShowCheckedModeBanner: false,
  pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
    settings: settings,
    pageBuilder: (context, _, _) => builder(context),
  ),
  home: home,
);
