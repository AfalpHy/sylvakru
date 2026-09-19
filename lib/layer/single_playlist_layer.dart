import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/widgets/song_list.dart';
import 'package:sylvakru/base/data/playlist.dart';

class SinglePlaylistLayer extends StatelessWidget {
  final Playlist playlist;
  final bool isRoot;
  final bool isHomeDetaile;

  const SinglePlaylistLayer({
    super.key,
    required this.playlist,
    required this.isRoot,
    this.isHomeDetaile = false,
  });

  @override
  Widget build(BuildContext context) {
    return SongList(
      playlist: playlist,
      isRoot: isRoot,
      isHomeDetail: isHomeDetaile,
    );
  }
}
