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

class ComposeSheet extends StatefulWidget {
  const ComposeSheet({
    super.key,
    required this.request,
    required this.service,
    required this.onClose,
  });

  final ComposeRequest request;
  final MailService service;
  final VoidCallback onClose;

  @override
  State<ComposeSheet> createState() => _ComposeSheetState();
}

/// The composer's open scale over time (ML-01b): from 98.8 % up past 100 % by ~1 pt on each
/// side, then back to 100 %, in [MailMetrics.composerOpen] (the overshoot's shape is
/// PROVISIONAL: only its size and the total time were measured).
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

  late final TextEditingController _to = TextEditingController(
    text: formatAddresses(widget.request.to),
  );
  late final TextEditingController _cc = TextEditingController(
    text: formatAddresses(widget.request.cc),
  );
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

  @override
  void initState() {
    super.initState();
    // The send button is dimmed until there is a recipient.
    _to.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      (widget.request.to.isEmpty ? _toFocus : _bodyFocus).requestFocus();
    });
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _opening.dispose();
    _closing.dispose();
    _lifting?.dispose();
    _to.removeListener(_changed);
    for (final c in [_to, _cc, _subject, _body]) {
      c.dispose();
    }
    for (final f in [_toFocus, _ccFocus, _subjectFocus, _bodyFocus]) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    final to = parseAddresses(_to.text);
    if (to.isEmpty) {
      setState(() => _error = l10n.noRecipients);
      return;
    }
    if (_lifting != null) return;
    setState(() {
      _sending = true;
      _error = null;
      _sendError = null;
    });
    // The message goes to the engine (its outbox) at once; the window leaves meanwhile.
    _sendResult = _deliver(
      Draft(
        account: widget.request.account.id,
        to: to,
        cc: parseAddresses(_cc.text),
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

  /// Closing without sending (Cancel, Escape, Cmd+W): a short blur-fade towards the centre.
  Future<void> _close() async {
    if (_closing.isAnimating || _lifting != null) return;
    await _closing.forward();
    if (mounted) widget.onClose();
  }

  Widget _field(
    MailColors colors,
    String label,
    TextEditingController controller,
    FocusNode focus,
    String key,
  ) => Container(
    // ML-01: one field per 40 pt row, 1 pt separators.
    height: MailMetrics.composerField,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: colors.separator)),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 64,
          child: Text('$label:', style: mailText(13, colors.secondary)),
        ),
        Expanded(
          child: EditableText(
            key: ValueKey(key),
            controller: controller,
            focusNode: focus,
            style: mailText(13, colors.text),
            cursorColor: colors.text,
            backgroundCursorColor: colors.text,
            maxLines: 1,
          ),
        ),
      ],
    ),
  );

  /// Send (ML-01: a 40 × 52 button; ML-01b: a 38 pt #008fff circle with a white upward
  /// arrow, faded until there is a recipient).
  Widget _sendButton(MailColors colors) {
    final ready = !_sending && parseAddresses(_to.text).isNotEmpty;
    return Semantics(
      button: true,
      enabled: ready,
      label: l10n.send,
      child: GestureDetector(
        key: const ValueKey('compose send'),
        behavior: HitTestBehavior.opaque,
        onTap: _sending ? null : _send,
        child: SizedBox(
          width: 40,
          height: toolbarHeight,
          child: Center(
            child: Opacity(
              opacity: ready ? 1 : 0.4,
              child: Container(
                width: MailMetrics.sendButton,
                height: MailMetrics.sendButton,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.send,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '↑',
                  style: mailText(
                    19,
                    colors.selectionText,
                    weight: FontWeight.w600,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

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
        const SingleActivator(LogicalKeyboardKey.escape): _close,
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
                  // PROVISIONAL: the dim behind the panel (the reference composer is its
                  // own window, silica-linux/mail issue for a separate window).
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

  Widget _panel(MailColors colors) => Container(
    key: const ValueKey('composer panel'),
    constraints: BoxConstraints.loose(MailMetrics.composer),
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: toolbarHeight,
          child: Row(
            children: [
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  _subject.text.isEmpty ? l10n.newMessage : _subject.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: mailText(13, colors.text, weight: FontWeight.w600),
                ),
              ),
              GestureDetector(
                key: const ValueKey('compose cancel'),
                onTap: _close,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    l10n.cancel,
                    style: mailText(13, colors.secondary),
                  ),
                ),
              ),
              _sendButton(colors),
              const SizedBox(width: 8),
            ],
          ),
        ),
        // ML-01: the first field row starts at y 61.
        const SizedBox(height: MailMetrics.composerFieldsY - toolbarHeight),
        Container(height: 1, color: colors.separator),
        _field(colors, l10n.to, _to, _toFocus, 'compose to'),
        _field(colors, l10n.cc, _cc, _ccFocus, 'compose cc'),
        _field(
          colors,
          l10n.subject,
          _subject,
          _subjectFocus,
          'compose subject',
        ),
        if (_error case final error?)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              error,
              key: const ValueKey('compose error'),
              style: mailText(12, const Color(0xFFE5484D)),
            ),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: EditableText(
              key: const ValueKey('compose body'),
              controller: _body,
              focusNode: _bodyFocus,
              style: mailText(13.5, colors.text, height: 1.45),
              cursorColor: colors.text,
              backgroundCursorColor: colors.text,
              maxLines: null,
              keyboardType: TextInputType.multiline,
            ),
          ),
        ),
      ],
    ),
  );
}
