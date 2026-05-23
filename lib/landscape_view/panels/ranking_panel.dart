import 'package:flutter/material.dart';
import 'package:sylvakru/base/widgets/switchable_song_list.dart';
import 'package:sylvakru/base/data/history.dart';

class RankingPanel extends StatelessWidget {
  const RankingPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return SwitchableSongList(
      songListManager: history.rankingSongListManager,
      isRanking: true,
      isPanel: true,
    );
  }
}
