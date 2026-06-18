import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/asset_images.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/base/widgets/buttons.dart';
import 'package:sylvakru/base/widgets/cover_art_widget.dart';
import 'package:sylvakru/base/widgets/my_auto_size_text.dart';
import 'package:sylvakru/base/data/setting.dart';
import 'package:sylvakru/landscape_view/speaker.dart';
import 'package:sylvakru/landscape_view/title_bar.dart';
import 'package:sylvakru/landscape_view/volume_bar.dart';
import 'package:sylvakru/base/widgets/lyric_list_view.dart';
import 'package:sylvakru/base/widgets/seekbar.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/utils/metadata_utils.dart';

class LandscapeLyricsPage extends StatefulWidget {
  const LandscapeLyricsPage({super.key});

  @override
  State<StatefulWidget> createState() => _LandscapeLyricsPageState();
}

class _LandscapeLyricsPageState extends State<LandscapeLyricsPage> {
  final ValueNotifier<bool> immersiveModeNotifier = ValueNotifier(false);
  Timer? immersiveModeTimer;

  @override
  void dispose() {
    immersiveModeNotifier.dispose();
    immersiveModeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    immersiveModeTimer?.cancel();
    immersiveModeTimer = Timer(const Duration(milliseconds: 5000), () {
      immersiveModeNotifier.value = true;
    });
    return ValueListenableBuilder(
      valueListenable: immersiveModeNotifier,
      builder: (context, value, child) {
        return MouseRegion(
          cursor: value ? SystemMouseCursors.none : MouseCursor.defer,
          onHover: (event) {
            immersiveModeNotifier.value = false;
            immersiveModeTimer?.cancel();
            immersiveModeTimer = Timer(const Duration(milliseconds: 5000), () {
              immersiveModeNotifier.value = true;
            });
          },
          child: child,
        );
      },
      child: content(),
    );
  }

  Widget content() {
    return ValueListenableBuilder(
      valueListenable: currentSongNotifier,
      builder: (context, currentSong, child) {
        final pageWidth = MediaQuery.widthOf(context);
        final pageHight = MediaQuery.heightOf(context);
        final coverArtSize = min(pageWidth * 0.3, pageHight * 0.6);

        return Material(
          color: Colors.transparent,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (lyricsPageThemeNotifier.value == .vivid) ...[
                CoverArtWidget(
                  song: currentSong,
                  color: colorManager.getSpecificLyricsPageCoverArtBaseColor(),
                ),
                BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: pageWidth * 0.03,
                    sigmaY: pageHight * 0.03,
                  ),
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeInOutCubic,
                    color: currentCoverArtColor.withAlpha(180),
                  ),
                ),
              ],

              ValueListenableBuilder(
                valueListenable: lyricsPageBackgroundColor.valueNotifier,
                builder: (context, value, child) {
                  return Container(color: value, child: child);
                },
                child: Row(
                  children: [
                    Spacer(),
                    Column(
                      children: [
                        if (pageHight >= 600) SizedBox(height: 75),
                        Spacer(),
                        Hero(
                          tag: 'cover',
                          child: GestureDetector(
                            onVerticalDragEnd: (details) {
                              if (isMobile &&
                                  (details.primaryVelocity ?? 0) > 500) {
                                Navigator.pop(context);
                              }
                            },
                            child: CoverArtWidget(
                              size: coverArtSize,
                              borderRadius: coverArtSize * 0.05,
                              song: currentSong,
                              elevation: 15,
                              color: colorManager
                                  .getSpecificLyricsPageCoverArtBaseColor(),
                            ),
                          ),
                        ),
                        if (pageHight >= 600) ...[
                          message(coverArtSize, pageHight, currentSong),
                          playControls(coverArtSize, pageHight, currentSong),
                        ],

                        Spacer(),
                      ],
                    ),
                    SizedBox(width: pageWidth * 0.05),
                    SizedBox(
                      width: pageWidth * 0.45,
                      child: Column(
                        children: [
                          SizedBox(height: 75),
                          if (pageHight < 600)
                            message(pageWidth * 0.35, pageHight, currentSong),

                          Expanded(
                            child: ShaderMask(
                              shaderCallback: (rect) {
                                return LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent, // fade out at top
                                    Colors.black, // fully visible
                                    Colors.black, // fully visible
                                    Colors.transparent, // fade out at bottom
                                  ],
                                  stops: [
                                    0.0,
                                    0.05,
                                    0.95,
                                    1.0,
                                  ], // adjust fade height
                                ).createShader(rect);
                              },
                              blendMode: BlendMode.dstIn,
                              // use key to force update
                              child: ScrollConfiguration(
                                behavior: ScrollConfiguration.of(
                                  context,
                                ).copyWith(scrollbars: false),
                                child: currentSong == null
                                    ? SizedBox()
                                    : LyricsListView(
                                        key: ValueKey(currentSong),
                                        expanded: pageHight < 600
                                            ? false
                                            : true,
                                        lines: currentSong.parsedLyrics!.lines,
                                        isKaraoke:
                                            currentSong.parsedLyrics!.isKaraoke,
                                      ),
                              ),
                            ),
                          ),

                          if (pageHight < 600) ...[
                            playControls(
                              pageWidth * 0.4,
                              pageHight,
                              currentSong,
                            ),
                            SizedBox(height: 20),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(width: pageWidth * 0.05),
                  ],
                ),
              ),

              Positioned(
                right: 60,
                bottom: 100,
                child: ValueListenableBuilder(
                  valueListenable: immersiveModeNotifier,
                  builder: (context, value, child) {
                    List<Widget> children = [
                      IconButton(
                        color: lyricsPageForegroundColor.value,
                        onPressed: () {
                          lyricsFontSizeOffsetNotifier.value += 2;
                          setting.save();
                        },
                        icon: Icon(Icons.text_increase_rounded, size: 20),
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
                        icon: Icon(Icons.text_decrease_rounded, size: 18),
                      ),
                    ];
                    return Offstage(
                      offstage: value,
                      child: pageHight <= 600
                          ? Column(children: children)
                          : Row(children: children),
                    );
                  },
                ),
              ),

              if (!isMobile)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: immersiveModeNotifier,
                    builder: (context, value, child) {
                      return Offstage(offstage: value, child: child);
                    },
                    child: TitleBar(isMainPage: false),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget message(double width, double pageHight, MyAudioMetadata? currentSong) {
    return Column(
      children: [
        SizedBox(height: pageHight * 0.01),
        SizedBox(
          width: width - 30,

          height: 36,
          child: Center(
            child: ValueListenableBuilder(
              valueListenable: lyricsPageHighlightTextColor.valueNotifier,
              builder: (context, value, child) {
                return MyAutoSizeText(
                  key: UniqueKey(),
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
          width: width - 30,

          height: 28,
          child: Center(
            child: ValueListenableBuilder(
              valueListenable: lyricsPageForegroundColor.valueNotifier,
              builder: (context, value, child) {
                return MyAutoSizeText(
                  key: UniqueKey(),
                  '${getArtist(currentSong)} - ${getAlbum(currentSong)}',
                  maxLines: 1,
                  textStyle: TextStyle(fontSize: 14, color: value),
                );
              },
            ),
          ),
        ),

        SizedBox(height: pageHight * 0.01),
      ],
    );
  }

  Widget playControls(
    double width,
    double pageHight,
    MyAudioMetadata? currentSong,
  ) {
    return ValueListenableBuilder(
      valueListenable: lyricsPageForegroundColor.valueNotifier,
      builder: (context, value, child) {
        return Column(
          children: [
            SizedBox(
              width: width - 15,
              child: SeekBar(color: value, widgetHeight: 20, seekBarHeight: 10),
            ),

            SizedBox(
              width: width,
              child: Row(
                children: [
                  playModeButton(25, iconColor: value),
                  Spacer(),

                  skip2PreviousButton(25, iconColor: value),

                  playOrPauseButton(35, iconColor: value),

                  skip2NextButton(25, iconColor: value),

                  Spacer(),
                  showPlayQueueButton(25, iconColor: value),
                ],
              ),
            ),
            if (!isMobile)
              SizedBox(
                width: width,
                child: Row(
                  children: [
                    Spacer(),

                    SizedBox(width: 40, child: Speaker(color: value)),
                    SizedBox(
                      height: 10,
                      width: width * 0.5,
                      child: VolumeBar(activeColor: value),
                    ),
                    SizedBox(
                      width: 40,
                      child: IconButton(
                        onPressed: () async {
                          showCenterMessage(
                            context,
                            'Desktop lyrics has been removed',
                          );
                        },
                        icon: const ImageIcon(desktopLyricsImage, size: 25),

                        color: value,
                      ),
                    ),
                    Spacer(),
                  ],
                ),
              ),
            SizedBox(height: pageHight * 0.02),
          ],
        );
      },
    );
  }
}
