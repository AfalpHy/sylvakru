import 'dart:convert';
import 'dart:io';

import 'package:audio_tags_lofty/audio_tags_lofty.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:particle_music/base/app.dart';
import 'package:particle_music/base/data/database.dart';
import 'package:particle_music/base/data/song_list_manager.dart';
import 'package:particle_music/base/extensions/metadata_extension.dart';
import 'package:particle_music/base/services/emby_client.dart';
import 'package:particle_music/base/services/logger.dart';
import 'package:particle_music/base/services/song_list_service.dart';
import 'package:particle_music/base/services/webdav_client.dart';
import 'package:particle_music/base/utils/path.dart';
import 'package:particle_music/base/data/folder.dart';
import 'package:particle_music/layer/layers_manager.dart';
import 'package:particle_music/base/my_audio_metadata.dart';
import 'package:particle_music/base/services/navidrome_client.dart';
import 'package:path/path.dart';
import 'package:pool/pool.dart';

final library = Library();

class Library {
  late File _localSongIdListFile;
  late File _webdavSongIdListFile;
  late File _navidromeSongIdListFile;
  late File _embySongIdListFile;

  late MetadataDB _localMetadataDB;
  late MetadataDB _webdavMetadataDB;
  late MetadataDB _navidromeMetadataDB;
  late MetadataDB _embyMetadataDB;

  ValueNotifier<double> cacheSizeNotifier = ValueNotifier(0);

  Map<String, MyAudioMetadata> id2Song = {};

  SongListManager songListManager = SongListManager();

  late final File _localFolderIdListFile;
  late final File _webdavFolderIdListFile;
  List<Folder> localFolderList = [];
  List<Folder> webdavFolderList = [];
  final folderListChangeNotifier = ValueNotifier(0);
  String? iosFileProviderStorage;

  late File _fontMapFile;
  Map<String, List<String>> _fontMap = {};

  Library() {
    _localSongIdListFile = File(
      "${appSupportDir.path}/local/song_id_list.json",
    );
    initFile(_localSongIdListFile, true);

    _webdavSongIdListFile = File(
      "${appSupportDir.path}/webdav/song_id_list.json",
    );
    initFile(_webdavSongIdListFile, true);

    _navidromeSongIdListFile = File(
      "${appSupportDir.path}/navidrome/song_id_list.json",
    );
    initFile(_navidromeSongIdListFile, true);

    _embySongIdListFile = File("${appSupportDir.path}/emby/song_id_list.json");
    initFile(_embySongIdListFile, true);

    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    _localMetadataDB = MetadataDB(openMetadataDB('local/metadata.db'));
    _webdavMetadataDB = MetadataDB(openMetadataDB('webdav/metadata.db'));
    _navidromeMetadataDB = MetadataDB(openMetadataDB('navidrome/metadata.db'));
    _embyMetadataDB = MetadataDB(openMetadataDB('emby/metadata.db'));

    _localFolderIdListFile = File(
      "${getFolderConfigPath(.local)}/folder_id_list.json",
    );
    initFile(_localFolderIdListFile, true);

    _webdavFolderIdListFile = File(
      "${getFolderConfigPath(.webdav)}/folder_id_list.json",
    );
    initFile(_webdavFolderIdListFile, true);

    _fontMapFile = File("${appSupportDir.path}/fonts/font_map.json");
    initFile(_fontMapFile, false);
  }

  Future<void> _initLocalFolders() async {
    List<dynamic> folderIdList = jsonDecode(
      await _localFolderIdListFile.readAsString(),
    );

    for (final id in folderIdList) {
      localFolderList.add(await Folder.from(id, false));
    }
  }

  Future<void> _initWebdavFolders() async {
    List<dynamic> folderIdList = jsonDecode(
      await _webdavFolderIdListFile.readAsString(),
    );

    for (final id in folderIdList) {
      webdavFolderList.add(await Folder.from(id, true));
    }
  }

  Future<void> initAllFolders() async {
    await _initLocalFolders();
    await _initWebdavFolders();
  }

  Future<void> loadFonts() async {
    _fontMap =
        (jsonDecode(_fontMapFile.readAsStringSync()) as Map<String, dynamic>)
            .map((key, value) => MapEntry(key, List<String>.from(value)));
    for (final entry in _fontMap.entries) {
      final name = entry.key;
      final fontPathList = entry.value;
      final loader = FontLoader(name);

      for (final fontPath in fontPathList) {
        final fontFile = File("${appSupportDir.path}/fonts/$fontPath");
        if (!fontFile.existsSync()) {
          continue;
        }
        final bytes = fontFile.readAsBytesSync();
        loader.addFont(Future.value(ByteData.view(bytes.buffer)));
      }
      await loader.load();
      importedFonts.add(name);
    }
  }

  Future<void> addFonts(String name, List<String> paths) async {
    for (String path in paths) {
      File originFile = File(path);
      path = basename(path);
      originFile.copySync("${appSupportDir.path}/fonts/$path");
      _fontMap
          .putIfAbsent(name, () {
            return [];
          })
          .add(path);
    }

    await _fontMapFile.writeAsString(json.encode(_fontMap));
  }

  Future<void> deleteFonts(String name) async {
    if (_fontMap[name] == null) {
      return;
    }
    for (final path in _fontMap[name]!) {
      final tmp = File("${appSupportDir.path}/fonts/$path");
      if (await tmp.exists()) {
        await tmp.delete();
      }
    }
    _fontMap.remove(name);
    importedFonts.remove(name);
    await _fontMapFile.writeAsString(json.encode(_fontMap));
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
        newFolderList.add(await Folder.create(id, !isLocal));
      }
    }

    for (final folder in folderList) {
      if (newFolderList.contains(folder)) {
        continue;
      }
      folder.delete();
      layersManager.removeLayer(folder);
    }

    if (isLocal) {
      localFolderList = newFolderList;
      await _localFolderIdListFile.writeAsString(
        jsonEncode(localFolderList.map((e) => e.id).toList()),
      );
    } else {
      webdavFolderList = newFolderList;
      await _webdavFolderIdListFile.writeAsString(
        jsonEncode(webdavFolderList.map((e) => e.id).toList()),
      );
    }

    folderListChangeNotifier.value++;
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
    id2Song.addAll(await _loadSongMap(_navidromeMetadataDB));
    id2Song.addAll(await _loadSongMap(_embyMetadataDB));
  }

  Future<void> _loadLocal() async {
    for (final folder in localFolderList) {
      await folder.load();
    }
    await loadSongList(_localSongIdListFile, songListManager.localSongList);
  }

  Future<void> _loadWebdav() async {
    for (final folder in webdavFolderList) {
      await folder.load();
    }
    await loadSongList(_webdavSongIdListFile, songListManager.webdavSongList);
  }

  Future<void> _loadNavidrome() async {
    await loadSongList(
      _navidromeSongIdListFile,
      songListManager.navidromeSongList,
    );
  }

  Future<void> _loadEmby() async {
    await loadSongList(_embySongIdListFile, songListManager.embySongList);
  }

  Future<void> load() async {
    await _prepare();
    await _loadLocal();
    await _loadWebdav();
    await _loadNavidrome();
    await _loadEmby();

    songListManager.resetSourceType();

    for (final sourceType in SourceType.values) {
      await _accumulateCache(sourceType);
    }
  }

  Future<void> _accumulateCache(SourceType sourceType) async {
    Directory cacheDir = Directory(getCachesPath(sourceType));
    if (!await cacheDir.exists()) {
      return;
    }
    int total = 0;
    await for (final file in cacheDir.list()) {
      if (file is File) {
        total += await file.length();
      }
    }
    cacheSizeNotifier.value += total / (1024 * 1024);
  }

  Future<void> tryAddCache(MyAudioMetadata song) async {
    if (song.sourceType == .local || song.cachePath != null) {
      return;
    }
    final savePath = song.cachePath!;
    if (song.sourceType == .webdav) {
      await webdavClient!.download(remotePath: song.path!, localPath: savePath);
    } else if (song.sourceType == .navidrome) {
      await navidromeClient!.downloadSong(songId: song.id, savePath: savePath);
    } else if (song.sourceType == .emby) {
      await embyClient!.downloadSong(itemId: song.id, savePath: savePath);
    }
    final tmp = File(savePath);
    if (await tmp.exists()) {
      song.cacheExist = true;
      cacheSizeNotifier.value += await tmp.length() / (1024 * 1024);
    }
  }

  Future<void> clearCache(SourceType sourceType) async {
    for (final song in songListManager.getSongList2(sourceType)) {
      song.cacheExist = false;
    }

    Directory cacheDir = Directory(getCachesPath(sourceType));
    int totalSize = 0;
    if (await cacheDir.exists()) {
      await for (final file in cacheDir.list()) {
        if (file is File) {
          totalSize += file.lengthSync();
          await file.delete();
        }
      }
    }

    cacheSizeNotifier.value -= totalSize / (1024 * 1024);
  }

  Future<void> clearPicture(SourceType sourceType) async {
    for (final song in songListManager.getSongList2(sourceType)) {
      song.pictureLoaded = false;
      song.pictureExist = false;
    }

    Directory pictureDir = Directory(getPicturesPath(sourceType));
    if (await pictureDir.exists()) {
      await for (final file in pictureDir.list()) {
        await file.delete();
      }
    }
  }

  File _getSongIdListFile(SourceType sourceType) {
    switch (sourceType) {
      case .local:
        return _localSongIdListFile;
      case .webdav:
        return _webdavSongIdListFile;
      case .navidrome:
        return _navidromeSongIdListFile;
      default:
        return _embySongIdListFile;
    }
  }

  MetadataDB _getMetadataDB(SourceType sourceType) {
    switch (sourceType) {
      case .local:
        return _localMetadataDB;
      case .webdav:
        return _webdavMetadataDB;
      case .navidrome:
        return _navidromeMetadataDB;
      default:
        return _embyMetadataDB;
    }
  }

  Future<void> _saveSongIdList(SourceType sourceType) async {
    await _getSongIdListFile(sourceType).writeAsString(
      jsonEncode(
        songListManager.getSongList2(sourceType).map((e) => e.id).toList(),
      ),
    );
  }

  Future<void> _saveMetadata(SourceType sourceType) async {
    final metadataDB = _getMetadataDB(sourceType);

    await metadataDB.transaction(() async {
      await metadataDB.delete(metadataDB.metadataItems).go();

      await metadataDB.batch((batch) {
        batch.insertAll(
          metadataDB.metadataItems,
          songListManager
              .getSongList2(sourceType)
              .map((e) => e.toCompanion())
              .toList(),
        );
      });
    });
  }

  Future<void> updatePlayCount(MyAudioMetadata song) async {
    final metadataDB = _getMetadataDB(song.sourceType);

    await (metadataDB.update(
      metadataDB.metadataItems,
    )..where((t) => t.id.equals(song.id))).write(
      MetadataItemsCompanion(
        playCount: Value(song.playCount),
        lastPlayed: Value(song.lastPlayed!.millisecondsSinceEpoch),
      ),
    );
  }

  void shuffle(SourceType sourceType) {
    songListManager.getSongList2(sourceType).shuffle();
    update(sourceType);
  }

  void update(SourceType sourceType) {
    songListManager.getChangeNotifier2(sourceType).value++;
    layersManager.updateBackground();
    _saveSongIdList(sourceType);
  }

  void _syncNotify(SourceType sourceType) {
    songListManager.getChangeNotifier2(sourceType).value++;
    songListManager.resetSourceType();
    layersManager.updateBackground();
  }

  Future<MyAudioMetadata?> _parseMetadataIfNeed(
    String id,
    String path,
    DateTime modified,
  ) async {
    MyAudioMetadata? song = library.id2Song[id];

    if (song?.modified != modified) {
      bool isWebdav = path.startsWith('http://') || path.startsWith('https://');
      AudioMetadata? tmp;
      try {
        tmp = await readMetadataAsync(
          path,
          false,
          headers: isWebdav ? webdavClient!.headers : null,
        );
      } catch (e) {
        logger.output("$path: $e");
      }

      if (tmp != null) {
        song = MyAudioMetadata(
          tmp,
          id: id,
          path: path,
          modified: modified,
          sourceType: isWebdav ? .webdav : .local,
        );
      } else {
        song = null;
      }
    }
    if (song != null) {
      library.id2Song[id] = song;
    } else {
      library.id2Song.remove(id);
    }
    return song;
  }

  Future<void> prepareForSync(SourceType sourceType) async {
    await library.clearCache(sourceType);
    await library.clearPicture(sourceType);

    songListManager.prepareForSync(sourceType);
    if (sourceType == .local || sourceType == .webdav) {
      final folderList = sourceType == .local
          ? localFolderList
          : webdavFolderList;

      for (final folder in folderList) {
        folder.songList.clear();
        folder.changeNotifier.value++;
      }
    }
  }

  Future<void> sync(SourceType sourceType) async {
    switch (sourceType) {
      case .local:
      case .webdav:
        Map<String, DateTime> pathAndModified = {};
        final folderList = sourceType == .local
            ? localFolderList
            : webdavFolderList;

        for (final folder in folderList) {
          await folder.setFileAndModified();
          pathAndModified.addAll(folder.pathAndModified);
        }

        final List<dynamic> songIdList = jsonDecode(
          await _getSongIdListFile(sourceType).readAsString(),
        );

        final pool = Pool(6);

        final tasks = <Future>[];

        Set<String> validId = {};

        Future<void> syncOne(String id, String path, DateTime modified) async {
          final song = await _parseMetadataIfNeed(id, path, modified);
          if (song != null) {
            validId.add(id);
            songListManager.getSongList2(sourceType).add(song);
            if (validId.length % 50 == 0) {
              _syncNotify(sourceType);
            }
          }
        }

        for (final id in songIdList) {
          String path = id;

          DateTime? modified;

          if (sourceType == .local) {
            if (Platform.isIOS) {
              path = revertIOSPath(path);
            }
            modified = pathAndModified.remove(path);
          } else {
            modified = pathAndModified.remove(
              Uri.decodeFull(Uri.parse(id).path),
            );
          }

          if (modified != null) {
            tasks.add(
              pool.withResource(() async {
                await syncOne(id, path, modified!);
              }),
            );
          }
        }

        await Future.wait(tasks);

        for (final entry in pathAndModified.entries) {
          String path = entry.key;
          String id = path;
          if (sourceType == .webdav) {
            id = Uri.parse(webdavClient!.baseUrl).resolve(path).toString();
            id = Uri.decodeFull(id);
          } else if (Platform.isIOS) {
            id = convertIOSPath(path);
          }
          tasks.add(pool.withResource(() => syncOne(id, path, entry.value)));
        }

        await Future.wait(tasks);

        id2Song.removeWhere(
          (id, song) => song.sourceType == sourceType && !validId.contains(id),
        );

        for (final folder in folderList) {
          await folder.sync();
          folder.clearPathAndModified();
        }

        await pool.close();
        break;
      case .navidrome:
        id2Song.removeWhere((id, song) => song.sourceType == sourceType);
        if (navidromeClient != null) {
          await for (final batch in navidromeClient!.getSongs()) {
            for (final map in batch) {
              MyAudioMetadata song = MyAudioMetadata.fromNavidromeMap(map);
              songListManager.navidromeSongList.add(song);
              id2Song[song.id] = song;
            }
            _syncNotify(sourceType);
          }
        }
        break;
      default:
        id2Song.removeWhere((id, song) => song.sourceType == sourceType);
        if (embyClient != null) {
          await for (final batch in embyClient!.getAllSongs()) {
            for (final map in batch) {
              final song = MyAudioMetadata.fromEmbyMap(map);
              songListManager.embySongList.add(song);
              id2Song[song.id] = song;
            }
            _syncNotify(sourceType);
          }
        }
        break;
    }

    _syncNotify(sourceType);

    await _saveSongIdList(sourceType);
    await _saveMetadata(sourceType);
  }
}
