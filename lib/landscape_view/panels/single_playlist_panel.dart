import 'package:flutter/material.dart';
import 'package:particle_music/base/widgets/switchable_song_list.dart';
import 'package:particle_music/base/data/playlist.dart';

class SinglePlaylistPanel extends StatelessWidget {
  final Playlist playlist;

  const SinglePlaylistPanel({super.key, required this.playlist});

  @override
  Widget build(BuildContext context) {
    return SwitchableSongList(
      songListManager: playlist.songListManager,
      playlist: playlist,
      isPanel: true,
    );
  }
}
