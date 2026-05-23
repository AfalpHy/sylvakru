import 'dart:io';
import 'dart:typed_data';

import 'package:audio_tags_lofty/audio_tags_lofty.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as image;
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/services/emby_client.dart';
import 'package:sylvakru/base/services/navidrome_client.dart';
import 'package:sylvakru/base/services/webdav_client.dart';
import 'package:sylvakru/base/services/logger.dart';
import 'package:sylvakru/base/services/picture_load_scheduler.dart';

Future<void> loadPictureSafe(MyAudioMetadata? song) async {
  if (song == null || song.pictureLoaded) {
    return;
  }
  return pictureLoadScheduler.load(song.id, () => _loadPicture(song));
}

Future<void> _loadPicture(MyAudioMetadata song) async {
  try {
    Uint8List? bytes;

    switch (song.sourceType) {
      case .local:
        bytes = await readPictureAsync(song.path!);
        break;
      case .webdav:
        bytes = await readPictureAsync(
          song.path!,
          headers: webdavClient?.headers,
        );
        break;
      case .navidrome:
        bytes = await navidromeClient!.getPictureBytes(song.id);
        break;
      default:
        bytes = await embyClient!.getPictureBytes(song.id);
        break;
    }

    if (bytes != null) {
      File pictureFile = File(song.picturePath);
      if (!await pictureFile.exists()) {
        await pictureFile.create(recursive: true);
      }
      await pictureFile.writeAsBytes(bytes);
      song.pictureExist = true;
    }
  } catch (e) {
    logger.output(e.toString());
  }
  song.pictureLoaded = true;
}

Future<Color> computeCoverArtColor(MyAudioMetadata? song) async {
  if (song?.coverArtColor != null) {
    return song!.coverArtColor!;
  }
  Uint8List? bytes;
  await loadPictureSafe(song);

  if (song?.pictureExist == true) {
    File pictureFile = File(song!.picturePath);
    if (await pictureFile.exists()) {
      bytes = await pictureFile.readAsBytes();
    }
  }

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
