import 'package:particle_music/base/data/song_list_manager.dart';
import 'package:particle_music/layer/layers_manager.dart';
import 'package:particle_music/base/data/library.dart';
import 'package:particle_music/base/my_audio_metadata.dart';
import 'package:particle_music/base/services/navidrome_client.dart';

final History history = History();

class History {
  SongListManager rankingSongListManager = SongListManager();
  SongListManager recentlySongListManager = SongListManager();

  void fetchSongs(
    List<MyAudioMetadata> fromSongList,
    List<MyAudioMetadata> toRankingSongList,
    List<MyAudioMetadata> toRecentlySongList,
  ) {
    for (final song in fromSongList) {
      if (song.playCount > 0) {
        toRankingSongList.add(song);
        toRecentlySongList.add(song);
      }
    }
    toRankingSongList.sort((a, b) {
      int tmp = b.playCount.compareTo(a.playCount);
      return tmp != 0 ? tmp : a.lastPlayed!.compareTo(b.lastPlayed!);
    });

    toRecentlySongList.sort((a, b) => b.lastPlayed!.compareTo(a.lastPlayed!));
  }

  Future<void> load() async {
    fetchSongs(
      library.songListManager.localSongList,
      rankingSongListManager.localSongList,
      recentlySongListManager.localSongList,
    );

    fetchSongs(
      library.songListManager.webdavSongList,
      rankingSongListManager.webdavSongList,
      recentlySongListManager.webdavSongList,
    );

    fetchSongs(
      library.songListManager.navidromeSongList,
      rankingSongListManager.navidromeSongList,
      recentlySongListManager.navidromeSongList,
    );

    fetchSongs(
      library.songListManager.embySongList,
      rankingSongListManager.embySongList,
      recentlySongListManager.embySongList,
    );

    rankingSongListManager.resetSourceType();
    recentlySongListManager.resetSourceType();
  }

  void _addSongTimes(MyAudioMetadata song, int times) {
    final currentRankingSongList = rankingSongListManager.getSongList2(
      song.sourceType,
    );
    int index = -1;
    for (int i = 0; i < currentRankingSongList.length; i++) {
      if (song == currentRankingSongList[i]) {
        currentRankingSongList[i].playCount += times;
        index = i;
        break;
      }
    }

    if (index == -1) {
      song.playCount = 1;
      currentRankingSongList.add(song);
      index = currentRankingSongList.length - 1;
    }

    final tmp = currentRankingSongList[index];
    for (int i = index - 1; i >= 0; i--) {
      if (currentRankingSongList[i].playCount < tmp.playCount) {
        currentRankingSongList[i + 1] = currentRankingSongList[i];
        index = i;
      } else {
        break;
      }
    }
    currentRankingSongList[index] = tmp;
  }

  Future<void> addSongTimes(MyAudioMetadata song, int times) async {
    _addSongTimes(song, times);

    switch (song.sourceType) {
      case .local:
      case .webdav:
        await library.updatePlayCount(song);
        break;
      case .navidrome:
        while (times-- > 0) {
          await navidromeClient!.scrobble(song.id);
        }
        break;
      default:
        break;
    }
    rankingSongListManager.getChangeNotifier2(song.sourceType).value++;

    _add2Recently(song);

    layersManager.updateBackground();
  }

  void _add2Recently(MyAudioMetadata song) {
    final songList = recentlySongListManager.getSongList2(song.sourceType);
    songList.remove(song);
    songList.insert(0, song);
    recentlySongListManager.getChangeNotifier2(song.sourceType).value++;
  }

  void clear() {
    rankingSongListManager.clear();
    recentlySongListManager.clear();
  }
}
