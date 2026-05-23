import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/data/artist_album.dart';
import 'package:sylvakru/base/data/folder.dart';
import 'package:sylvakru/base/services/metadata_service.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/widgets/cover_art_widget.dart';
import 'package:sylvakru/base/data/history.dart';
import 'package:sylvakru/landscape_view/sidebar.dart';
import 'package:sylvakru/layer/artists_albums_layer.dart';
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

final layersManager = LayersManager();
MyAudioMetadata? backgroundSong;

class LayerInfo {
  MyAudioMetadata? backgroundSong;
  Color backgroundCoverArtColor;
  final changeNotifier = ValueNotifier(0);
  LayerInfo(this.backgroundSong, this.backgroundCoverArtColor);
}

enum SwitchType { push, pop, afterPop }

class LayersManager {
  final Map<String, Widget> layerMap = {};
  final Map<Widget, LayerInfo> layerInfoMap = {};
  final Map<Widget, Widget> pageMap = {};

  final List<Widget> layerHistory = [];
  final List<String> labelHistory = [];

  Widget? currentLayer;
  Widget? helperLayer;

  Widget? currentPage;
  Widget? helperPage;

  final backgroundChangeNotifier = ValueNotifier(0);
  final switchNotifier = ValueNotifier(0);
  late SwitchType switchType;

  Widget getPage(Widget layer) {
    return pageMap.putIfAbsent(layer, () {
      final layerInfo = layerInfoMap.putIfAbsent(
        layer,
        () => LayerInfo(null, Colors.grey),
      );
      return Stack(
        key: GlobalKey(),

        children: [
          ValueListenableBuilder(
            valueListenable: layerInfo.changeNotifier,
            builder: (context, value, child) {
              return ValueListenableBuilder(
                valueListenable: mainPageThemeNotifier,
                builder: (context, value, child) {
                  if (value != .vivid) {
                    return SizedBox();
                  }
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      CoverArtWidget(
                        song: layerInfo.backgroundSong,
                        color: layerInfo.backgroundCoverArtColor,
                      ),

                      ClipRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                          child: Container(
                            color: layerInfo.backgroundCoverArtColor.withAlpha(
                              180,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
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
    });
  }

  Widget getLayer(String label, {String? content}) {
    final keyValue = label + (content ?? '');
    return layerMap.putIfAbsent(keyValue, () {
      if (content == null) {
        if (label == 'artists') {
          return ArtistsAlbumsLayer(key: GlobalKey(), isArtist: true);
        } else if (label == 'albums') {
          return ArtistsAlbumsLayer(key: GlobalKey(), isArtist: false);
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
        } else if (label == 'license') {
          return LicenseLayer(key: GlobalKey());
        } else if (label == 'font_picker') {
          return FontPickerLayer(key: GlobalKey());
        }
        return SinglePlaylistLayer(
          key: GlobalKey(),
          playlist: playlistManager.getPlaylistByName(label.substring(1))!,
        );
      }
      if (label == 'artists') {
        return SingleArtistLayer(
          key: GlobalKey(),
          artist: artistAlbumManager.name2Artist[content]!,
        );
      } else if (label == 'albums') {
        return SingleAlbumLayer(
          key: GlobalKey(),
          album: artistAlbumManager.name2Album[content]!,
        );
      }
      return SingleFolderLayer(
        key: GlobalKey(),
        folder: library.getFolderById(content)!,
      );
    });
  }

  void pushLayer(String label, {String? content}) {
    Widget layer = getLayer(label, content: content);
    if (layer == currentLayer) {
      return;
    }

    switchType = .push;

    helperLayer = currentLayer;
    currentLayer = layer;
    if (isMobile) {
      helperPage = currentPage;
      currentPage = getPage(currentLayer!);
    }

    layerHistory.add(currentLayer!);
    labelHistory.add(label);

    sidebarHighlighLabel.value = label;
    switchNotifier.value++;
    updateBackground();
  }

  void popLayer() {
    if (layerHistory.length == 1) {
      return;
    }
    switchType = .pop;

    layerHistory.removeLast();
    labelHistory.removeLast();
    helperLayer = currentLayer;
    currentLayer = layerHistory.last;
    if (isMobile) {
      helperPage = currentPage;
      currentPage = pageMap[currentLayer];
    }
    sidebarHighlighLabel.value = labelHistory.last;
    switchNotifier.value++;

    updateBackground();
  }

  void afterPopLayer() {
    switchType = .afterPop;

    if (layerHistory.length >= 2) {
      helperLayer = layerHistory[layerHistory.length - 2];
      helperPage = pageMap[helperLayer];
    } else {
      helperLayer = null;
      helperPage = null;
    }
    switchNotifier.value++;
  }

  void removeLayer(dynamic target) async {
    late String key;
    if (target is Playlist) {
      key = '_${target.name}';
    } else if (target is Artist) {
      key = 'artists${target.name}';
    } else if (target is Album) {
      key = 'albums${target.name}';
    } else if (target is Folder) {
      key = 'folders${target.id}';
    } else {
      assert(false);
    }
    final layer = layerMap.remove(key);
    if (layer == currentLayer) {
      popLayer();
    }

    // ensure pop complete
    await Future.delayed(Duration(milliseconds: 500));

    if (isMobile) {
      pageMap.remove(layer);
    }
    for (int i = layerHistory.length - 1; i >= 0; i--) {
      if (layerHistory[i] == layer) {
        layerHistory.removeAt(i);
        labelHistory.removeAt(i);
      }
    }
  }

  void clear() {
    layerHistory.clear();
    labelHistory.clear();
    layerMap.clear();
    pageMap.clear();
    currentLayer = null;
    helperLayer = null;
    currentPage = null;
    helperPage = null;
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

  void updateBackground() async {
    if (currentLayer == null) {
      return;
    }

    backgroundSong = _getBackgroundSong(currentLayer!);
    backgroundCoverArtColor = await computeCoverArtColor(backgroundSong);

    final layerInfo = layerInfoMap.putIfAbsent(
      currentLayer!,
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
