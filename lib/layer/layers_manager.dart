import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/data/artist_album.dart';
import 'package:sylvakru/base/data/folder.dart';
import 'package:sylvakru/base/services/metadata_service.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/utils/dynamic_datail_route.dart';
import 'package:sylvakru/base/utils/media_query.dart';
import 'package:sylvakru/base/widgets/cover_art_widget.dart';
import 'package:sylvakru/base/data/history.dart';
import 'package:sylvakru/landscape_view/sidebar.dart';
import 'package:sylvakru/layer/about_layer.dart';
import 'package:sylvakru/layer/albums_layer.dart';
import 'package:sylvakru/layer/artists_layer.dart';
import 'package:sylvakru/layer/folders_layer.dart';
import 'package:sylvakru/layer/font_picker_layer.dart';
import 'package:sylvakru/layer/license_layer.dart';
import 'package:sylvakru/layer/playlists_layer.dart';
import 'package:sylvakru/layer/ranking_layer.dart';
import 'package:sylvakru/layer/recently_layer.dart';
import 'package:sylvakru/layer/settings_layer.dart';
import 'package:sylvakru/layer/single_album_layer.dart';
import 'package:sylvakru/layer/single_artist_layer.dart';
import 'package:sylvakru/layer/single_folder_layer.dart';
import 'package:sylvakru/layer/single_playlist_layer.dart';
import 'package:sylvakru/layer/songs_layer.dart';
import 'package:sylvakru/base/data/library.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/data/playlist.dart';
import 'package:sylvakru/base/utils/metadata_utils.dart';
import 'package:sylvakru/portrait_view/portrait_view.dart';

final layersManager = LayersManager();
MyAudioMetadata? backgroundSong;

class LayerInfo {
  MyAudioMetadata? backgroundSong;
  Color backgroundCoverArtColor;
  final changeNotifier = ValueNotifier(0);
  LayerInfo(this.backgroundSong, this.backgroundCoverArtColor);
}

class LayersManager {
  final Map<Widget, LayerInfo> layerInfoMap = {};

  // lable -> rootLayer
  final Map<String, Widget> rootLayerMap = {};
  // rootLayer -> rootPage
  final Map<Widget, Widget> rootPageMap = {};

  // root -> detail
  final Map<Widget, Widget?> detailWidgetMap = {};
  final Map<Widget, Widget> parentWidgetMap = {};

  Widget? topRootLayer;
  Widget? bottomRootLayer;

  Widget? topRootPage;
  Widget? bottomRootPage;

  final backgroundChangeNotifier = ValueNotifier(0);
  final switchNotifier = ValueNotifier(0);

  Widget createPage(Widget layer) {
    final layerInfo = layerInfoMap.putIfAbsent(
      layer,
      () => LayerInfo(null, Colors.grey),
    );
    return Stack(
      key: GlobalKey(),
      fit: .expand,
      children: [
        ValueListenableBuilder(
          valueListenable: mainPageThemeNotifier,
          builder: (context, value, child) {
            if (value != .vivid) {
              return SizedBox.shrink();
            }
            return ValueListenableBuilder(
              valueListenable: layerInfo.changeNotifier,
              builder: (context, value, child) {
                return CoverArtWidget(
                  song: layerInfo.backgroundSong,
                  color: layerInfo.backgroundCoverArtColor,
                );
              },
            );
          },
        ),
        ValueListenableBuilder(
          valueListenable: mainPageThemeNotifier,
          builder: (context, value, child) {
            if (value != .vivid) {
              return SizedBox.shrink();
            }

            // ClipRect is important
            return ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: ValueListenableBuilder(
                  valueListenable: layerInfo.changeNotifier,
                  builder: (context, value, child) {
                    return Container(
                      color: layerInfo.backgroundCoverArtColor.withAlpha(180),
                    );
                  },
                ),
              ),
            );
          },
        ),
        ValueListenableBuilder(
          valueListenable: pageBackgroundColor.valueNotifier,
          builder: (context, value, child) {
            return Material(color: value, child: layer);
          },
        ),
      ],
    );
  }

  Widget getRootLayer(String label) {
    return rootLayerMap.putIfAbsent(label, () {
      if (label == 'artists') {
        return ArtistsLayer(key: GlobalKey());
      } else if (label == 'albums') {
        return AlbumsLayer(key: GlobalKey());
      } else if (label == 'folders') {
        return FoldersLayer(key: GlobalKey());
      } else if (label == 'songs') {
        return SongsLayer(key: GlobalKey());
      } else if (label == 'ranking') {
        return RankingLayer(key: GlobalKey());
      } else if (label == 'recently') {
        return RecentlyLayer(key: GlobalKey());
      } else if (label == 'playlists') {
        return PlaylistsLayer(key: GlobalKey());
      } else if (label == 'settings') {
        return SettingsLayer(key: GlobalKey());
      } else {
        return SinglePlaylistLayer(
          key: GlobalKey(),
          playlist: playlistManager.getPlaylistByName(label.substring(1))!,
          isRoot: true,
        );
      }
    });
  }

  void switchRootLayer(String label) {
    Widget layer = getRootLayer(label);
    if (layer == topRootLayer) {
      return;
    }

    bottomRootLayer = topRootLayer;
    topRootLayer = layer;
    if (isMobile) {
      bottomRootPage = topRootPage;
      topRootPage = rootPageMap.putIfAbsent(
        topRootLayer!,
        () => createPage(topRootLayer!),
      );
    }

    sidebarHighlighLabel.value = label;
    switchNotifier.value++;
    updateBackground();
  }

  void removeLayerIfNeed(dynamic target) async {
    if (target is Playlist) {
      String key = '_${target.name}';
      final rootLayer = getRootLayer('playlists');
      if ((detailWidgetMap[rootLayer] as SinglePlaylistLayer?)?.playlist ==
          target) {
        popDetail('playlists');
      }
      final removedLayer = rootLayerMap.remove(key);
      if (removedLayer == topRootLayer) {
        switchRootLayer('songs');
      }
      // prevent black screen appear
      await Future.delayed(Duration(milliseconds: 500));
      rootPageMap.remove(removedLayer);
    } else if (target is Artist) {
      final rootLayer = getRootLayer('artists');
      if ((detailWidgetMap[rootLayer] as SingleArtistLayer?)?.artist ==
          target) {
        popDetail('artists');
      }
    } else if (target is Album) {
      final rootLayer = getRootLayer('albums');
      if ((detailWidgetMap[rootLayer] as SingleAlbumLayer?)?.album == target) {
        popDetail('albums');
      }
    } else if (target is Folder) {
      final rootLayer = getRootLayer('folders');
      if ((detailWidgetMap[rootLayer] as SingleFolderLayer?)?.folder ==
          target) {
        popDetail('folders');
      }
    } else {
      assert(false);
    }
  }

  void pushDetail(String label, dynamic detail) async {
    final rootLayer = getRootLayer(label);

    late GlobalKey<NavigatorState> rootKey;
    late ValueNotifier<bool> visibleNotifier;
    late Widget detailLayer;
    if (label == 'artists') {
      rootKey = artistsKey;
      visibleNotifier = artistsVisibleNotifier;
      detailLayer = SingleArtistLayer(artist: detail);
    } else if (label == 'albums') {
      rootKey = albumsKey;
      visibleNotifier = albumsVisibleNotifier;
      detailLayer = SingleAlbumLayer(album: detail);
    } else if (label == 'folders') {
      rootKey = foldersKey;
      visibleNotifier = foldersVisibleNotifier;
      detailLayer = SingleFolderLayer(folder: detail);
    } else if (label == 'playlists') {
      rootKey = playlistsKey;
      visibleNotifier = playlistsVisibleNotifier;
      detailLayer = SinglePlaylistLayer(playlist: detail, isRoot: false);
    } else {
      rootKey = settingsKey;
      visibleNotifier = settingsVisibleNotifier;
      if (detail == 'about') {
        detailLayer = AboutLayer();
      } else if (detail == 'license') {
        visibleNotifier = aboutVisibleNotifier;
        detailLayer = LicenseLayer();
        parentWidgetMap[detailLayer] = detailWidgetMap[rootLayer]!;
      } else {
        detailLayer = FontPickerLayer();
      }
    }

    detailWidgetMap[rootLayer] = detailLayer;

    await layersManager.updateBackground();

    final detailPage = createPage(detailLayer);
    rootKey.currentState?.push(
      DynamicDatailRoute(
        pageBuilder: (context, animation, secondaryAnimation) {
          if (isMobile && isPortrait(context)) {
            if (Platform.isAndroid) {
              return detailPage;
            }
            bool draging = false;
            final dragDxNotifier = ValueNotifier(0.0);

            return GestureDetector(
              onHorizontalDragUpdate: (details) {
                draging = true;

                dragDxNotifier.value += details.delta.dx;
                if (dragDxNotifier.value < 0) {
                  dragDxNotifier.value = 0;
                }
              },
              onHorizontalDragEnd: (details) async {
                final velocity = (details.primaryVelocity ?? 0);
                final bool isOverThreshold =
                    dragDxNotifier.value / MediaQuery.widthOf(context) > 0.5;

                if (dragDxNotifier.value == 0 && velocity < -500) {
                  portraitKey.currentState?.openEndDrawer();
                }

                if (velocity > 500 || isOverThreshold) {
                  layersManager.popDetail(label);
                } else {
                  draging = false;
                  dragDxNotifier.value = 0;
                }
              },
              child: ValueListenableBuilder(
                valueListenable: dragDxNotifier,
                builder: (context, value, child) {
                  return AnimatedContainer(
                    duration: Duration(milliseconds: draging ? 0 : 250),
                    curve: Curves.easeOutCubic,
                    transform: .translationValues(value, 0, 0),
                    child: detailPage,
                  );
                },
              ),
            );
          }
          return detailLayer;
        },
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      visibleNotifier.value = false;
    });
  }

  Future<bool> popDetail(String label) async {
    final rootLayer = getRootLayer(label);
    if (detailWidgetMap[rootLayer] == null) {
      return false;
    }

    final detailLayer = detailWidgetMap.remove(rootLayer);

    late GlobalKey<NavigatorState> rootKey;
    late ValueNotifier<bool> visibleNotifier;
    if (label == 'artists') {
      rootKey = artistsKey;
      visibleNotifier = artistsVisibleNotifier;
    } else if (label == 'albums') {
      rootKey = albumsKey;
      visibleNotifier = albumsVisibleNotifier;
    } else if (label == 'folders') {
      rootKey = foldersKey;
      visibleNotifier = foldersVisibleNotifier;
    } else if (label == 'playlists') {
      rootKey = playlistsKey;
      visibleNotifier = playlistsVisibleNotifier;
    } else {
      rootKey = settingsKey;
      visibleNotifier = settingsVisibleNotifier;
      if (detailLayer is LicenseLayer) {
        detailWidgetMap[rootLayer] = parentWidgetMap.remove(detailLayer);
        visibleNotifier = aboutVisibleNotifier;
      }
    }

    await layersManager.updateBackground();

    rootKey.currentState?.pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      visibleNotifier.value = true;
    });

    return true;
  }

  void pushDetailIfNeed(dynamic detail) async {
    if (detail is Artist) {
      if ((detailWidgetMap[getRootLayer('artists')] as SingleArtistLayer?)
              ?.artist !=
          detail) {
        await Future.delayed(Duration(milliseconds: 300));
        popDetail('artists');
        await Future.delayed(Duration(milliseconds: 300));
        pushDetail('artists', detail);
      }
    } else {
      if ((detailWidgetMap[getRootLayer('albums')] as SingleAlbumLayer?)
              ?.album !=
          detail) {
        await Future.delayed(Duration(milliseconds: 300));
        popDetail('albums');
        await Future.delayed(Duration(milliseconds: 300));
        pushDetail('albums', detail);
      }
    }
  }

  MyAudioMetadata? _getBackgroundSong(Widget layer) {
    if (layer is SingleArtistLayer) {
      return layer.artist.getCoverSong();
    } else if (layer is SingleAlbumLayer) {
      return layer.album.getCoverSong();
    } else if (layer is SingleFolderLayer) {
      final songList = layer.folder.songList;
      return getFirstSong(songList);
    } else if (layer is SongsLayer) {
      return getFirstSong(library.songListManager.getSongList());
    } else if (layer is RankingLayer) {
      return getFirstSong(history.rankingSongListManager.getSongList());
    } else if (layer is RecentlyLayer) {
      return getFirstSong(history.recentlySongListManager.getSongList());
    } else if (layer is SinglePlaylistLayer) {
      return layer.playlist.getCoverSong();
    } else {
      return currentSongNotifier.value;
    }
  }

  Future<void> updateBackground() async {
    if (topRootLayer == null) {
      return;
    }

    Widget displayLayer = topRootLayer!;

    if (detailWidgetMap[topRootLayer] != null) {
      displayLayer = detailWidgetMap[topRootLayer]!;
    }

    backgroundSong = _getBackgroundSong(displayLayer);
    backgroundCoverArtColor = await computeCoverArtColor(backgroundSong);

    final layerInfo = layerInfoMap.putIfAbsent(
      displayLayer,
      () => LayerInfo(backgroundSong, backgroundCoverArtColor),
    );
    if (layerInfo.backgroundSong != backgroundSong ||
        layerInfo.backgroundCoverArtColor != backgroundCoverArtColor) {
      layerInfo.backgroundSong = backgroundSong;
      layerInfo.backgroundCoverArtColor = backgroundCoverArtColor;
      layerInfo.changeNotifier.value++;
    }

    if (mainPageThemeNotifier.value == .vivid) {
      searchFieldColor.updateColor();
      buttonColor.updateColor();
      dividerColor.updateColor();
      selectedItemColor.updateColor();
      backgroundChangeNotifier.value++;
    }
  }
}
