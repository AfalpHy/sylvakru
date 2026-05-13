import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:particle_music/base/audio_handler.dart';
import 'package:particle_music/base/data/config.dart';
import 'package:particle_music/base/data/artist_album.dart';
import 'package:particle_music/base/services/bookmark_service.dart';
import 'package:particle_music/base/utils/color_manager.dart';
import 'package:particle_music/base/app.dart';
import 'package:particle_music/base/data/history.dart';
import 'package:particle_music/layer/layers_manager.dart';
import 'package:particle_music/base/data/library.dart';
import 'package:particle_music/base/data/playlist.dart';
import 'package:particle_music/base/data/setting.dart';
import 'package:permission_handler/permission_handler.dart';

final ValueNotifier<int> loadedCountNotifier = ValueNotifier(0);

final ValueNotifier<String> currentLoadingFolderNotifier = ValueNotifier('');

final ValueNotifier<bool> loadingLibraryNotifier = ValueNotifier(true);

final ValueNotifier<bool> loadingNavidromeNotifier = ValueNotifier(false);

class Loader {
  static Future<void> init() async {
    if (Platform.isAndroid) {
      await Permission.storage.request();
      await Permission.audio.request();
    } else if (Platform.isIOS) {
      await BookmarkService.init();
    }

    _handleLegacyVersionData();

    await config.load();
    await setting.load();

    colorManager = ColorManager();
    colorManager.loadCustomColors();

    library = Library();
    await library.initAllFolders();

    await playlistManager.initAllPlaylists();

    audioHandler.initStateFiles();
  }

  static Future<void> load() async {
    loadingLibraryNotifier.value = true;
    loadingNavidromeNotifier.value = false;
    loadedCountNotifier.value = 0;

    await library.load();

    artistAlbumManager.load();

    await history.load();

    await playlistManager.load();

    await audioHandler.loadPlayQueueState();
    await audioHandler.loadPlayState();
    await audioHandler.loadEqualizerState();

    await layersManager.pushLayer('songs');

    loadingLibraryNotifier.value = false;
  }

  static Future<void> reload() async {
    library.clear();

    playlistManager.clear();

    artistAlbumManager.clear();

    history.clear();
    layersManager.clear();

    await audioHandler.clearForReload();

    await load();
  }

  static void _handleLegacyVersionData() {
    File tmp = File('${appSupportDir.path}/version.json');
    if (tmp.existsSync()) {
      return;
    } else {
      tmp.writeAsStringSync(jsonEncode(versionNumber));
    }
  }
}
