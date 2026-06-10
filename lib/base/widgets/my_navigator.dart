import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sylvakru/base/app.dart';

final canFocusNavigatorNotifier = ValueNotifier(true);

Widget myNavigator({
  required Key key,
  required ValueNotifier visibleNotifier,
  required Widget pageView,
  required Widget panelView,
}) {
  return ValueListenableBuilder(
    valueListenable: canFocusNavigatorNotifier,
    builder: (context, value, child) {
      return FocusScope(canRequestFocus: value, child: child!);
    },
    child: Navigator(
      key: key,
      observers: [HeroController()],
      pages: [
        if (Platform.isAndroid) MaterialPage(child: SizedBox.shrink()),
        MaterialPage(
          child: OrientationBuilder(
            builder: (context, orientation) {
              if (isMobile && orientation == Orientation.portrait) {
                return pageView;
              } else {
                return ValueListenableBuilder(
                  valueListenable: visibleNotifier,
                  builder: (context, value, child) {
                    return Opacity(opacity: value ? 1 : 0, child: panelView);
                  },
                );
              }
            },
          ),
        ),
      ],
      onDidRemovePage: (page) {},
    ),
  );
}
