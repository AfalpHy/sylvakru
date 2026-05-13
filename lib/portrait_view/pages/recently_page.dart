import 'package:flutter/material.dart';
import 'package:particle_music/base/widgets/switchable_song_list.dart';
import 'package:particle_music/base/data/history.dart';

class RecentlyPage extends StatelessWidget {
  const RecentlyPage({super.key});
  @override
  Widget build(BuildContext context) {
    return SwitchableSongList(
      songListManager: history.recentlySongListManager,
      isRecently: true,
      isPanel: false,
    );
  }
}
