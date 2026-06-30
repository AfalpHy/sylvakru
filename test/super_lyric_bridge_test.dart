import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sylvakru/base/services/lyric.dart';
import 'package:sylvakru/base/services/super_lyric_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.afalphy.sylvakru/super_lyric');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    SuperLyricBridge.resetForTest();
  });

  test('sendLyric sends non-empty lyric and skips duplicates', () async {
    final calls = <MethodCall>[];
    SuperLyricBridge.configureForTest(channel: channel, isAndroid: true);

    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });

    await SuperLyricBridge.sendLyric('first line');
    await SuperLyricBridge.sendLyric('first line');
    await SuperLyricBridge.sendLyric('second line');

    expect(calls, hasLength(2));
    expect(calls[0].method, 'sendLyric');
    expect(calls[0].arguments, {'lyric': 'first line'});
    expect(calls[1].arguments, {'lyric': 'second line'});
  });

  test('sendLyricLine sends line timing and word timing tokens', () async {
    final calls = <MethodCall>[];
    SuperLyricBridge.configureForTest(channel: channel, isAndroid: true);

    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });

    await SuperLyricBridge.sendLyricLine(
      LyricLine(const Duration(seconds: 10), 'hello world', [
        LyricToken(
          const Duration(seconds: 10),
          'hello ',
          const Duration(milliseconds: 10400),
        ),
        LyricToken(
          const Duration(milliseconds: 10400),
          'world',
          const Duration(seconds: 11),
        ),
      ]),
    );

    expect(calls, hasLength(1));
    expect(calls.single.method, 'sendLyric');
    expect(calls.single.arguments, {
      'lyric': 'hello world',
      'startTime': 10000,
      'endTime': 11000,
      'tokens': [
        {'text': 'hello ', 'startTime': 10000, 'endTime': 10400},
        {'text': 'world', 'startTime': 10400, 'endTime': 11000},
      ],
    });
  });

  test('sendLyric sends stop for blank or placeholder lyrics', () async {
    final calls = <MethodCall>[];
    SuperLyricBridge.configureForTest(channel: channel, isAndroid: true);

    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });

    await SuperLyricBridge.sendLyric('   ');
    await SuperLyricBridge.sendLyric('There are no lyrics');
    await SuperLyricBridge.sendLyric('Lyrics parsing failed');

    expect(calls.map((call) => call.method), ['sendStop']);
  });

  test('sendStop clears last sent lyric and skips duplicate stop', () async {
    final calls = <MethodCall>[];
    SuperLyricBridge.configureForTest(channel: channel, isAndroid: true);

    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });

    await SuperLyricBridge.sendLyric('one line');
    await SuperLyricBridge.sendStop();
    await SuperLyricBridge.sendStop();
    await SuperLyricBridge.sendLyric('one line');

    expect(calls.map((call) => call.method), [
      'sendLyric',
      'sendStop',
      'sendLyric',
    ]);
  });
}
