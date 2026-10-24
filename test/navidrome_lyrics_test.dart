import 'package:flutter_test/flutter_test.dart';
import 'package:sylvakru/base/services/lyric.dart';
import 'package:sylvakru/base/services/navidrome_client.dart';

void main() {
  group('structuredLyricsToLrc', () {
    test('returns empty text when there are no entries', () {
      expect(structuredLyricsToLrc([]), '');
    });

    test('converts plain line-based entries as before', () {
      final lrc = structuredLyricsToLrc([
        {
          'synced': true,
          'line': [
            {'start': 12000, 'value': 'Hello world'},
            {'start': 15500, 'value': 'Second line'},
          ],
        },
      ]);

      expect(lrc, '[00:12.000]Hello world\n[00:15.500]Second line\n');
    });

    test('converts cueLine karaoke data to enhanced LRC with word timing', () {
      final lrc = structuredLyricsToLrc([
        {
          'kind': 'main',
          'synced': true,
          'line': [
            {'start': 2747, 'value': 'Hello world'},
          ],
          'cueLine': [
            {
              'index': 0,
              'start': 2747,
              'end': 5000,
              'value': 'Hello world',
              'cue': [
                {
                  'start': 2747,
                  'end': 3800,
                  'value': 'Hello',
                  'byteStart': 0,
                  'byteEnd': 4,
                },
                {
                  'start': 3800,
                  'end': 5000,
                  'value': ' world',
                  'byteStart': 5,
                  'byteEnd': 10,
                },
              ],
            },
          ],
        },
      ]);

      expect(lrc, '[00:02.747]<00:02.747>Hello<00:03.800> world\n');
    });

    test('feeds through applyLrcParsing as karaoke', () {
      final lrc = structuredLyricsToLrc([
        {
          'kind': 'main',
          'synced': true,
          'line': [
            {'start': 2747, 'value': 'Hello world'},
          ],
          'cueLine': [
            {
              'index': 0,
              'start': 2747,
              'value': 'Hello world',
              'cue': [
                {'start': 2747, 'value': 'Hello', 'byteStart': 0, 'byteEnd': 4},
                {
                  'start': 3800,
                  'value': ' world',
                  'byteStart': 5,
                  'byteEnd': 10,
                },
              ],
            },
          ],
        },
      ]);

      final result = ParsedLyrics();
      applyLrcParsing(
        result,
        lrc.split('\n'),
        noLyricsMessage: 'none',
        parseFailedMessage: 'bad',
      );

      expect(result.isKaraoke, isTrue);
      expect(result.lines.single.text, 'Hello world');
      expect(result.lines.single.tokens.map((t) => t.text), [
        'Hello',
        ' world',
      ]);
    });

    test('slices cue text by UTF-8 byte offsets for CJK', () {
      final lrc = structuredLyricsToLrc([
        {
          'kind': 'main',
          'synced': true,
          'line': [
            {'start': 2747, 'value': '눈물'},
          ],
          'cueLine': [
            {
              'index': 0,
              'start': 2747,
              'value': '눈물',
              'cue': [
                {'start': 2747, 'value': '눈', 'byteStart': 0, 'byteEnd': 2},
                {'start': 4000, 'value': '물', 'byteStart': 3, 'byteEnd': 5},
              ],
            },
          ],
        },
      ]);

      expect(lrc, '[00:02.747]<00:02.747>눈<00:04.000>물\n');
    });

    test('applies the entry offset', () {
      final lrc = structuredLyricsToLrc([
        {
          'offset': -100,
          'synced': true,
          'line': [
            {'start': 12000, 'value': 'Hello'},
          ],
        },
      ]);

      expect(lrc, '[00:11.900]Hello\n');
    });

    test('emits translation entries as same-timestamp lines', () {
      final lrc = structuredLyricsToLrc([
        {
          'kind': 'main',
          'synced': true,
          'line': [
            {'start': 2747, 'value': 'Hello'},
          ],
          'cueLine': [
            {
              'index': 0,
              'start': 2747,
              'value': 'Hello',
              'cue': [
                {'start': 2747, 'value': 'Hello'},
              ],
            },
          ],
        },
        {
          'kind': 'translation',
          'lang': 'zh',
          'synced': true,
          'line': [
            {'start': 2747, 'value': '你好'},
          ],
        },
      ]);

      expect(lrc, '[00:02.747]<00:02.747>Hello\n[00:02.747]你好\n');
    });

    test('merges agent layers sharing an index onto one line', () {
      final lrc = structuredLyricsToLrc([
        {
          'kind': 'main',
          'synced': true,
          'agents': [
            {'id': 'v1', 'role': 'main'},
            {'id': 'v2', 'role': 'bg'},
          ],
          'line': [
            {'start': 1000, 'value': 'Main (bg)'},
          ],
          'cueLine': [
            {
              'index': 0,
              'start': 1000,
              'agentId': 'v1',
              'value': 'Main (bg)',
              'cue': [
                {'start': 1000, 'value': 'Main ', 'byteStart': 0, 'byteEnd': 4},
              ],
            },
            {
              'index': 0,
              'start': 1500,
              'agentId': 'v2',
              'value': '(bg)',
              'cue': [
                {'start': 1500, 'value': '(bg)', 'byteStart': 0, 'byteEnd': 3},
              ],
            },
          ],
        },
      ]);

      expect(lrc, '[00:01.000]<00:01.000>Main <00:01.500>(bg)\n');
    });

    test('falls back to the longest first line when no cueLine data', () {
      final lrc = structuredLyricsToLrc([
        {
          'synced': true,
          'line': [
            {'start': 1000, 'value': 'short'},
          ],
        },
        {
          'synced': true,
          'line': [
            {'start': 2000, 'value': 'the longest first line'},
            {'start': 3000, 'value': 'second'},
          ],
        },
      ]);

      expect(lrc, '[00:02.000]the longest first line\n[00:03.000]second\n');
    });
  });
}
