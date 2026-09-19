import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/widgets/song_list.dart';

class RecentlyLayer extends StatelessWidget {
  const RecentlyLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return SongList(isRecently: true);
  }
}
