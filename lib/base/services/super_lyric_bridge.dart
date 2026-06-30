import 'dart:io';

import 'package:flutter/services.dart';
import 'package:sylvakru/base/services/lyric.dart';

class SuperLyricBridge {
  static const MethodChannel _defaultChannel = MethodChannel(
    'com.afalphy.sylvakru/super_lyric',
  );

  static MethodChannel _channel = _defaultChannel;
  static bool _isAndroid = Platform.isAndroid;
  static String? _lastLyric;
  static bool _hasSentStop = false;

  SuperLyricBridge._();

  static Future<void> sendLyric(String lyric) async {
    final text = lyric.trim();
    if (_shouldStopForLyric(text)) {
      await sendStop();
      return;
    }

    if (text == _lastLyric) {
      return;
    }

    _lastLyric = text;
    _hasSentStop = false;
    if (!_isAndroid) {
      return;
    }

    await _invokeSendLyric({'lyric': text});
  }

  static Future<void> sendLyricLine(LyricLine line) async {
    final text = line.text.trim();
    if (_shouldStopForLyric(text)) {
      await sendStop();
      return;
    }

    final arguments = _lineToArguments(line, text);
    final dedupeKey = arguments.toString();
    if (dedupeKey == _lastLyric) {
      return;
    }

    _lastLyric = dedupeKey;
    _hasSentStop = false;
    if (!_isAndroid) {
      return;
    }

    await _invokeSendLyric(arguments);
  }

  static Future<void> _invokeSendLyric(Map<String, Object?> arguments) async {
    try {
      await _channel.invokeMethod<void>('sendLyric', arguments);
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }

  static Future<void> sendStop() async {
    if (_hasSentStop) {
      return;
    }

    _lastLyric = null;
    _hasSentStop = true;
    if (!_isAndroid) {
      return;
    }

    try {
      await _channel.invokeMethod<void>('sendStop');
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }

  static bool _shouldStopForLyric(String lyric) {
    return lyric.isEmpty ||
        lyric == 'There are no lyrics' ||
        lyric == 'Lyrics parsing failed';
  }

  static Map<String, Object?> _lineToArguments(LyricLine line, String text) {
    return {
      'lyric': text,
      'startTime': line.start.inMilliseconds,
      'endTime': _lineEnd(line)?.inMilliseconds,
      'tokens': line.tokens
          .where((token) => token.text.isNotEmpty && token.end != null)
          .map(
            (token) => {
              'text': token.text,
              'startTime': token.start.inMilliseconds,
              'endTime': token.end!.inMilliseconds,
            },
          )
          .toList(growable: false),
    };
  }

  static Duration? _lineEnd(LyricLine line) {
    if (line.tokens.isEmpty) {
      return null;
    }
    return line.tokens.last.end;
  }

  static void configureForTest({
    required MethodChannel channel,
    required bool isAndroid,
  }) {
    _channel = channel;
    _isAndroid = isAndroid;
    _lastLyric = null;
    _hasSentStop = false;
  }

  static void resetForTest() {
    _channel = _defaultChannel;
    _isAndroid = Platform.isAndroid;
    _lastLyric = null;
    _hasSentStop = false;
  }
}
