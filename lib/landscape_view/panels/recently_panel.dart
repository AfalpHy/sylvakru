import 'package:flutter/material.dart';
import 'package:sylvakru/base/widgets/switchable_song_list.dart';
import 'package:sylvakru/base/data/history.dart';

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
