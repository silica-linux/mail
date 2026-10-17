// The composer: a sheet over the window with To, Cc, Subject and the text. A reply, a reply to
// all and a forward start from the message in the reader, with the quoted text below.

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'l10n.dart';
import 'model.dart';
import 'service.dart';
import 'style.dart';
import 'window.dart' show ComposeKind;

/// "Name <a@b>, c@d" → addresses; empty parts are dropped.
List<Address> parseAddresses(String text) {
  final out = <Address>[];
  for (final part in text.split(RegExp(r'[,;]'))) {
    final p = part.trim();
    if (p.isEmpty) continue;
    final m = RegExp(r'^(.*?)\s*<([^>]+)>$').firstMatch(p);
    if (m != null) {
      out.add(
        Address(
          m.group(2)!.trim(),
          name: m.group(1)!.replaceAll('"', '').trim(),
        ),
      );
    } else {
      out.add(Address(p));
    }
  }
  return out;
}

String formatAddresses(List<Address> list) => list
    .map((a) => a.name.isEmpty ? a.address : '${a.name} <${a.address}>')
    .join(', ');

/// What the composer opens with.
class ComposeRequest {
  const ComposeRequest({
    required this.account,
    this.to = const [],
    this.cc = const [],
    this.subject = '',
    this.text = '',
    this.inReplyTo,
  });

  factory ComposeRequest.from({
    required ComposeKind kind,
    required Account account,
    required Message? message,
    required DateTime now,
  }) {
    if (message == null || kind == ComposeKind.fresh) {
      return ComposeRequest(account: account);
    }
    String prefixed(String prefix) {
      final s = message.subject;
      final lower = s.toLowerCase();
      return lower.startsWith(prefix.trim().toLowerCase()) ? s : '$prefix$s';
    }

    final quoted = message.text.split('\n').map((l) => '> $l').join('\n');
    final when = readerDate(message.date, now);
    switch (kind) {
      case ComposeKind.reply || ComposeKind.replyAll:
        final others = kind == ComposeKind.replyAll
            ? [...message.to, ...message.cc]
                  .where(
                    (a) =>
                        a.address != account.address &&
                        a.address != message.from.address,
                  )
                  .toList()
            : const <Address>[];
        return ComposeRequest(
          account: account,
          to: [message.from],
          cc: others,
          subject: prefixed(l10n.replyPrefix),
          text: '\n\n${l10n.quoteHeader(when, message.from.display)}\n$quoted',
          inReplyTo: message.id,
        );
      case ComposeKind.forward:
        return ComposeRequest(
          account: account,
          subject: prefixed(l10n.forwardPrefix),
          text:
              '\n\n— ${l10n.forwardHeader} —\n'
              '${l10n.from}: ${formatAddresses([message.from])}\n'
              '${l10n.subject}: ${message.subject}\n\n${message.text}',
        );
      case ComposeKind.fresh:
        return ComposeRequest(account: account);
    }
  }

  final Account account;
  final List<Address> to;
  final List<Address> cc;
  final String subject;
  final String text;
  final String? inReplyTo;
}

/// The composer's actions for the menu bar (Message › Send, File › Close): the sheet attaches
/// its own while it is open and tells when the state of the menu items changes.
class ComposeController extends ChangeNotifier {
  Future<void> Function()? _send;
  Future<void> Function()? _close;
  bool _canSend = false;

  /// The composer has a recipient (the send button is not dimmed).
  bool get canSend => _canSend;

  /// Sends the message, as the send button does.
  Future<void> send() async => await _send?.call();

  /// Closes the composer without sending, as Cancel does.
  Future<void> close() async => await _close?.call();

  void _attach(Future<void> Function() send, Future<void> Function() close) {
    _send = send;
    _close = close;
  }

  void _detach() {
    _send = null;
    _close = null;
    _canSend = false;
  }

  void _setCanSend(bool value) {
    if (value == _canSend) return;
    _canSend = value;
    notifyListeners();
  }
}

class ComposeSheet extends StatefulWidget {
  const ComposeSheet({
    super.key,
    required this.request,
    required this.service,
    required this.onClose,
    this.controller,
  });

  /// The menu bar's handle on this composer; null: no menu actions.
  final ComposeController? controller;

  final ComposeRequest request;
  final MailService service;
  final VoidCallback onClose;

  @override
  State<ComposeSheet> createState() => _ComposeSheetState();
}

/// The composer's open scale over time (ML-01b): from 98.8 % up past 100 % by ~1 pt on each
/// side, then back to 100 %, in [MailMetrics.composerOpen] (the overshoot's shape is an
/// assumption, not measured: only its size and the total time were).
double composerOpenScale(double t) {
  const overshoot = 1 + 2 / 836;
  if (t <= 0) return MailMetrics.composerOpenScale;
  if (t >= 1) return 1;
  if (t < 0.75) {
    final u = Curves.easeOut.transform(t / 0.75);
    return MailMetrics.composerOpenScale +
        (overshoot - MailMetrics.composerOpenScale) * u;
  }
  final u = Curves.easeInOut.transform((t - 0.75) / 0.25);
  return overshoot + (1 - overshoot) * u;
}

class _ComposeSheetState extends State<ComposeSheet>
    with TickerProviderStateMixin {
  late final AnimationController _opening = AnimationController(
    vsync: this,
    duration: MailMetrics.composerOpen,
  )..forward();
  late final AnimationController _closing = AnimationController(
    vsync: this,
    duration: MailMetrics.composerClose,
  );

  /// Sending: the pause after the release, then the lift at constant speed (the whole span
  /// is one controller so that frames keep coming during the pause).
  AnimationController? _lifting;
  double _liftDistance = 0;
  Future<void>? _sendResult;
  String? _sendError;

  /// The recipients already turned into tokens; what is typed after them is in the
  /// controller until a comma, a semicolon or leaving the field commits it.
  late final List<Address> _toTokens = [...widget.request.to];
  late final List<Address> _ccTokens = [...widget.request.cc];
  final TextEditingController _to = TextEditingController();
  final TextEditingController _cc = TextEditingController();
  late final TextEditingController _subject = TextEditingController(
    text: widget.request.subject,
  );
  late final TextEditingController _body = TextEditingController(
    text: widget.request.text,
  );
  final FocusNode _toFocus = FocusNode();
  final FocusNode _ccFocus = FocusNode();
  final FocusNode _subjectFocus = FocusNode();
  final FocusNode _bodyFocus = FocusNode();
  bool _sending = false;
  String? _error;

  /// The "save as a draft?" alert is up.
  bool _asking = false;

  List<Address> get _toAll => [..._toTokens, ...parseAddresses(_to.text)];
  List<Address> get _ccAll => [..._ccTokens, ...parseAddresses(_cc.text)];

  @override
  void initState() {
    super.initState();
    // The send button is dimmed until there is a recipient.
    _to.addListener(_changed);
    _cc.addListener(_changed);
    _toFocus.addListener(_leftField);
    _ccFocus.addListener(_leftField);
    widget.controller?._attach(_send, _close);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.controller?._setCanSend(_toAll.isNotEmpty);
      (_toTokens.isEmpty ? _toFocus : _bodyFocus).requestFocus();
    });
  }

  /// A comma or semicolon turns what was typed before it into tokens.
  void _commitSeparated(TextEditingController c, List<Address> tokens) {
    final text = c.text;
    final cut = text.lastIndexOf(RegExp(r'[,;]'));
    if (cut < 0) return;
    tokens.addAll(parseAddresses(text.substring(0, cut)));
    final rest = text.substring(cut + 1).trimLeft();
    c.value = TextEditingValue(
      text: rest,
      selection: TextSelection.collapsed(offset: rest.length),
    );
  }

  /// Leaving a recipient field commits what is typed in it.
  void _leftField() {
    if (!_toFocus.hasFocus && _to.text.trim().isNotEmpty) {
      _toTokens.addAll(parseAddresses(_to.text));
      _to.clear();
    }
    if (!_ccFocus.hasFocus && _cc.text.trim().isNotEmpty) {
      _ccTokens.addAll(parseAddresses(_cc.text));
      _cc.clear();
    }
  }

  void _changed() {
    _commitSeparated(_to, _toTokens);
    _commitSeparated(_cc, _ccTokens);
    setState(() {});
    widget.controller?._setCanSend(_toAll.isNotEmpty);
  }

  @override
  void dispose() {
    widget.controller?._detach();
    _opening.dispose();
    _closing.dispose();
    _lifting?.dispose();
    _to.removeListener(_changed);
    _cc.removeListener(_changed);
    _toFocus.removeListener(_leftField);
    _ccFocus.removeListener(_leftField);
    for (final c in [_to, _cc, _subject, _body]) {
      c.dispose();
    }
    for (final f in [_toFocus, _ccFocus, _subjectFocus, _bodyFocus]) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    final to = _toAll;
    if (to.isEmpty) {
      setState(() => _error = l10n.noRecipients);
      return;
    }
    if (_lifting != null) return;
    setState(() {
      _sending = true;
      _error = null;
      _sendError = null;
      _asking = false;
    });
    // The message goes to the engine (its outbox) at once; the window leaves meanwhile.
    _sendResult = _deliver(
      Draft(
        account: widget.request.account.id,
        to: to,
        cc: _ccAll,
        subject: _subject.text,
        text: _body.text,
        inReplyTo: widget.request.inReplyTo,
      ),
    );
    final pause = MailMetrics.sendLiftDelay.inMicroseconds / 1000;
    final lift = _liftDistance / MailMetrics.sendLiftSpeed;
    final total = pause + lift;
    final controller = AnimationController(
      vsync: this,
      duration: Duration(microseconds: (total * 1000).round()),
    );
    setState(() => _lifting = controller);
    await controller.forward();
    await _sendResult;
    if (!mounted) return;
    if (_sendError case final error?) {
      // Back in place with the reason.
      controller.dispose();
      setState(() {
        _lifting = null;
        _sending = false;
        _error = l10n.sendFailed(error);
      });
      return;
    }
    widget.onClose();
  }

  /// Sends `draft`, keeping the engine's error for after the lift.
  Future<void> _deliver(Draft draft) async {
    try {
      await widget.service.send(draft);
    } on MailError catch (e) {
      _sendError = e.message;
    }
  }

  /// The upward offset while sending: nothing during the pause, then a constant speed.
  double _liftOffset() {
    final c = _lifting;
    if (c == null) return 0;
    final elapsed = c.value * c.duration!.inMicroseconds / 1000;
    final pause = MailMetrics.sendLiftDelay.inMicroseconds / 1000;
    return -((elapsed - pause).clamp(0.0, double.infinity) *
            MailMetrics.sendLiftSpeed)
        .clamp(0.0, _liftDistance);
  }

  /// Whether the user changed the message from what the composer opened with.
  bool get _changedByUser {
    final r = widget.request;
    return formatAddresses(_toAll) != formatAddresses(r.to) ||
        formatAddresses(_ccAll) != formatAddresses(r.cc) ||
        _subject.text != r.subject ||
        _body.text != r.text;
  }

  /// Closing (the close button, Escape, Cmd+W): a changed message asks first, as the
  /// reference's alert does; an unchanged one goes at once.
  Future<void> _close() async {
    if (_closing.isAnimating || _lifting != null) return;
    if (_changedByUser && !_asking) {
      setState(() => _asking = true);
      return;
    }
    await _discard();
  }

  /// Closes without sending: a short blur-fade towards the centre.
  Future<void> _discard() async {
    if (_closing.isAnimating || _lifting != null) return;
    if (_asking) setState(() => _asking = false);
    await _closing.forward();
    if (mounted) widget.onClose();
  }

  /// One row of the header (kit `Apps/Mail/Compose`): a 40 pt row with the label at x 24 and
  /// the value at x 104, a separator inset 24 along its top (none on the first row).
  Widget _row(
    MailColors colors,
    String label,
    Widget value, {
    bool first = false,
  }) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: MailMetrics.composerField),
    child: Stack(
      children: [
        if (!first)
          Positioned(
            left: MailMetrics.composerSeparatorInset,
            right: MailMetrics.composerSeparatorInset,
            top: 0,
            height: 1,
            child: ColoredBox(color: colors.separator),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MailMetrics.composerLabelX,
          ),
          child: Row(
            children: [
              SizedBox(
                width: MailMetrics.composerLabelWidth,
                child: Text(
                  '$label:',
                  style: AmalfiType.callout(color: colors.secondary),
                ),
              ),
              Expanded(child: value),
            ],
          ),
        ),
      ],
    ),
  );

  /// A plain value: one line of text in the body style.
  Widget _textValue(
    MailColors colors,
    TextEditingController controller,
    FocusNode focus,
    String key,
  ) => SizedBox(
    height: MailMetrics.composerField,
    child: Align(
      alignment: Alignment.centerLeft,
      child: EditableText(
        key: ValueKey(key),
        controller: controller,
        focusNode: focus,
        style: AmalfiType.body(color: colors.text),
        cursorColor: colors.accent,
        backgroundCursorColor: colors.text,
        selectionColor: colors.accentSoft,
        maxLines: 1,
      ),
    ),
  );

  /// The recipients of a row: a token each (kit `Fields/Token`), then the text being typed.
  Widget _recipients(
    MailColors colors,
    List<Address> tokens,
    TextEditingController controller,
    FocusNode focus,
    String key,
  ) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: focus.requestFocus,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: MailMetrics.composerField),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (var i = 0; i < tokens.length; i++)
              AmalfiToken(
                key: ValueKey('$key token $i'),
                label: tokens[i].name.isEmpty
                    ? tokens[i].address
                    : tokens[i].name,
                onRemove: () {
                  setState(() => tokens.removeAt(i));
                  widget.controller?._setCanSend(_toAll.isNotEmpty);
                },
              ),
            SizedBox(
              width: 200,
              height: 20,
              child: Focus(
                // Backspace in an empty field removes the last token.
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.backspace &&
                      controller.text.isEmpty &&
                      tokens.isNotEmpty) {
                    setState(tokens.removeLast);
                    widget.controller?._setCanSend(_toAll.isNotEmpty);
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: EditableText(
                    key: ValueKey(key),
                    controller: controller,
                    focusNode: focus,
                    style: AmalfiType.body(color: colors.text),
                    cursorColor: colors.accent,
                    backgroundCursorColor: colors.text,
                    selectionColor: colors.accentSoft,
                    maxLines: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = MailColors.of(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(
          LogicalKeyboardKey.enter,
          meta: true,
          shift: true,
        ): _send,
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_asking) {
            setState(() => _asking = false);
          } else {
            _close();
          }
        },
        const SingleActivator(LogicalKeyboardKey.keyW, meta: true): _close,
      },
      child: LayoutBuilder(
        builder: (context, box) {
          // The panel leaves upwards until its bottom edge is past the window's top.
          final height = box.maxHeight.isFinite
              ? box.maxHeight
              : MailMetrics.composer.height;
          final panel = height < MailMetrics.composer.height
              ? height
              : MailMetrics.composer.height;
          _liftDistance = height / 2 + panel / 2;
          return AnimatedBuilder(
            animation: Listenable.merge([_opening, _closing, ?_lifting]),
            builder: (context, child) {
              final close = Curves.easeIn.transform(_closing.value);
              final scale =
                  composerOpenScale(_opening.value) *
                  (1 - (1 - MailMetrics.composerCloseScale) * close);
              final blur = MailMetrics.composerCloseBlur * close;
              Widget panel = Transform.translate(
                offset: Offset(0, _liftOffset()),
                child: Transform.scale(scale: scale, child: child),
              );
              if (blur > 0) {
                panel = ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                  child: panel,
                );
              }
              return Opacity(
                opacity: 1 - close,
                child: ColoredBox(
                  // Assumption: not in the kit (the reference composer is its own window,
                  // silica-os/mail#5): the dim behind the panel.
                  color: Color.fromRGBO(0, 0, 0, _lifting == null ? 0.2 : 0),
                  child: Center(child: panel),
                ),
              );
            },
            child: _panel(colors),
          );
        },
      ),
    );
  }

  /// Send (kit `Titlebars/Piece/Mail Send`): a 36 pt accent circle with a white upward arrow,
  /// dimmed until there is a recipient.
  Widget _sendButton() {
    final ready = !_sending && _toAll.isNotEmpty;
    return _SendButton(
      key: const ValueKey('compose send'),
      label: l10n.send,
      // Pressing it without a recipient says so (the error line), as before.
      onPressed: _sending ? null : _send,
      dimmed: !ready,
    );
  }

  Widget _panel(MailColors colors) {
    final from = widget.request.account;
    return Container(
      key: const ValueKey('composer panel'),
      constraints: BoxConstraints.loose(MailMetrics.composer),
      child: AmalfiWindow(
        active: WindowActiveScope.of(context),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AmalfiToolbar(
                  padding: const EdgeInsets.only(left: 4, right: 8),
                  children: [
                    // Nothing minimises or zooms a sheet-like panel: those two stay grey.
                    AmalfiControlsPiece(onClose: _close),
                    const AmalfiSpacerPiece(),
                    AmalfiTitlePiece(
                      title: _subject.text.isEmpty
                          ? l10n.newMessage
                          : _subject.text,
                    ),
                    const AmalfiSpacerPiece(),
                    AmalfiToolbarPiece(
                      leading: 4,
                      trailing: 16,
                      child: _sendButton(),
                    ),
                  ],
                ),
                _row(
                  colors,
                  l10n.to,
                  _recipients(colors, _toTokens, _to, _toFocus, 'compose to'),
                  first: true,
                ),
                _row(
                  colors,
                  l10n.cc,
                  _recipients(colors, _ccTokens, _cc, _ccFocus, 'compose cc'),
                ),
                _row(
                  colors,
                  l10n.subject,
                  _textValue(
                    colors,
                    _subject,
                    _subjectFocus,
                    'compose subject',
                  ),
                ),
                _row(
                  colors,
                  l10n.from,
                  SizedBox(
                    height: MailMetrics.composerField,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        key: const ValueKey('compose from'),
                        formatAddresses([
                          Address(from.address, name: from.name),
                        ]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AmalfiType.body(color: colors.secondary),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 1, child: ColoredBox(color: colors.separator)),
                if (_error case final error?)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      MailMetrics.composerBodyInset,
                      8,
                      MailMetrics.composerBodyInset,
                      0,
                    ),
                    child: Text(
                      error,
                      key: const ValueKey('compose error'),
                      style: AmalfiType.callout(color: colors.destructive),
                    ),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      MailMetrics.composerBodyInset,
                      MailMetrics.composerBodyTop,
                      MailMetrics.composerBodyInset,
                      MailMetrics.composerBodyTop,
                    ),
                    child: EditableText(
                      key: const ValueKey('compose body'),
                      controller: _body,
                      focusNode: _bodyFocus,
                      style: AmalfiType.body(color: colors.text),
                      cursorColor: colors.accent,
                      backgroundCursorColor: colors.text,
                      selectionColor: colors.accentSoft,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                    ),
                  ),
                ),
              ],
            ),
            if (_asking) ...[
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: ColoredBox(
                    key: const ValueKey('compose scrim'),
                    color: colors.banner.withValues(alpha: 0.7),
                  ),
                ),
              ),
              Center(child: _discardAlert()),
            ],
          ],
        ),
      ),
    );
  }

  /// The alert on closing a changed message (kit `Apps/Mail/Compose Discard`).
  Widget _discardAlert() => AmalfiAlert(
    key: const ValueKey('compose discard'),
    title: l10n.saveDraftTitle,
    message: l10n.saveDraftMessage,
    actions: [
      AmalfiPushButton(
        key: const ValueKey('compose discard cancel'),
        label: l10n.cancel,
        autofocus: true,
        onPressed: () => setState(() => _asking = false),
      ),
      AmalfiPushButton(
        key: const ValueKey('compose discard dont save'),
        label: l10n.dontSave,
        onPressed: _discard,
      ),
      // The engine keeps no drafts yet (silica-os/mail#10): Save waits for it.
      AmalfiPushButton(
        key: const ValueKey('compose discard save'),
        label: l10n.save,
        variant: AmalfiPushButtonVariant.primary,
        onPressed: null,
      ),
    ],
  );
}

/// The Send button: a 36 pt accent circle with a white arrow; hovered or pressed it takes
/// the pressed accent; dimmed (35 %) it still answers, so that Send without a recipient says
/// why it did nothing.
class _SendButton extends StatefulWidget {
  const _SendButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.dimmed,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool dimmed;

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = MailColors.of(context);
    final enabled = widget.onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled && !widget.dimmed,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onPressed,
        child: Opacity(
          opacity: widget.dimmed ? AmalfiStates.disabledOpacity : 1,
          child: Container(
            width: MailMetrics.sendButton,
            height: MailMetrics.sendButton,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _pressed
                  ? AmalfiTheme.of(context).colors.accentAmalfiPressed
                  : colors.accent,
              shape: BoxShape.circle,
            ),
            child: AmalfiSymbol(
              'arrow-up',
              size: 20,
              color: colors.onAccent,
              fallback: Text(
                '↑',
                style: mailText(16, colors.onAccent, height: 1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
