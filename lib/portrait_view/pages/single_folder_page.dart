import 'package:flutter/material.dart';
import 'package:sylvakru/base/data/folder.dart';
import 'package:sylvakru/portrait_view/pages/song_list_page.dart';

class SingleFolderPage extends StatelessWidget {
  final Folder folder;
  const SingleFolderPage({super.key, required this.folder});
  @override
  Widget build(BuildContext context) {
    return SongListPage(folder: folder);
  }
}
