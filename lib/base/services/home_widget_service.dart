import 'dart:io';
import 'dart:typed_data';

import 'package:home_widget/home_widget.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/data/playlist.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/services/logger.dart';
import 'package:sylvakru/base/services/picture_service.dart';
import 'package:sylvakru/base/utils/common_utils.dart';
import 'package:sylvakru/base/utils/metadata_utils.dart';

class HomeWidgetService {
  static Future<void> reloadNowPlayingWidget() async {
    await HomeWidget.updateWidget(iOSName: 'NowPlayingWidget');
  }

  static Future<void> reloadPlaylistsWidget() async {
    await HomeWidget.updateWidget(iOSName: 'PlaylistsWidget');
  }

  static Future<void> updateNowPlayingWidget() async {
    try {
      final song = currentSongNotifier.value;
      if (song != null) {
        await HomeWidget.saveWidgetData('title', getTitle(song));
        await HomeWidget.saveWidgetData('artist', getArtist(song));
        await HomeWidget.saveWidgetData('album', getAlbum(song));
      } else {
        // use placeholder
        await HomeWidget.saveWidgetData('title', null);
      }

      final pictureFile = File(song?.picture.path ?? '');

      if (await pictureFile.exists()) {
        await HomeWidget.saveFile('coverPath', await pictureFile.readAsBytes());
        await HomeWidget.saveWidgetData(
          'coverColor',
          currentCoverArtColor.toARGB32(),
        );
        await HomeWidget.saveWidgetData(
          'foregroundColor',
          contrastColorTheme.accent.toARGB32(),
        );
      } else {
        await HomeWidget.saveFile('coverPath', Uint8List(0));
        await HomeWidget.saveWidgetData('coverColor', Colors.white.toARGB32());
        await HomeWidget.saveWidgetData(
          'foregroundColor',
          Colors.black.toARGB32(),
        );
      }

      await HomeWidget.saveWidgetData('is_playing', isPlayingNotifier.value);

      await HomeWidget.saveWidgetData(
        'is_favorite',
        song?.isFavoriteNotifier.value,
      );

      // U+001F (unit separator) binds translations to their line: the
      // widget splits on newline for lines and on U+001F for the
      // translations following the original text, so lyricsIndex keeps
      // pointing at the original line without remapping.
      await HomeWidget.saveWidgetData(
        'lyrics',
        song?.parsedLyrics?.lines
            .map(
              (line) => [
                line.text,
                ...line.translates.where((t) => t.trim().isNotEmpty),
              ].join('\u001F'),
            )
            .toList()
            .join('\n'),
      );

      await HomeWidget.saveWidgetData(
        'lyricsIndex',
        currentLyricsIndexNotifier.value,
      );
    } catch (error) {
      logger.output("widget save error: $error");
    }

    await reloadNowPlayingWidget();
  }

  static Future<void> updateIsFavorite() async {
    try {
      final song = currentSongNotifier.value;
      await HomeWidget.saveWidgetData(
        'is_favorite',
        song?.isFavoriteNotifier.value,
      );
    } catch (error) {
      logger.output("widget save error: $error");
    }

    await reloadNowPlayingWidget();
  }

  static Future<void> updateIsPlaying() async {
    try {
      await HomeWidget.saveWidgetData('is_playing', isPlayingNotifier.value);
    } catch (error) {
      logger.output("widget save error: $error");
    }

    await reloadNowPlayingWidget();
  }

  static Future<void> updateLyricsIndex() async {
    try {
      await HomeWidget.saveWidgetData(
        'lyricsIndex',
        currentLyricsIndexNotifier.value,
      );
    } catch (error) {
      logger.output("widget save error: $error");
    }

    await reloadNowPlayingWidget();
  }

  static Future<void> updatePlaylistsWidget() async {
    final playlists = playlistManager.playlists;
    try {
      await HomeWidget.saveWidgetData('playlistCount', playlists.length);

      for (int i = 0; i < playlists.length; i++) {
        final playlist = playlists[i];

        final picture = playlist.picture;

        if (picture != null) {
          await loadPictureSafe(playlist.picture!);
        }

        File pictureFile = File(picture?.path ?? '');

        if (await pictureFile.exists()) {
          await HomeWidget.saveFile('cover$i', await pictureFile.readAsBytes());
        } else {
          await HomeWidget.saveFile('cover$i', Uint8List(0));
        }

        if (playlist.isFavorite) {
          await HomeWidget.saveWidgetData(
            'name$i',
            getAppLocalizations().favorites,
          );
        } else {
          await HomeWidget.saveWidgetData('name$i', playlist.name);
        }
      }
    } catch (error) {
      logger.output("widget save error: $error");
    }
    await reloadPlaylistsWidget();
  }
}
