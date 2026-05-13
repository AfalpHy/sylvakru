import 'package:flutter/material.dart';
import 'package:particle_music/base/app.dart';
import 'package:particle_music/base/data/artist_album.dart';
import 'package:particle_music/base/data/song_list_manager.dart';
import 'package:particle_music/base/utils/interaction.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/landscape_view/panels/song_list_panel.dart';
import 'package:particle_music/base/data/playlist.dart';
import 'package:particle_music/layer/layers_manager.dart';
import 'package:particle_music/portrait_view/pages/song_list_page.dart';

class SwitchableSongList extends StatelessWidget {
  final Playlist? playlist;
  final Artist? artist;
  final Album? album;
  final bool isRanking;
  final bool isRecently;

  final SongListManager songListManager;
  final bool isPanel;

  const SwitchableSongList({
    super.key,
    this.playlist,
    this.artist,
    this.album,
    this.isRanking = false,
    this.isRecently = false,

    required this.songListManager,
    required this.isPanel,
  });

  void switchCallBack(BuildContext context) {
    showAnimationDialog(
      context: context,
      child: SizedBox(
        width: 300,
        height: 300,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: ListView(
            children: [
              if (songListManager.localSongList.isNotEmpty)
                ListTile(
                  title: Text(AppLocalizations.of(context).local),
                  onTap: () {
                    songListManager.sourceTypeNotifier.value = .local;
                    layersManager.updateBackground();
                    Navigator.pop(context);
                  },
                  trailing: songListManager.sourceTypeNotifier.value == .local
                      ? Icon(Icons.check)
                      : null,
                ),
              if (songListManager.webdavSongList.isNotEmpty)
                ListTile(
                  title: Text('WebDAV'),
                  onTap: () {
                    songListManager.sourceTypeNotifier.value = .webdav;
                    layersManager.updateBackground();
                    Navigator.pop(context);
                  },
                  trailing: songListManager.sourceTypeNotifier.value == .webdav
                      ? Icon(Icons.check)
                      : null,
                ),
              if (songListManager.navidromeSongList.isNotEmpty)
                ListTile(
                  title: Text('Navidrome'),
                  onTap: () {
                    songListManager.sourceTypeNotifier.value = .navidrome;
                    layersManager.updateBackground();
                    Navigator.pop(context);
                  },
                  trailing:
                      songListManager.sourceTypeNotifier.value == .navidrome
                      ? Icon(Icons.check)
                      : null,
                ),
              if (songListManager.embySongList.isNotEmpty)
                ListTile(
                  title: Text('Emby'),
                  onTap: () {
                    songListManager.sourceTypeNotifier.value = .emby;
                    layersManager.updateBackground();
                    Navigator.pop(context);
                  },
                  trailing: songListManager.sourceTypeNotifier.value == .emby
                      ? Icon(Icons.check)
                      : null,
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: songListManager.sourceTypeNotifier,
      builder: (context, value, child) {
        return Stack(
          children: [
            if (songListManager.localSongList.isNotEmpty ||
                songListManager.isEmpty)
              Visibility(
                visible: value == .local,
                maintainState: true,
                child: isPanel ? panel(.local) : page(.local),
              ),

            if (songListManager.webdavSongList.isNotEmpty)
              Visibility(
                visible: value == .webdav,
                maintainState: true,
                child: isPanel ? panel(.webdav) : page(.webdav),
              ),

            if (songListManager.navidromeSongList.isNotEmpty)
              Visibility(
                visible: value == .navidrome,
                maintainState: true,
                child: isPanel ? panel(.navidrome) : page(.navidrome),
              ),

            if (songListManager.embySongList.isNotEmpty)
              Visibility(
                visible: value == .emby,
                maintainState: true,
                child: isPanel ? panel(.emby) : page(.emby),
              ),
          ],
        );
      },
    );
  }

  Widget panel(SourceType sourceType) {
    return SongListPanel(
      playlist: playlist,
      artist: artist,
      album: album,
      isRanking: isRanking,
      isRecently: isRecently,
      sourceType: sourceType,
      switchCallBack: songListManager.notEmptyCount >= 2
          ? switchCallBack
          : null,
    );
  }

  Widget page(SourceType sourceType) {
    return SongListPage(
      playlist: playlist,
      artist: artist,
      album: album,
      isRanking: isRanking,
      isRecently: isRecently,
      sourceType: sourceType,
      switchCallBack: songListManager.notEmptyCount >= 2
          ? switchCallBack
          : null,
    );
  }
}
