// Geometry and colours of the Mail window, in one place.
//
// PROVISIONAL: the reference measurements (silica-reference ML-01, `mail.md`) have not arrived
// yet. The values below follow the Silica window language already measured for Mustache
// (toolbar 52 pt, sidebar and content colours, list selection, text greys) and must be replaced
// by the measured ones; docs/parity.md lists them.

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:silica_ui/silica_ui.dart';

/// Provisional geometry (pt).
abstract final class MailMetrics {
  static const double sidebarWidth = 220;
  static const double listWidth = 360;
  static const double sidebarRow = 28;
  static const double sidebarHeading = 30;
  static const double listRow = 78;
  static const double listInset = 12;
  static const double unreadDot = 9;
  static const double readerPadding = 24;
  static const double headerGap = 6;
  static const double bannerHeight = 30;

  /// The window buttons end at x 79: with the sidebar hidden the toolbar starts there.
  static const double windowButtonsEnd = 80;
}

/// Provisional colours, light and dark.
@immutable
class MailColors {
  const MailColors({
    required this.sidebar,
    required this.content,
    required this.text,
    required this.secondary,
    required this.tertiary,
    required this.separator,
    required this.selection,
    required this.selectionText,
    required this.selectionSecondary,
    required this.inactiveSelection,
    required this.sidebarSelection,
    required this.unread,
    required this.flagged,
    required this.banner,
    required this.link,
    required this.field,
    required this.quote,
  });

  final Color sidebar;
  final Color content;
  final Color text;
  final Color secondary;
  final Color tertiary;
  final Color separator;
  final Color selection;
  final Color selectionText;
  final Color selectionSecondary;
  final Color inactiveSelection;
  final Color sidebarSelection;
  final Color unread;
  final Color flagged;
  final Color banner;
  final Color link;
  final Color field;
  final Color quote;

  static const MailColors light = MailColors(
    sidebar: Color(0xFFEDEDED),
    content: Color(0xFFFFFFFF),
    text: Color(0xFF1D1D1F),
    secondary: Color(0xFF6E6E73),
    tertiary: Color(0xFF9E9EA3),
    separator: Color(0xFFE5E5E5),
    selection: Color(0xFF0064E1),
    selectionText: Color(0xFFFFFFFF),
    selectionSecondary: Color(0xFFBAD0F7),
    inactiveSelection: Color(0xFFDCDCDC),
    sidebarSelection: Color(0xFFD7D7D7),
    unread: Color(0xFF0A84FF),
    flagged: Color(0xFFFF9500),
    banner: Color(0xFFF2F2F7),
    link: Color(0xFF0064E1),
    field: Color(0xFFFFFFFF),
    quote: Color(0xFFC7C7CC),
  );

  static const MailColors dark = MailColors(
    sidebar: Color(0xFF29292A),
    content: Color(0xFF272728),
    text: Color(0xFFDFDFE0),
    secondary: Color(0xFF9E9E9E),
    tertiary: Color(0xFF6E6E73),
    separator: Color(0xFF363637),
    selection: Color(0xFF0059D1),
    selectionText: Color(0xFFFFFFFF),
    selectionSecondary: Color(0xFFB8CDF2),
    inactiveSelection: Color(0xFF464646),
    sidebarSelection: Color(0xFF464647),
    unread: Color(0xFF0A84FF),
    flagged: Color(0xFFFF9F0A),
    banner: Color(0xFF323234),
    link: Color(0xFF4DA3FF),
    field: Color(0xFF1E1E1F),
    quote: Color(0xFF48484A),
  );

  static MailColors of(BuildContext context) =>
      MediaQuery.maybePlatformBrightnessOf(context) == Brightness.dark
      ? dark
      : light;
}

/// A text style in Inter.
TextStyle mailText(
  double size,
  Color color, {
  FontWeight? weight,
  double? height,
}) => TextStyle(
  fontFamily: uiFontFamily,
  package: 'silica_ui',
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
);

/// A symbol of silica-icons (`symbols/regular/<name>.svg`) in `color`, or a glyph when the icons
/// are not installed (tests, outside Silica).
class Symbol extends StatelessWidget {
  const Symbol(
    this.name, {
    super.key,
    required this.color,
    this.size = 18,
    this.iconsDir,
    this.fallback = '•',
  });

  final String name;
  final Color color;
  final double size;
  final String? iconsDir;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    final dir = iconsDir;
    final file = dir == null ? null : File('$dir/symbols/regular/$name.svg');
    if (file != null && file.existsSync()) {
      return SvgPicture.file(
        file,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Text(fallback, style: mailText(size * 0.7, color, height: 1)),
      ),
    );
  }
}
