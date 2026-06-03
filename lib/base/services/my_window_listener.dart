import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sylvakru/base/services/exit.dart';
import 'package:sylvakru/base/data/setting.dart';
import 'package:sylvakru/mini_view/mini_view.dart';
import 'package:window_manager/window_manager.dart';

ValueNotifier<bool> isMaximizedNotifier = ValueNotifier(false);
ValueNotifier<bool> isFullScreenNotifier = ValueNotifier(false);

class MyWindowListener extends WindowListener {
  @override
  void onWindowMaximize() {
    isMaximizedNotifier.value = true;
  }

  @override
  void onWindowUnmaximize() {
    isMaximizedNotifier.value = false;
  }

  @override
  void onWindowClose() {
    if (exitOnCloseNotifier.value) {
      exitApp();
    } else {
      windowManager.hide();
    }
  }

  @override
  void onWindowResized() async {
    if (miniModeNotifier.value) {
      final size = await windowManager.getSize();
      final gap =
          size.height - (Platform.isWindows ? 9 : 0) - miniViewMainHeight;

      if (gap > 0 && gap < 120) {
        await Future.delayed(Duration(milliseconds: 100));
        if (Platform.isWindows) {
          await windowManager.setSize(Size(size.width, miniViewMainHeight + 9));
        } else {
          await windowManager.setSize(Size(size.width, miniViewMainHeight));
        }
      }
      miniModeHideOverlayTimer = Timer(const Duration(milliseconds: 1000), () {
        miniModeDisplayOverlayNotifier.value = false;
      });
    }
  }
}
