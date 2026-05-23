import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/data/artist_album.dart';
import 'package:sylvakru/base/data/song_list_manager.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/widgets/cover_art_widget.dart';
import 'package:sylvakru/base/data/folder.dart';
import 'package:sylvakru/base/data/history.dart';
import 'package:sylvakru/base/data/library.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/data/playlist.dart';
import 'package:sylvakru/base/utils/metadata_utils.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';

abstract class BaseSongListWidget extends StatefulWidget {
  final Playlist? playlist;
  final Artist? artist;
  final Album? album;
  final Folder? folder;
  final bool isRanking;
  final bool isRecently;

  final SourceType sourceType;

  final Function(BuildContext)? switchCallBack;

  const BaseSongListWidget({
    super.key,
    this.playlist,
    this.artist,
    this.album,
    this.folder,
    this.isRanking = false,
    this.isRecently = false,
    this.sourceType = .local,
    this.switchCallBack,
  });
}

abstract class BaseSongListState<T extends BaseSongListWidget>
    extends State<T> {
  late String title;
  late SongListManager songListManager;
  late List<MyAudioMetadata> songList;
  Playlist? playlist;
  Artist? artist;
  Album? album;
  Folder? folder;

  bool isLibrary = false;
  bool isRanking = false;
  bool isRecently = false;

  bool reorderable = false;

  late SourceType sourceType;

  Timer? timer;

  final ValueNotifier<List<MyAudioMetadata>> currentSongListNotifier =
      ValueNotifier([]);

  final listIsScrollingNotifier = ValueNotifier(false);
  final scrollController = ScrollController();
  final TextEditingController textController = TextEditingController();

  ValueNotifier<int> sortTypeNotifier = ValueNotifier(0);

  String getTitleText(AppLocalizations l10n) {
    return isLibrary
        ? l10n.songs
        : playlist?.isFavorite == true
        ? l10n.favorites
        : isRanking
        ? l10n.ranking
        : isRecently
        ? l10n.recently
        : title;
  }

  void updateSongList() {
    final value = textController.text;
    final filteredSongList = filterSongList(songList, value);
    sortSongList(sortTypeNotifier.value, filteredSongList);
    currentSongListNotifier.value = filteredSongList;
  }

  @override
  void initState() {
    super.initState();

    playlist = widget.playlist;
    artist = widget.artist;
    album = widget.album;
    folder = widget.folder;
    isRanking = widget.isRanking;
    isRecently = widget.isRecently;

    sourceType = widget.sourceType;

    if (playlist != null) {
      title = playlist!.name;
      songListManager = playlist!.songListManager;
      reorderable = true;
    } else if (artist != null) {
      title = artist!.name;
      songListManager = artist!.songListManager;
    } else if (album != null) {
      title = album!.name;
      songListManager = album!.songListManager;
    } else if (folder != null) {
      title = folder!.id;
      reorderable = true;
    } else if (isRanking) {
      songListManager = history.rankingSongListManager;
    } else if (isRecently) {
      songListManager = history.recentlySongListManager;
    } else {
      isLibrary = true;
      songListManager = library.songListManager;
      reorderable = sourceType == .local || sourceType == .webdav;
    }
    if (folder == null) {
      songList = songListManager.getSongList2(sourceType);
      sortTypeNotifier = songListManager.getSortTypeNotifier2(sourceType);
      songListManager
          .getChangeNotifier2(sourceType)
          .addListener(updateSongList);
    } else {
      songList = folder!.songList;
      sortTypeNotifier = folder!.sortTypeNotifier;
      folder!.changeNotifier.addListener(updateSongList);
    }
    updateSongList();
    sortTypeNotifier.addListener(updateSongList);
    textController.addListener(updateSongList);
  }

  @override
  void dispose() {
    if (folder == null) {
      songListManager
          .getChangeNotifier2(sourceType)
          .removeListener(updateSongList);
    } else {
      folder!.changeNotifier.removeListener(updateSongList);
    }

    sortTypeNotifier.removeListener(updateSongList);
    textController.removeListener(updateSongList);
    scrollController.dispose();
    timer?.cancel();
    super.dispose();
  }

  Widget mainCover(double size) {
    return ValueListenableBuilder(
      valueListenable: currentSongListNotifier,
      builder: (_, _, _) {
        if (songList.isEmpty) {
          return CoverArtWidget(
            size: size,
            borderRadius: 10,
            song: null,
            elevation: 5,
            color: colorManager.getSpecificMainPageCoverArtBaseColorForm(null),
          );
        }
        final song = songList.first;
        return ValueListenableBuilder(
          valueListenable: song.updateNotifier,
          builder: (_, _, _) {
            return ValueListenableBuilder(
              valueListenable: mainPageThemeNotifier,
              builder: (_, _, _) {
                return CoverArtWidget(
                  size: size,
                  borderRadius: 10,
                  song: song,
                  elevation: 5,
                  color: colorManager.getSpecificMainPageCoverArtBaseColorForm(
                    song,
                  ), // keep stable color
                );
              },
            );
          },
        );
      },
    );
  }
}
