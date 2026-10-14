// Localization: English is the source language, Italian the first translation (lib/l10n/*.arb,
// generated with `flutter gen-l10n`). The embedder passes the system languages
// (FlutterEngineUpdateLocales); the root resolves them against the supported locales, falling
// back to English. Strings are also needed outside widgets (dates, sizes, mailbox names), so the
// resolved translation is kept in [l10n].

import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../l10n/app_localizations.dart';
import 'model.dart';

export '../l10n/app_localizations.dart';

/// The languages Mail is translated into.
const List<Locale> supportedLocales = [Locale('en'), Locale('it')];

AppLocalizations _current = lookupAppLocalizations(const Locale('en'));

/// The texts in the resolved language (English until the root resolves the platform's).
AppLocalizations get l10n => _current;

/// The first preferred language Mail has, otherwise English.
Locale resolveLocale(Iterable<Locale> preferred) {
  for (final locale in preferred) {
    for (final supported in supportedLocales) {
      if (supported.languageCode == locale.languageCode) return supported;
    }
  }
  return supportedLocales.first;
}

/// Uses the translation of `locale` from now on (tests, and the root on a language change).
void useLocale(Locale locale) =>
    _current = lookupAppLocalizations(resolveLocale([locale]));

/// The root of the tree: resolves the platform languages, keeps [l10n] in step and provides
/// [Localizations] below.
class AppLocalizationsScope extends StatefulWidget {
  const AppLocalizationsScope({super.key, required this.child, this.locale});

  final Widget child;

  /// A fixed language (tests); null: the platform's.
  final Locale? locale;

  @override
  State<AppLocalizationsScope> createState() => _AppLocalizationsScopeState();
}

class _AppLocalizationsScopeState extends State<AppLocalizationsScope>
    with WidgetsBindingObserver {
  late Locale _locale = _resolve();

  Locale _resolve() =>
      resolveLocale([?widget.locale, ...PlatformDispatcher.instance.locales]);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    useLocale(_locale);
  }

  @override
  void didUpdateWidget(AppLocalizationsScope old) {
    super.didUpdateWidget(old);
    final locale = _resolve();
    if (locale != _locale) {
      _locale = locale;
      useLocale(locale);
    }
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    final locale = _resolve();
    if (locale == _locale) return;
    setState(() => _locale = locale);
    useLocale(locale);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Localizations(
    locale: _locale,
    delegates: const [
      AppLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    child: widget.child,
  );
}

String _two(int v) => v.toString().padLeft(2, '0');

/// "HH:MM" (24 hours in both languages).
String clockTime(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';

/// A calendar date ("Oct 13, 2026", "13 ott 2026").
String calendarDate(DateTime t) => l10n.dateShort(
  '${t.day}',
  l10n.monthsShort.split(',')[t.month - 1],
  '${t.year}',
);

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// A numeric date with a two-digit year ("10/11/26", "11/10/26"; ML-01).
String numericDate(DateTime t) =>
    l10n.dateNumeric(_two(t.day), _two(t.month), _two(t.year % 100));

/// The relative day name, or null past the day before yesterday.
String? _relativeDay(DateTime t, DateTime now) {
  if (_sameDay(t, now.subtract(const Duration(days: 1)))) return l10n.yesterday;
  if (_sameDay(t, now.subtract(const Duration(days: 2)))) {
    return l10n.dayBeforeYesterday;
  }
  return null;
}

/// The date of a row in the list: the time today, "Yesterday", "Day before yesterday",
/// otherwise the numeric date (ML-01).
String listDate(DateTime t, DateTime now) {
  if (_sameDay(t, now)) return clockTime(t);
  return _relativeDay(t, now) ?? numericDate(t);
}

/// The date in the reader header: the time today, otherwise the day with the time (ML-01).
String readerDate(DateTime t, DateTime now) {
  if (_sameDay(t, now)) return clockTime(t);
  return l10n.dateTime(_relativeDay(t, now) ?? calendarDate(t), clockTime(t));
}

/// A size in bytes, decimal units, one decimal under 10 ("48.2 KB", "48,2 KB").
String fileSize(int bytes) {
  String one(double v) => (v < 10 ? v.toStringAsFixed(1) : v.round().toString())
      .replaceAll('.', l10n.decimalSeparator);
  if (bytes < 1000) return l10n.sizeBytes(bytes);
  if (bytes < 1000 * 1000) return l10n.sizeKb(one(bytes / 1000));
  return l10n.sizeMb(one(bytes / 1e6));
}

/// The name shown for a mailbox: the translated role, or the server's name.
String mailboxName(Mailbox m) => switch (m.role) {
  MailboxRole.inbox => l10n.mailboxInbox,
  MailboxRole.drafts => l10n.mailboxDrafts,
  MailboxRole.sent => l10n.mailboxSent,
  MailboxRole.archive => l10n.mailboxArchive,
  MailboxRole.junk => l10n.mailboxJunk,
  MailboxRole.trash => l10n.mailboxTrash,
  MailboxRole.other => m.name,
};
