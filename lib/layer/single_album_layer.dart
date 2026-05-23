import 'package:flutter/material.dart';
import 'package:sylvakru/base/data/artist_album.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/landscape_view/panels/single_album_panel.dart';
import 'package:sylvakru/portrait_view/pages/single_album_page.dart';

class SingleAlbumLayer extends StatelessWidget {
  final Album album;
  const SingleAlbumLayer({super.key, required this.album});

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (isMobile && orientation == Orientation.portrait) {
          return SingleAlbumPage(album: album);
        } else {
          return SingleAlbumPanel(album: album);
        }
      },
    );
  }
}
