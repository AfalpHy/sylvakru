import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/widgets/song_list.dart';

class RankingLayer extends StatelessWidget {
  const RankingLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return SongList(isRanking: true);
  }
}
