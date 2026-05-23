import 'package:flutter/material.dart';
import 'package:sylvakru/base/data/artist_album.dart';
import 'package:sylvakru/base/widgets/switchable_song_list.dart';

class SingleArtistPanel extends StatelessWidget {
  final Artist artist;
  const SingleArtistPanel({super.key, required this.artist});

  @override
  Widget build(BuildContext context) {
    return SwitchableSongList(
      songListManager: artist.songListManager,
      artist: artist,
      isPanel: true,
    );
  }
}
