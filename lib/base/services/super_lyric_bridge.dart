import 'dart:io';

import 'package:flutter/services.dart';

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

    try {
      await _channel.invokeMethod<void>('sendLyric', {'lyric': text});
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
