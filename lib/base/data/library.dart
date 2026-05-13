import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/base/app.dart';
import 'package:particle_music/base/data/database.dart';
import 'package:particle_music/base/data/song_list_manager.dart';
import 'package:particle_music/base/extensions/metadata_extension.dart';
import 'package:particle_music/base/services/emby_client.dart';
import 'package:particle_music/base/services/webdav_client.dart';
import 'package:particle_music/base/utils/io.dart';
import 'package:particle_music/base/data/folder.dart';
import 'package:particle_music/layer/layers_manager.dart';
import 'package:particle_music/base/data/loader.dart';
import 'package:particle_music/base/my_audio_metadata.dart';
import 'package:particle_music/base/services/navidrome_client.dart';
import 'package:particle_music/base/utils/metadata.dart';
import 'package:uuid/uuid.dart';

late Library library;

class Library {
  late File _localSongIdListFile;
  late File _webdavSongIdListFile;

  late MetadataDB _localMetadataDB;
  late MetadataDB _webdavMetadataDB;

  late File _webdavCacheMapFile;
  late File _navidromeCacheMapFile;
  late File _embyCacheMapFile;

  Map<String, String> _id2WebdavCache = {};
  Map<String, String> _id2navidromeCache = {};
  Map<String, String> _id2embyCache = {};
  ValueNotifier<double> cacheSizeNotifier = ValueNotifier(0);

  Map<String, MyAudioMetadata> id2Song = {};

  SongListManager songListManager = SongListManager();

  late final File _localFolderMapListFile;
  late final File _webdavFolderMapListFile;
  List<Folder> localFolderList = [];
  List<Folder> webdavFolderList = [];
  String? iosFileProviderStorage;

  Library() {
    _localSongIdListFile = File(
      "${appSupportDir.path}/local_song_id_list.json",
    );
    initFile(_localSongIdListFile, true);

    _webdavSongIdListFile = File(
      "${appSupportDir.path}/webdav_song_id_list.json",
    );
    initFile(_webdavSongIdListFile, true);

    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    _localMetadataDB = MetadataDB(openMetadataDB('local_metadata.db'));
    _webdavMetadataDB = MetadataDB(openMetadataDB('webdav_metadata.db'));

    _webdavCacheMapFile = File("${cacheConfigDir.path}/webdav_cache_map.json");
    initFile(_webdavCacheMapFile, false);

    _navidromeCacheMapFile = File(
      "${cacheConfigDir.path}/navidrome_cache_map.json",
    );
    initFile(_navidromeCacheMapFile, false);

    _embyCacheMapFile = File("${cacheConfigDir.path}/emby_cache_map.json");
    initFile(_embyCacheMapFile, false);

    _localFolderMapListFile = File(
      "${localFolderConfigDir.path}/folder_map_list.json",
    );
    initFile(_localFolderMapListFile, true);

    _webdavFolderMapListFile = File(
      "${webdavFolderConfigDir.path}/folder_map_list.json",
    );
    initFile(_webdavFolderMapListFile, true);
  }

  Future<void> _initLocalFolders() async {
    final jsonString = await _localFolderMapListFile.readAsString();
    List<dynamic> result = jsonDecode(jsonString);
    final folderMapList = result.cast<Map<String, dynamic>>();

    for (final map in folderMapList) {
      localFolderList.add(await Folder.fromLocal(map));
    }
  }

  Future<void> _initWebdavFolders() async {
    final jsonString = await _webdavFolderMapListFile.readAsString();
    List<dynamic> result = jsonDecode(jsonString);
    final folderMapList = result.cast<Map<String, dynamic>>();

    for (final map in folderMapList) {
      webdavFolderList.add(await Folder.fromWebdav(map));
    }
  }

  Future<void> initAllFolders() async {
    await _initLocalFolders();
    await _initWebdavFolders();
  }

  void setIOSFileProviderStorageIfNeed(String? iosPath) {
    if (iosFileProviderStorage == null && iosPath != null) {
      final tmp = iosPath.split('File Provider Storage/').first;
      iosFileProviderStorage = "${tmp}File Provider Storage/";
    }
  }

  Future<bool> updateFolders(List<String> idList, bool isLocal) async {
    bool needUpdate = false;
    final folderList = isLocal ? localFolderList : webdavFolderList;
    if (idList.length == folderList.length) {
      for (int i = 0; i < idList.length; i++) {
        if (idList[i] != folderList[i].id) {
          needUpdate = true;
          break;
        }
      }
    } else {
      needUpdate = true;
    }
    if (!needUpdate) {
      return false;
    }

    List<Folder> newFolderList = [];
    for (int i = 0; i < idList.length; i++) {
      String id = idList[i];
      bool exist = false;
      for (final folder in folderList) {
        if (id == folder.id) {
          newFolderList.add(folder);
          exist = true;
          break;
        }
      }
      if (!exist) {
        newFolderList.add(
          isLocal
              ? await Folder.createLocal(id)
              : await Folder.createWebdav(id),
        );
      }
    }

    for (final folder in folderList) {
      if (newFolderList.contains(folder)) {
        continue;
      }
      folder.delete();
    }

    if (isLocal) {
      localFolderList = newFolderList;
      await _localFolderMapListFile.writeAsString(
        jsonEncode(localFolderList.map((e) => e.toMap()).toList()),
      );
    } else {
      webdavFolderList = newFolderList;
      await _webdavFolderMapListFile.writeAsString(
        jsonEncode(webdavFolderList.map((e) => e.toMap()).toList()),
      );
    }

    return true;
  }

  Folder? getFolderById(String id) {
    for (final folder in localFolderList) {
      if (folder.id == id) {
        return folder;
      }
    }

    for (final folder in webdavFolderList) {
      if (folder.id == id) {
        return folder;
      }
    }
    return null;
  }

  Future<Map<String, MyAudioMetadata>> _loadSongMap(MetadataDB db) async {
    final rows = await db.select(db.metadataItems).get();

    return {for (final row in rows) row.id: row.toMetadata()};
  }

  Future<void> _prepare() async {
    id2Song.addAll(await _loadSongMap(_localMetadataDB));
    id2Song.addAll(await _loadSongMap(_webdavMetadataDB));

    for (final folder in localFolderList) {
      folder.prepare();
    }
    for (final folder in webdavFolderList) {
      folder.prepare();
    }
    id2Song = {};
  }

  Future<void> _loadLocal() async {
    for (final folder in localFolderList) {
      await folder.load();
      id2Song.addAll(folder.id2Song);
    }
    await setSongList(
      _localSongIdListFile,
      songListManager.localSongList,
      Map.fromEntries(
        id2Song.entries.where((e) => e.value.sourceType == .local),
      ),
    );

    await _saveLocalSongIdList();
  }

  Future<void> _loadWebdav() async {
    for (final folder in webdavFolderList) {
      await folder.load();
      id2Song.addAll(folder.id2Song);
    }
    await setSongList(
      _webdavSongIdListFile,
      songListManager.webdavSongList,
      Map.fromEntries(
        id2Song.entries.where((e) => e.value.sourceType == .webdav),
      ),
    );

    await _saveWebdavSongIdList();
  }

  Future<void> _loadNavidrome() async {
    if (navidromeClient != null) {
      loadingNavidromeNotifier.value = true;
      final list = await navidromeClient!.getSongs();
      for (final map in list) {
        MyAudioMetadata song = MyAudioMetadata.fromNavidromeMap(map);
        songListManager.navidromeSongList.add(song);
        id2Song[song.id] = song;
      }
    }
  }

  Future<void> _loadEmby() async {
    if (embyClient != null) {
      final list = await embyClient!.getAllSongs();
      for (final map in list) {
        MyAudioMetadata song = MyAudioMetadata.fromEmbyMap(map);
        songListManager.embySongList.add(song);
        id2Song[song.id] = song;
      }
    }
  }

  Future<void> load() async {
    await _prepare();
    await _loadLocal();
    await _loadWebdav();
    await _loadNavidrome();
    await _loadEmby();

    songListManager.resetSourceType();

    await _saveLocalMetadata();
    await _saveWebdavMetadata();

    await _processCache(.webdav);
    await _saveWebdavCache();

    await _processCache(.navidrome);
    await _saveNavidromeCache();

    await _processCache(.emby);
    await _saveEmbyCache();
  }

  Future<void> _processCache(SourceType souceType) async {
    final cacheMapFile = souceType == .webdav
        ? _webdavCacheMapFile
        : souceType == .navidrome
        ? _navidromeCacheMapFile
        : _embyCacheMapFile;
    final cacheMap = souceType == .webdav
        ? _id2WebdavCache
        : souceType == .navidrome
        ? _id2navidromeCache
        : _id2embyCache;

    cacheMap.addAll(
      (jsonDecode(await cacheMapFile.readAsString()) as Map<String, dynamic>)
          .cast(),
    );

    for (final id in cacheMap.keys) {
      final song = id2Song[id];
      String cachePath = cacheMap[id]!;

      if (Platform.isIOS) {
        cachePath = revertIOSSupportPath(cachePath);
      }
      File cacheFile = File(cachePath);
      if (song != null && await cacheFile.exists()) {
        if (souceType == .webdav) {
          song.webdavCachePath = cachePath;
        } else if (souceType == .navidrome) {
          song.navidromeCachePath = cachePath;
        } else {
          song.embyCachePath = cachePath;
        }
        cacheSizeNotifier.value += await cacheFile.length() / (1024 * 1024);
      } else {
        if (await cacheFile.exists()) {
          await cacheFile.delete();
        }
        cacheMap[id] = '';
      }
    }

    cacheMap.removeWhere((key, value) => value == '');
  }

  Future<void> tryAddCache(MyAudioMetadata song) async {
    if (song.sourceType == .webdav) {
      if (song.webdavCachePath != null) {
        return;
      }
      final uuid = Uuid();
      final savePath = "${cacheConfigDir.path}/webdavCache/${uuid.v4()}";

      await webdavClient!.download(remotePath: song.path!, localPath: savePath);

      final tmp = File(savePath);
      if (await tmp.exists()) {
        _id2WebdavCache[song.id] = savePath;
        song.webdavCachePath = savePath;
        cacheSizeNotifier.value += await tmp.length() / (1024 * 1024);
        await _saveWebdavCache();
      }
    } else if (song.sourceType == .navidrome) {
      if (song.navidromeCachePath != null) {
        return;
      }

      final uuid = Uuid();
      final savePath = "${cacheConfigDir.path}/navidromeCache/${uuid.v4()}";

      await navidromeClient!.downloadSong(songId: song.id, savePath: savePath);

      final tmp = File(savePath);
      if (await tmp.exists()) {
        _id2navidromeCache[song.id] = savePath;
        song.navidromeCachePath = savePath;
        cacheSizeNotifier.value += await tmp.length() / (1024 * 1024);
        await _saveNavidromeCache();
      }
    } else if (song.sourceType == .emby) {
      if (song.embyUrl != null) {
        return;
      }

      final uuid = Uuid();
      final savePath = "${cacheConfigDir.path}/embyCache/${uuid.v4()}";

      await embyClient!.downloadSong(itemId: song.id, savePath: savePath);

      final tmp = File(savePath);
      if (await tmp.exists()) {
        _id2embyCache[song.id] = savePath;
        song.navidromeCachePath = savePath;
        cacheSizeNotifier.value += await tmp.length() / (1024 * 1024);
        await _saveNavidromeCache();
      }
    }
  }

  Future<void> _saveWebdavCache() async {
    if (Platform.isIOS) {
      await _webdavCacheMapFile.writeAsString(
        jsonEncode(
          _id2WebdavCache.map(
            (key, value) => MapEntry(key, convertIOSSupportPath(value)),
          ),
        ),
      );
    } else {
      await _webdavCacheMapFile.writeAsString(jsonEncode(_id2WebdavCache));
    }
  }

  Future<void> _saveNavidromeCache() async {
    if (Platform.isIOS) {
      await _navidromeCacheMapFile.writeAsString(
        jsonEncode(
          _id2navidromeCache.map(
            (key, value) => MapEntry(key, convertIOSSupportPath(value)),
          ),
        ),
      );
    } else {
      await _navidromeCacheMapFile.writeAsString(
        jsonEncode(_id2navidromeCache),
      );
    }
  }

  Future<void> _saveEmbyCache() async {
    if (Platform.isIOS) {
      await _embyCacheMapFile.writeAsString(
        jsonEncode(
          _id2embyCache.map(
            (key, value) => MapEntry(key, convertIOSSupportPath(value)),
          ),
        ),
      );
    } else {
      await _embyCacheMapFile.writeAsString(jsonEncode(_id2embyCache));
    }
  }

  Future<void> clearCache() async {
    for (final id in _id2WebdavCache.keys) {
      final song = id2Song[id];
      song!.webdavCachePath = null;
    }

    for (final id in _id2navidromeCache.keys) {
      final song = id2Song[id];
      song!.navidromeCachePath = null;
    }

    Directory webdavCacheDir = Directory("${cacheConfigDir.path}/webdavCache");
    if (await webdavCacheDir.exists()) {
      await webdavCacheDir.delete(recursive: true);
    }
    Directory navidromeCacheDir = Directory(
      "${cacheConfigDir.path}/navidromeCache",
    );
    if (await navidromeCacheDir.exists()) {
      await navidromeCacheDir.delete(recursive: true);
    }
    Directory embyCacheDir = Directory("${cacheConfigDir.path}/embyCache");
    if (await embyCacheDir.exists()) {
      await embyCacheDir.delete(recursive: true);
    }

    cacheSizeNotifier.value = 0;

    _id2WebdavCache = {};
    await _saveWebdavCache();
    _id2navidromeCache = {};
    await _saveNavidromeCache();
    _id2embyCache = {};
    await _saveEmbyCache();
  }

  Future<void> _saveLocalSongIdList() async {
    await _localSongIdListFile.writeAsString(
      jsonEncode(songListManager.localSongList.map((e) => e.id).toList()),
    );
  }

  Future<void> _saveWebdavSongIdList() async {
    await _webdavSongIdListFile.writeAsString(
      jsonEncode(songListManager.webdavSongList.map((e) => e.id).toList()),
    );
  }

  Future<void> _saveLocalMetadata() async {
    await _localMetadataDB.batch((batch) {
      batch.insertAll(
        _localMetadataDB.metadataItems,

        songListManager.localSongList.map((e) => e.toCompanion()).toList(),

        mode: InsertMode.insertOrReplace,
      );
    });
  }

  Future<void> _saveWebdavMetadata() async {
    await _webdavMetadataDB.batch((batch) {
      batch.insertAll(
        _webdavMetadataDB.metadataItems,

        songListManager.webdavSongList.map((e) => e.toCompanion()).toList(),

        mode: InsertMode.insertOrReplace,
      );
    });
  }

  Future<void> updatePlayCount(MyAudioMetadata song) async {
    final db = song.sourceType == .local ? _localMetadataDB : _webdavMetadataDB;
    await (db.update(
      db.metadataItems,
    )..where((t) => t.id.equals(song.id))).write(
      MetadataItemsCompanion(
        playCount: Value(song.playCount),
        lastPlayed: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  void shuffle() {
    songListManager.localSongList.shuffle();
    update();
  }

  Future<void> update() async {
    await layersManager.updateBackground();
    songListManager.localChangeNotifier.value++;
    await _saveLocalSongIdList();
  }

  Future<void> updateLocal() async {
    await layersManager.updateBackground();
    songListManager.localChangeNotifier.value++;
    await _saveLocalSongIdList();
  }

  Future<void> updateWebdav() async {
    await layersManager.updateBackground();
    songListManager.localChangeNotifier.value++;
    await _saveLocalSongIdList();
  }

  void clear() {
    _id2WebdavCache = {};
    _id2navidromeCache = {};
    _id2embyCache = {};
    cacheSizeNotifier.value = 0;

    songListManager.clear();
    id2Song = {};

    for (final folder in localFolderList) {
      folder.clear();
    }

    for (final folder in webdavFolderList) {
      folder.clear();
    }
  }
}
