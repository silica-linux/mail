// Adding an account: the address and the name, then the engine looks for the settings
// (`DiscoverAccount`: the provider's autoconfig, the public ISPDB, common host names), then the
// password. When nothing is found the servers are entered by hand. The password goes to the
// engine once, which keeps it in the Secret Service; the app never stores it.
//
// Providers that sign in only through their own page (OAuth, silica-os/mail#3) are said so:
// Google takes an app password meanwhile, Microsoft can't be added yet.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'l10n.dart';
import 'model.dart';
import 'service.dart';
import 'style.dart';

enum _Step { address, discovering, manual, password, adding }

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
  final TextEditingController _imapHost = TextEditingController();
  final TextEditingController _imapPort = TextEditingController();
  final TextEditingController _smtpHost = TextEditingController();
  final TextEditingController _smtpPort = TextEditingController();
  final TextEditingController _username = TextEditingController();
  final FocusNode _addressFocus = FocusNode();
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _imapHostFocus = FocusNode();
  final FocusNode _imapPortFocus = FocusNode();
  final FocusNode _smtpHostFocus = FocusNode();
  final FocusNode _smtpPortFocus = FocusNode();
  final FocusNode _usernameFocus = FocusNode();
  _Step _step = _Step.address;
  AccountConfig? _config;
  String? _error;

  List<TextEditingController> get _controllers => [
    _address,
    _name,
    _password,
    _imapHost,
    _imapPort,
    _smtpHost,
    _smtpPort,
    _username,
  ];

  List<FocusNode> get _focusNodes => [
    _addressFocus,
    _nameFocus,
    _passwordFocus,
    _imapHostFocus,
    _imapPortFocus,
    _smtpHostFocus,
    _smtpPortFocus,
    _usernameFocus,
  ];

  @override
  void initState() {
    super.initState();
    // Continue stays dimmed until there is an address.
    _address.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _addressFocus.requestFocus(),
    );
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _address.removeListener(_changed);
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  /// The servers entered by hand, with the usual security of each port.
  AccountConfig? _manualConfig() {
    final imapPort = int.tryParse(_imapPort.text.trim());
    final smtpPort = int.tryParse(_smtpPort.text.trim());
    final imapHost = _imapHost.text.trim();
    final smtpHost = _smtpHost.text.trim();
    if (imapHost.isEmpty ||
        smtpHost.isEmpty ||
        imapPort == null ||
        smtpPort == null ||
        imapPort <= 0 ||
        imapPort > 65535 ||
        smtpPort <= 0 ||
        smtpPort > 65535) {
      return null;
    }
    return AccountConfig(
      address: _address.text.trim(),
      name: _name.text.trim(),
      imapHost: imapHost,
      imapPort: imapPort,
      imapTls: MailTls.forPort(imapPort),
      smtpHost: smtpHost,
      smtpPort: smtpPort,
      smtpTls: MailTls.forPort(smtpPort),
      username: _username.text.trim(),
    );
  }

  /// Nothing was found for the address: the servers by hand, starting from the usual names.
  void _toManual(String? error) {
    final address = _address.text.trim();
    final domain = address.contains('@') ? address.split('@').last : '';
    final config = _config;
    _imapHost.text = config?.imapHost ?? 'imap.$domain';
    _imapPort.text = '${config?.imapPort ?? 993}';
    _smtpHost.text = config?.smtpHost ?? 'smtp.$domain';
    _smtpPort.text = '${config?.smtpPort ?? 465}';
    _username.text = config == null || config.username.isEmpty
        ? address
        : config.username;
    setState(() {
      _step = _Step.manual;
      _error = error;
    });
    _imapHostFocus.requestFocus();
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
          if (mounted) _toManual(l10n.settingsNotFound(e.message));
        }
      case _Step.manual:
        final config = _manualConfig();
        if (config == null) {
          setState(() => _error = l10n.serverSettingsInvalid);
          return;
        }
        setState(() {
          _config = config;
          _step = _Step.password;
          _error = null;
        });
        _passwordFocus.requestFocus();
      case _Step.password:
        final config = _config;
        if (config == null || config.provider == SignInProvider.microsoft) {
          return;
        }
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

  /// A text field of the sheet (kit `Fields/Text Field/Large`), with an optional caption
  /// above it.
  Widget _field(
    MailColors colors,
    String? label,
    TextEditingController controller,
    FocusNode focus,
    String key, {
    bool obscure = false,
    String? placeholder,
    double? width,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label, style: AmalfiType.callout(color: colors.secondary)),
          const SizedBox(height: 4),
        ],
        AmalfiTextField(
          key: ValueKey(key),
          controller: controller,
          focusNode: focus,
          size: AmalfiFieldSize.large,
          width: width ?? MailMetrics.accountFieldWidth,
          obscureText: obscure,
          placeholder: placeholder,
          semanticLabel: label ?? placeholder,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _continue(),
        ),
      ],
    ),
  );

  /// A server row of the manual step: the host, and the port beside it.
  // Assumption: not in the kit (it shows only the first step): the manual server form keeps
  // the first step's field width.
  Widget _serverRow(
    MailColors colors,
    String label,
    TextEditingController host,
    FocusNode hostFocus,
    String hostKey,
    TextEditingController port,
    FocusNode portFocus,
    String portKey,
  ) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _field(
        colors,
        label,
        host,
        hostFocus,
        hostKey,
        width: MailMetrics.accountFieldWidth - 96 - 8,
      ),
      const SizedBox(width: 8),
      _field(colors, l10n.port, port, portFocus, portKey, width: 96),
    ],
  );

  /// What the provider of the servers needs, said before the password.
  Widget? _providerNote(MailColors colors, AccountConfig config) =>
      switch (config.provider) {
        SignInProvider.password => null,
        SignInProvider.google => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            l10n.googleAppPassword,
            key: const ValueKey('setup provider note'),
            style: AmalfiType.callout(color: colors.secondary),
          ),
        ),
        SignInProvider.microsoft => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            l10n.microsoftNotSupported,
            key: const ValueKey('setup provider note'),
            style: AmalfiType.callout(color: colors.destructive),
          ),
        ),
      };

  @override
  Widget build(BuildContext context) {
    final colors = MailColors.of(context);
    final config = _config;
    final blocked =
        _step == _Step.password && config?.provider == SignInProvider.microsoft;
    final busy =
        _step == _Step.discovering ||
        _step == _Step.adding ||
        blocked ||
        (_step == _Step.address && _address.text.trim().isEmpty);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): widget.onClose,
      },
      child: SizedBox(
        key: const ValueKey('account sheet'),
        width: MailMetrics.accountSheet.width,
        height: MailMetrics.accountSheet.height,
        child: AmalfiAlertSurface(
          color: AmalfiTheme.of(context).colors.surfaceWindow,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: MailMetrics.accountTitleTop),
              Text(
                l10n.addAccount,
                textAlign: TextAlign.center,
                style: AmalfiType.title2(color: colors.text),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  l10n.addAccountHint,
                  textAlign: TextAlign.center,
                  style: AmalfiType.callout(color: colors.secondary),
                ),
              ),
              const SizedBox(height: 36),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_step == _Step.address ||
                          _step == _Step.discovering) ...[
                        _field(
                          colors,
                          null,
                          _address,
                          _addressFocus,
                          'setup address',
                          placeholder: l10n.addressPlaceholder,
                        ),
                        _field(
                          colors,
                          null,
                          _name,
                          _nameFocus,
                          'setup name',
                          placeholder: l10n.yourName,
                        ),
                      ],
                      if (_step == _Step.discovering)
                        Text(
                          l10n.lookingForSettings,
                          style: AmalfiType.callout(color: colors.secondary),
                        ),
                      if (_step == _Step.manual) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            _address.text.trim(),
                            style: AmalfiType.bodyEmphasis(color: colors.text),
                          ),
                        ),
                        _serverRow(
                          colors,
                          l10n.incomingServer,
                          _imapHost,
                          _imapHostFocus,
                          'setup imap host',
                          _imapPort,
                          _imapPortFocus,
                          'setup imap port',
                        ),
                        _serverRow(
                          colors,
                          l10n.outgoingServer,
                          _smtpHost,
                          _smtpHostFocus,
                          'setup smtp host',
                          _smtpPort,
                          _smtpPortFocus,
                          'setup smtp port',
                        ),
                        _field(
                          colors,
                          l10n.userName,
                          _username,
                          _usernameFocus,
                          'setup username',
                        ),
                      ],
                      if (config != null &&
                          (_step == _Step.password ||
                              _step == _Step.adding)) ...[
                        Text(
                          config.address,
                          style: AmalfiType.bodyEmphasis(color: colors.text),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${l10n.incomingServer}: ${config.imapHost}:${config.imapPort}',
                          key: const ValueKey('setup imap'),
                          style: AmalfiType.callout(color: colors.secondary),
                        ),
                        Text(
                          '${l10n.outgoingServer}: ${config.smtpHost}:${config.smtpPort}',
                          style: AmalfiType.callout(color: colors.secondary),
                        ),
                        GestureDetector(
                          key: const ValueKey('setup edit servers'),
                          onTap: _step == _Step.adding
                              ? null
                              : () => _toManual(null),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              l10n.editServerSettings,
                              style: AmalfiType.callout(color: colors.link),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ?_providerNote(colors, config),
                        if (!blocked) ...[
                          _field(
                            colors,
                            l10n.password,
                            _password,
                            _passwordFocus,
                            'setup password',
                            obscure: true,
                          ),
                          Text(
                            l10n.passwordNote,
                            style: AmalfiType.caption(color: colors.tertiary),
                          ),
                        ],
                      ],
                      if (_error case final error?)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            error,
                            key: const ValueKey('setup error'),
                            style: AmalfiType.callout(
                              color: colors.destructive,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // The kit's footer: Cancel and Continue at the end, 28 from the right edge, 32
              // from the bottom (its Help button is not here: there is no help to open yet).
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 28, 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AmalfiPushButton(
                      key: const ValueKey('setup cancel'),
                      label: l10n.cancel,
                      onPressed: widget.onClose,
                    ),
                    const SizedBox(width: 8),
                    AmalfiPushButton(
                      key: const ValueKey('setup continue'),
                      label: _step == _Step.password || _step == _Step.adding
                          ? l10n.signIn
                          : l10n.continueButton,
                      variant: AmalfiPushButtonVariant.primary,
                      onPressed: busy ? null : _continue,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
