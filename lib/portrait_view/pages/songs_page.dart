import 'package:flutter/material.dart';
import 'package:particle_music/base/widgets/switchable_song_list.dart';
import 'package:particle_music/base/data/library.dart';

class SongsPage extends StatelessWidget {
  const SongsPage({super.key});

  @override
  Widget build(BuildContext _) {
    return SwitchableSongList(
      songListManager: library.songListManager,
      isPanel: false,
    );
  }
}
