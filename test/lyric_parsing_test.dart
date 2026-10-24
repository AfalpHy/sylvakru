import 'package:flutter_test/flutter_test.dart';
import 'package:sylvakru/base/services/lyric.dart';

const _noLyrics = 'no lyrics';
const _parseFailed = 'parse failed';

ParsedLyrics parse(List<String> lines, {Duration? songDuration}) {
  final result = ParsedLyrics();
  applyLrcParsing(
    result,
    lines,
    noLyricsMessage: _noLyrics,
    parseFailedMessage: _parseFailed,
    songDuration: songDuration,
  );
  return result;
}

ParsedLyrics parseTtml(String ttml, {Duration? songDuration}) {
  final result = ParsedLyrics();
  applyTtmlParsing(
    result,
    ttml,
    noLyricsMessage: _noLyrics,
    parseFailedMessage: _parseFailed,
    songDuration: songDuration,
  );
  return result;
}

void main() {
  group('applyLrcParsing', () {
    test('falls back to noLyricsMessage when there are no lines', () {
      final result = parse([]);
      expect(result.lines, hasLength(1));
      expect(result.lines.first.text, _noLyrics);
      expect(result.isKaraoke, isFalse);
    });

    test('falls back to noLyricsMessage when all lines are empty strings', () {
      final result = parse(['', '', '']);
      expect(result.lines, hasLength(1));
      expect(result.lines.first.text, _noLyrics);
    });

    test('falls back to parseFailedMessage for whitespace-only lines '
        '(only exactly-empty strings are filtered before parsing)', () {
      final result = parse(['   ', '\t']);
      expect(result.lines, hasLength(1));
      expect(result.lines.first.text, _parseFailed);
    });

    test(
      'falls back to parseFailedMessage when no line matches the LRC format',
      () {
        final result = parse(['just plain text', 'no timestamps here']);
        expect(result.lines, hasLength(1));
        expect(result.lines.first.text, _parseFailed);
      },
    );

    test('parses plain (non-karaoke) LRC lines in order', () {
      final result = parse(['[00:01.000]First line', '[00:05.500]Second line']);

      expect(result.isKaraoke, isFalse);
      expect(result.lines, hasLength(2));
      expect(result.lines[0].start, Duration(seconds: 1));
      expect(result.lines[0].text, 'First line');
      expect(result.lines[1].start, Duration(milliseconds: 5500));
      expect(result.lines[1].text, 'Second line');
    });

    test(
      'backfills the previous line\'s end time from the next line start',
      () {
        final result = parse([
          '[00:01.000]First line',
          '[00:05.000]Second line',
        ]);

        expect(result.lines[0].tokens.single.end, Duration(seconds: 5));
      },
    );

    test('detects karaoke lines (multiple timed tokens per line)', () {
      final result = parse(['[00:01.000]He[00:01.500]llo [00:02.000]world']);

      expect(result.isKaraoke, isTrue);
      expect(result.lines, hasLength(1));
      expect(result.lines.first.text, 'Hello world');
      expect(result.lines.first.tokens, hasLength(3));
      expect(result.lines.first.tokens[0].text, 'He');
      expect(result.lines.first.tokens[0].end, Duration(milliseconds: 1500));
      expect(result.lines.first.tokens[1].text, 'llo ');
      expect(result.lines.first.tokens[1].end, Duration(seconds: 2));
      expect(result.lines.first.tokens[2].text, 'world');
    });

    test('treats a second line at the same timestamp as a translation', () {
      final result = parse([
        '[00:01.000]Hello world',
        '[00:01.000]你好世界',
        '[00:05.000]Next line',
      ]);

      expect(result.lines, hasLength(2));
      expect(result.lines[0].text, 'Hello world');
      expect(result.lines[0].translates, ['你好世界']);
    });

    test('supports angle-bracket timestamps as well as square brackets', () {
      final result = parse(['<00:01.00>Hello']);

      expect(result.lines, hasLength(1));
      expect(result.lines.first.text, 'Hello');
    });

    test(
      'sets the final token\'s end time to the song duration when nothing follows',
      () {
        final result = parse([
          '[00:01.000]Only line',
        ], songDuration: Duration(minutes: 3));

        expect(result.lines.single.tokens.single.end, Duration(minutes: 3));
      },
    );

    test('keeps translation lines in their written order', () {
      final result = parse([
        '[00:05.000]Line A',
        '[00:01.000]Main',
        '[00:01.000]翻译一',
        '[00:01.000]翻译二',
      ]);

      expect(result.lines.first.text, 'Main');
      expect(result.lines.first.translates, ['翻译一', '翻译二']);
    });

    test('sorts plain same-timestamp lines after word-timed originals', () {
      final result = parse([
        '[00:01.000]翻译',
        '[00:01.000]<00:01.000>Hel<00:01.500>lo',
        '[00:05.000]Next',
      ]);

      expect(result.isKaraoke, isTrue);
      expect(result.lines, hasLength(2));
      expect(result.lines[0].text, 'Hello');
      expect(result.lines[0].translates, ['翻译']);
      expect(result.lines[1].text, 'Next');
      expect(result.lines[0].tokens.last.end, Duration(seconds: 5));
    });

    test('ignores lines whose only token is blank', () {
      final result = parse(['[00:01.000]   ', '[00:02.000]Real line']);

      expect(result.lines, hasLength(1));
      expect(result.lines.first.text, 'Real line');
    });
  });

  group('looksLikeTtml', () {
    test('detects plain, prefixed and declaration-prefixed TTML', () {
      expect(looksLikeTtml('<tt xmlns="http://www.w3.org/ns/ttml">'), isTrue);
      expect(looksLikeTtml('<tt:tt xmlns:tt="http://www.w3.org/ns/ttml">'), isTrue);
      expect(looksLikeTtml('<?xml version="1.0" encoding="UTF-8"?><tt>'), isTrue);
      expect(looksLikeTtml('  <tt>'), isTrue);
      expect(looksLikeTtml('<html><body></body></html>'), isFalse);
      expect(looksLikeTtml('[00:01.000]plain lrc'), isFalse);
      expect(looksLikeTtml(''), isFalse);
    });
  });

  group('applyTtmlParsing', () {
    test('falls back to noLyricsMessage when input is empty', () {
      final result = parseTtml('   ');
      expect(result.lines, hasLength(1));
      expect(result.lines.first.text, _noLyrics);
    });

    test('falls back to parseFailedMessage for malformed XML', () {
      final result = parseTtml('this is not xml at all');
      expect(result.lines, hasLength(1));
      expect(result.lines.first.text, _parseFailed);
    });

    test(
      'falls back to parseFailedMessage when there are no p elements',
      () {
        final result = parseTtml(
          '<tt><body><div>nothing here</div></body></tt>',
        );
        expect(result.lines, hasLength(1));
        expect(result.lines.first.text, _parseFailed);
      },
    );

    test('parses line-timed TTML without karaoke', () {
      final result = parseTtml('''
<tt xmlns="http://www.w3.org/ns/ttml">
  <body>
    <div>
      <p begin="00:00:01.000" end="00:00:04.000">First line</p>
      <p begin="00:00:05.500">Second line</p>
    </div>
  </body>
</tt>
''');

      expect(result.isKaraoke, isFalse);
      expect(result.lines, hasLength(2));
      expect(result.lines[0].start, const Duration(seconds: 1));
      expect(result.lines[0].text, 'First line');
      expect(result.lines[0].tokens.single.end, const Duration(seconds: 4));
      expect(result.lines[1].start, const Duration(milliseconds: 5500));
      expect(result.lines[1].text, 'Second line');
    });

    test('parses word-timed spans into karaoke tokens', () {
      final result = parseTtml('''
<tt xmlns="http://www.w3.org/ns/ttml">
  <body>
    <div>
      <p begin="00:00:01.000" end="00:00:03.000"><span begin="00:00:01.000">He</span><span begin="00:00:01.500">llo </span><span begin="00:00:02.000">world</span></p>
    </div>
  </body>
</tt>
''');

      expect(result.isKaraoke, isTrue);
      expect(result.lines, hasLength(1));
      expect(result.lines.first.text, 'Hello world');
      expect(result.lines.first.tokens, hasLength(3));
      expect(result.lines.first.tokens[0].text, 'He');
      expect(result.lines.first.tokens[0].end, const Duration(milliseconds: 1500));
      expect(result.lines.first.tokens[1].text, 'llo ');
      expect(result.lines.first.tokens[1].end, const Duration(seconds: 2));
      expect(result.lines.first.tokens[2].text, 'world');
      expect(result.lines.first.tokens[2].end, const Duration(seconds: 3));
    });

    test('flattens nested background-vocal spans without duplicating text', () {
      final result = parseTtml('''
<tt xmlns="http://www.w3.org/ns/ttml" xmlns:ttm="http://www.w3.org/ns/ttml#metadata">
  <body>
    <div>
      <p begin="00:00:01.000" end="00:00:03.500"><span begin="00:00:01.000" end="00:00:02.000">Main </span><span ttm:role="x-bg" begin="00:00:02.000" end="00:00:03.000"><span begin="00:00:02.000">(echo</span><span begin="00:00:02.500"> voice)</span></span></p>
    </div>
  </body>
</tt>
''');

      expect(result.isKaraoke, isTrue);
      expect(result.lines, hasLength(1));
      expect(result.lines.first.text, 'Main (echo voice)');
      expect(result.lines.first.tokens, hasLength(3));
      expect(result.lines.first.tokens[0].text, 'Main ');
      expect(result.lines.first.tokens[0].end, const Duration(seconds: 2));
      expect(result.lines.first.tokens[1].text, '(echo');
      expect(result.lines.first.tokens[1].end, const Duration(milliseconds: 2500));
      expect(result.lines.first.tokens[2].text, ' voice)');
      expect(result.lines.first.tokens[2].end, const Duration(milliseconds: 3500));
    });

    test('supports offset time formats and sorts by begin', () {
      final result = parseTtml('''
<tt xmlns="http://www.w3.org/ns/ttml">
  <body>
    <div>
      <p begin="2m">D</p>
      <p begin="1.5s">B</p>
      <p begin="1230ms">A</p>
      <p begin="00:30.250">C</p>
    </div>
  </body>
</tt>
''');

      expect(result.lines.map((l) => l.start), [
        const Duration(milliseconds: 1230),
        const Duration(milliseconds: 1500),
        const Duration(seconds: 30, milliseconds: 250),
        const Duration(minutes: 2),
      ]);
      expect(result.lines.map((l) => l.text), ['A', 'B', 'C', 'D']);
    });

    test('skips paragraphs with unsupported begin values', () {
      final result = parseTtml('''
<tt xmlns="http://www.w3.org/ns/ttml">
  <body>
    <div>
      <p begin="12f">Frames</p>
      <p begin="00:00:01.000">Real line</p>
    </div>
  </body>
</tt>
''');

      expect(result.lines, hasLength(1));
      expect(result.lines.first.text, 'Real line');
    });

    test('backfills token ends from the next line and song duration', () {
      final result = parseTtml('''
<tt xmlns="http://www.w3.org/ns/ttml">
  <body>
    <div>
      <p begin="00:00:01.000"><span begin="00:00:01.000">First</span></p>
      <p begin="00:00:05.000"><span begin="00:00:05.000">Second</span></p>
    </div>
  </body>
</tt>
''', songDuration: const Duration(minutes: 3));

      expect(result.lines.first.tokens.single.end, const Duration(seconds: 5));
      expect(result.lines.last.tokens.single.end, const Duration(minutes: 3));
    });

    test('treats a second paragraph with the same begin as a translation', () {
      final result = parseTtml('''
<tt xmlns="http://www.w3.org/ns/ttml">
  <body>
    <div>
      <p begin="00:00:01.000">Hello world</p>
      <p begin="00:00:01.000">你好世界</p>
      <p begin="00:00:05.000">Next line</p>
    </div>
  </body>
</tt>
''');

      expect(result.lines, hasLength(2));
      expect(result.lines[0].text, 'Hello world');
      expect(result.lines[0].translates, ['你好世界']);
      expect(result.lines[1].text, 'Next line');
    });

    test('sorts plain paragraphs after word-timed ones sharing a begin', () {
      final result = parseTtml('''
<tt xmlns="http://www.w3.org/ns/ttml">
  <body>
    <div>
      <p begin="00:00:01.000">翻译</p>
      <p begin="00:00:01.000" end="00:00:03.000"><span begin="00:00:01.000">Hel</span><span begin="00:00:01.500">lo</span></p>
      <p begin="00:00:05.000">Next</p>
    </div>
  </body>
</tt>
''');

      expect(result.isKaraoke, isTrue);
      expect(result.lines, hasLength(2));
      expect(result.lines[0].text, 'Hello');
      expect(result.lines[0].translates, ['翻译']);
      expect(result.lines[1].text, 'Next');
    });

    test('collapses pretty-printed whitespace inside lines', () {
      final result = parseTtml('''
<tt xmlns="http://www.w3.org/ns/ttml">
  <body>
    <div>
      <p begin="00:00:01.000">
        Hello
        world
      </p>
    </div>
  </body>
</tt>
''');

      expect(result.lines.single.text, 'Hello world');
    });

    test('finds paragraphs under a prefixed TTML namespace', () {
      final result = parseTtml('''
<tt:tt xmlns:tt="http://www.w3.org/ns/ttml">
  <tt:body>
    <tt:div>
      <tt:p begin="00:00:01.000">Hello</tt:p>
    </tt:div>
  </tt:body>
</tt:tt>
''');

      expect(result.lines, hasLength(1));
      expect(result.lines.first.text, 'Hello');
    });

    test('treats br elements as spaces', () {
      final result = parseTtml('''
<tt xmlns="http://www.w3.org/ns/ttml">
  <body>
    <div>
      <p begin="00:00:01.000">Line<br/>break</p>
    </div>
  </body>
</tt>
''');

      expect(result.lines.single.text, 'Line break');
    });

    test('skips paragraphs without text', () {
      final result = parseTtml('''
<tt xmlns="http://www.w3.org/ns/ttml">
  <body>
    <div>
      <p begin="00:00:01.000">   </p>
      <p begin="00:00:02.000">Real line</p>
    </div>
  </body>
</tt>
''');

      expect(result.lines, hasLength(1));
      expect(result.lines.first.text, 'Real line');
    });

    test('handles an XML declaration before the root element', () {
      final result = parseTtml(
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<tt xmlns="http://www.w3.org/ns/ttml">'
        '<body><div><p begin="00:00:01.000">Hello</p></div></body></tt>',
      );

      expect(result.lines.single.text, 'Hello');
    });
  });
}
