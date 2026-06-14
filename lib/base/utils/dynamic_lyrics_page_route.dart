import 'package:flutter/material.dart';
import 'package:sylvakru/base/app.dart';

class DynamicLyricsPageRoute<T> extends PageRouteBuilder<T> {
  DynamicLyricsPageRoute({required super.pageBuilder}) : super(opaque: false);

  @override
  Duration get transitionDuration => const Duration(milliseconds: 500);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 500);

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
              begin: Offset(0, 1),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          );
        } else {
          return FadeTransition(opacity: curved, child: child);
        }
      },
    );
  }
}
