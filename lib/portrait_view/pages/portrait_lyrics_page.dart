import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/asset_images.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/base/widgets/audio_output_panel.dart';
import 'package:sylvakru/base/widgets/buttons.dart';
import 'package:sylvakru/base/widgets/cover_art_widget.dart';
import 'package:sylvakru/base/widgets/my_auto_size_text.dart';
import 'package:sylvakru/base/widgets/my_divider.dart';
import 'package:sylvakru/base/widgets/playlist_widgets.dart';
import 'package:sylvakru/base/data/setting.dart';
import 'package:sylvakru/portrait_view/sleep_timer.dart';
import 'package:sylvakru/base/widgets/my_sheet.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/base/widgets/lyric_list_view.dart';
import 'package:sylvakru/base/widgets/play_queue_sheet.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/data/playlist.dart';
import 'package:sylvakru/base/widgets/seekbar.dart';
import 'package:sylvakru/base/utils/metadata_utils.dart';
import 'package:smooth_corner/smooth_corner.dart';

const double _backgroundBlurSigma = 16;
const int _backgroundCoverCacheWidth = 160;

class PortraitLyricsPage extends StatefulWidget {
  const PortraitLyricsPage({super.key});

  @override
  State<PortraitLyricsPage> createState() => _PortraitLyricsPageState();
}

class _PortraitLyricsPageState extends State<PortraitLyricsPage> {
  double dragOffset = 0.0;

  int _animationDuration = 0;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return GestureDetector(
      onVerticalDragUpdate: (details) {
        setState(() {
          _animationDuration = 0;
          dragOffset += details.delta.dy / screenHeight;
          dragOffset = dragOffset.clamp(0.0, 1.0);
        });
      },

      onVerticalDragEnd: (details) {
        double velocity = details.primaryVelocity ?? 0;

        if (dragOffset > 0.25 || velocity > 500) {
          Navigator.pop(context);
        } else {
          setState(() {
            _animationDuration = 250;
            dragOffset = 0.0;
          });
        }
      },

      child: AnimatedContainer(
        duration: Duration(milliseconds: _animationDuration),
        curve: Curves.easeOutCubic,

        transform: Matrix4.translationValues(0, dragOffset * screenHeight, 0),
        child: content(),
      ),
    );
  }

  Widget content() {
    return ValueListenableBuilder(
      valueListenable: currentSongNotifier,
      builder: (context, currentSong, child) {
        return AnnotatedRegion(
          value: lyricsPageForegroundColor.value.computeLuminance() > 0.5
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
          child: Material(
            color: Colors.transparent,
            shape: SmoothRectangleBorder(
              smoothness: 1,
              borderRadius: .circular(
                dragOffset > 0 ? screenRadius?.topLeft ?? 0 : 0,
              ),
            ),
            clipBehavior: .antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (lyricsPageThemeNotifier.value == .vivid) ...[
                  RepaintBoundary(
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(
                        sigmaX: _backgroundBlurSigma,
                        sigmaY: _backgroundBlurSigma,
                      ),
                      child: CoverArtWidget(
                        song: currentSong,
                        color: colorManager
                            .getSpecificLyricsPageCoverArtBaseColor(),
                        cacheWidth: _backgroundCoverCacheWidth,
                        filterQuality: FilterQuality.low,
                      ),
                    ),
                  ),
                  AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeInOutCubic,
                    color: currentCoverArtColor.withAlpha(180),
                  ),
                ],
                ValueListenableBuilder(
                  valueListenable: lyricsPageBackgroundColor.valueNotifier,
                  builder: (context, value, child) {
                    return Container(color: value, child: child);
                  },
                  child: Column(
                    children: [
                      SizedBox(height: 50),
                      Row(
                        children: [
                          SizedBox(width: 30),
                          Expanded(
                            child: Column(
                              children: [
                                SizedBox(
                                  height: 36,
                                  child: Center(
                                    child: ValueListenableBuilder(
                                      valueListenable:
                                          lyricsPageHighlightTextColor
                                              .valueNotifier,
                                      builder: (context, value, child) {
                                        return MyAutoSizeText(
                                          getTitle(currentSong),
                                          maxLines: 1,
                                          textStyle: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 20,
                                            color: value,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: 28,
                                  child: Center(
                                    child: ValueListenableBuilder(
                                      valueListenable: lyricsPageForegroundColor
                                          .valueNotifier,
                                      builder: (context, value, child) {
                                        return MyAutoSizeText(
                                          '${getArtist(currentSong)} - ${getAlbum(currentSong)}',
                                          maxLines: 1,
                                          textStyle: TextStyle(
                                            fontSize: 14,
                                            color: value,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 30),
                        ],
                      ),
                      SizedBox(height: 10),
                      Expanded(
                        child: PageView(
                          children: [
                            artPage(context, currentSong),
                            expandedLyricsPage(context, currentSong),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget artPage(BuildContext context, MyAudioMetadata? currentSong) {
    final l10n = AppLocalizations.of(context);
    final mobileWidth = MediaQuery.widthOf(context);

    return Column(
      children: [
        Hero(
          tag: 'cover',
          child: CoverArtWidget(
            size: mobileWidth * 0.84,
            borderRadius: mobileWidth * 0.04,
            song: currentSong,
            elevation: 15,
            color: colorManager.getSpecificLyricsPageCoverArtBaseColor(),
          ),
        ),

        const SizedBox(height: 30),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: ShaderMask(
              shaderCallback: (rect) {
                return LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent, // fade out at top
                    Colors.grey.shade50, // fully visible
                    Colors.grey.shade50, // fully visible
                    Colors.transparent, // fade out at bottom
                  ],
                  stops: [0.0, 0.1, 0.8, 1.0], // adjust fade height
                ).createShader(rect);
              },
              blendMode: BlendMode.dstIn,
              // use key to force update
              child: currentSong == null
                  ? SizedBox()
                  : LyricsListView(
                      key: ValueKey(currentSong),
                      expanded: false,
                      lines: currentSong.parsedLyrics!.lines,
                      isKaraoke: currentSong.parsedLyrics!.isKaraoke,
                    ),
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(34, 0, 34, 12),
          child: ValueListenableBuilder(
            valueListenable: lyricsPageForegroundColor.valueNotifier,
            builder: (context, value, child) {
              return AudioOutputChip(song: currentSong, color: value);
            },
          ),
        ),

        Row(
          children: [
            SizedBox(width: 25),
            FavoriteButton(),
            IconButton(
              color: lyricsPageForegroundColor.value,
              onPressed: () {
                displayTimedPauseSetting(context);
              },
              icon: ImageIcon(timerImage, size: 25),
            ),
            remainTimesText(textColor: lyricsPageForegroundColor.value),
            Spacer(),
            IconButton(
              color: lyricsPageForegroundColor.value,
              onPressed: () {
                lyricsFontSizeOffsetNotifier.value += 2;
                setting.save();
              },
              icon: Icon(Icons.text_increase_rounded),
            ),
            IconButton(
              color: lyricsPageForegroundColor.value,
              onPressed: () {
                if (lyricsFontSizeOffsetNotifier.value < -2) {
                  return;
                }
                lyricsFontSizeOffsetNotifier.value -= 2;
                setting.save();
              },
              icon: Icon(Icons.text_decrease_rounded),
            ),

            IconButton(
              onPressed: () {
                tryVibrate();
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) {
                    return MySheet(
                      ValueListenableBuilder(
                        valueListenable:
                            lyricsPageForegroundColor.valueNotifier,
                        builder: (context, value, child) {
                          return Column(
                            children: [
                              SizedBox(height: 5),

                              ListTile(
                                leading: CoverArtWidget(
                                  size: 50,
                                  borderRadius: 5,
                                  song: currentSong,
                                ),
                                title: Text(
                                  getTitle(currentSong),
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: value),
                                ),
                                subtitle: Text(
                                  "${getArtist(currentSong)} - ${getAlbum(currentSong)}",
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: value),
                                ),
                              ),

                              SizedBox(height: 5),
                              MyDivider(
                                color: lyricsPageDividerColor,
                                thickness: 0.5,
                                height: 1,
                              ),
                              SizedBox(height: 5),

                              Expanded(
                                child: ListView(
                                  physics: const ClampingScrollPhysics(),
                                  children: [
                                    ListTile(
                                      leading: Icon(
                                        Icons.add_rounded,
                                        color: value,
                                      ),
                                      title: Text(
                                        l10n.add2Playlist,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: value,
                                        ),
                                      ),
                                      visualDensity: const VisualDensity(
                                        horizontal: 0,
                                        vertical: -4,
                                      ),
                                      onTap: () {
                                        Navigator.pop(context);

                                        showAddPlaylistDialog(context, [
                                          currentSong!,
                                        ]);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    );
                  },
                );
              },
              icon: ValueListenableBuilder(
                valueListenable: lyricsPageForegroundColor.valueNotifier,
                builder: (context, value, child) {
                  return Icon(Icons.more_vert, color: value);
                },
              ),
            ),
            SizedBox(width: 25),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: ValueListenableBuilder(
            valueListenable: lyricsPageForegroundColor.valueNotifier,
            builder: (context, value, child) {
              return SeekBar(color: value, widgetHeight: 60, seekBarHeight: 40);
            },
          ),
        ),

        // -------- Play Controls --------
        ValueListenableBuilder(
          valueListenable: lyricsPageForegroundColor.valueNotifier,
          builder: (context, value, child) {
            return Row(
              children: [
                SizedBox(width: 25),

                playModeButton(32, iconColor: value),

                Spacer(),

                skip2PreviousButton(32, iconColor: value),

                Spacer(),

                playOrPauseButton(50, iconColor: value),

                Spacer(),

                skip2NextButton(32, iconColor: value),

                Spacer(),

                IconButton(
                  color: value,

                  icon: const ImageIcon(playQueueImage, size: 32),

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
                SizedBox(width: 25),
              ],
            );
          },
        ),

        SizedBox(height: 40),
      ],
    );
  }

  Widget expandedLyricsPage(
    BuildContext context,
    MyAudioMetadata? currentSong,
  ) {
    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: ShaderMask(
                shaderCallback: (rect) {
                  return LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent, // fade out at top
                      Colors.grey.shade50, // fully visible
                      Colors.grey.shade50, // fully visible
                      Colors.transparent, // fade out at bottom
                    ],
                    stops: [0.0, 0.1, 0.7, 1.0], // adjust fade height
                  ).createShader(rect);
                },
                blendMode: BlendMode.dstIn,
                child: currentSong == null
                    ? SizedBox()
                    : LyricsListView(
                        key: ValueKey(currentSong),
                        expanded: true,
                        lines: currentSong.parsedLyrics!.lines,
                        isKaraoke: currentSong.parsedLyrics!.isKaraoke,
                      ),
              ),
            ),
            SizedBox(height: 50),
          ],
        ),

        Positioned(
          right: 25,
          bottom: 40,
          child: ValueListenableBuilder(
            valueListenable: lyricsPageForegroundColor.valueNotifier,
            builder: (context, value, child) {
              return IconButton(
                color: value,
                icon: ValueListenableBuilder(
                  valueListenable: isPlayingNotifier,
                  builder: (_, isPlaying, _) {
                    return Icon(
                      isPlaying
                          ? Icons.pause_circle_rounded
                          : Icons.play_circle_rounded,
                      size: 48,
                    );
                  },
                ),
                onPressed: () => audioHandler.togglePlay(),
              );
            },
          ),
        ),
      ],
    );
  }
}

class FavoriteButton extends StatelessWidget {
  final double? size;
  const FavoriteButton({super.key, this.size});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: currentSongNotifier,
      builder: (_, currentSong, _) {
        if (currentSong == null) return SizedBox();
        return ValueListenableBuilder(
          valueListenable: currentSong.isFavoriteNotifier,
          builder: (_, value, _) {
            return IconButton(
              onPressed: () {
                tryVibrate();
                toggleFavoriteState(currentSong);
              },
              icon: ValueListenableBuilder(
                valueListenable: lyricsPageForegroundColor.valueNotifier,
                builder: (context, color, child) {
                  return Icon(
                    value ? Icons.favorite : Icons.favorite_outline,
                    color: value ? Colors.red : color,
                    size: size,
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
