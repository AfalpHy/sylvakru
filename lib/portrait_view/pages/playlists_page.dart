import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/base/widgets/cover_art_widget.dart';
import 'package:particle_music/base/data/playlist.dart';
import 'package:particle_music/layer/layers_manager.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/portrait_view/custom_appbar_leading.dart';

class PlaylistsPage extends StatelessWidget {
  const PlaylistsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: customAppBarLeading(context),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(l10n.playlists),
        centerTitle: true,
      ),
      body: ValueListenableBuilder(
        valueListenable: playlistManager.updateNotifier,
        builder: (context, _, _) {
          return ListView.builder(
            itemCount: playlistManager.playlists.length + 1,
            itemBuilder: (_, index) {
              if (index == playlistManager.playlists.length) {
                return SizedBox(height: 70);
              }
              final playlist = playlistManager.getPlaylistByIndex(index);
              return ListTile(
                contentPadding: EdgeInsets.fromLTRB(20, 0, 20, 0),
                visualDensity: const VisualDensity(horizontal: 0, vertical: -1),

                leading: ValueListenableBuilder(
                  valueListenable: playlist.changeNotifier,
                  builder: (_, _, _) {
                    return ValueListenableBuilder(
                      valueListenable:
                          playlist.songListManager.sourceTypeNotifier,
                      builder: (context, value, child) {
                        return CoverArtWidget(
                          size: 50,
                          borderRadius: 5,
                          song: playlist.getCoverSong(),
                        );
                      },
                    );
                  },
                ),
                title: AutoSizeText(
                  index == 0 ? l10n.favorites : playlist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  minFontSize: 15,
                  maxFontSize: 15,
                ),
                subtitle: ValueListenableBuilder(
                  valueListenable: playlist.changeNotifier,
                  builder: (_, _, _) {
                    return Text(l10n.songCount(playlist.totalCount));
                  },
                ),
                onTap: () {
                  layersManager.pushLayer('_${playlist.name}');
                },
              );
            },
          );
        },
      ),
    );
  }
}
