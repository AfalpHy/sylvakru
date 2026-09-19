import 'dart:convert';
import 'dart:io';

import 'package:audio_tags_lofty/audio_tags_lofty.dart';
import 'package:crypto/crypto.dart';
import 'package:lpinyin/lpinyin.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/data/library.dart';
import 'package:sylvakru/base/services/lyric.dart';
import 'package:sylvakru/base/services/picture_service.dart';
import 'package:sylvakru/base/utils/metadata_utils.dart';
import 'package:sylvakru/base/utils/path.dart';

class MyAudioMetadata {
  final String id;
  final String? coverId;

  String? path;
  DateTime? modified;

  final AudioMetadata _audioMetadata;

  late MyPicture picture;

  ParsedLyrics? parsedLyrics;

  bool cacheExist = false;
  String? cachePath;

  final isFavoriteNotifier = ValueNotifier(false);
  final updateNotifier = ValueNotifier(0);

  int playCount;
  DateTime? lastPlayed;

  late String compareTitle;
  late String compareArtist;
  late String compareAlbum;

  MyAudioMetadata(
    this._audioMetadata, {
    required this.id,
    this.coverId,
    this.path,
    this.modified,
    this.playCount = 0,
    this.lastPlayed,
  }) {
    picture = MyPicture.form(isStreamSource ? coverId ?? id : path!);

    final md5Hash = md5.convert(utf8.encode(id)).toString();
    if (sourceType != .local) {
      cachePath = '${getCachesPath(sourceType)}/$md5Hash';
      cacheExist = File(cachePath!).existsSync();
    }

    compareTitle = PinyinHelper.getPinyinE(getTitle(this));
    compareArtist = PinyinHelper.getPinyinE(getArtist(this));
    compareAlbum = PinyinHelper.getPinyinE(getAlbum(this));
  }

  String? get format => _audioMetadata.format;
  String? get title => _audioMetadata.title;
  String? get artist => _audioMetadata.artist;
  String? get album => _audioMetadata.album;
  String? get albumArtist => _audioMetadata.albumArtist;
  String? get genre => _audioMetadata.genre;

  int? get year => _audioMetadata.year;
  int? get track => _audioMetadata.track;
  int? get disc => _audioMetadata.disc;
  int? get bitrate => _audioMetadata.bitrate;
  int? get samplerate => _audioMetadata.samplerate;

  Duration? get duration => _audioMetadata.duration;

  String? get lyrics => _audioMetadata.lyrics;

  set title(String? value) => _audioMetadata.title = value;
  set artist(String? value) => _audioMetadata.artist = value;
  set album(String? value) => _audioMetadata.album = value;
  set albumArtist(String? value) => _audioMetadata.albumArtist = value;
  set genre(String? value) => _audioMetadata.genre = value;

  set year(int? value) => _audioMetadata.year = value;
  set track(int? value) => _audioMetadata.track = value;
  set disc(int? value) => _audioMetadata.disc = value;
  set bitrate(int? value) => _audioMetadata.bitrate = value;
  set samplerate(int? value) => _audioMetadata.samplerate = value;

  set lyrics(String? value) => _audioMetadata.lyrics = value;
  set duration(Duration? value) => _audioMetadata.duration = value;

  factory MyAudioMetadata.fromMap(
    Map<String, dynamic> song,
    SourceType sourceType,
  ) {
    if (sourceType == .navidrome) {
      return library.id2Song.putIfAbsent(
        song['id'],
        () => MyAudioMetadata(
          AudioMetadata(
            format: (song['contentType'] as String?)?.split('audio/').last,
            title: song['title'],
            artist: song['artist'],
            album: song['album'],
            albumArtist: song['displayAlbumArtist'],
            genre: song['genre'],
            year: song['year'],
            track: song['track'],
            disc: song['discNumber'],
            bitrate: song['bitRate'],
            samplerate: song['samplingRate'],
            duration: song['duration'] != null
                ? Duration(seconds: song['duration'])
                : null,
          ),
          id: song['id'],
          path: song['path'],
          playCount: song['playCount'] as int? ?? 0,
          lastPlayed: song['played'] != null
              ? DateTime.parse(song['played'])
              : null,
        ),
      );
    }

    if (sourceType == .feiniu) {
      return library.id2Song.putIfAbsent(song['guid'], () {
        final audioSpec = song['audioSpec'] as Map? ?? const {};
        final album = song['album'] as Map? ?? const {};
        final artists = (song['artists'] as List?) ?? const [];
        final genres = (song['genres'] as List?) ?? const [];
        final durationMs = (song['duration'] ?? audioSpec['duration']) as num?;
        final bitrate = audioSpec['bitrate'] as num?;
        final releaseDate = DateTime.tryParse(album['releaseDate'] ?? '');

        return MyAudioMetadata(
          AudioMetadata(
            format: audioSpec['format'],
            title: song['title'],
            artist: artists.map((artist) => artist['name']).join('/'),
            album: album['name'],
            genre: genres.map((genre) => genre['name']).join('/'),
            year: (song['year'] as num?)?.toInt() ?? releaseDate?.year,
            track: (song['trackNo'] as num?)?.toInt(),
            disc: (song['discNo'] as num?)?.toInt(),
            // 飞牛时长为毫秒、码率为 bps；播放器码率统一使用 kbps。
            bitrate: bitrate == null ? null : (bitrate / 1000).round(),
            samplerate: (audioSpec['sampleRate'] as num?)?.toInt(),
            duration: durationMs == null
                ? null
                : Duration(milliseconds: durationMs.toInt()),
          ),
          id: song['guid'],
          coverId: song['coverId'],
          path: audioSpec['path'],
        );
      });
    }

    return library.id2Song.putIfAbsent(song['Id'], () {
      final mediaSources = (song['MediaSources'] as List?) ?? [];
      final primarySource = mediaSources.isNotEmpty ? mediaSources.first : null;
      final streams = (primarySource?['MediaStreams'] as List?) ?? [];

      final audioStream = streams.firstWhere(
        (s) => s['Type'] == 'Audio',
        orElse: () => null,
      );

      final lyricStream = streams.firstWhere(
        (s) => s['Type'] == 'Subtitle',
        orElse: () => null,
      );
      return MyAudioMetadata(
        AudioMetadata(
          format: audioStream?['Codec'] ?? primarySource?['Container'],

          title: song['Name'],

          artist:
              (song['ArtistItems'] as List?)?.map((a) => a['Name']).join('/') ??
              (song['Artists'] as List?)?.join('/'),

          album: song['Album'],

          albumArtist: song['AlbumArtist'],

          genre: (song['Genres'] as List?)?.join('/'),

          year: song['ProductionYear'],

          track: song['IndexNumber'],

          disc: song['ParentIndexNumber'],

          bitrate: audioStream?['BitRate'] ?? primarySource?['Bitrate'],

          samplerate: audioStream?['SampleRate'],

          duration: song['RunTimeTicks'] != null
              ? Duration(microseconds: song['RunTimeTicks'] ~/ 10)
              : null,

          lyrics: lyricStream?['Extradata'],
        ),

        id: song['Id'],

        playCount: song['UserData']?['PlayCount'] as int? ?? 0,

        lastPlayed: song['UserData']?['LastPlayedDate'] != null
            ? DateTime.parse(song['UserData']['LastPlayedDate'])
            : DateTime.fromMillisecondsSinceEpoch(0),
      );
    });
  }

  @override
  String toString() {
    return "$_audioMetadata\n"
        "playCount:$playCount\n"
        "lastPlayed:$lastPlayed";
  }
}
