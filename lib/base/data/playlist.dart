import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:particle_music/base/app.dart';
import 'package:particle_music/base/data/song_list_manager.dart';
import 'package:particle_music/base/services/emby_client.dart';
import 'package:particle_music/base/services/webdav_client.dart';
import 'package:particle_music/base/utils/path.dart';
import 'package:particle_music/base/utils/metadata_utils.dart';
import 'package:particle_music/base/utils/source_type.dart';
import 'package:particle_music/layer/layers_manager.dart';
import 'package:particle_music/base/data/library.dart';
import 'package:particle_music/base/my_audio_metadata.dart';
import 'package:particle_music/base/services/navidrome_client.dart';

final playlistManager = PlaylistManager();

class PlaylistManager {
  late File _localFile;
  late File _webdavFile;
  late File _navidromeFile;
  late File _embyFile;

  List<Playlist> playlists = [];
  Map<String, Playlist> playlistsMap = {};
  ValueNotifier<int> updateNotifier = ValueNotifier(0);
  final useLargePictureNotifier = ValueNotifier(true);

  Future<void> initAllPlaylists() async {
    _localFile = File(
      "${getPlaylistConfigPath(.local)}/particle_music_playlists.json",
    );
    if (!(_localFile.existsSync())) {
      _localFile.createSync(recursive: true);
      _localFile.writeAsStringSync(jsonEncode(['Favorite']));
    }

    _webdavFile = File(
      "${getPlaylistConfigPath(.webdav)}/particle_music_playlists.json",
    );
    initFile(_webdavFile, true);

    _navidromeFile = File(
      "${getPlaylistConfigPath(.navidrome)}/particle_music_playlists.json",
    );
    initFile(_navidromeFile, true);

    _embyFile = File(
      "${getPlaylistConfigPath(.emby)}/particle_music_playlists.json",
    );
    initFile(_embyFile, true);
  }

  Future<void> load() async {
    List<dynamic> localPlaylists = jsonDecode(await _localFile.readAsString());
    for (String name in localPlaylists) {
      addPlaylist(Playlist(name: name));
    }

    List<dynamic> webdavPlaylists = jsonDecode(
      await _webdavFile.readAsString(),
    );
    for (String name in webdavPlaylists) {
      playlistsMap[name]!.setWebdavFile();
    }

    List<dynamic> navidromePlaylists = jsonDecode(
      await _navidromeFile.readAsString(),
    );
    for (final map in navidromePlaylists) {
      String? id = map['id'];
      String name = map['name'];
      playlistsMap[name]!.navidromeId = id;
      playlistsMap[name]!.setNavidromeFile();
    }

    List<dynamic> embyPlaylists = jsonDecode(await _embyFile.readAsString());
    for (final map in embyPlaylists) {
      String? id = map['id'];
      String name = map['name'];
      playlistsMap[name]!.embyId = id;
      playlistsMap[name]!.setEmbyFile();
    }

    for (final playlist in playlists) {
      await playlist.load();
    }
  }

  Future<void> prepareForSync(SourceType sourceType) async {
    if (sourceType == .webdav) {
      if (webdavClient == null) {
        for (final playlist in playlists) {
          await playlist.webdavFile?.delete();
          playlist.webdavFile = null;
        }
      }
    } else if (sourceType == .navidrome) {
      for (final playlist in playlists) {
        playlist.navidromeId = null;
        await playlist.navidromeFile?.delete();
        playlist.navidromeFile = null;
      }
      if (navidromeClient != null) {
        final navidromePlaylists = await navidromeClient!.getPlaylists();
        for (final playlist in navidromePlaylists) {
          String id = playlist['id'];
          String name = playlist['name'];
          if (playlistsMap[name] == null) {
            addPlaylist(Playlist(name: name));
          }
          playlistsMap[name]!.navidromeId = id;
          playlistsMap[name]!.setNavidromeFile();
        }
      }
    } else if (sourceType == .emby) {
      for (final playlist in playlists) {
        playlist.embyId = null;
        await playlist.embyFile?.delete();
        playlist.embyFile = null;
      }
      if (embyClient != null) {
        final embyPlaylists = await embyClient!.getPlaylists();
        for (final playlist in embyPlaylists) {
          String id = playlist['Id'];
          String name = playlist['Name'];
          if (playlistsMap[name] == null) {
            addPlaylist(Playlist(name: name));
          }
          playlistsMap[name]!.embyId = id;
          playlistsMap[name]!.setEmbyFile();
        }
      }
    }

    for (final playlist in playlists) {
      playlist.songListManager.prepareForSync(sourceType);
    }
  }

  Future<void> sync(SourceType sourceType) async {
    for (final playlist in playlists) {
      await playlist.sync(sourceType);
      playlist.songListManager.resetSourceType();
    }
    update();
  }

  Playlist getPlaylistByIndex(int index) {
    assert(index >= 0 && index < playlists.length);
    return playlists[index];
  }

  Playlist? getPlaylistByName(String name) {
    return playlistsMap[name];
  }

  void addPlaylist(Playlist playlist) {
    playlists.add(playlist);
    playlistsMap[playlist.name] = playlist;
  }

  Future<void> createPlaylist(String name) async {
    for (Playlist playlist in playlists) {
      // check whether the name exists
      if (name == playlist.name) {
        return;
      }
    }

    addPlaylist(Playlist(name: name));

    update();
  }

  Future<void> deletePlaylist(Playlist playlist) async {
    playlist.localFile.deleteSync();
    playlist.webdavFile?.deleteSync();
    playlist.navidromeFile?.deleteSync();
    playlist.embyFile?.deleteSync();
    playlist._settingFile.deleteSync();
    if (playlist.navidromeId != null) {
      await navidromeClient!.deletePlaylist(playlist.navidromeId!);
    }
    if (playlist.embyId != null) {
      await embyClient!.deletePlaylist(playlist.embyId!);
    }
    playlists.remove(playlist);
    playlistsMap.remove(playlist.name);

    update();
  }

  void update() {
    _localFile.writeAsStringSync(
      jsonEncode(playlists.map((pl) => pl.name).toList()),
    );
    _webdavFile.writeAsStringSync(
      jsonEncode(
        playlists
            .where((pl) => pl.webdavFile != null)
            .map((pl) => pl.name)
            .toList(),
      ),
    );
    _navidromeFile.writeAsStringSync(
      jsonEncode(
        playlists
            .where((pl) => pl.navidromeFile != null)
            .map((pl) => {'id': pl.navidromeId, 'name': pl.name})
            .toList(),
      ),
    );
    _embyFile.writeAsStringSync(
      jsonEncode(
        playlists
            .where((pl) => pl.embyFile != null)
            .map((pl) => {'id': pl.embyId, 'name': pl.name})
            .toList(),
      ),
    );
    updateNotifier.value++;
  }

  void clear() {
    playlists.clear();
    playlistsMap.clear();
  }
}

class Playlist {
  String name;

  String? navidromeId;
  String? embyId;

  late File localFile;
  File? webdavFile;
  File? navidromeFile;
  File? embyFile;

  late File _settingFile;

  SongListManager songListManager = SongListManager();

  late bool isFavorite;
  late bool isNotFavorite;

  Playlist({required this.name}) {
    localFile = File("${getPlaylistConfigPath(.local)}/$name.json");
    initFile(localFile, true);

    _settingFile = File(
      "${getPlaylistConfigPath(.local)}/${name}_setting.json",
    );

    if (!_settingFile.existsSync()) {
      saveSetting();
    } else {
      loadSetting();
    }

    isFavorite = name == 'Favorite';
    isNotFavorite = !isFavorite;
  }

  void setWebdavFile() {
    webdavFile = File("${getPlaylistConfigPath(.webdav)}/$name.json");
    initFile(webdavFile!, true);
  }

  void setNavidromeFile() {
    navidromeFile = File("${getPlaylistConfigPath(.navidrome)}/$name.json");
    initFile(navidromeFile!, true);
  }

  void setEmbyFile() {
    embyFile = File("${getPlaylistConfigPath(.emby)}/$name.json");
    initFile(embyFile!, true);
  }

  MyAudioMetadata? getCoverSong() {
    return getFirstSong(songListManager.getSongList());
  }

  int get totalCount => songListManager.totalCount;

  Future<void> _load(SourceType sourceType) async {
    late File? file;
    switch (sourceType) {
      case .local:
        file = localFile;
        break;
      case .webdav:
        file = webdavFile;
        break;
      case .navidrome:
        file = navidromeFile;
        break;
      default:
        file = embyFile;
        break;
    }
    if (file == null) {
      return;
    }
    final contents = await file.readAsString();
    List<dynamic> decoded = jsonDecode(contents);
    for (String id in decoded) {
      MyAudioMetadata? song = library.id2Song[id];
      if (song == null) {
        continue;
      }
      songListManager.getSongList2(sourceType).add(song);
      if (isFavorite) {
        song.isFavoriteNotifier.value = true;
      }
    }
    songListManager.getChangeNotifier2(sourceType).value++;
  }

  Future<void> load() async {
    await _load(.local);
    await _load(.webdav);
    await _load(.navidrome);
    await _load(.emby);

    songListManager.resetSourceType();
  }

  Future<void> sync(SourceType sourceType) async {
    switch (sourceType) {
      case .local:
        await _load(sourceType);
        break;
      case .webdav:
        if (webdavFile == null) {
          return;
        }
        await _load(sourceType);
        break;
      case .navidrome:
        if (navidromeClient == null || (isNotFavorite && navidromeId == null)) {
          return;
        }
        List<String> songIds = [];
        if (isFavorite) {
          songIds = await navidromeClient!.getFavoriteSongIds();
        } else {
          songIds = await navidromeClient!.getPlaylistSongIds(navidromeId!);
        }

        for (final songId in songIds) {
          final song = library.id2Song[songId];
          if (song == null) {
            continue;
          }
          songListManager.navidromeSongList.add(song);
          if (isFavorite) {
            song.isFavoriteNotifier.value = true;
          }
        }
        break;
      default:
        if (embyClient == null || (isNotFavorite && embyId == null)) {
          return;
        }
        List<String> songIds = [];
        if (embyClient != null) {
          if (isFavorite) {
            songIds = await embyClient!.getFavoriteSongIds();
          } else if (embyId != null) {
            songIds = await embyClient!.getPlaylistItems(embyId!);
          }
        }
        for (final songId in songIds) {
          final song = library.id2Song[songId];
          if (song == null) {
            continue;
          }
          songListManager.embySongList.add(song);
          if (isFavorite) {
            song.isFavoriteNotifier.value = true;
          }
        }
        break;
    }

    await update(getSourceTypeBitMask(sourceType));
  }

  Future<void> add(List<MyAudioMetadata> songList) async {
    int sourceTypeBitMask = 0;

    for (MyAudioMetadata song in songList) {
      final targetSongList = songListManager.getSongList2(song.sourceType);
      if (targetSongList.contains(song)) {
        continue;
      }
      targetSongList.insert(0, song);

      if (isFavorite) {
        song.isFavoriteNotifier.value = true;
      }

      sourceTypeBitMask |= getSourceTypeBitMask(song.sourceType);
    }
    await update(sourceTypeBitMask);
  }

  Future<void> remove(List<MyAudioMetadata> songList) async {
    int sourceTypeBitMask = 0;
    for (MyAudioMetadata song in songList) {
      final targetSongList = songListManager.getSongList2(song.sourceType);
      targetSongList.remove(song);

      if (isFavorite) {
        song.isFavoriteNotifier.value = false;
      }

      sourceTypeBitMask |= getSourceTypeBitMask(song.sourceType);
    }
    await update(sourceTypeBitMask);
  }

  Future<void> update(int sourceTypeBitMask) async {
    if ((sourceTypeBitMask & 1) == 1) {
      songListManager.localChangeNotifier.value++;
      await localFile.writeAsString(
        jsonEncode(songListManager.localSongList.map((e) => e.id).toList()),
      );
    }

    if ((sourceTypeBitMask & 2) == 2) {
      songListManager.webdavChangeNotifier.value++;
      if (webdavFile == null) {
        setWebdavFile();
      }
      await webdavFile!.writeAsString(
        jsonEncode(songListManager.webdavSongList.map((e) => e.id).toList()),
      );
    }

    if ((sourceTypeBitMask & 4) == 4) {
      songListManager.navidromeChangeNotifier.value++;
      if (navidromeClient != null) {
        if (isFavorite) {
          await navidromeClient!.unstarAllSongs();
          await navidromeClient!.starSongs(
            songListManager.navidromeSongList
                .map((e) => e.id)
                .toList()
                .reversed
                .toList(),
          );
        } else {
          if (navidromeId != null) {
            await navidromeClient!.deletePlaylist(navidromeId!);
          }
          navidromeId = await navidromeClient!.createPlaylistAndGetId(name);
          if (navidromeId != null) {
            await navidromeClient!.addSongsToPlaylist(
              navidromeId!,
              songListManager.navidromeSongList.map((e) => e.id).toList(),
            );
          }
        }
        if (navidromeFile == null) {
          setNavidromeFile();
        }
        await navidromeFile!.writeAsString(
          jsonEncode(
            songListManager.navidromeSongList.map((e) => e.id).toList(),
          ),
        );
      }
    }

    if ((sourceTypeBitMask & 8) == 8) {
      songListManager.embyChangeNotifier.value++;
      if (embyClient != null) {
        if (isFavorite) {
          await embyClient!.rebuildFavorites(
            songListManager.embySongList
                .map((e) => e.id)
                .toList()
                .reversed
                .toList(),
          );
        } else {
          if (embyId != null) {
            await embyClient!.deletePlaylist(embyId!);
          }
          embyId = await embyClient?.createPlaylist(
            name: name,
            songIds: songListManager.embySongList.map((e) => e.id).toList(),
          );
        }
        if (embyFile == null) {
          setEmbyFile();
        }
        await embyFile!.writeAsString(
          jsonEncode(songListManager.embySongList.map((e) => e.id).toList()),
        );
      }
    }

    songListManager.resetSourceType();

    layersManager.updateBackground();
  }

  void loadSetting() {
    final content = _settingFile.readAsStringSync();
    final Map<String, dynamic> json =
        jsonDecode(content) as Map<String, dynamic>;

    songListManager.localSortTypeNotifier.value =
        json['localSortType'] as int? ?? 0;
    songListManager.webdavSortTypeNotifier.value =
        json['webdavSortType'] as int? ?? 0;
    songListManager.navidromeSortTypeNotifier.value =
        json['navidromeSortType'] as int? ?? 0;
    songListManager.embySortTypeNotifier.value =
        json['embySortType'] as int? ?? 0;
  }

  void saveSetting() {
    _settingFile.writeAsStringSync(
      jsonEncode({
        'sortType': songListManager.localSortTypeNotifier.value,
        'wevdavSortType': songListManager.navidromeSortTypeNotifier.value,
        'navidromeSortType': songListManager.navidromeSortTypeNotifier.value,
        'embySortType': songListManager.embySortTypeNotifier.value,
      }),
    );
  }
}

void toggleFavoriteState(MyAudioMetadata song) {
  final favorite = playlistManager.playlists.first;
  final isFavorite = song.isFavoriteNotifier;
  if (isFavorite.value) {
    favorite.remove([song]);
  } else {
    favorite.add([song]);
  }
}
