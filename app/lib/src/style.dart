// Geometry and colours of the Mail window, in one place.
//
// Layout and colours come from the Amalfi kit (`App · Mail`, masters `Apps/Mail/*`) and the
// design system's `components.md`; the durations of the motion are the measured ones
// (silica-reference ML-01, `mail.md`) and stay as they were.

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

/// Geometry (pt). Every frame is on the 4 pt grid except where the kit centres text.
abstract final class MailMetrics {
  /// The smallest window: the sidebar (240), the list (320) and a reader wide enough for the
  /// toolbar's compose button, reply group, triage group and the search button (the kit
  /// draws the window at 1280 × 720).
  static const Size minimumWindow = Size(888, 200);

  // Window (kit `Apps/Mail/Inbox`: sidebar 240 · list 320 · reader 720 at 1280).
  static const double toolbar = AmalfiToolbarMetrics.toolbarHeight;
  static const double sidebarWidth = AmalfiWindowMetrics.sidebarWidth;
  static const double listWidth = 320;

  /// Below this reader width the toolbar's search field becomes a button: compose 40, reply
  /// group 104, triage group 104, field 200 (240 with a token) and the section's padding.
  static const double searchFieldMinReader = 484;

  // Message list (kit `Apps/Mail/List Row/*`, 320 × 84).
  static const double listRow = 84;

  /// The selection capsule: x 8, y 4, 304 × 76, radius 8.
  static const double selectionInsetX = 8;
  static const double selectionInsetY = 4;
  static const double selectionRadius = 8;

  /// Inside a row: the sender, subject and summary start at x 24 and end 16 before the
  /// row's edge.
  static const double textX = 24;
  static const double textEnd = 16;
  static const double senderY = 8;
  static const double senderLine = 18;
  static const double dateY = 8;
  static const double subjectY = 26;
  static const double subjectLine = 18;
  static const double summaryY = 44;
  static const double summaryLine = 16;

  /// The unread dot: 8 across at x 12, y 12.
  static const double unreadDot = 8;
  static const double unreadDotX = 12;
  static const double unreadDotY = 12;

  /// A section header of the search results (kit `Apps/Mail/List Header`): 28 tall, the
  /// title at x 24, y 8.
  static const double listHeader = 28;
  static const double listHeaderTop = 8;

  /// A selected message is marked read ~120 ms after the selection (ML-01b); after a delete
  /// the next message is selected at once and the reader follows ~120 ms later.
  static const Duration markReadDelay = Duration(milliseconds: 120);
  static const Duration readerAfterDelete = Duration(milliseconds: 120);

  /// A thread child row: sender and one summary line (two-line list row, `components.md`).
  static const double threadChildRow = 44;

  /// Thread expansion: the list changes ~76 ms after the release and settles in ~190–240 ms.
  static const Duration threadExpand = Duration(milliseconds: 200);
  static const Duration threadCollapse = Duration(milliseconds: 210);

  // Reader (kit `Apps/Mail/Reader`, 720 × 668).
  static const double readerPadding = 20;
  static const double readerCountX = 24;
  static const double readerCountY = 16;
  static const double readerCountLine = 16;

  /// The first card starts at y 40 of the reader; the next ones 12 below the previous.
  static const double readerCardsTop = 40;
  static const double cardGap = 12;
  static const double cardRadius = 12;

  /// Inside a card: the avatar at (16, 16), 32 across; the sender, subject and recipients
  /// at x 60, y 12 (pitch 20); the header is 80 tall with the separator at its bottom; the
  /// body starts 16 below it.
  static const double cardPadding = 16;
  static const double cardHeader = 80;
  static const double cardTextX = 60;
  static const double cardTextY = 12;
  static const double avatar = 32;
  static const double avatarTop = 16;

  /// PROVISIONAL (not in the kit): the message bar under the toolbar.
  static const double bannerHeight = 32;

  // Composer (kit `Apps/Mail/Compose`, 832 × 720).
  static const Size composer = Size(832, 720);

  /// The field rows start at y 52 (under the toolbar), 40 tall; the labels at x 24 (64 wide),
  /// the values at x 104; the separators run from x 24 to 24 before the right edge.
  static const double composerField = 40;
  static const double composerLabelX = 24;
  static const double composerLabelWidth = 80;
  static const double composerSeparatorInset = 24;

  /// Below the last row: a separator, then the body 20 further down at x 24.
  static const double composerBodyInset = 24;
  static const double composerBodyTop = 20;

  /// The Send button (kit `Titlebars/Piece/Mail Send`): a 28 pt circle.
  static const double sendButton = 28;

  /// Composer motion (ML-01b): it appears opaque at 98.8 % and reaches 100 % in ~80 ms with a
  /// 1 pt overshoot; closing an empty one fades and blurs while shrinking slightly towards
  /// the centre in ~160 ms (shrink amount and blur are an assumption: not measured).
  static const Duration composerOpen = Duration(milliseconds: 80);
  static const double composerOpenScale = 0.988;
  static const Duration composerClose = Duration(milliseconds: 160);
  static const double composerCloseScale = 0.96;
  static const double composerCloseBlur = 8;

  /// Sending (ML-01b): ~100 ms after the release the window moves straight up at a constant
  /// ~3.3 pt/ms (no easing, fade or scale) and leaves behind the menu bar in ~250 ms.
  static const Duration sendLiftDelay = Duration(milliseconds: 100);
  static const double sendLiftSpeed = 3.3;

  // Add Account sheet (kit `Apps/Mail/Add Account`, 528 × 416).
  static const Size accountSheet = Size(528, 416);
  static const double accountFieldWidth = 488;
  static const double accountTitleTop = 40;
  static const double accountHintTop = 76;
  static const double accountFieldsTop = 128;
}

/// The colours of the window, read from the Amalfi tokens of the current appearance and the
/// Mail palette (`App/Mail/*`).
@immutable
class MailColors {
  const MailColors._(this.theme);

  final AmalfiThemeData theme;

  AmalfiColors get _c => theme.colors;

  /// The colours of the appearance under [context] (with the Mail palette).
  factory MailColors.of(BuildContext context) =>
      MailColors._(AmalfiTheme.of(context).copyWith(app: 'Mail'));

  /// The colours of [brightness] (tests, HTML pages that keep their own colours).
  factory MailColors.forBrightness(Brightness brightness) =>
      MailColors._(AmalfiThemeData(brightness: brightness, app: 'Mail'));

  static final MailColors light = MailColors.forBrightness(Brightness.light);
  static final MailColors dark = MailColors.forBrightness(Brightness.dark);

  Color get sidebar => _c.surfaceSidebar;

  /// The list's and the toolbars' background.
  Color get content => _c.surfaceWindow;

  /// The reader's background; the message cards are [card].
  Color get reader => _c.surfaceSidebar;
  Color get card => _c.surfaceRaised;
  Color get field => _c.surfaceRaised;

  /// The block behind an expanded thread's children and the remote-content banner.
  Color get banner => _c.surfaceSunken;
  Color get threadTint => _c.surfaceSidebar;

  Color get text => _c.textPrimary;
  Color get secondary => _c.textSecondary;
  Color get tertiary => _c.textTertiary;
  Color get separator => _c.lineSeparator;
  Color get border => _c.lineBorder;

  Color get accent => _c.accentAmalfi;
  Color get accentSoft => _c.accentAmalfiSoft;
  Color get onAccent => _c.textOnAccent;

  /// The selected row's text (on the accent).
  Color get selectionText => _c.textOnAccent;
  Color get selection => _c.accentAmalfi;

  /// The selected row of an inactive window.
  // Assumption: not measured (the kit draws only the active window): a neutral capsule.
  Color get inactiveSelection => _c.lineBorder;

  Color get unread => _c.accentAmalfi;
  Color get link => _c.accentAmalfi;
  Color get destructive => _c.paletteTerracotta;

  /// `App/Mail/Flag`.
  Color get flagged => _c.mail.flag;

  /// `App/Mail/Search Highlight`.
  Color get highlight => _c.mail.searchHighlight;
}

/// A text style in Inter at an arbitrary size (the message body, which has no token).
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

/// An Icon Kit symbol (`symbols/regular/<name>.svg` of the installed silica-icons) in
/// [color], or an empty box of [size] when the icons are not installed (tests).
Widget mailSymbol(String name, {double size = 16, Color? color}) =>
    AmalfiSymbol(name, size: size, color: color);
