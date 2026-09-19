import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/data/history.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';

import 'package:sylvakru/big_picture_view/panels/big_song_list_base_panel.dart';

class BigRankingPanel extends StatelessWidget {
  const BigRankingPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return _BigRankingSongListPanel();
  }
}

class _BigRankingSongListPanel extends BigSongListBasePanel {
  const _BigRankingSongListPanel();

  @override
  State<StatefulWidget> createState() => _BigRankingSongListPanelState();
}

class _BigRankingSongListPanelState extends BigSongListBasePanelState {
  @override
  List<MyAudioMetadata> get songList => history.rankingSongList;

  @override
  bool get isRanking => true;
}
