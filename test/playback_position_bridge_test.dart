import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sylvakru/base/services/playback_position_bridge.dart';
import 'package:sylvakru/base/services/usb_audio_service.dart';

void main() {
  test('USB 真独占 active 时位置流使用独占播放位置', () async {
    final playerPositions = StreamController<Duration>.broadcast();
    var playerPosition = Duration.zero;
    final exclusiveState = ValueNotifier(UsbExclusivePlaybackState.inactive());
    final bridge = PlaybackPositionBridge(
      playerPositionStream: playerPositions.stream,
      playerPosition: () => playerPosition,
      exclusiveStateListenable: exclusiveState,
    );

    addTearDown(() async {
      bridge.dispose();
      exclusiveState.dispose();
      await playerPositions.close();
    });

    final emitted = <Duration>[];
    final subscription = bridge.stream.listen(emitted.add);
    addTearDown(subscription.cancel);

    playerPosition = const Duration(seconds: 2);
    playerPositions.add(playerPosition);
    await pumpEventQueue();

    exclusiveState.value = const UsbExclusivePlaybackState(
      active: true,
      playing: true,
      position: Duration(seconds: 42),
      duration: Duration(minutes: 3),
      sampleRate: 96000,
      bitDepth: 24,
      format: 'flac',
      message: 'Playing.',
    );
    await pumpEventQueue();

    playerPosition = const Duration(seconds: 3);
    playerPositions.add(playerPosition);
    await pumpEventQueue();

    expect(emitted, [const Duration(seconds: 2), const Duration(seconds: 42)]);
    expect(bridge.position, const Duration(seconds: 42));
  });
}
