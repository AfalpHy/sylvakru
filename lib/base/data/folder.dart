import 'dart:convert';
import 'dart:io';

import 'package:audio_tags_lofty/audio_tags_lofty.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/base/services/bookmark_service.dart';
import 'package:particle_music/base/app.dart';
import 'package:particle_music/base/utils/io.dart';
import 'package:particle_music/base/utils/logger.dart';
import 'package:particle_music/base/services/webdav_client.dart';
import 'package:particle_music/base/widgets/manage_music_folders.dart';
import 'package:particle_music/layer/layers_manager.dart';
import 'package:particle_music/base/data/library.dart';
import 'package:particle_music/base/data/loader.dart';
import 'package:particle_music/base/my_audio_metadata.dart';
import 'package:particle_music/base/utils/metadata.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import 'package:pool/pool.dart';

final Set<String> _loftySupportedExts = {
  '.mp2',
  '.mp3',
  '.flac',
  '.m4a',
  '.m4r',
  '.mp4',
  '.aac',
  '.wav',
  '.aiff',
  '.aif',
  '.ogg',
  '.opus',
  '.ape',
  '.mpc',
  '.wv',
  '.spx',
};

class Folder {
  final String id;
  final String path;
  late Directory? _dir;
  bool isWebdav;
  late File _songIdListFile;

  List<MyAudioMetadata> songList = [];
  Map<String, MyAudioMetadata> id2Song = {};

  ValueNotifier<int> sortTypeNotifier = ValueNotifier(0);

  final updateNotifier = ValueNotifier(0);

  Folder(this.id, this.path, String songIdListPath, {this.isWebdav = false}) {
    if (!isWebdav) {
      _dir = Directory(path);
    }
    _songIdListFile = File(songIdListPath);
    if (!_songIdListFile.existsSync()) {
      _songIdListFile.writeAsStringSync('[]');
    }
  }

  static Future<Folder> fromLocal(Map<String, dynamic> map) async {
    String id = map['id'] as String;
    String path = id;
    String songIdListPath = map['songIdListPath'] as String;
    if (Platform.isIOS) {
      if (id.startsWith('Particle Music')) {
        path =
            '${appDocsDir.parent.path}/${id.replaceFirst('Particle Music', 'Documents')}';
      } else {
        path = await BookmarkService.getUrlById(id) ?? '';
        library.setIOSFileProviderStorageIfNeed(path);
      }
      songIdListPath = "${localFolderConfigDir.path}/$songIdListPath";
    }

    return Folder(id, path, songIdListPath);
  }

  static Future<Folder> fromWebdav(Map<String, dynamic> map) async {
    String id = map['id'] as String;
    String path = id;

    String songIdListPath = map['songIdListPath'] as String;

    return Folder(id, path, songIdListPath, isWebdav: true);
  }

  static Future<Folder> createLocal(String id) async {
    final uuid = Uuid();
    final songIdListPath = '${localFolderConfigDir.path}/${uuid.v4()}.json';

    String path = id;
    if (Platform.isIOS) {
      if (id.startsWith('Particle Music')) {
        path =
            '${appDocsDir.parent.path}/${id.replaceFirst('Particle Music', 'Documents')}';
      } else {
        path = library.iosFileProviderStorage! + id;
        if (!await BookmarkService.saveDirectoryAndActive(id, path)) {
          path = '';
        }
      }
    }

    return Folder(id, path, songIdListPath);
  }

  static Future<Folder> createWebdav(String id) async {
    final uuid = Uuid();
    final songIdListPath = '${webdavFolderConfigDir.path}/${uuid.v4()}.json';

    String path = id;

    return Folder(id, path, songIdListPath, isWebdav: true);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'songIdListPath': Platform.isIOS
          ? _songIdListFile.path.split('folder_config/').last
          : _songIdListFile.path,
    };
  }

  Future<void> _processSong(String id, String path, DateTime modified) async {
    MyAudioMetadata? song = library.id2Song[id];
    // visited
    if (song != null) {
      id2Song[id] = song;
      return;
    }

    song = id2Song[id];
    if (song?.modified != modified) {
      try {
        final tmp = isWebdav
            ? await readMetadataAsync(
                path,
                false,
                headers: webdavClient?.headers,
              )
            : readMetadata(path, false);

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
      } catch (e) {
        song = null;
        logger.output(e.toString());
      }
    }
    if (song != null) {
      id2Song[id] = song;
      loadedCountNotifier.value++;
    } else {
      id2Song.remove(id);
    }
  }

  void prepare() {
    final jsonString = _songIdListFile.readAsStringSync();
    final List<dynamic> songIdList = jsonDecode(jsonString);
    for (final id in songIdList) {
      id2Song[id] = library.id2Song[id]!;
    }
  }

  Future<void> load() async {
    currentLoadingFolderNotifier.value = id;
    if (isWebdav) {
      if (await webdavClient?.ping() != true) {
        logger.output('WebDAV not connected');
        return;
      }

      try {
        final pool = Pool(4);

        final tasks = <Future>[];

        await for (final file in webdavClient!.listStream(
          path,
          recursive: recursiveScanNotifier.value,
        )) {
          if (file.isDirectory) {
            continue;
          }

          final ext = extension(file.path).toLowerCase();

          if (!_loftySupportedExts.contains(ext)) {
            continue;
          }
          String id = Uri.parse(
            webdavClient!.baseUrl,
          ).resolve(file.path).toString();
          id = Uri.decodeFull(id);
          tasks.add(
            pool.withResource(() => _processSong(id, id, file.modified!)),
          );
        }

        await Future.wait(tasks);

        await pool.close();
      } catch (e) {
        logger.output(e.toString());
        return;
      }
    } else {
      if (!_dir!.existsSync()) {
        logger.output('$path is not exist');
        return;
      }
      await for (final file in _dir!.list(
        recursive: recursiveScanNotifier.value,
      )) {
        if (file is! File) continue;

        final ext = extension(file.path).toLowerCase();
        if (!_loftySupportedExts.contains(ext)) {
          continue;
        }

        String path = file.path;
        final modified = (await file.stat()).modified;
        if (Platform.isIOS) {
          await _processSong(convertIOSPath(path), path, modified);
        } else {
          await _processSong(path, path, modified);
        }
      }
    }

    await setSongList(_songIdListFile, songList, id2Song);

    await _saveSongIdList();
  }

  Future<void> _saveSongIdList() async {
    await _songIdListFile.writeAsString(
      jsonEncode(songList.map((e) => e.id).toList()),
    );
  }

  void shuffle() {
    songList.shuffle();
    update();
  }

  Future<void> update() async {
    await layersManager.updateBackground();
    updateNotifier.value++;
    await _saveSongIdList();
  }

  void delete() {
    try {
      _songIdListFile.deleteSync();
    } catch (e) {
      logger.output(e.toString());
    }
  }

  void clear() {
    songList = [];
    id2Song = {};
  }
}
