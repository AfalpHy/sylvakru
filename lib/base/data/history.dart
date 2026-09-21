import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/services/emby_client.dart';
import 'package:sylvakru/base/services/feiniu_client.dart';
import 'package:sylvakru/base/services/stream_client.dart';
import 'package:sylvakru/layer/layers_manager.dart';
import 'package:sylvakru/base/data/library.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';

final history = History();

class History {
  final List<MyAudioMetadata> frequentlySongList = [];
  final List<MyAudioMetadata> recentlySongList = [];
  final frequentlyChangeNotifier = ValueNotifier(0);
  final recentlyChangeNotifier = ValueNotifier(0);

  Future<void> load() async {
    if (sourceType == .emby) {
      frequentlySongList.addAll(
        await (streamClient as EmbyClient?)?.getFrequentlySongs() ?? [],
      );
      frequentlyChangeNotifier.value++;

      recentlySongList.addAll(
        await (streamClient as EmbyClient?)?.getRecentlySongs() ?? [],
      );
      recentlyChangeNotifier.value++;
      return;
    }

    for (final song in library.songList) {
      if (song.playCount > 0 && song.lastPlayed != null) {
        frequentlySongList.add(song);
        if (sourceType != .feiniu) {
          recentlySongList.add(song);
        }
      }
    }

    frequentlySongList.sort((a, b) {
      int tmp = b.playCount.compareTo(a.playCount);
      return tmp != 0 ? tmp : a.lastPlayed!.compareTo(b.lastPlayed!);
    });

    if (sourceType != .feiniu) {
      recentlySongList.sort((a, b) => b.lastPlayed!.compareTo(a.lastPlayed!));
    } else {
      recentlySongList.addAll(
        await (streamClient as FeiniuClient?)?.getRecentlySongs() ?? [],
      );
    }

    frequentlyChangeNotifier.value++;
    recentlyChangeNotifier.value++;
  }

  void _addSongTimes(MyAudioMetadata song, int times) {
    int index = frequentlySongList.indexOf(song);

    song.playCount += times;

    if (index == -1) {
      frequentlySongList.add(song);
      index = frequentlySongList.length - 1;
    }

    for (int i = index - 1; i >= 0; i--) {
      if (frequentlySongList[i].playCount < song.playCount) {
        frequentlySongList[i + 1] = frequentlySongList[i];
        index = i;
      } else {
        break;
      }
    }
    frequentlySongList[index] = song;
    frequentlyChangeNotifier.value++;
  }

  Future<void> addSongTimes(MyAudioMetadata song, int times) async {
    _add2Recently(song);
    if (sourceType != .emby) {
      _addSongTimes(song, times);
      song.lastPlayed = DateTime.now();
      await library.updatePlayCount(song);
    }

    if (isStreamSource) {
      while (times-- > 0) {
        await streamClient?.scrobble(song.id);
      }
    }

    if (sourceType == .emby) {
      final songs = await (streamClient as EmbyClient?)?.getFrequentlySongs();
      if (songs?.isNotEmpty ?? false) {
        frequentlySongList.clear();
        frequentlySongList.addAll(songs!);
        frequentlyChangeNotifier.value++;
      }
    }

    layersManager.updateBackground();
  }

  void _add2Recently(MyAudioMetadata song) {
    recentlySongList.remove(song);
    recentlySongList.insert(0, song);
    if (sourceType == .emby || sourceType == .feiniu) {
      if (recentlySongList.length > 100) {
        recentlySongList.removeRange(100, recentlySongList.length);
      }
    }
    recentlyChangeNotifier.value++;
  }

  void clear() {
    frequentlySongList.clear();
    recentlySongList.clear();
  }
}
