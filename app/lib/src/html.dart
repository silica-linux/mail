// A safe renderer for HTML mail: no scripts, no styles, no forms, no network unless the user
// allows remote content. It keeps the structure that matters for reading (paragraphs, line
// breaks, headings, bold and italic, links, lists, quotes, preformatted text) and drops the rest.
// Links never navigate inside the app: the callback receives the URL (the window opens it with
// the system handler).

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// A token of the HTML: text, or a tag with its name, closing flag and attributes.
sealed class _Token {
  const _Token();
}

class _Text extends _Token {
  const _Text(this.text);
  final String text;
}

class _Tag extends _Token {
  const _Tag(this.name, {this.closing = false, this.attributes = const {}});
  final String name;
  final bool closing;
  final Map<String, String> attributes;
}

final RegExp _tagPattern = RegExp(
  r'<(/?)([a-zA-Z][a-zA-Z0-9]*)([^>]*)>|<!--[\s\S]*?-->',
);
final RegExp _attributePattern = RegExp(
  r'''([a-zA-Z_:][a-zA-Z0-9_:.-]*)\s*=\s*("([^"]*)"|'([^']*)'|([^\s"'>]+))''',
);

/// Decodes the common entities and numeric references.
String decodeEntities(String s) =>
    s.replaceAllMapped(RegExp(r'&(#x[0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);'), (m) {
      final e = m.group(1) ?? '';
      if (e.startsWith('#x') || e.startsWith('#X')) {
        final code = int.tryParse(e.substring(2), radix: 16);
        return code == null || code > 0x10FFFF
            ? m.group(0)!
            : String.fromCharCode(code);
      }
      if (e.startsWith('#')) {
        final code = int.tryParse(e.substring(1));
        return code == null || code > 0x10FFFF
            ? m.group(0)!
            : String.fromCharCode(code);
      }
      return switch (e) {
        'amp' => '&',
        'lt' => '<',
        'gt' => '>',
        'quot' => '"',
        'apos' => "'",
        'nbsp' => ' ',
        'mdash' => '—',
        'ndash' => '–',
        'hellip' => '…',
        'laquo' => '«',
        'raquo' => '»',
        'rsquo' => '’',
        'lsquo' => '‘',
        'rdquo' => '”',
        'ldquo' => '“',
        _ => m.group(0)!,
      };
    });

List<_Token> _tokenize(String html) {
  final tokens = <_Token>[];
  var at = 0;
  for (final m in _tagPattern.allMatches(html)) {
    if (m.start > at) tokens.add(_Text(html.substring(at, m.start)));
    at = m.end;
    final name = m.group(2);
    if (name == null) continue; // a comment
    final attributes = <String, String>{};
    for (final a in _attributePattern.allMatches(m.group(3) ?? '')) {
      attributes[a.group(1)!.toLowerCase()] = decodeEntities(
        a.group(3) ?? a.group(4) ?? a.group(5) ?? '',
      );
    }
    tokens.add(
      _Tag(
        name.toLowerCase(),
        closing: m.group(1) == '/',
        attributes: attributes,
      ),
    );
  }
  if (at < html.length) tokens.add(_Text(html.substring(at)));
  return tokens;
}

/// Whether the HTML refers to content on the network (images, styles, frames).
bool hasRemoteContent(String html) {
  for (final t in _tokenize(html)) {
    if (t is _Tag && !t.closing) {
      final src =
          t.attributes['src'] ??
          (t.name == 'link' ? t.attributes['href'] : null);
      if (src != null && _isRemote(src)) return true;
      final background = t.attributes['background'];
      if (background != null && _isRemote(background)) return true;
    }
  }
  return false;
}

bool _isRemote(String url) {
  final u = url.trim().toLowerCase();
  return u.startsWith('http:') || u.startsWith('https:') || u.startsWith('//');
}

/// Only these schemes are offered to the system handler.
bool safeLink(String url) {
  final u = Uri.tryParse(url.trim());
  return u != null && const {'http', 'https', 'mailto'}.contains(u.scheme);
}

/// The text content of the HTML, for previews, quotes and the plain-text fallback.
String htmlToPlainText(String html) {
  final out = StringBuffer();
  var skip = 0;
  for (final t in _tokenize(html)) {
    switch (t) {
      case _Tag(:final name, :final closing):
        if (const {'script', 'style', 'head', 'title'}.contains(name)) {
          skip += closing ? -1 : 1;
          if (skip < 0) skip = 0;
        } else if (const {
          'p',
          'div',
          'br',
          'li',
          'tr',
          'h1',
          'h2',
          'h3',
          'blockquote',
        }.contains(name)) {
          out.write('\n');
        }
      case _Text(:final text):
        if (skip == 0)
          out.write(decodeEntities(text.replaceAll(RegExp(r'\s+'), ' ')));
    }
  }
  return out
      .toString()
      .replaceAll(RegExp(r'\n[ \t]+'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

/// The message body as styled text.
class HtmlBody extends StatefulWidget {
  const HtmlBody({
    super.key,
    required this.html,
    required this.style,
    required this.linkColor,
    required this.quoteColor,
    required this.onLink,
    this.allowRemote = false,
  });

  final String html;
  final TextStyle style;
  final Color linkColor;
  final Color quoteColor;
  final ValueChanged<String> onLink;

  /// Remote images are loaded only when this is true.
  final bool allowRemote;

  @override
  State<HtmlBody> createState() => _HtmlBodyState();
}

class _HtmlBodyState extends State<HtmlBody> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
    final spans = <InlineSpan>[];
    var bold = 0, italic = 0, skip = 0, pre = 0, quote = 0, heading = 0;
    final links = <String?>[];
    final listDepth = <String>[];
    var needBreak = false;

    void breakLine({bool blank = false}) {
      if (spans.isEmpty) return;
      spans.add(TextSpan(text: blank ? '\n\n' : '\n'));
      needBreak = false;
    }

    for (final t in _tokenize(widget.html)) {
      switch (t) {
        case _Tag(:final name, :final closing, :final attributes):
          switch (name) {
            case 'script' ||
                'style' ||
                'head' ||
                'title' ||
                'noscript' ||
                'template':
              skip = closing ? (skip > 0 ? skip - 1 : 0) : skip + 1;
            case 'b' || 'strong':
              bold += closing ? -1 : 1;
            case 'i' || 'em':
              italic += closing ? -1 : 1;
            case 'h1' || 'h2' || 'h3' || 'h4':
              heading += closing ? -1 : 1;
              breakLine(blank: true);
            case 'pre':
              pre += closing ? -1 : 1;
              breakLine();
            case 'blockquote':
              quote += closing ? -1 : 1;
              breakLine();
            case 'a':
              if (closing) {
                if (links.isNotEmpty) links.removeLast();
              } else {
                final href = attributes['href'];
                links.add(href != null && safeLink(href) ? href : null);
              }
            case 'br':
              spans.add(const TextSpan(text: '\n'));
            case 'p' || 'div' || 'tr' || 'table':
              if (!closing) needBreak = true;
              if (closing && name == 'p') breakLine(blank: true);
            case 'ul' || 'ol':
              if (closing) {
                if (listDepth.isNotEmpty) listDepth.removeLast();
              } else {
                listDepth.add(name);
              }
              breakLine();
            case 'li':
              if (!closing) {
                breakLine();
                spans.add(TextSpan(text: '${'  ' * listDepth.length}• '));
              }
            case 'img':
              if (closing || skip > 0) break;
              final src = attributes['src'] ?? '';
              final alt = attributes['alt'] ?? '';
              if (_isRemote(src) && widget.allowRemote) {
                final url = src.startsWith('//') ? 'https:$src' : src;
                spans.add(
                  WidgetSpan(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 600,
                        maxHeight: 400,
                      ),
                      child: Image.network(
                        url,
                        errorBuilder: (_, _, _) =>
                            Text(alt, style: widget.style),
                      ),
                    ),
                  ),
                );
              } else if (alt.isNotEmpty) {
                spans.add(
                  TextSpan(
                    text: '[$alt]',
                    style: widget.style.copyWith(color: widget.quoteColor),
                  ),
                );
              }
            default:
              break;
          }
        case _Text(:final text):
          if (skip > 0) break;
          var content = decodeEntities(
            pre > 0 ? text : text.replaceAll(RegExp(r'\s+'), ' '),
          );
          if (content.trim().isEmpty && pre == 0) {
            if (spans.isNotEmpty && content.isNotEmpty)
              spans.add(const TextSpan(text: ' '));
            break;
          }
          if (needBreak) breakLine();
          if (spans.isEmpty) content = content.trimLeft();
          final link = links.isEmpty ? null : links.last;
          var style = widget.style.copyWith(
            fontWeight: bold > 0 || heading > 0 ? FontWeight.w600 : null,
            fontStyle: italic > 0 ? FontStyle.italic : null,
            fontSize: heading > 0 ? (widget.style.fontSize ?? 13) * 1.3 : null,
            color: quote > 0 ? widget.quoteColor : null,
          );
          if (pre > 0) {
            // Preformatted text in the system monospaced font (not Inter).
            style = TextStyle(
              fontFamily: 'monospace',
              fontSize: widget.style.fontSize,
              height: widget.style.height,
              color: style.color,
            );
          }
          TapGestureRecognizer? recognizer;
          if (link != null) {
            style = style.copyWith(
              color: widget.linkColor,
              decoration: TextDecoration.underline,
              decorationColor: widget.linkColor,
            );
            recognizer = TapGestureRecognizer()
              ..onTap = () => widget.onLink(link);
            _recognizers.add(recognizer);
          }
          spans.add(
            TextSpan(text: content, style: style, recognizer: recognizer),
          );
      }
    }
    return Text.rich(TextSpan(style: widget.style, children: spans));
  }
}
