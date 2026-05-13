import 'package:flutter/material.dart';
import 'package:particle_music/base/widgets/switchable_song_list.dart';
import 'package:particle_music/base/data/library.dart';

class SongsPanel extends StatelessWidget {
  const SongsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return SwitchableSongList(
      songListManager: library.songListManager,
      isPanel: true,
    );
  }
}
