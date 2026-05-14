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

  late File _cacheMapFile;
  final Map<String, String> _id2CachePath = {};
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
      "${appSupportDir.path}/local/song_id_list.json",
    );
    initFile(_localSongIdListFile, true);

    _webdavSongIdListFile = File(
      "${appSupportDir.path}/webdav/song_id_list.json",
    );
    initFile(_webdavSongIdListFile, true);

    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    _localMetadataDB = MetadataDB(openMetadataDB('local/metadata.db'));
    _webdavMetadataDB = MetadataDB(openMetadataDB('webdav/metadata.db'));

    _cacheMapFile = File("${cacheConfigDir.path}/cache_map.json");
    initFile(_cacheMapFile, false);

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

    await _processCache();
  }

  Future<void> _processCache() async {
    _id2CachePath.addAll(
      (jsonDecode(await _cacheMapFile.readAsString()) as Map<String, dynamic>)
          .cast(),
    );

    for (final id in _id2CachePath.keys) {
      final song = id2Song[id];
      String cachePath = _id2CachePath[id]!;

      if (Platform.isIOS) {
        cachePath = revertIOSSupportPath(cachePath);
      }
      File cacheFile = File(cachePath);
      if (song != null && await cacheFile.exists()) {
        song.cachePath = cachePath;
        cacheSizeNotifier.value += await cacheFile.length() / (1024 * 1024);
      } else {
        if (await cacheFile.exists()) {
          await cacheFile.delete();
        }
        _id2CachePath[id] = '';
      }
    }

    _id2CachePath.removeWhere((key, value) => value == '');
    await _saveCacheMap();
  }

  Future<void> tryAddCache(MyAudioMetadata song) async {
    if (song.sourceType == .local || song.cachePath != null) {
      return;
    }
    final uuid = Uuid();
    final savePath = "${cacheConfigDir.path}/cache/${uuid.v4()}";
    if (song.sourceType == .webdav) {
      await webdavClient!.download(remotePath: song.path!, localPath: savePath);
    } else if (song.sourceType == .navidrome) {
      await navidromeClient!.downloadSong(songId: song.id, savePath: savePath);
    } else if (song.sourceType == .emby) {
      await embyClient!.downloadSong(itemId: song.id, savePath: savePath);
    }
    final tmp = File(savePath);
    if (await tmp.exists()) {
      song.cachePath = savePath;
      _id2CachePath[song.id] = savePath;
      cacheSizeNotifier.value += await tmp.length() / (1024 * 1024);
      await _saveCacheMap();
    }
  }

  Future<void> _saveCacheMap() async {
    if (Platform.isIOS) {
      await _cacheMapFile.writeAsString(
        jsonEncode(
          _id2CachePath.map(
            (key, value) => MapEntry(key, convertIOSSupportPath(value)),
          ),
        ),
      );
    } else {
      await _cacheMapFile.writeAsString(jsonEncode(_id2CachePath));
    }
  }

  Future<void> clearCache() async {
    for (final id in _id2CachePath.keys) {
      final song = id2Song[id];
      song!.cachePath = null;
    }
    _id2CachePath.clear();
    await _saveCacheMap();

    Directory cacheDir = Directory("${cacheConfigDir.path}/cache");
    if (await cacheDir.exists()) {
      await cacheDir.delete(recursive: true);
    }

    cacheSizeNotifier.value = 0;
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

  void shuffle(SourceType sourceType) {
    if (sourceType == .local) {
      songListManager.localSongList.shuffle();
    } else {
      songListManager.webdavSongList.shuffle();
    }

    update(sourceType);
  }

  Future<void> update(SourceType sourceType) async {
    if (sourceType == .local) {
      songListManager.localChangeNotifier.value++;
      _saveLocalSongIdList();
    } else {
      songListManager.webdavChangeNotifier.value++;
      _saveWebdavSongIdList();
    }

    layersManager.updateBackground();
  }

  void clear() {
    _id2CachePath.clear();
    cacheSizeNotifier.value = 0;

    songListManager.clear();
    id2Song.clear();

    for (final folder in localFolderList) {
      folder.clear();
    }

    for (final folder in webdavFolderList) {
      folder.clear();
    }
  }
}
