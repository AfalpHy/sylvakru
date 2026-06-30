import 'package:flutter_test/flutter_test.dart';
import 'package:sylvakru/base/services/lyric.dart';
import 'package:sylvakru/base/services/super_lyric_position_publisher.dart';

void main() {
  test('publishes lyric lines as playback position advances', () async {
    final events = <String>[];
    final publisher = SuperLyricPositionPublisher(
      sendLyricLine: (line) async => events.add('lyric:${line.text}'),
      sendStop: () async => events.add('stop'),
    );

    publisher.updateLines([
      LyricLine(const Duration(seconds: 1), 'first', const []),
      LyricLine(const Duration(seconds: 3), 'second', const []),
    ]);

    await publisher.publishAt(const Duration(milliseconds: 500));
    await publisher.publishAt(const Duration(seconds: 1));
    await publisher.publishAt(const Duration(seconds: 2));
    await publisher.publishAt(const Duration(seconds: 3));

    expect(events, ['stop', 'lyric:first', 'lyric:second']);
  });

  test(
    'reset makes the current lyric publish again after a song change',
    () async {
      final events = <String>[];
      final publisher = SuperLyricPositionPublisher(
        sendLyricLine: (line) async => events.add(line.text),
        sendStop: () async {},
      );

      publisher.updateLines([
        LyricLine(Duration.zero, 'same visible text', const []),
      ]);
      await publisher.publishAt(Duration.zero);

      publisher.updateLines([
        LyricLine(Duration.zero, 'same visible text', const []),
      ]);
      await publisher.publishAt(Duration.zero);

      expect(events, ['same visible text', 'same visible text']);
    },
  );

  test(
    'reset makes the current lyric publish again after pause stop',
    () async {
      final events = <String>[];
      final publisher = SuperLyricPositionPublisher(
        sendLyricLine: (line) async => events.add(line.text),
        sendStop: () async {},
      );

      publisher.updateLines([
        LyricLine(Duration.zero, 'current line', const []),
      ]);
      await publisher.publishAt(Duration.zero);

      publisher.reset();
      await publisher.publishAt(Duration.zero);

      expect(events, ['current line', 'current line']);
    },
  );
}
