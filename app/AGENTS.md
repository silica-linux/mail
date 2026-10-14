# AGENTS.md

The Mail app is a Silica app: the rules of `silica-desktop/AGENTS.md` apply (clean-room, assets,
never crash, everything is a command, measured parity, English everywhere). On top of them:

## Clean-room

- Observations of the reference system live in the private repository `silica-reference`
  (request ML-01, `mail.md`), never here. Here only the request codes and measured metrics.
- Specification, comments and interface texts are our own words. No product names or texts
  copied from the reference interface.
- No personal mail anywhere: tests and screenshots use the generated sample mail of
  `FakeMailService`.

## Architecture

- The app never speaks IMAP or SMTP and never stores credentials: everything goes through
  `MailService` (`lib/src/service.dart`). In Silica it is the engine on the session bus
  (`dev.frascella.Mail1`, `engine/` in this repository); in tests and without the engine it is
  `FakeMailService`.
- HTML mail is rendered by `lib/src/html.dart`: no scripts, no styles, no network unless the user
  loads remote content for that message; only `http`, `https` and `mailto` links reach the
  system handler.
- Geometry and colours live in `lib/src/style.dart` and are provisional until ML-01 is measured.
- The toolbar is an overlay above the content, which starts at a top inset: the shared glass
  toolbar of silica_ui (silica-linux/silica-ui#2) will let the lists scroll under it.

## Work

- Before every commit, from `app/`: `dart format --set-exit-if-changed .`,
  `flutter analyze --fatal-infos`, `flutter test`, `tool/check_assets.sh`.
- Interface texts live in `lib/l10n/app_en.arb` (English source, with descriptions) and
  `app_it.arb`; code reads them through `l10n` (`lib/src/l10n.dart`). After editing the ARB files
  run `flutter gen-l10n`; tests run in English.
- `silica_ui` is used from a tag (`ref` in `pubspec.yaml`); a widget other apps need goes into
  `silica-ui`.
- Never crash: a server error, a missing engine, a malformed message are normal cases with a
  message in the window, not exceptions.
