import 'dart:io';

import 'package:flutter/material.dart';
import 'package:particle_music/base/asset_images.dart';
import 'package:particle_music/base/my_audio_metadata.dart';
import 'package:particle_music/base/services/metadata_service.dart';
import 'package:smooth_corner/smooth_corner.dart';

class CoverArtWidget extends StatelessWidget {
  final double? size;
  final double borderRadius;
  final MyAudioMetadata? song;
  final String? picturePath;
  final double elevation;
  final Color? color;
  const CoverArtWidget({
    super.key,
    this.size,
    this.borderRadius = 0,
    this.song,
    this.picturePath,
    this.elevation = 0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: elevation,
      color: color ?? Colors.transparent,
      shape: SmoothRectangleBorder(
        smoothness: 1,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      clipBehavior: .antiAlias,
      child: content(context),
    );
  }

  Widget content(BuildContext context) {
    if (picturePath != null) {
      return imageWidget(picturePath!);
    }
    if (song == null) {
      return musicNote();
    }

    if (song!.pictureLoaded) {
      return imageWidget(song!.picturePath);
    }

    return FutureBuilder(
      future: loadPictureSafe(song),
      builder: (context, asyncSnapshot) {
        if (asyncSnapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(width: size, height: size);
        }

        if (asyncSnapshot.hasError) {
          return musicNote();
        }
        return Image.file(
          File(song!.picturePath),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return musicNote();
          },
        );
      },
    );
  }

  Widget imageWidget(String path) {
    return Image.file(
      File(path),
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return musicNote();
      },
    );
  }

  Widget musicNote() {
    return ImageIcon(musicNoteImage, size: size);
  }
}
