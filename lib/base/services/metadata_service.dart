import 'dart:typed_data';

import 'package:audio_tags_lofty/audio_tags_lofty.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as image;
import 'package:particle_music/base/my_audio_metadata.dart';
import 'package:particle_music/base/services/emby_client.dart';
import 'package:particle_music/base/services/navidrome_client.dart';
import 'package:particle_music/base/services/webdav_client.dart';
import 'package:particle_music/base/services/logger.dart';
import 'package:particle_music/base/services/picture_load_scheduler.dart';

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
    if (song.cachePath != null) {
      result = await readPictureAsync(song.cachePath!);
    } else {
      switch (song.sourceType) {
        case .local:
          result = await readPictureAsync(song.path!);
          break;
        case .webdav:
          result = await readPictureAsync(
            song.path!,
            headers: webdavClient?.headers,
          );
          break;
        case .navidrome:
          result = await navidromeClient!.getPictureBytes(song.id);
          break;
        default:
          result = await embyClient!.getPictureBytes(song.id);
          break;
      }
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
