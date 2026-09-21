import 'dart:convert';
import 'dart:io';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/data/config.dart';
import 'package:sylvakru/base/data/artist_album.dart';
import 'package:sylvakru/base/data/font_manager.dart';
import 'package:sylvakru/base/services/bookmark_service.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/data/history.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/data/library.dart';
import 'package:sylvakru/base/data/playlist.dart';
import 'package:sylvakru/base/data/setting.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sylvakru/base/services/logger.dart';
import 'package:sylvakru/base/services/picture_load_scheduler.dart';
import 'package:sylvakru/base/services/picture_service.dart';
import 'package:sylvakru/base/services/stream_client.dart';
import 'package:sylvakru/base/utils/common_utils.dart';
import 'package:sylvakru/base/utils/path.dart';
import 'package:sylvakru/layer/layers_manager.dart';

bool firstLaunch = true;

class Loader {
  static bool _busy = false;

  static bool get busy => _busy;

  static final stateNotifier = ValueNotifier(0);

  static Future<void> init() async {
    if (Platform.isAndroid) {
      await Permission.storage.request();
      await Permission.audio.request();
    } else if (Platform.isIOS) {
      await BookmarkService.init();
      File keepFile = File('${appDocsDir.path}/sylvakru.keep');
      if (!keepFile.existsSync()) {
        keepFile.createSync();
      }
    }

    _handleLegacyVersionData();

    await config.load();
    await setting.load();

    colorManager.updateColors();

    await fontManager.loadFonts();
  }

  static Future<void> load() async {
    _busy = true;
    stateNotifier.value++;

    if (isStreamSource && streamClient != null) {
      if (!File(getSyncedFilePath(sourceType)).existsSync()) {
        await firstSync();
        return;
      }
    }

    await library.load();

    audioHandler.loadStates();

    await history.load();

    await playlistManager.load();

    artistAlbumManager.classify();

    _busy = false;
    stateNotifier.value++;
  }

  static Future<void> reload() async {
    if (viewModeNotifier.value == .normal) {
      layersManager.clearDataLayers();
    }
    pictureLoadScheduler.clear();
    audioHandler.justClear();

    globalPictureList = [];

    library = Library();
    artistAlbumManager.clear();
    history.clear();
    playlistManager.reset();

    await load();
  }

  static Future<void> sync() async {
    _busy = true;
    stateNotifier.value++;

    if (viewModeNotifier.value == .normal) {
      layersManager.clearDataLayers();
    }

    globalPictureList = [];

    artistAlbumManager.clear();

    history.clear();

    playlistManager.reset();

    await library.sync();

    audioHandler.sync();

    await history.load();

    await playlistManager.sync();

    artistAlbumManager.classify();

    if (isStreamSource) {
      File syncedFile = File(getSyncedFilePath(sourceType));

      if (streamClient != null && !syncedFile.existsSync()) {
        syncedFile.createSync(recursive: true);
      }

      if (streamClient == null && syncedFile.existsSync()) {
        syncedFile.deleteSync(recursive: true);
      }
    }

    _busy = false;
    stateNotifier.value++;
  }

  static Future<void> firstSync() async {
    _busy = true;
    stateNotifier.value++;

    logger.output('${sourceType.name} first sync');

    layersManager.switchRootLayer('songs');

    playlistManager.reset();

    await library.sync();

    audioHandler.loadStates();

    await history.load();

    await playlistManager.sync();

    artistAlbumManager.classify();

    if (isStreamSource) {
      File syncedFile = File(getSyncedFilePath(sourceType));

      if (streamClient != null && !syncedFile.existsSync()) {
        syncedFile.createSync(recursive: true);
      }

      if (streamClient == null && syncedFile.existsSync()) {
        syncedFile.deleteSync(recursive: true);
      }
    }

    _busy = false;
    stateNotifier.value++;
  }

  static void _handleLegacyVersionData() {
    File tmp = File('${appSupportDir.path}/version.json');
    if (tmp.existsSync()) {
      firstLaunch = false;
      if (compareVersion('4.0.1', jsonDecode(tmp.readAsStringSync())) > 0) {
        File playlistsFile = File(
          "${getPlaylistConfigPath(.local)}/sylvakru_playlists.json",
        );
        if (playlistsFile.existsSync()) {
          final content = playlistsFile.readAsStringSync();
          final list = jsonDecode(content) as List;
          if (list.isNotEmpty && list[0] == 'Favorite') {
            playlistsFile.writeAsStringSync(jsonEncode(list.skip(1).toList()));
          }
        }

        playlistsFile = File(
          "${getPlaylistConfigPath(.webdav)}/sylvakru_playlists.json",
        );
        if (playlistsFile.existsSync()) {
          final content = playlistsFile.readAsStringSync();
          final list = jsonDecode(content) as List;
          if (list.isNotEmpty && list[0] == 'Favorite') {
            playlistsFile.writeAsStringSync(jsonEncode(list.skip(1).toList()));
          }
        }
      }

      if (compareVersion('4.2.0', jsonDecode(tmp.readAsStringSync())) > 0) {
        Directory tmpDir = Directory('${appSupportDir.path}/subsonic');
        if (tmpDir.existsSync()) {
          tmpDir.deleteSync(recursive: true);
        }

        tmpDir = Directory('${appSupportDir.path}/navidrome');
        if (tmpDir.existsSync()) {
          tmpDir.deleteSync(recursive: true);
        }

        tmpDir = Directory('${appSupportDir.path}/emby');
        if (tmpDir.existsSync()) {
          tmpDir.deleteSync(recursive: true);
        }
      }
    }
    tmp.writeAsStringSync(jsonEncode(versionNumber));
  }
}
