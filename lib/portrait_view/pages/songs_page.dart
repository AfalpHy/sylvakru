import 'package:flutter/material.dart';
import 'package:sylvakru/base/widgets/switchable_song_list.dart';
import 'package:sylvakru/base/data/library.dart';

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
