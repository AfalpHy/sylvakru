import 'package:flutter/material.dart';
import 'package:sylvakru/base/data/artist_album.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/landscape_view/panels/single_artist_panel.dart';
import 'package:sylvakru/portrait_view/pages/single_artist_page.dart';

class SingleArtistLayer extends StatelessWidget {
  final Artist artist;
  const SingleArtistLayer({super.key, required this.artist});

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (isMobile && orientation == Orientation.portrait) {
          return SingleArtistPage(artist: artist);
        } else {
          return SingleArtistPanel(artist: artist);
        }
      },
    );
  }
}
