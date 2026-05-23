import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/data/config.dart';
import 'package:sylvakru/base/data/artist_album.dart';
import 'package:sylvakru/base/services/bookmark_service.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/data/history.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/layer/layers_manager.dart';
import 'package:sylvakru/base/data/library.dart';
import 'package:sylvakru/base/data/playlist.dart';
import 'package:sylvakru/base/data/setting.dart';
import 'package:permission_handler/permission_handler.dart';

class Loader {
  static bool _syncing = false;

  static bool get syncing => _syncing;

  static final syncStateNotifier = ValueNotifier(0);

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

    colorManager.updateColors();

    await library.loadFonts();
    await library.initAllFolders();

    await playlistManager.initAllPlaylists();

    audioHandler.initStateFiles();
  }

  static Future<void> load() async {
    await library.load();

    artistAlbumManager.classify();

    history.load();

    await playlistManager.load();

    await audioHandler.loadPlayQueueState();
    await audioHandler.loadPlayState();
    await audioHandler.loadEqualizerState();

    layersManager.pushLayer('songs');
  }

  static Future<void> _prepareForSync(SourceType sourceType) async {
    await library.prepareForSync(sourceType);
    history.prepareForSync(sourceType);
    await playlistManager.prepareForSync(sourceType);
  }

  static Future<void> _sync(SourceType sourceType) async {
    await library.sync(sourceType);
    history.sync(sourceType);
    await playlistManager.sync(sourceType);
  }

  static Future<void> sync(int syncBitMask) async {
    _syncing = true;
    syncStateNotifier.value++;

    await audioHandler.clear();
    artistAlbumManager.clear();

    if ((syncBitMask & 1) == 1) {
      await _prepareForSync(.local);
    }

    if ((syncBitMask & 2) == 2) {
      await _prepareForSync(.webdav);
    }

    if ((syncBitMask & 4) == 4) {
      await _prepareForSync(.navidrome);
    }

    if ((syncBitMask & 8) == 8) {
      await _prepareForSync(.emby);
    }

    if ((syncBitMask & 1) == 1) {
      await _sync(.local);
    }

    if ((syncBitMask & 2) == 2) {
      await _sync(.webdav);
    }

    if ((syncBitMask & 4) == 4) {
      await _sync(.navidrome);
    }

    if ((syncBitMask & 8) == 8) {
      await _sync(.emby);
    }
    artistAlbumManager.classify();

    _syncing = false;
    syncStateNotifier.value++;
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
