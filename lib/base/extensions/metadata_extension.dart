import 'dart:io';

import 'package:audio_tags_lofty/audio_tags_lofty.dart';
import 'package:drift/drift.dart';
import 'package:particle_music/base/app.dart';
import 'package:particle_music/base/data/database.dart';
import 'package:particle_music/base/my_audio_metadata.dart';
import 'package:particle_music/base/utils/io.dart';

extension MetadataItemMapper on MetadataItem {
  MyAudioMetadata toMetadata() {
    String path = id;

    final isWebdav = id.startsWith('http://') || id.startsWith('https://');

    if (!isWebdav && Platform.isIOS) {
      path = revertIOSPath(path);
    }

    return MyAudioMetadata(
      AudioMetadata(
        format: format,
        title: title,
        artist: artist,
        album: album,
        genre: genre,
        year: year,
        track: track,
        disc: disc,
        bitrate: bitrate,
        samplerate: samplerate,
        duration: duration != null ? Duration(milliseconds: duration!) : null,
        lyrics: lyrics,
      ),

      id: id,
      path: path,

      sourceType: isWebdav ? SourceType.webdav : SourceType.local,

      modified: modified != null
          ? DateTime.fromMillisecondsSinceEpoch(modified!)
          : null,

      playCount: playCount,

      lastPlayed: lastPlayed != null
          ? DateTime.fromMillisecondsSinceEpoch(lastPlayed!)
          : null,
    );
  }
}

extension MyAudioMetadataMapper on MyAudioMetadata {
  MetadataItemsCompanion toCompanion() {
    return MetadataItemsCompanion.insert(
      id: id,

      modified: Value(modified?.millisecondsSinceEpoch),

      format: Value(format),

      title: Value(title),
      artist: Value(artist),
      album: Value(album),
      genre: Value(genre),

      year: Value(year),
      track: Value(track),
      disc: Value(disc),

      bitrate: Value(bitrate),
      samplerate: Value(samplerate),

      duration: Value(duration?.inMilliseconds),

      lyrics: Value(lyrics),

      playCount: Value(playCount),

      lastPlayed: Value(lastPlayed?.millisecondsSinceEpoch),
    );
  }
}
