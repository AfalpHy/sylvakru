import 'dart:convert';
import 'dart:io';

import 'package:audio_tags_lofty/audio_tags_lofty.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as image;
import 'package:lpinyin/lpinyin.dart';
import 'package:particle_music/base/services/emby_client.dart';
import 'package:particle_music/base/services/webdav_client.dart';
import 'package:particle_music/base/utils/logger.dart';
import 'package:particle_music/base/my_audio_metadata.dart';
import 'package:particle_music/base/services/navidrome_client.dart';
import 'package:particle_music/base/utils/picture_load_scheduler.dart';
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

Uint8List? getPictureBytes(MyAudioMetadata? song) {
  return song?.pictureBytes;
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

Future<Uint8List?> loadPictureBytesSafe(MyAudioMetadata? song) async {
  if (song == null) {
    return null;
  }

  if (song.pictureLoaded) {
    return song.pictureBytes;
  }

  return pictureLoadScheduler.load(song.id, () => _loadPictureBytes(song));
}

Future<Uint8List?> _loadPictureBytes(MyAudioMetadata song) async {
  try {
    late Uint8List? result;
    if (song.sourceType == .navidrome) {
      if (song.navidromeCachePath != null) {
        result = await readPictureAsync(song.navidromeCachePath!);
      } else {
        result = await navidromeClient!.getPictureBytes(song.id);
      }
    } else if (song.sourceType == .webdav) {
      if (song.webdavCachePath != null) {
        result = await readPictureAsync(song.webdavCachePath!);
      } else {
        result = await readPictureAsync(
          song.path!,
          headers: webdavClient?.headers,
        );
      }
    } else if (song.sourceType == .emby) {
      result = await embyClient!.getPictureBytes(song.id);
    } else {
      result = await readPictureAsync(song.path!);
    }

    song.pictureBytes = result;
    song.pictureLoaded = true;
    return result;
  } catch (e) {
    song.pictureBytes = null;
    song.pictureLoaded = true;
    logger.output(e.toString());
  }
  return null;
}

Future<Color> computeCoverArtColor(MyAudioMetadata? song) async {
  if (song?.coverArtColor != null) {
    return song!.coverArtColor!;
  }
  final bytes = await loadPictureBytesSafe(song);
  if (bytes == null) {
    song?.coverArtColor = Colors.grey;
    return Colors.grey;
  }

  final decoded = image.decodeImage(bytes);
  if (decoded == null) {
    song?.coverArtColor = Colors.grey;
    return Colors.grey;
  }

  // simple average of top pixels
  double r = 0, g = 0, b = 0, count = 0;
  for (int y = 0; y < decoded.height; y += 5) {
    for (int x = 0; x < decoded.width; x += 5) {
      final pixel = decoded.getPixel(x, y);
      if (pixel.a == 0) {
        r += 128;
        g += 128;
        b += 128;
      } else {
        r += pixel.r.toDouble();
        g += pixel.g.toDouble();
        b += pixel.b.toDouble();
      }

      count++;
    }
  }
  r /= count;
  g /= count;
  b /= count;
  final color = Color.fromARGB(255, r.toInt(), g.toInt(), b.toInt());
  song!.coverArtColor = color;

  int luminance = image.getLuminanceRgb(r, g, b).toInt();
  int maxLuminace = 200;
  if (luminance > maxLuminace) {
    r -= luminance - maxLuminace;
    g -= luminance - maxLuminace;
    b -= luminance - maxLuminace;
    song.lowerLuminance = Color.fromARGB(255, r.toInt(), g.toInt(), b.toInt());
  }

  return color;
}

MyAudioMetadata? getFirstSong(List<MyAudioMetadata> songList) {
  if (songList.isEmpty) {
    return null;
  }
  return songList.first;
}

Future<void> setSongList(
  File songIdListFile,
  List<MyAudioMetadata> destList,
  Map<String, MyAudioMetadata> id2Song,
) async {
  final idSet = id2Song.keys.toSet();

  final jsonString = await songIdListFile.readAsString();
  final List<dynamic> songIdList = jsonDecode(jsonString);
  for (final id in songIdList) {
    final song = id2Song[id];
    if (song != null) {
      idSet.remove(id);
      destList.add(song);
    }
  }
  for (final id in idSet) {
    destList.add(id2Song[id]!);
  }
}
