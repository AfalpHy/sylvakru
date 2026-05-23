import 'package:flutter/material.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/data/artist_album.dart';
import 'package:sylvakru/base/data/song_list_manager.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/base/utils/source_type.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/landscape_view/panels/song_list_panel.dart';
import 'package:sylvakru/base/data/playlist.dart';
import 'package:sylvakru/layer/layers_manager.dart';
import 'package:sylvakru/portrait_view/pages/song_list_page.dart';

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
        height: isMobile ? 240 : 220,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Builder(
            builder: (context) {
              return ListView(
                children: [
                  for (final sourceType in SourceType.values)
                    if (songListManager.getSongList2(sourceType).isNotEmpty)
                      ListTile(
                        leading: Image(
                          image: getSourceTypeImage(sourceType),
                          height: 30,
                          width: 30,
                        ),
                        title: Text(
                          getSourceTypeName(
                            AppLocalizations.of(context),
                            sourceType,
                          ),
                        ),
                        onTap: () async {
                          Navigator.pop(context);
                          await Future.delayed(Duration(milliseconds: 250));
                          songListManager.sourceTypeNotifier.value = sourceType;
                          layersManager.updateBackground();
                        },
                        trailing:
                            songListManager.sourceTypeNotifier.value ==
                                sourceType
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
      valueListenable: songListManager.sourceTypeNotifier,
      builder: (context, sourceType, child) {
        return Stack(
          children: [
            if (songListManager.localSongList.isNotEmpty ||
                songListManager.isEmpty)
              Visibility(
                key: ValueKey('local'),
                visible: sourceType == .local,
                maintainState: true,
                child: isPanel ? panel(.local) : page(.local),
              ),

            if (songListManager.webdavSongList.isNotEmpty)
              Visibility(
                key: ValueKey('webdav'),
                visible: sourceType == .webdav,
                maintainState: true,
                child: isPanel ? panel(.webdav) : page(.webdav),
              ),

            if (songListManager.navidromeSongList.isNotEmpty)
              Visibility(
                key: ValueKey('navidrome'),
                visible: sourceType == .navidrome,
                maintainState: true,
                child: isPanel ? panel(.navidrome) : page(.navidrome),
              ),

            if (songListManager.embySongList.isNotEmpty)
              Visibility(
                key: ValueKey('emby'),
                visible: sourceType == .emby,
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
