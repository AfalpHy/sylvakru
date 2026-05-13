import 'package:flutter/material.dart';
import 'package:particle_music/base/data/artist_album.dart';
import 'package:particle_music/base/widgets/switchable_song_list.dart';

class SingleArtistPage extends StatelessWidget {
  final Artist artist;
  const SingleArtistPage({super.key, required this.artist});
  @override
  Widget build(BuildContext context) {
    return SwitchableSongList(
      songListManager: artist.songListManager,
      artist: artist,
      isPanel: false,
    );
  }
}
