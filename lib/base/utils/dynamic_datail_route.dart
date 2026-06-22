import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/utils/media_query.dart';

class DynamicDatailRoute extends PageRouteBuilder {
  DynamicDatailRoute({required super.pageBuilder});

  @override
  Duration get transitionDuration =>
      Duration(milliseconds: isMobile ? 400 : 500);

  @override
  Duration get reverseTransitionDuration =>
      Duration(milliseconds: isMobile ? 400 : 500);

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
    if (isMobile && isPortrait(context)) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: Offset(Platform.isIOS ? 1.0 : -1.0, 0.0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    }
    return child;
  }
}
