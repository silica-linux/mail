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
  final connection = await connect(Platform.environment);
  // Mail keeps running when its window closes; a reopen shows the main window again on the
  // same mailbox (APP-LC). The engine connection and the mailbox outlive the window.
  final lastMailbox = ValueNotifier<String?>(null);
  runApp(
    AppLocalizationsScope(
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: SilicaAppWindow(
          builder: (context) => MailWindow(
            service: connection.service,
            engineError: connection.error,
            sampleData: connection.sample,
            iconsDir: Platform.environment['SILICA_ICONS_DIR'],
            lastMailbox: lastMailbox,
          ),
        ),
      ),
    ),
  );
}

/// The smallest window (ML-01).
Future<void> setMinimumSize() =>
    SilicaWindow.setSizeLimits(min: MailMetrics.minimumWindow);

/// How the app reaches its mail.
typedef Connection = ({MailService service, String? error, bool sample});

/// The engine on the session bus, started through D-Bus activation. When it can't start, the
/// window says why and offers to try again: sample mail only with `MAIL_SAMPLE_DATA=1`
/// (development), never instead of the user's mail.
Future<Connection> connect(
  Map<String, String> env, {
  MailService? engine,
}) async {
  if (env['MAIL_SAMPLE_DATA'] == '1') {
    return (
      service: FakeMailService(now: DateTime.now()) as MailService,
      error: null,
      sample: true,
    );
  }
  final service = engine ?? DBusMailService();
  try {
    await service.start();
    await service.listAccounts();
    return (service: service, error: null, sample: false);
  } on MailError catch (e) {
    return (service: service, error: e.message, sample: false);
  }
}
