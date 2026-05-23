import 'package:flutter/material.dart';
import 'package:sylvakru/base/widgets/switchable_song_list.dart';
import 'package:sylvakru/base/data/history.dart';

class RankingPage extends StatelessWidget {
  const RankingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SwitchableSongList(
      songListManager: history.rankingSongListManager,
      isRanking: true,
      isPanel: false,
    );
  }
}
