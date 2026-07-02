import 'package:sylvakru/base/services/lyric.dart';

class SuperLyricPositionPublisher {
  final Future<void> Function(LyricLine line) sendLyricLine;
  final Future<void> Function() sendStop;

  List<LyricLine> _lines = const [];
  int? _lastPublishedIndex;

  SuperLyricPositionPublisher({
    required this.sendLyricLine,
    required this.sendStop,
  });

  void updateLines(List<LyricLine> lines) {
    _lines = lines;
    reset();
  }

  void reset() {
    _lastPublishedIndex = null;
  }

  Future<void> publishAt(Duration position) async {
    if (position < Duration.zero) {
      return;
    }

    final currentIndex = _currentIndexAt(position);
    if (currentIndex == _lastPublishedIndex) {
      return;
    }

    _lastPublishedIndex = currentIndex;
    if (currentIndex >= 0 && currentIndex < _lines.length) {
      await sendLyricLine(_lines[currentIndex]);
    } else {
      await sendStop();
    }
  }

  int _currentIndexAt(Duration position) {
    var current = -1;

    for (var i = 0; i < _lines.length; i++) {
      final line = _lines[i];
      if (position < line.start) {
        break;
      }
      if (current == -1 || line.start > _lines[current].start) {
        current = i;
      }
    }

    return current;
  }
}
