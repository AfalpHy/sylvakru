import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sylvakru/base/app.dart';

class DynamicDatailRoute extends PageRouteBuilder {
  DynamicDatailRoute({required super.pageBuilder});

  @override
  Duration get transitionDuration => Duration(milliseconds: 400);

  @override
  Duration get reverseTransitionDuration => Duration(milliseconds: 400);

  @override
  bool get opaque => false;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeInOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );
    return OrientationBuilder(
      builder: (context, orientation) {
        if (isMobile && orientation == Orientation.portrait) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: Offset(Platform.isIOS ? 1.0 : -1.0, 0.0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          );
        } else {
          return child;
        }
      },
    );
  }
}
