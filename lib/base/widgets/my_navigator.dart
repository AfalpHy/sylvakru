import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/utils/media_query.dart';

final canFocusNavigatorNotifier = ValueNotifier(true);

Widget myNavigator({
  required Key key,
  required ValueNotifier visibleNotifier,
  required Widget Function() pageViewBuilder,
  required Widget Function() panelViewBuilder,
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
          child: Builder(
            builder: (context) {
              return isMobile && isPortrait(context)
                  ? pageViewBuilder()
                  : ValueListenableBuilder(
                      valueListenable: visibleNotifier,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value ? 1 : 0,
                          child: panelViewBuilder(),
                        );
                      },
                    );
            },
          ),
        ),
      ],
      onDidRemovePage: (page) {},
    ),
  );
}
