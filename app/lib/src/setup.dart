// Adding an account: the address and the name, then the engine looks for the settings
// (`DiscoverAccount`: autoconfig, well-known hosts), then the password. The password goes to the
// engine once, which keeps it in the Secret Service; the app never stores it.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'l10n.dart';
import 'model.dart';
import 'service.dart';
import 'style.dart';

enum _Step { address, discovering, password, adding }

class AccountSetup extends StatefulWidget {
  const AccountSetup({super.key, required this.service, required this.onClose});

  final MailService service;
  final VoidCallback onClose;

  @override
  State<AccountSetup> createState() => _AccountSetupState();
}

class _AccountSetupState extends State<AccountSetup> {
  final TextEditingController _address = TextEditingController();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final FocusNode _addressFocus = FocusNode();
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  _Step _step = _Step.address;
  AccountConfig? _config;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Continue stays dimmed until there is an address.
    _address.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _nameFocus.requestFocus(),
    );
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _address.removeListener(_changed);
    for (final c in [_address, _name, _password]) {
      c.dispose();
    }
    for (final f in [_addressFocus, _nameFocus, _passwordFocus]) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _continue() async {
    switch (_step) {
      case _Step.address:
        if (_address.text.trim().isEmpty) return;
        setState(() {
          _step = _Step.discovering;
          _error = null;
        });
        try {
          final config = await widget.service.discoverAccount(
            _address.text.trim(),
          );
          if (!mounted) return;
          setState(() {
            _config = config.copyWith(name: _name.text.trim());
            _step = _Step.password;
          });
          _passwordFocus.requestFocus();
        } on MailError catch (e) {
          if (mounted) {
            setState(() {
              _step = _Step.address;
              _error = l10n.setupFailed(e.message);
            });
          }
        }
      case _Step.password:
        final config = _config;
        if (config == null) return;
        setState(() {
          _step = _Step.adding;
          _error = null;
        });
        try {
          await widget.service.addAccount(
            config.copyWith(password: _password.text),
          );
          _password.clear();
          widget.onClose();
        } on MailError catch (e) {
          if (mounted) {
            setState(() {
              _step = _Step.password;
              _error = l10n.setupFailed(e.message);
            });
          }
        }
      case _Step.discovering || _Step.adding:
        break;
    }
  }

  Widget _field(
    MailColors colors,
    String label,
    TextEditingController controller,
    FocusNode focus,
    String key, {
    bool obscure = false,
    String? placeholder,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: mailText(12, colors.secondary)),
        const SizedBox(height: 4),
        // ML-01: the address sits in a 488 × 40 box (radius PROVISIONAL).
        Container(
          width: MailMetrics.accountFieldWidth,
          height: MailMetrics.accountField,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: colors.field,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.separator),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              if (placeholder != null && controller.text.isEmpty)
                IgnorePointer(
                  child: Text(
                    placeholder,
                    style: mailText(13, colors.tertiary),
                  ),
                ),
              EditableText(
                key: ValueKey(key),
                controller: controller,
                focusNode: focus,
                obscureText: obscure,
                style: mailText(13, colors.text),
                cursorColor: colors.text,
                backgroundCursorColor: colors.text,
                maxLines: 1,
                onSubmitted: (_) => _continue(),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = MailColors.of(context);
    final config = _config;
    final busy =
        _step == _Step.discovering ||
        _step == _Step.adding ||
        (_step == _Step.address && _address.text.trim().isEmpty);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): widget.onClose,
      },
      child: ColoredBox(
        color: const Color(0x33000000),
        child: Center(
          // ML-01: the sheet is 528 × 416 (padding PROVISIONAL: 20 around the 488 field).
          child: Container(
            width: MailMetrics.accountSheet.width,
            constraints: BoxConstraints(
              minHeight: MailMetrics.accountSheet.height,
            ),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.content,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.separator),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 30,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.addAccount,
                  style: mailText(15, colors.text, weight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                if (_step == _Step.address || _step == _Step.discovering) ...[
                  _field(
                    colors,
                    l10n.yourName,
                    _name,
                    _nameFocus,
                    'setup name',
                  ),
                  _field(
                    colors,
                    l10n.emailAddress,
                    _address,
                    _addressFocus,
                    'setup address',
                    placeholder: l10n.addressPlaceholder,
                  ),
                ],
                if (_step == _Step.discovering)
                  Text(
                    l10n.lookingForSettings,
                    style: mailText(12, colors.secondary),
                  ),
                if (config != null &&
                    (_step == _Step.password || _step == _Step.adding)) ...[
                  Text(
                    config.address,
                    style: mailText(13, colors.text, weight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${l10n.incomingServer}: ${config.imapHost}:${config.imapPort}',
                    key: const ValueKey('setup imap'),
                    style: mailText(12, colors.secondary),
                  ),
                  Text(
                    '${l10n.outgoingServer}: ${config.smtpHost}:${config.smtpPort}',
                    style: mailText(12, colors.secondary),
                  ),
                  const SizedBox(height: 12),
                  _field(
                    colors,
                    l10n.password,
                    _password,
                    _passwordFocus,
                    'setup password',
                    obscure: true,
                  ),
                  Text(l10n.passwordNote, style: mailText(11, colors.tertiary)),
                ],
                if (_error case final error?)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      error,
                      key: const ValueKey('setup error'),
                      style: mailText(12, const Color(0xFFE5484D)),
                    ),
                  ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      key: const ValueKey('setup cancel'),
                      onTap: widget.onClose,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        child: Text(
                          l10n.cancel,
                          style: mailText(13, colors.secondary),
                        ),
                      ),
                    ),
                    GestureDetector(
                      key: const ValueKey('setup continue'),
                      onTap: busy ? null : _continue,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: busy ? colors.tertiary : colors.selection,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _step == _Step.password || _step == _Step.adding
                              ? l10n.signIn
                              : l10n.continueButton,
                          style: mailText(
                            13,
                            colors.selectionText,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
