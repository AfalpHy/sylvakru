import 'dart:typed_data';

import 'package:audio_tags_lofty/audio_tags_lofty.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/base/app.dart';
import 'package:particle_music/base/utils/lyric.dart';

class MyAudioMetadata {
  final String id;

  String? path;
  DateTime? modified;

  final SourceType sourceType;

  final AudioMetadata _audioMetadata;

  bool pictureLoaded = false;
  Color? coverArtColor;
  Color? lowerLuminance;
  ParsedLyrics? parsedLyrics;

  String? navidromeUrl;
  String? embyUrl;

  String? navidromeCachePath;
  String? webdavCachePath;
  String? embyCachePath;

  final isFavoriteNotifier = ValueNotifier(false);
  final updateNotifier = ValueNotifier(0);

  int playCount;
  DateTime? lastPlayed;

  MyAudioMetadata(
    this._audioMetadata, {
    required this.id,
    this.path,
    this.modified,
    this.sourceType = .local,
    this.playCount = 0,
    this.lastPlayed,
  });

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

  Uint8List? get pictureBytes => _audioMetadata.pictureBytes;

  bool get noPicture => pictureLoaded && pictureBytes == null;

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
  set pictureBytes(Uint8List? value) => _audioMetadata.pictureBytes = value;

  factory MyAudioMetadata.fromNavidromeMap(Map<String, dynamic> song) {
    return MyAudioMetadata(
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
      sourceType: .navidrome,
      id: song['id'],
      playCount: song['playCount'] as int? ?? 0,
      lastPlayed: song['played'] != null
          ? DateTime.parse(song['played'])
          : null,
    );
  }

  factory MyAudioMetadata.fromEmbyMap(Map<String, dynamic> song) {
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
            (song['ArtistItems'] as List?)?.map((a) => a['Name']).join(', ') ??
            (song['Artists'] as List?)?.join(', '),

        album: song['Album'],

        albumArtist: song['AlbumArtist'],

        genre: (song['Genres'] as List?)?.join(', '),

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

      sourceType: SourceType.emby,

      id: song['Id'],

      playCount: song['UserData']?['PlayCount'] as int? ?? 0,

      lastPlayed: song['UserData']?['LastPlayedDate'] != null
          ? DateTime.parse(song['UserData']['LastPlayedDate'])
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  @override
  String toString() {
    return "$_audioMetadata\n"
        "playCount:$playCount\n"
        "lastPlayed:$lastPlayed";
  }
}
