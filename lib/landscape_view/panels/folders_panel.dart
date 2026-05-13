import 'package:flutter/material.dart';
import 'package:particle_music/base/data/folder.dart';
import 'package:particle_music/base/utils/color_manager.dart';
import 'package:particle_music/base/asset_images.dart';
import 'package:particle_music/base/widgets/cover_art_widget.dart';
import 'package:particle_music/base/widgets/my_divider.dart';
import 'package:particle_music/landscape_view/title_bar.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/layer/layers_manager.dart';
import 'package:particle_music/base/data/library.dart';
import 'package:particle_music/base/utils/metadata.dart';
import 'package:smooth_corner/smooth_corner.dart';

class FoldersPanel extends StatelessWidget {
  const FoldersPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TitleBar(),
        Expanded(child: contentWidget(context)),
      ],
    );
  }

  Widget contentWidget(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Focus(
              child: ListTile(
                leading: ValueListenableBuilder(
                  valueListenable: iconColor.valueNotifier,
                  builder: (_, value, _) {
                    return ImageIcon(folderImage, size: 50, color: value);
                  },
                ),
                title: Text(
                  l10n.folders,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  l10n.folderCount(
                    library.localFolderList.length +
                        library.webdavFolderList.length,
                  ),
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: MyDivider(
            thickness: 0.5,
            height: 0.5,
            indent: 30,
            endIndent: 30,
            color: dividerColor,
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: 15)),

        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 40),

          sliver: SliverList.builder(
            itemCount:
                library.localFolderList.length +
                library.webdavFolderList.length,
            itemBuilder: (_, index) {
              late Folder folder;
              if (index < library.localFolderList.length) {
                folder = library.localFolderList[index];
              } else {
                folder = library
                    .webdavFolderList[index - library.localFolderList.length];
              }
              return ValueListenableBuilder(
                valueListenable: folder.updateNotifier,
                builder: (context, value, child) {
                  final displaySong = getFirstSong(folder.songList);
                  return SizedBox(
                    height: 64,
                    child: InkWell(
                      customBorder: SmoothRectangleBorder(
                        smoothness: 1,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      mouseCursor: SystemMouseCursors.click,
                      child: Row(
                        children: [
                          SizedBox(width: 20),
                          displaySong == null
                              ? CoverArtWidget(
                                  size: 50,
                                  borderRadius: 5,
                                  song: null,
                                )
                              : ValueListenableBuilder(
                                  valueListenable: displaySong.updateNotifier,
                                  builder: (_, _, _) {
                                    return CoverArtWidget(
                                      size: 50,
                                      borderRadius: 5,
                                      song: displaySong,
                                    );
                                  },
                                ),
                          SizedBox(width: 10),

                          Expanded(
                            child: Text(
                              folder.id,
                              style: TextStyle(overflow: .ellipsis),
                            ),
                          ),
                        ],
                      ),
                      onTap: () {
                        layersManager.pushLayer('folders', content: folder.id);
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
