import 'package:flutter/services.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/services/my_window_listener.dart';
import 'package:sylvakru/layer/lyrics_page_layer.dart';
import 'package:window_manager/window_manager.dart';

bool isTyping = false;

bool shiftIsPressed = false;
bool ctrlIsPressed = false;

void keyboardInit() {
  HardwareKeyboard.instance.addHandler((event) {
    if (event is KeyDownEvent) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.shiftLeft:
        case LogicalKeyboardKey.shiftRight:
          shiftIsPressed = true;
          break;
        case LogicalKeyboardKey.controlLeft:
        case LogicalKeyboardKey.controlRight:
          ctrlIsPressed = true;
          break;
        case LogicalKeyboardKey.space:
          if (!isTyping && playQueue.isNotEmpty) {
            audioHandler.togglePlay();
          }
          break;
        case LogicalKeyboardKey.escape:
          if (displayLyricsPage && isFullScreenNotifier.value) {
            windowManager.setFullScreen(false);
            isFullScreenNotifier.value = false;
          }
          break;
        case LogicalKeyboardKey.f11:
          if (displayLyricsPage && !isMaximizedNotifier.value) {
            windowManager.setFullScreen(true);
            isFullScreenNotifier.value = true;
          }
          break;
      }
    } else if (event is KeyUpEvent) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.shiftLeft:
        case LogicalKeyboardKey.shiftRight:
          shiftIsPressed = false;
          break;
        case LogicalKeyboardKey.controlLeft:
        case LogicalKeyboardKey.controlRight:
          ctrlIsPressed = false;
          break;
      }
    }
    return false;
  });
}
