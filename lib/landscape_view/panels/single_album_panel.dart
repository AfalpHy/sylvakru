import 'package:flutter/material.dart';
import 'package:sylvakru/base/data/artist_album.dart';
import 'package:sylvakru/base/widgets/switchable_song_list.dart';

class SingleAlbumPanel extends StatelessWidget {
  final Album album;
  const SingleAlbumPanel({super.key, required this.album});

  @override
  Widget build(BuildContext context) {
    return SwitchableSongList(
      songListManager: album.songListManager,
      album: album,
      isPanel: true,
    );
  }
}
