import 'package:flutter/material.dart';
import 'package:particle_music/base/widgets/switchable_song_list.dart';
import 'package:particle_music/base/data/history.dart';

class RecentlyPanel extends StatelessWidget {
  const RecentlyPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return SwitchableSongList(
      songListManager: history.recentlySongListManager,
      isRecently: true,
      isPanel: true,
    );
  }
}
