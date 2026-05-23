import 'package:flutter/material.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/landscape_view/panels/recently_panel.dart';
import 'package:sylvakru/portrait_view/pages/recently_page.dart';

class RecentlyLayer extends StatelessWidget {
  const RecentlyLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (isMobile && orientation == Orientation.portrait) {
          return RecentlyPage();
        } else {
          return RecentlyPanel();
        }
      },
    );
  }
}
