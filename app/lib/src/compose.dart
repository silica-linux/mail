// The composer: a sheet over the window with To, Cc, Subject and the text. A reply, a reply to
// all and a forward start from the message in the reader, with the quoted text below.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

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

class _ComposeSheetState extends State<ComposeSheet> {
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      (widget.request.to.isEmpty ? _toFocus : _bodyFocus).requestFocus();
    });
  }

  @override
  void dispose() {
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
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.service.send(
        Draft(
          account: widget.request.account.id,
          to: to,
          cc: parseAddresses(_cc.text),
          subject: _subject.text,
          text: _body.text,
          inReplyTo: widget.request.inReplyTo,
        ),
      );
      widget.onClose();
    } on MailError catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = l10n.sendFailed(e.message);
        });
      }
    }
  }

  Widget _field(
    MailColors colors,
    String label,
    TextEditingController controller,
    FocusNode focus,
    String key,
  ) => Container(
    height: 34,
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
        const SingleActivator(LogicalKeyboardKey.escape): widget.onClose,
      },
      child: ColoredBox(
        color: const Color(0x33000000),
        child: Center(
          child: Container(
            width: 640,
            height: 500,
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
                  height: 44,
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          _subject.text.isEmpty
                              ? l10n.newMessage
                              : _subject.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: mailText(
                            13,
                            colors.text,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                      GestureDetector(
                        key: const ValueKey('compose cancel'),
                        onTap: widget.onClose,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            l10n.cancel,
                            style: mailText(13, colors.secondary),
                          ),
                        ),
                      ),
                      GestureDetector(
                        key: const ValueKey('compose send'),
                        onTap: _sending ? null : _send,
                        child: Container(
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _sending
                                ? colors.tertiary
                                : colors.selection,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            l10n.send,
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
                ),
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
          ),
        ),
      ),
    );
  }
}
