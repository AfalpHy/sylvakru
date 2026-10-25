import 'dart:io';

import 'package:charset/charset.dart';
import 'package:xml/xml.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/services/stream_client.dart';
import 'package:sylvakru/base/services/webdav_client.dart';
import 'package:sylvakru/base/services/logger.dart';
import 'package:sylvakru/base/utils/common_utils.dart';

class LyricToken {
  final Duration start;
  final String text;
  Duration? end;

  LyricToken(this.start, this.text, [this.end]);

  Map<String, dynamic> toMap() {
    return {
      'start': start.inMilliseconds,
      'end': end?.inMilliseconds,
      'text': text,
    };
  }

  factory LyricToken.fromMap(Map raw) {
    final map = Map<String, dynamic>.from(raw);

    return LyricToken(
      Duration(milliseconds: map['start'] as int),
      map['text'] as String,
      map['end'] != null ? Duration(milliseconds: map['end'] as int) : null,
    );
  }
}

class LyricLine {
  final Duration start;
  final String text;
  final List<LyricToken> tokens;

  List<String> translates = [];

  LyricLine(this.start, this.text, this.tokens);

  Map<String, dynamic> toMap() {
    return {
      'start': start.inMilliseconds,
      'text': text,
      'tokens': tokens.map((t) => t.toMap()).toList(),
      'translates': translates,
    };
  }

  factory LyricLine.fromMap(Map raw) {
    final map = Map<String, dynamic>.from(raw);
    final lyricLine = LyricLine(
      Duration(milliseconds: map['start'] as int),
      map['text'] as String,
      (map['tokens'] as List).map((e) => LyricToken.fromMap(e as Map)).toList(),
    );
    lyricLine.translates = List<String>.from(map['translates']);
    return lyricLine;
  }
}

class ParsedLyrics {
  bool isKaraoke = false;
  List<LyricLine> lines = [];
}

Duration parseTime(RegExpMatch m) {
  final min = int.parse(m.group(1)!);
  final sec = int.parse(m.group(2)!);
  final ms = int.parse(m.group(3)!.padRight(3, '0'));
  return Duration(minutes: min, seconds: sec, milliseconds: ms);
}

/// Whether [text] starts like a TTML document (`<tt>` or prefixed `<tt:tt>`),
/// skipping an optional XML declaration and byte-order mark.
bool looksLikeTtml(String text) {
  var trimmed = text.trimLeft().replaceFirst(RegExp(r'^\uFEFF'), '');
  if (trimmed.startsWith('<?xml')) {
    final declarationEnd = trimmed.indexOf('?>');
    if (declarationEnd == -1) {
      return false;
    }
    trimmed = trimmed.substring(declarationEnd + 2).trimLeft();
  }
  if (!trimmed.startsWith('<')) {
    return false;
  }
  return RegExp(r'^<\s*(?:[\w.-]+:)?tt[\s>]').hasMatch(trimmed);
}

/// Parses a TTML `begin`/`end` attribute value: clock times
/// (`HH:MM:SS.fff` / `MM:SS.fff`) and offset times (`1.5s`, `1230ms`,
/// `2m`, `1h`). Returns null for unsupported or malformed values.
Duration? parseTtmlTime(String raw) {
  final s = raw.trim();

  final offsetMatch = RegExp(r'^(\d+(?:\.\d+)?)(ms|s|m|h)?$').firstMatch(s);
  if (offsetMatch != null) {
    final value = double.parse(offsetMatch.group(1)!);
    return switch (offsetMatch.group(2)) {
      'ms' => Duration(milliseconds: value.round()),
      'm' => Duration(
        microseconds: (value * Duration.microsecondsPerMinute).round(),
      ),
      'h' => Duration(
        microseconds: (value * Duration.microsecondsPerHour).round(),
      ),
      _ => Duration(
        microseconds: (value * Duration.microsecondsPerSecond).round(),
      ),
    };
  }

  final clockMatch = RegExp(
    r'^(\d+):(\d+)(?::(\d+))?(?:\.(\d+))?$',
  ).firstMatch(s);
  if (clockMatch == null) {
    return null;
  }

  final hasHours = clockMatch.group(3) != null;
  final hours = hasHours ? int.parse(clockMatch.group(1)!) : 0;
  final minutes = hasHours
      ? int.parse(clockMatch.group(2)!)
      : int.parse(clockMatch.group(1)!);
  final seconds = hasHours
      ? int.parse(clockMatch.group(3)!)
      : int.parse(clockMatch.group(2)!);
  final milliseconds = int.parse(
    (clockMatch.group(4) ?? '').padRight(3, '0').substring(0, 3),
  );

  return Duration(
    hours: hours,
    minutes: minutes,
    seconds: seconds,
    milliseconds: milliseconds,
  );
}

String _normalizeWhitespace(String text) {
  return text.replaceAll(RegExp(r'\s+'), ' ');
}

/// Text content of [element] with `<br/>` turned into a space — innerText
/// alone would fuse the words around it.
String _elementText(XmlElement element) {
  final buffer = StringBuffer();
  for (final node in element.descendants) {
    if (node is XmlText) {
      buffer.write(node.value);
    } else if (node is XmlElement && node.name.local == 'br') {
      buffer.write(' ');
    }
  }
  return buffer.toString();
}

/// Collects the timed leaf spans of a TTML element in document order: a
/// span with a `begin` attribute whose descendants carry no timing becomes
/// one token, so nested spans (e.g. background-vocal wrappers) are
/// flattened to their innermost timed children without duplicating text.
List<LyricToken> _collectTimedTokens(XmlElement node) {
  final tokens = <LyricToken>[];

  for (final child in node.children.whereType<XmlElement>()) {
    if (child.name.local == 'br') {
      continue;
    }
    final beginAttr = child.getAttribute('begin');
    if (child.name.local == 'span' && beginAttr != null) {
      final begin = parseTtmlTime(beginAttr);
      if (begin == null) {
        continue;
      }
      final nested = _collectTimedTokens(child);
      if (nested.isNotEmpty) {
        tokens.addAll(nested);
        continue;
      }
      final text = _normalizeWhitespace(_elementText(child));
      if (text.trim().isEmpty) {
        continue;
      }
      final endAttr = child.getAttribute('end');
      tokens.add(
        LyricToken(
          begin,
          text,
          endAttr != null ? parseTtmlTime(endAttr) : null,
        ),
      );
    } else {
      tokens.addAll(_collectTimedTokens(child));
    }
  }

  return tokens;
}

Future<void> setParsedLyrics(MyAudioMetadata song) async {
  if (song.parsedLyrics != null) {
    return;
  }
  ParsedLyrics result = ParsedLyrics();

  String lyrics = '';

  if (sourceType == .navidrome || sourceType == .feiniu) {
    final lycFile = File(song.lrcPath!);
    if (await lycFile.exists()) {
      lyrics = await lycFile.readAsString();
    } else {
      lyrics = await streamClient?.getLyricsById(song.id) ?? '';
      if (lyrics.isNotEmpty) {
        await lycFile.create(recursive: true);
        await lycFile.writeAsString(lyrics);
      }
    }
  } else if (sourceType == .emby) {
    lyrics = song.lyrics ?? '';
  } else {
    if (song.lyrics == null || song.lyrics!.isEmpty) {
      lyrics = await _readSidecarLyrics(song);
    } else {
      lyrics = song.lyrics!;
    }
  }

  final l10n = getAppLocalizations();

  if (looksLikeTtml(lyrics)) {
    applyTtmlParsing(
      result,
      lyrics,
      noLyricsMessage: l10n.noLyrics,
      parseFailedMessage: l10n.lyricsParseFailed,
      songDuration: song.duration,
    );
  } else {
    applyLrcParsing(
      result,
      lyrics.split(RegExp(r'\r?\n')),
      noLyricsMessage: l10n.noLyrics,
      parseFailedMessage: l10n.lyricsParseFailed,
      songDuration: song.duration,
    );
  }

  song.parsedLyrics = result;
}

/// Reads the lyric sidecar for a local/WebDAV song, trying `.lrc`, `.ttml`
/// and `.xml` in order and treating empty content as a miss.
Future<String> _readSidecarLyrics(MyAudioMetadata song) async {
  final path = song.path!;
  final base = path.substring(0, path.lastIndexOf('.'));

  for (final ext in const ['.lrc', '.ttml', '.xml']) {
    late File file;
    if (sourceType == .webdav) {
      file = File(song.lrcPath!);
      if (!await file.exists()) {
        final downloaded =
            await webdavClient?.download(
              remotePath: '$base$ext',
              localPath: file.path,
            ) ??
            false;
        if (!downloaded || !await file.exists()) {
          continue;
        }
      }
    } else {
      file = File('$base$ext');
      if (!file.existsSync()) {
        continue;
      }
    }

    final lyrics = await _readFileWithEncodingFallback(file);
    if (lyrics.trim().isNotEmpty) {
      return lyrics;
    }
  }

  return '';
}

Future<String> _readFileWithEncodingFallback(File file) async {
  try {
    return await file.readAsString();
  } catch (e) {
    logger.output(e.toString());
    try {
      return await file.readAsString(encoding: gbk);
    } catch (e) {
      logger.output(e.toString());
    }
  }
  return '';
}

/// Fills in [result] from already-fetched raw LRC lines: parses word/line
/// timestamps, detects karaoke (multiple timed tokens per line) and
/// translation lines (a second line sharing the same timestamp as the one
/// before it), and falls back to [noLyricsMessage]/[parseFailedMessage]
/// placeholders when there's nothing to show. Split out from
/// [setParsedLyrics] so the parsing itself can be unit tested without a
/// network/file round trip.
void applyLrcParsing(
  ParsedLyrics result,
  List<String> rawLines, {
  required String noLyricsMessage,
  required String parseFailedMessage,
  Duration? songDuration,
}) {
  final lines = List<String>.from(rawLines)..removeWhere((e) => e.isEmpty);
  if (lines.isEmpty) {
    result.lines.add(LyricLine(Duration.zero, noLyricsMessage, []));
    return;
  }

  final lineTimeRegex = RegExp(r'^[\[<](\d{2}):(\d{2})[.:](\d{1,3})[\]>]');
  final wordRegex = RegExp(r'[\[<](\d{2}):(\d{2})[.:](\d{1,3})[\]>]([^\[<]*)');

  // Dart's sort is unstable, so ties are broken deterministically: lines
  // carrying per-word timestamps are the originals and come first, plain
  // lines sharing the timestamp are translations and follow them, then by
  // written order.
  bool isWordTimed(String line) {
    var timedTokens = 0;
    for (final match in wordRegex.allMatches(line)) {
      if (match.group(4)!.isNotEmpty) {
        timedTokens++;
      }
    }
    return timedTokens > 1;
  }

  final indexedLines = List.generate(
    lines.length,
    (i) => MapEntry(i, lines[i]),
  );
  indexedLines.sort((a, b) {
    final timeA = lineTimeRegex.firstMatch(a.value);
    final timeB = lineTimeRegex.firstMatch(b.value);

    if (timeA == null || timeB == null) return 0;

    final cmp = parseTime(timeA).compareTo(parseTime(timeB));
    if (cmp != 0) return cmp;
    final wordA = isWordTimed(a.value);
    final wordB = isWordTimed(b.value);
    if (wordA != wordB) return wordA ? -1 : 1;
    return a.key.compareTo(b.key);
  });

  for (var line in indexedLines.map((e) => e.value)) {
    final lineMatch = lineTimeRegex.firstMatch(line);
    if (lineMatch == null) continue;

    final lineStart = parseTime(lineMatch);

    final lastLyric = result.lines.isNotEmpty ? result.lines.last : null;
    bool isTranslate = lastLyric?.start == lineStart;

    if (lastLyric?.tokens.last.end == null && !isTranslate) {
      lastLyric?.tokens.last.end = lineStart;
    }

    final tokenMatches = wordRegex.allMatches(line);

    final tokens = <LyricToken>[];
    final textBuffer = StringBuffer();

    for (final match in tokenMatches) {
      final start = parseTime(match);
      final token = match.group(4)!;

      if (tokens.isNotEmpty) {
        tokens.last.end = start;
      }

      if (token.isNotEmpty) {
        tokens.add(LyricToken(start, token));
        textBuffer.write(token);
      }
    }
    if (tokens.isNotEmpty) {
      if (tokens.length == 1 && tokens[0].text.trim().isEmpty) {
        continue;
      }
      if (tokens.length > 1) {
        result.isKaraoke = true;
      }
      if (isTranslate) {
        lastLyric!.translates.add(textBuffer.toString());
      } else {
        result.lines.add(LyricLine(lineStart, textBuffer.toString(), tokens));
      }
    }
  }
  if (result.lines.isEmpty) {
    result.lines.add(LyricLine(Duration.zero, parseFailedMessage, []));
  } else {
    if (result.lines.last.tokens.last.end == null) {
      result.lines.last.tokens.last.end = songDuration;
    }
  }
}

/// Fills in [result] from raw TTML text: each `<p>` becomes a line, timed
/// `<span>` children become word tokens (nested spans are flattened to
/// their timed leaves), lines sharing a `begin` become translations of the
/// line before them, and the same [noLyricsMessage]/[parseFailedMessage]
/// placeholders apply as in [applyLrcParsing]. Split out from
/// [setParsedLyrics] so the parsing itself can be unit tested without a
/// network/file round trip.
void applyTtmlParsing(
  ParsedLyrics result,
  String rawTtml, {
  required String noLyricsMessage,
  required String parseFailedMessage,
  Duration? songDuration,
}) {
  if (rawTtml.trim().isEmpty) {
    result.lines.add(LyricLine(Duration.zero, noLyricsMessage, []));
    return;
  }

  XmlDocument document;
  try {
    document = XmlDocument.parse(rawTtml);
  } catch (_) {
    result.lines.add(LyricLine(Duration.zero, parseFailedMessage, []));
    return;
  }

  // Local-name matching so both plain <p> and prefixed <tt:p> are found.
  final paragraphs = document.findAllElements('p', namespaceUri: '*').toList();

  final parsedParagraphs =
      <
        ({Duration begin, Duration? end, String text, List<LyricToken> tokens})
      >[];
  for (final paragraph in paragraphs) {
    final tokens = _collectTimedTokens(paragraph);
    final beginAttr = paragraph.getAttribute('begin');
    var begin = beginAttr != null ? parseTtmlTime(beginAttr) : null;
    begin ??= tokens.isNotEmpty ? tokens.first.start : null;
    if (begin == null) {
      continue;
    }
    final endAttr = paragraph.getAttribute('end');
    parsedParagraphs.add((
      begin: begin,
      end: endAttr != null ? parseTtmlTime(endAttr) : null,
      text: _normalizeWhitespace(_elementText(paragraph)).trim(),
      tokens: tokens,
    ));
  }

  // Dart's sort is unstable, so ties are broken deterministically:
  // paragraphs with per-word spans are the originals and come first, plain
  // paragraphs sharing the begin are translations and follow them, then by
  // written order.
  final order = List<int>.generate(parsedParagraphs.length, (i) => i);
  order.sort((a, b) {
    final cmp = parsedParagraphs[a].begin.compareTo(parsedParagraphs[b].begin);
    if (cmp != 0) return cmp;
    final wordA = parsedParagraphs[a].tokens.length > 1;
    final wordB = parsedParagraphs[b].tokens.length > 1;
    if (wordA != wordB) return wordA ? -1 : 1;
    return a.compareTo(b);
  });

  for (final i in order) {
    final paragraph = parsedParagraphs[i];
    if (paragraph.text.isEmpty) {
      continue;
    }

    final lastLyric = result.lines.isNotEmpty ? result.lines.last : null;
    final isTranslate = lastLyric?.start == paragraph.begin;

    if (!isTranslate && lastLyric?.tokens.last.end == null) {
      lastLyric?.tokens.last.end = paragraph.begin;
    }

    var tokens = paragraph.tokens;
    if (tokens.isEmpty) {
      tokens = [LyricToken(paragraph.begin, paragraph.text, paragraph.end)];
    }
    for (var j = 1; j < tokens.length; j++) {
      if (tokens[j - 1].end == null) {
        tokens[j - 1].end = tokens[j].start;
      }
    }
    if (tokens.last.end == null) {
      tokens.last.end = paragraph.end;
    }
    if (tokens.length > 1) {
      result.isKaraoke = true;
    }

    if (isTranslate) {
      lastLyric!.translates.add(paragraph.text);
    } else {
      result.lines.add(LyricLine(paragraph.begin, paragraph.text, tokens));
    }
  }

  if (result.lines.isEmpty) {
    result.lines.add(LyricLine(Duration.zero, parseFailedMessage, []));
  } else {
    if (result.lines.last.tokens.last.end == null) {
      result.lines.last.tokens.last.end = songDuration;
    }
  }
}
