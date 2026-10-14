// Geometry and colours of the Mail window, in one place.
//
// Measured in silica-reference ML-01 (`mail.md`, 1 pt = 1 px). Values the session did not
// measure are marked PROVISIONAL with the sibling they were taken from.

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:silica_ui/silica_ui.dart';

/// Geometry (pt).
abstract final class MailMetrics {
  /// The smallest window (ML-01: the toolbar collapses into an overflow button there).
  static const Size minimumWindow = Size(751, 200);

  // Sidebar (ML-01 › Sidebar).
  static const double sidebarWidth = 208;
  static const double sidebarRow = 32;
  static const double sidebarHeading = 19;
  static const double sidebarHeadingX = 17;
  static const double sidebarIconX = 20;
  static const double sidebarTitleX = 55;

  /// The unread count ends 15 pt before the sidebar edge (x 193 of 208).
  static const double sidebarCountEnd = 15;

  /// The selected mailbox: a rounded rectangle inset ~8 pt (radius PROVISIONAL, from the list).
  static const double sidebarSelectionInset = 8;
  static const double sidebarSelectionRadius = 6;

  /// The sidebar button, 40 × 52, at x 164 of the sidebar.
  static const double sidebarToggleX = 164;
  static const double sidebarToggleWidth = 40;

  // Message list (ML-01 › Message list).
  static const double listWidth = 325;
  static const double listRow = 80;

  /// The row cell: 276 wide at x 16 of the list; the overlay scroller takes the right edge.
  static const double cellX = 16;
  static const double cellWidth = 276;

  /// Inside the cell: sender, date, subject and summary.
  static const double senderX = 17;
  static const double senderY = 7;
  static const double dateY = 9;
  static const double subjectY = 26;
  static const double summaryY = 43;
  static const double summaryLine = 15;

  /// The unread dot: AX box 13 × 10 at cell x −1, y 11; the dot is 10 across (PROVISIONAL).
  static const double unreadDotX = -1;
  static const double unreadDotY = 11;
  static const double unreadDotBox = 13;
  static const double unreadDot = 10;

  /// The selection fill across the row (inset and radius PROVISIONAL, from Mustache's list).
  static const double selectionInset = 8;
  static const double selectionRadius = 8;

  /// A thread child row: sender and one summary line (~45 pt).
  static const double threadChildRow = 45;

  /// Thread expansion: the list changes ~76 ms after the release and settles in ~190–240 ms.
  static const Duration threadExpand = Duration(milliseconds: 200);
  static const Duration threadCollapse = Duration(milliseconds: 210);

  // Toolbar (ML-01 › Viewer window).
  static const double titleBlockWidth = 235;
  static const double searchFieldWidth = 299;

  // Reader (ML-01 › Reader).
  static const double readerHeader = 32;
  static const double cardGap = 8;

  /// Card padding and radius: PROVISIONAL (not measured; window language).
  static const double cardPadding = 16;
  static const double cardRadius = 10;
  static const double avatar = 32;

  /// Composer (ML-01 › Composer): window size, field rows from y 61, 40 pt each.
  static const Size composer = Size(836, 779);
  static const double composerFieldsY = 61;
  static const double composerField = 40;

  /// Add Account sheet: 528 × 416, the address box 488 × 40.
  static const Size accountSheet = Size(528, 416);
  static const double accountFieldWidth = 488;
  static const double accountField = 40;

  /// PROVISIONAL: the message bar under the toolbar (not in the reference).
  static const double bannerHeight = 30;

  /// The window buttons end at x 79: with the sidebar hidden the toolbar starts there.
  static const double windowButtonsEnd = 80;
}

/// Colours, light and dark (ML-01; greys are captured values, saturated colours sRGB).
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
    required this.sidebarHeading,
    required this.unread,
    required this.thread,
    required this.threadTint,
    required this.flagged,
    required this.banner,
    required this.link,
    required this.field,
    required this.quote,
    required this.reader,
    required this.card,
    required this.highlight,
    required this.send,
  });

  final Color sidebar;

  /// The list background.
  final Color content;
  final Color text;
  final Color secondary;
  final Color tertiary;

  /// List/reader separator and row separators.
  final Color separator;
  final Color selection;
  final Color selectionText;
  final Color selectionSecondary;
  final Color inactiveSelection;
  final Color sidebarSelection;
  final Color sidebarHeading;
  final Color unread;

  /// The thread count and its chevron.
  final Color thread;

  /// The block behind an expanded thread's children.
  final Color threadTint;
  final Color flagged;
  final Color banner;
  final Color link;
  final Color field;
  final Color quote;

  /// The reader background and its message cards.
  final Color reader;
  final Color card;

  /// Search matches in the list.
  final Color highlight;

  /// The send button.
  final Color send;

  static const MailColors light = MailColors(
    sidebar: Color(0xFFEAEAEB),
    content: Color(0xFFFFFFFF),
    // PROVISIONAL text greys (window language, as in Mustache).
    text: Color(0xFF1D1D1F),
    secondary: Color(0xFF6E6E73),
    tertiary: Color(0xFF9E9EA3),
    separator: Color(0xFFE6E6E6),
    selection: Color(0xFF0171E1),
    selectionText: Color(0xFFFFFFFF),
    // PROVISIONAL: secondary text on the selection.
    selectionSecondary: Color(0xFFD6E6FA),
    inactiveSelection: Color(0xFFDCDCDC),
    sidebarSelection: Color(0xFFD3D6DC),
    // PROVISIONAL: "small gray semibold".
    sidebarHeading: Color(0xFF8E8E93),
    unread: Color(0xFF0088FF),
    thread: Color(0xFF0088FF),
    threadTint: Color(0xFFEDF3FB),
    flagged: Color(0xFFFF9500),
    banner: Color(0xFFF2F2F7),
    link: Color(0xFF0064E1),
    field: Color(0xFFFFFFFF),
    quote: Color(0xFFC7C7CC),
    reader: Color(0xFFF8F8F8),
    card: Color(0xFFFFFFFF),
    // PROVISIONAL: the yellow of the search matches.
    highlight: Color(0xFFFFE066),
    send: Color(0xFF0171E1),
  );

  static const MailColors dark = MailColors(
    sidebar: Color(0xFF2C2C2D),
    content: Color(0xFF272728),
    text: Color(0xFFDFDFE0),
    secondary: Color(0xFF9E9E9E),
    tertiary: Color(0xFF6E6E73),
    separator: Color(0xFF3C3C3D),
    selection: Color(0xFF026ED1),
    selectionText: Color(0xFFFFFFFF),
    selectionSecondary: Color(0xFFCFE0F5),
    inactiveSelection: Color(0xFF464646),
    sidebarSelection: Color(0xFF44484D),
    sidebarHeading: Color(0xFF8E8E93),
    // PROVISIONAL: the dark unread dot is taken as the light one.
    unread: Color(0xFF0088FF),
    thread: Color(0xFF0088FF),
    threadTint: Color(0xFF253244),
    flagged: Color(0xFFFF9F0A),
    banner: Color(0xFF323234),
    link: Color(0xFF4DA3FF),
    field: Color(0xFF1E1E1F),
    quote: Color(0xFF48484A),
    reader: Color(0xFF1B1B1B),
    card: Color(0xFF272728),
    highlight: Color(0xFF8A7414),
    send: Color(0xFF026ED1),
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
