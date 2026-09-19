import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/data/artist_album.dart';
import 'package:sylvakru/base/widgets/song_list.dart';

class SingleAlbumLayer extends StatelessWidget {
  final Album album;
  final bool isHomeDetaile;
  const SingleAlbumLayer({
    super.key,
    required this.album,
    this.isHomeDetaile = false,
  });

  @override
  Widget build(BuildContext context) {
    return SongList(album: album, isRoot: false, isHomeDetail: isHomeDetaile);
  }
}
