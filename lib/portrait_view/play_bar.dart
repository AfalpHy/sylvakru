import 'package:flutter/material.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/asset_images.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/base/widgets/cover_art_widget.dart';
import 'package:sylvakru/base/widgets/my_auto_size_text.dart';
import 'package:sylvakru/base/widgets/play_queue_sheet.dart';
import 'package:sylvakru/base/utils/dynamic_lyrics_page_route.dart';
import 'package:sylvakru/layer/layers_manager.dart';
import 'package:sylvakru/layer/lyrics_page_layer.dart';
import 'package:sylvakru/base/utils/metadata_utils.dart';
import 'package:smooth_corner/smooth_corner.dart';

class PlayBar extends StatelessWidget {
  const PlayBar({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: currentSongNotifier,
      builder: (_, currentSong, _) {
        if (currentSong == null) return const SizedBox.shrink();

        return SizedBox(
          height: 50,
          child: ListenableBuilder(
            listenable: Listenable.merge([
              layersManager.backgroundChangeNotifier,
              playBarColor.valueNotifier,
            ]),
            builder: (context, child) {
              return Material(
                shape: SmoothRectangleBorder(
                  smoothness: 1,
                  borderRadius: BorderRadius.circular(
                    25,
                  ), // rounded half-circle ends
                ),
                color: Color.alphaBlend(
                  playBarColor.value,
                  mainPageThemeNotifier.value == .vivid
                      ? backgroundCoverArtColor.withAlpha(180)
                      : Colors.transparent,
                ),
                clipBehavior: .antiAlias,
                child: child,
              );
            },
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  DynamicLyricsPageRoute(
                    pageBuilder: (_, _, _) => LyricsPageLayer(),
                  ),
                );
              },

              child: Row(
                children: [
                  const SizedBox(width: 15),
                  Hero(
                    tag: 'cover',
                    flightShuttleBuilder:
                        (
                          flightContext,
                          animation,
                          flightDirection,
                          fromHeroContext,
                          toHeroContext,
                        ) => FittedBox(
                          child: flightDirection == .push
                              ? toHeroContext.widget
                              : fromHeroContext.widget,
                        ),
                    child: CoverArtWidget(
                      size: 35,
                      borderRadius: 3,
                      song: currentSong,
                    ),
                  ),

                  const SizedBox(width: 10),
                  Expanded(
                    child: MyAutoSizeText(
                      "${getTitle(currentSong)} - ${getArtist(currentSong)}",
                      key: ValueKey(currentSong),
                      maxLines: 1,
                      textStyle: TextStyle(fontSize: 16),
                    ),
                  ),

                  // Play/Pause Button
                  SizedBox(
                    width: 40,
                    child: IconButton(
                      icon: ValueListenableBuilder(
                        valueListenable: isPlayingNotifier,
                        builder: (_, isPlaying, _) {
                          return ImageIcon(
                            isPlaying ? pauseCircleImage : playCircleFillImage,
                            size: 25,
                          );
                        },
                      ),

                      onPressed: () {
                        tryVibrate();
                        audioHandler.togglePlay();
                      },
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: IconButton(
                      icon: Icon(Icons.playlist_play_rounded, size: 30),
                      onPressed: () {
                        tryVibrate();
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (context) {
                            return PlayQueueSheet();
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 15),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
