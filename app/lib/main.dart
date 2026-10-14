// Mail, the mail app of Silica.

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'src/l10n.dart';
import 'src/service.dart';
import 'src/style.dart';
import 'src/window.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The toolbar is unified with the window: Ossido draws only the window buttons.
  SilicaWindow.setFullSizeContent(toolbarHeight).ignore();
  setMinimumSize().ignore();
  final (service, missing) = await connect();
  runApp(
    AppLocalizationsScope(
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: MailWindow(
          service: service,
          engineMissing: missing,
          iconsDir: Platform.environment['SILICA_ICONS_DIR'],
        ),
      ),
    ),
  );
}

/// The smallest window (ML-01).
Future<void> setMinimumSize() =>
    SilicaWindow.setSizeLimits(min: MailMetrics.minimumWindow);

/// The engine on the session bus, or sample mail in memory when it does not answer (not
/// installed, outside Silica). The second value says which.
Future<(MailService, bool)> connect() async {
  final engine = DBusMailService();
  try {
    await engine.listAccounts();
    return (engine as MailService, false);
  } on MailError {
    return (FakeMailService(now: DateTime.now()) as MailService, true);
  }
}
