import 'package:flutter/material.dart';
import 'package:sylvakru/base/widgets/switchable_song_list.dart';
import 'package:sylvakru/base/data/library.dart';

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
