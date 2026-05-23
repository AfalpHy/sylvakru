import 'package:flutter/material.dart';
import 'package:sylvakru/base/widgets/switchable_song_list.dart';
import 'package:sylvakru/base/data/history.dart';

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
