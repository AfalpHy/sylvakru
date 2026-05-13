import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:particle_music/base/app.dart';
import 'package:particle_music/base/data/song_list_manager.dart';
import 'package:particle_music/base/utils/io.dart';
import 'package:particle_music/base/utils/metadata.dart';
import 'package:particle_music/layer/layers_manager.dart';
import 'package:particle_music/base/data/library.dart';
import 'package:particle_music/base/my_audio_metadata.dart';
import 'package:particle_music/base/services/navidrome_client.dart';

final playlistManager = PlaylistManager();

class PlaylistManager {
  late File localFile;
  late File webdavFile;

  List<Playlist> playlists = [];
  Map<String, Playlist> playlistsMap = {};
  ValueNotifier<int> updateNotifier = ValueNotifier(0);
  final useLargePictureNotifier = ValueNotifier(true);

  Future<void> initAllPlaylists() async {
    localFile = File(
      "${localPlaylistConfigDir.path}/particle_music_playlists.json",
    );
    if (!(localFile.existsSync())) {
      localFile.writeAsStringSync(jsonEncode(['Favorite']));
    }

    webdavFile = File(
      "${webdavPlaylistConfigDir.path}/particle_music_playlists.json",
    );
    initFile(webdavFile, true);
  }

  Future<void> load() async {
    List<dynamic> localPlaylists = jsonDecode(await localFile.readAsString());
    for (String name in localPlaylists) {
      addPlaylist(Playlist(name: name));
    }

    List<dynamic> webdavPlaylits = jsonDecode(await webdavFile.readAsString());
    for (String name in webdavPlaylits) {
      if (playlistsMap[name] == null) {
        addPlaylist(Playlist(name: name));
      }
      playlistsMap[name]!.setWebdavFile();
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
      }
    }
    update();
    for (final playlist in playlists) {
      await playlist.load();
    }
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
    playlist.settingFile.deleteSync();
    if (playlist.navidromeId != null) {
      await navidromeClient?.deletePlaylist(playlist.navidromeId!);
    }
    playlists.remove(playlist);
    playlistsMap.remove(playlist.name);

    update();
  }

  void update() {
    localFile.writeAsStringSync(
      jsonEncode(playlists.map((pl) => pl.name).toList()),
    );
    webdavFile.writeAsStringSync(
      jsonEncode(
        playlists
            .where((pl) => pl.webdavFile != null)
            .map((pl) => pl.name)
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

  late File settingFile;

  ValueNotifier<int> changeNotifier = ValueNotifier(0);

  SongListManager songListManager = SongListManager();

  late bool isFavorite;
  late bool isNotFavorite;

  Playlist({required this.name}) {
    localFile = File("${localPlaylistConfigDir.path}/$name.json");
    initFile(localFile, true);
    settingFile = File("${localPlaylistConfigDir.path}/${name}_setting.json");

    if (!settingFile.existsSync()) {
      saveSetting();
    } else {
      loadSetting();
    }

    isFavorite = name == 'Favorite';
    isNotFavorite = !isFavorite;
  }

  void setWebdavFile() {
    webdavFile = File("${webdavPlaylistConfigDir.path}/$name.json");
    initFile(webdavFile!, true);
  }

  MyAudioMetadata? getCoverSong() {
    return getFirstSong(songListManager.getSongList());
  }

  int get totalCount => songListManager.totalCount;

  Future<void> _loadLocal() async {
    final contents = await localFile.readAsString();
    List<dynamic> decoded = jsonDecode(contents);
    for (String id in decoded) {
      MyAudioMetadata? song = library.id2Song[id];
      if (song == null) {
        continue;
      }
      songListManager.localSongList.add(song);
      if (isFavorite) {
        song.isFavoriteNotifier.value = true;
      }
    }
  }

  Future<void> _loadWebdav() async {
    if (webdavFile == null) {
      return;
    }
    final contents = await webdavFile!.readAsString();
    List<dynamic> decoded = jsonDecode(contents);
    for (String id in decoded) {
      MyAudioMetadata? song = library.id2Song[id];
      if (song == null) {
        continue;
      }
      songListManager.webdavSongList.add(song);
      if (isFavorite) {
        song.isFavoriteNotifier.value = true;
      }
    }
  }

  Future<void> _loadNavidrome() async {
    if (navidromeClient == null) {
      return;
    }
    List<String> songIds = [];
    if (isFavorite) {
      songIds = await navidromeClient!.getFavoriteSongIds();
    } else if (navidromeId != null) {
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
  }

  Future<void> _loadEmby() async {
    if (navidromeClient == null) {
      return;
    }
  }

  Future<void> load() async {
    await _loadLocal();
    await _loadWebdav();
    await _loadNavidrome();
    await _loadEmby();

    songListManager.resetSourceType();
  }

  Future<void> add(List<MyAudioMetadata> songList) async {
    for (MyAudioMetadata song in songList) {
      switch (song.sourceType) {
        case .local:
          if (songListManager.localSongList.contains(song)) {
            continue;
          }
          songListManager.localSongList.insert(0, song);
          break;
        case .webdav:
          break;
        case .navidrome:
          if (songListManager.navidromeSongList.contains(song)) {
            continue;
          }
          songListManager.navidromeSongList.insert(0, song);
          break;
        default:
          break;
      }
      if (isFavorite) {
        song.isFavoriteNotifier.value = true;
      }
    }
    await update();
  }

  Future<void> remove(List<MyAudioMetadata> songList) async {
    for (MyAudioMetadata song in songList) {
      if (song.sourceType == .navidrome) {
        songListManager.navidromeSongList.remove(song);
      } else {
        songListManager.localSongList.remove(song);
      }
      if (isFavorite) {
        song.isFavoriteNotifier.value = false;
      }
    }
    await update();
  }

  Future<void> update() async {
    // await file.writeAsString(
    //   jsonEncode(songListManager.localSongList.map((e) => e.id).toList()),
    // );
    // if (isFavorite) {
    //   await navidromeClient?.unstarAllSongs();
    //   await navidromeClient?.starSongs(
    //     songListManager.navidromeSongList
    //         .map((e) => e.id)
    //         .toList()
    //         .reversed
    //         .toList(),
    //   );
    // } else if (navidromeId != null ||
    //     songListManager.navidromeSongList.isNotEmpty) {
    //   if (navidromeId != null) {
    //     await navidromeClient!.deletePlaylist(navidromeId!);
    //   }
    //   navidromeId = await navidromeClient!.createPlaylistAndGetId(name);
    //   if (navidromeId != null) {
    //     await navidromeClient!.addSongsToPlaylist(
    //       navidromeId!,
    //       songListManager.navidromeSongList.map((e) => e.id).toList(),
    //     );
    //   }
    // }

    if (songListManager.getSongList().isEmpty) {
      songListManager.resetSourceType();
    }

    layersManager.updateBackground();
  }

  void loadSetting() {
    final content = settingFile.readAsStringSync();
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
    settingFile.writeAsStringSync(
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
