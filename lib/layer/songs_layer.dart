import 'package:flutter/material.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/landscape_view/panels/songs_panel.dart';
import 'package:sylvakru/portrait_view/pages/songs_page.dart';

class SongsLayer extends StatelessWidget {
  const SongsLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (isMobile && orientation == Orientation.portrait) {
          return SongsPage();
        } else {
          return SongsPanel();
        }
      },
    );
  }
}
