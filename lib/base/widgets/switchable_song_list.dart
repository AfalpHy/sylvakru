import 'package:flutter/material.dart';
import 'package:particle_music/base/app.dart';
import 'package:particle_music/base/data/artist_album.dart';
import 'package:particle_music/base/data/song_list_manager.dart';
import 'package:particle_music/base/services/interaction.dart';
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

  final sources = [
    SourceType.local,
    SourceType.webdav,
    SourceType.navidrome,
    SourceType.emby,
  ];

  SwitchableSongList({
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
          child: Builder(
            builder: (context) {
              return ListView(
                children: [
                  if (songListManager.localSongList.isNotEmpty)
                    ListTile(
                      title: Text(AppLocalizations.of(context).local),
                      onTap: () async {
                        Navigator.pop(context);
                        await Future.delayed(Duration(milliseconds: 250));
                        songListManager.sourceTypeNotifier.value = .local;
                        layersManager.updateBackground();
                      },
                      trailing:
                          songListManager.sourceTypeNotifier.value == .local
                          ? Icon(Icons.check)
                          : null,
                    ),
                  if (songListManager.webdavSongList.isNotEmpty)
                    ListTile(
                      title: Text('WebDAV'),
                      onTap: () async {
                        Navigator.pop(context);
                        await Future.delayed(Duration(milliseconds: 250));
                        songListManager.sourceTypeNotifier.value = .webdav;
                        layersManager.updateBackground();
                      },
                      trailing:
                          songListManager.sourceTypeNotifier.value == .webdav
                          ? Icon(Icons.check)
                          : null,
                    ),
                  if (songListManager.navidromeSongList.isNotEmpty)
                    ListTile(
                      title: Text('Navidrome'),
                      onTap: () async {
                        Navigator.pop(context);
                        await Future.delayed(Duration(milliseconds: 250));
                        songListManager.sourceTypeNotifier.value = .navidrome;
                        layersManager.updateBackground();
                      },
                      trailing:
                          songListManager.sourceTypeNotifier.value == .navidrome
                          ? Icon(Icons.check)
                          : null,
                    ),
                  if (songListManager.embySongList.isNotEmpty)
                    ListTile(
                      title: Text('Emby'),
                      onTap: () async {
                        Navigator.pop(context);
                        await Future.delayed(Duration(milliseconds: 250));
                        songListManager.sourceTypeNotifier.value = .emby;
                        layersManager.updateBackground();
                      },
                      trailing:
                          songListManager.sourceTypeNotifier.value == .emby
                          ? Icon(Icons.check)
                          : null,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: songListManager.changeNotifier,
      builder: (context, value, child) {
        final sourceType = songListManager.sourceTypeNotifier.value;

        final index = sources.indexOf(sourceType);

        return IndexedStack(
          index: index,
          children: sources.map((source) {
            return isPanel ? panel(source) : page(source);
          }).toList(),
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
      switchCallBack: switchCallBack,
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
      switchCallBack: switchCallBack,
    );
  }
}
