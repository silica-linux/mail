import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_mail/src/html.dart';

void main() {
  test('plain text drops scripts and styles, keeps the paragraphs', () {
    const html =
        '<html><head><style>p{color:red}</style><title>t</title></head>'
        '<body><p>One &amp; two</p><script>alert(1)</script><p>Three&nbsp;&#x41;</p></body></html>';
    expect(htmlToPlainText(html), 'One & two\n\nThree A');
  });

  test(
    'remote content: images, backgrounds and stylesheets on the network',
    () {
      expect(hasRemoteContent('<img src="https://e.org/p.png">'), isTrue);
      expect(hasRemoteContent('<img src=//e.org/p.png>'), isTrue);
      expect(hasRemoteContent('<td background="http://e.org/b.png">'), isTrue);
      expect(
        hasRemoteContent('<link rel=stylesheet href="https://e.org/s.css">'),
        isTrue,
      );
      expect(hasRemoteContent('<img src="cid:logo">'), isFalse);
      expect(hasRemoteContent('<a href="https://e.org">link</a>'), isFalse);
    },
  );

  test('only web and mail links are offered to the system', () {
    expect(safeLink('https://example.org'), isTrue);
    expect(safeLink('mailto:a@b.c'), isTrue);
    expect(safeLink('javascript:alert(1)'), isFalse);
    expect(safeLink('file:///etc/passwd'), isFalse);
  });

  testWidgets(
    'links call back with the URL; javascript links are inert; no remote image',
    (tester) async {
      final opened = <String>[];
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: HtmlBody(
            html:
                '<p>Go <a href="https://example.org/x">here</a> or '
                '<a href="javascript:steal()">there</a>.</p><img src="https://e.org/p.png" alt="logo">',
            style: const TextStyle(fontSize: 13, color: Color(0xFF000000)),
            linkColor: const Color(0xFF0000FF),
            quoteColor: const Color(0xFF777777),
            onLink: opened.add,
          ),
        ),
      );
      expect(find.byType(Image), findsNothing);
      final rich =
          tester.widget<RichText>(find.byType(RichText).first).text as TextSpan;
      final spans = <TextSpan>[];
      rich.visitChildren((s) {
        if (s is TextSpan) spans.add(s);
        return true;
      });
      final here = spans.firstWhere((s) => s.text == 'here');
      (here.recognizer! as TapGestureRecognizer).onTap!();
      expect(opened, ['https://example.org/x']);
      final there = spans.firstWhere((s) => s.text == 'there');
      expect(there.recognizer, isNull);
      // ML-01b: an image not loaded is a 320 × 120 box with the alt text.
      expect(
        tester.getSize(find.byKey(const ValueKey('missing image'))),
        const Size(320, 120),
      );
      expect(find.text('logo'), findsOneWidget);
    },
  );
}
