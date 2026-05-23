import 'package:flutter/material.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/landscape_view/panels/single_playlist_panel.dart';
import 'package:sylvakru/base/data/playlist.dart';
import 'package:sylvakru/portrait_view/pages/single_playlist_page.dart';

class SinglePlaylistLayer extends StatelessWidget {
  final Playlist playlist;

  const SinglePlaylistLayer({super.key, required this.playlist});

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (isMobile && orientation == Orientation.portrait) {
          return SinglePlaylistPage(playlist: playlist);
        } else {
          return SinglePlaylistPanel(playlist: playlist);
        }
      },
    );
  }
}
