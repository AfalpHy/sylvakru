import 'package:flutter/material.dart';
import 'package:sylvakru/base/widgets/switchable_song_list.dart';
import 'package:sylvakru/base/data/playlist.dart';

class SinglePlaylistPage extends StatelessWidget {
  final Playlist playlist;
  const SinglePlaylistPage({super.key, required this.playlist});
  @override
  Widget build(BuildContext context) {
    return SwitchableSongList(
      songListManager: playlist.songListManager,
      playlist: playlist,
      isPanel: false,
    );
  }
}
