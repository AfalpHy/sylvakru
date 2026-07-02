import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sylvakru/base/services/usb_audio_service.dart';

class PlaybackPositionBridge {
  final Duration Function() _playerPosition;
  final ValueListenable<UsbExclusivePlaybackState> _exclusiveStateListenable;
  final _controller = StreamController<Duration>.broadcast();
  late final StreamSubscription<Duration> _playerPositionSubscription;
  late final VoidCallback _exclusiveStateListener;

  Duration _exclusivePosition = Duration.zero;
  bool _exclusiveActive = false;
  bool _disposed = false;

  PlaybackPositionBridge({
    required Stream<Duration> playerPositionStream,
    required Duration Function() playerPosition,
    required ValueListenable<UsbExclusivePlaybackState>
    exclusiveStateListenable,
  }) : _playerPosition = playerPosition,
       _exclusiveStateListenable = exclusiveStateListenable {
    _exclusiveStateListener = _handleExclusiveState;
    _exclusiveStateListenable.addListener(_exclusiveStateListener);
    _handleExclusiveState();

    _playerPositionSubscription = playerPositionStream.listen((position) {
      if (!_exclusiveActive) {
        _emit(position);
      }
    });
  }

  Stream<Duration> get stream => _controller.stream;

  Duration get position =>
      _exclusiveActive ? _exclusivePosition : _playerPosition();

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _exclusiveStateListenable.removeListener(_exclusiveStateListener);
    unawaited(_playerPositionSubscription.cancel());
    unawaited(_controller.close());
  }

  void _handleExclusiveState() {
    final state = _exclusiveStateListenable.value;
    _exclusiveActive = state.active;
    if (state.active) {
      _exclusivePosition = state.position;
      _emit(state.position);
    }
  }

  void _emit(Duration position) {
    if (!_disposed && !_controller.isClosed) {
      _controller.add(position);
    }
  }
}
