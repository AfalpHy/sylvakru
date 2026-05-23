import 'package:flutter/material.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/landscape_view/panels/playlists_panel.dart';
import 'package:sylvakru/portrait_view/pages/playlists_page.dart';

class PlaylistsLayer extends StatelessWidget {
  const PlaylistsLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (isMobile && orientation == Orientation.portrait) {
          return PlaylistsPage();
        } else {
          return PlaylistsPanel();
        }
      },
    );
  }
}
