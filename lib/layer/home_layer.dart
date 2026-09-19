import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/data/artist_album.dart';
import 'package:sylvakru/base/data/history.dart';
import 'package:sylvakru/base/data/playlist.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/utils/media_query.dart';
import 'package:sylvakru/base/utils/metadata_utils.dart';
import 'package:sylvakru/base/widgets/cover_art_widget.dart';
import 'package:sylvakru/base/widgets/my_navigator.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/landscape_view/title_bar.dart';
import 'package:sylvakru/layer/layers_manager.dart';
import 'package:sylvakru/portrait_view/custom_appbar_leading.dart';

part '../landscape_view/panels/home_panel.dart';
part '../portrait_view/pages/home_page.dart';

final GlobalKey<NavigatorState> homeKey = GlobalKey();
final homeVisibleNotifier = ValueNotifier(true);

class HomeLayer extends StatelessWidget {
  const HomeLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return myNavigator(
      key: homeKey,
      visibleNotifier: homeVisibleNotifier,
      pageViewBuilder: () => pageView(context),
      panelViewBuilder: () => panelView(context),
    );
  }

  Widget content(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ListView(
      children: [
        Row(
          mainAxisSize: .min,
          children: [
            SizedBox(width: 20),
            GestureDetector(
              onTap: () {
                layersManager.switchRootLayer('albums');
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Row(
                  children: [
                    Text(
                      l10n.albums,
                      style: .new(fontWeight: .bold, fontSize: 20),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 10),

        SizedBox(
          height: 180,
          child: ValueListenableBuilder(
            valueListenable: artistAlbumManager.updateNotifier,
            builder: (context, value, child) {
              return ListView.separated(
                scrollDirection: .horizontal,
                itemCount: artistAlbumManager.albumList.length + 1,
                separatorBuilder: (context, index) {
                  return SizedBox(width: 15);
                },
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return SizedBox(width: 5);
                  }
                  index--;
                  final album = artistAlbumManager.albumList[index];
                  return Column(
                    children: [
                      GestureDetector(
                        onTap: () {
                          layersManager.pushDetail('home', album);
                        },
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Hero(
                            tag: '${album.picture.id}home${album.name}',
                            child: CoverArtWidget(
                              size: 150,
                              borderRadius: 15,
                              picture: album.picture,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 5),
                      SizedBox(
                        width: 140,
                        child: Text(
                          album.name,
                          style: .new(overflow: .ellipsis, fontSize: 15),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),

        SizedBox(height: 15),

        Row(
          mainAxisSize: .min,
          children: [
            SizedBox(width: 20),
            GestureDetector(
              onTap: () {
                layersManager.switchRootLayer('ranking');
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Row(
                  children: [
                    Text(
                      l10n.ranking,
                      style: .new(fontWeight: .bold, fontSize: 20),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 10),

        ValueListenableBuilder(
          valueListenable: history.rankingChangeNotifier,
          builder: (context, value, child) {
            return songListView(history.rankingSongList);
          },
        ),

        SizedBox(height: 15),

        Row(
          mainAxisSize: .min,
          children: [
            SizedBox(width: 20),
            GestureDetector(
              onTap: () {
                layersManager.switchRootLayer('recently');
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Row(
                  children: [
                    Text(
                      l10n.recently,
                      style: .new(fontWeight: .bold, fontSize: 20),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 10),

        ValueListenableBuilder(
          valueListenable: history.recentlyChangeNotifier,
          builder: (context, value, child) {
            return songListView(history.recentlySongList);
          },
        ),

        SizedBox(height: 15),

        Row(
          mainAxisSize: .min,
          children: [
            SizedBox(width: 20),
            GestureDetector(
              onTap: () {
                layersManager.switchRootLayer('playlists');
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Row(
                  children: [
                    Text(
                      l10n.playlists,
                      style: .new(fontWeight: .bold, fontSize: 20),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 10),

        SizedBox(
          height: 180,
          child: ValueListenableBuilder(
            valueListenable: playlistManager.updateNotifier,
            builder: (context, value, child) {
              return ListView.separated(
                scrollDirection: .horizontal,
                itemCount: playlistManager.playlists.length + 1,
                separatorBuilder: (context, index) {
                  return SizedBox(width: 15);
                },
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return SizedBox(width: 5);
                  }
                  index--;
                  final playlist = playlistManager.playlists[index];
                  return ValueListenableBuilder(
                    valueListenable: playlist.changeNotifier,
                    builder: (context, value, child) {
                      return Column(
                        children: [
                          GestureDetector(
                            onTap: () {
                              layersManager.pushDetail('home', playlist);
                            },
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Hero(
                                tag:
                                    '${playlist.picture?.id ?? ''}home${playlist.isFavorite ? l10n.favorites : playlist.name}',
                                child: CoverArtWidget(
                                  size: 150,
                                  borderRadius: 15,
                                  picture: playlist.picture,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 5),
                          SizedBox(
                            width: 140,
                            child: Text(
                              playlist.name,
                              style: .new(overflow: .ellipsis, fontSize: 15),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
        SizedBox(height: 15),

        if (isTooNarrow(context)) SizedBox(height: 60),
      ],
    );
  }

  Widget songListView(List<MyAudioMetadata> songList) {
    return SizedBox(
      height: 180,
      child: MouseRegion(
        child: ListView.builder(
          padding: .zero,
          scrollDirection: .horizontal,
          itemCount: songList.length ~/ 3 + 2,
          itemBuilder: (context, index) {
            if (index == 0) {
              return SizedBox(width: 15);
            }
            index -= 1;
            return SizedBox(
              width: 300,
              child: Column(
                mainAxisSize: .min,
                children: List.generate(min(3, songList.length - index * 3), (
                  j,
                ) {
                  final song = songList[index * 3 + j];
                  return InkWell(
                    onTap: isMobile
                        ? () {
                            audioHandler.setPlayQueue(
                              songList,
                              0,
                              targetIndex: index * 3 + j,
                            );
                          }
                        : null,
                    onDoubleTap: isMobile
                        ? null
                        : () {
                            audioHandler.setPlayQueue(
                              songList,
                              0,
                              targetIndex: index * 3 + j,
                            );
                          },
                    customBorder: SmoothRectangleBorder(
                      smoothness: 1,
                      borderRadius: .circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          SizedBox(width: 5),
                          CoverArtWidget(
                            size: 50,
                            borderRadius: 5,
                            picture: song.picture,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: .start,
                              children: [
                                Text(
                                  getTitle(song),
                                  style: .new(
                                    fontSize: 15,
                                    overflow: .ellipsis,
                                  ),
                                ),
                                Text(
                                  '${getArtist(song)} - ${getAlbum(song)}',
                                  style: .new(
                                    fontSize: 12,
                                    overflow: .ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isMobile)
                            IconButton(
                              onPressed: () {},
                              icon: Icon(Icons.more_vert_rounded),
                            )
                          else
                            SizedBox(width: 10),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            );
          },
        ),
      ),
    );
  }
}
