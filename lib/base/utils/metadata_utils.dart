import 'package:lpinyin/lpinyin.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:path/path.dart';

String getTitle(MyAudioMetadata? song) {
  if (song == null) {
    return '';
  }
  if (song.title == null || song.title == '') {
    return basename(song.id);
  }
  return song.title!;
}

String getArtist(MyAudioMetadata? song) {
  if (song == null) {
    return '';
  }
  if (song.artist == null || song.artist == '') {
    return 'Unknown Artist';
  }
  return song.artist!;
}

List<String> getArtists(String artist) {
  List<String> artists = [];
  for (String artistName in artist.split(RegExp(r'[/&,]'))) {
    if (artistName.isEmpty) {
      return [artist];
    }
    artists.add(artistName);
  }
  return artists;
}

String getAlbum(MyAudioMetadata? song) {
  if (song == null) {
    return '';
  }
  if (song.album == null || song.album == '') {
    return 'Unknown Album';
  }
  return song.album!;
}

String getAlbumArtist(MyAudioMetadata? song) {
  if (song == null) {
    return '';
  }
  if (song.albumArtist == null || song.albumArtist == '') {
    return 'Unknown Album Artist';
  }
  return song.albumArtist!;
}

String getGenre(MyAudioMetadata? song) {
  if (song == null) {
    return '';
  }
  if (song.genre == null || song.genre == '') {
    return 'Unknown Genre';
  }
  return song.genre!;
}

Duration getDuration(MyAudioMetadata? song) {
  if (song == null) {
    return Duration.zero;
  }
  return song.duration ?? Duration.zero;
}

List<MyAudioMetadata> filterSongList(
  List<MyAudioMetadata> songList,
  String value,
) {
  return songList.where((song) {
    final songTitle = getTitle(song);
    final songArtist = getArtist(song);
    final songAlbum = getAlbum(song);

    return value.isEmpty ||
        songTitle.toLowerCase().contains(value.toLowerCase()) ||
        songArtist.toLowerCase().contains(value.toLowerCase()) ||
        songAlbum.toLowerCase().contains(value.toLowerCase());
  }).toList();
}

void sortSongList(int sortType, List<MyAudioMetadata> songList) {
  switch (sortType) {
    case 1: // Title Ascending
      songList.sort((a, b) {
        return compareMixed(getTitle(a), getTitle(b));
      });
      break;
    case 2: // Title Descending
      songList.sort((a, b) {
        return compareMixed(getTitle(b), getTitle(a));
      });
      break;
    case 3: // Artist Ascending
      songList.sort((a, b) {
        return compareMixed(getArtist(a), getArtist(b));
      });
      break;
    case 4: // Artist Descending
      songList.sort((a, b) {
        return compareMixed(getArtist(b), getArtist(a));
      });
      break;
    case 5: // Album Ascending
      songList.sort((a, b) {
        return compareMixed(getAlbum(a), getAlbum(b));
      });
      break;
    case 6: // Album Descending
      songList.sort((a, b) {
        return compareMixed(getAlbum(b), getAlbum(a));
      });
      break;
    case 7: // Duration Ascending
      songList.sort((a, b) {
        return a.duration!.compareTo(b.duration!);
      });
      break;
    case 8: // Duration Descending
      songList.sort((a, b) {
        return b.duration!.compareTo(a.duration!);
      });
      break;
    case 9: // modified time Ascending
      songList.sort((a, b) {
        return a.modified!.compareTo(b.modified!);
      });
    case 10: // modified time Descending
      songList.sort((a, b) {
        return b.modified!.compareTo(a.modified!);
      });
    case 11:
      songList.shuffle();
      break;
    default:
      break;
  }
}

bool _isEnglish(String s) {
  final c = s[0];
  return RegExp(r'^[A-Za-z]').hasMatch(c);
}

int compareMixed(String a, String b) {
  final aIsEng = _isEnglish(a);
  final bIsEng = _isEnglish(b);

  if (aIsEng && !bIsEng) return -1;
  if (!aIsEng && bIsEng) return 1;

  if (aIsEng && bIsEng) {
    return a.toLowerCase().compareTo(b.toLowerCase());
  }

  final pa = PinyinHelper.getPinyinE(a);
  final pb = PinyinHelper.getPinyinE(b);
  return pa.compareTo(pb);
}

MyAudioMetadata? getFirstSong(List<MyAudioMetadata> songList) {
  if (songList.isEmpty) {
    return null;
  }
  return songList.first;
}
