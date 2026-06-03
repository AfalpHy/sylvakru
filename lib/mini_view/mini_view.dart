import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/asset_images.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/services/lyric.dart';
import 'package:sylvakru/base/widgets/buttons.dart';
import 'package:sylvakru/base/widgets/cover_art_widget.dart';
import 'package:sylvakru/base/widgets/seekbar.dart';
import 'package:sylvakru/landscape_view/desktop_lyrics.dart';
import 'package:sylvakru/landscape_view/pages/play_queue_page.dart';
import 'package:sylvakru/landscape_view/speaker.dart';
import 'package:sylvakru/landscape_view/volume_bar.dart';
import 'package:sylvakru/base/widgets/lyric_list_view.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/utils/metadata_utils.dart';
import 'package:window_manager/window_manager.dart';

final miniModeDisplayOthersNotifier = ValueNotifier(true);
Timer? miniModeHideOthersTimer;
final miniModeNotifier = ValueNotifier(false);

class MiniView extends StatefulWidget {
  const MiniView({super.key});

  @override
  State<StatefulWidget> createState() => _MiniViewState();
}

class _MiniViewState extends State<MiniView> {
  final displayCoverNotifier = ValueNotifier(true);
  final _lyricsOrPlayQueueNotifier = ValueNotifier(true);

  @override
  void initState() {
    super.initState();
    colorManager.updateMiniViewColors();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.widthOf(context);
    final height = MediaQuery.heightOf(context);
    if (height > 150) {
      displayCoverNotifier.value = true;
    } else {
      displayCoverNotifier.value = false;
    }
    miniModeDisplayOthersNotifier.value = true;
    return Column(
      children: [
        Expanded(
          child: ValueListenableBuilder(
            valueListenable: currentSongNotifier,
            builder: (context, value, child) {
              return Material(color: currentCoverArtColor, child: child);
            },
            child: ValueListenableBuilder(
              valueListenable: displayCoverNotifier,
              builder: (context, displayCover, child) {
                if (displayCover) {
                  return coverView();
                }
                return listTileView(context);
              },
            ),
          ),
        ),
        if (height > width)
          ValueListenableBuilder(
            valueListenable: currentSongNotifier,
            builder: (context, currentSong, child) {
              return Material(
                color: currentCoverArtColor,
                child: SizedBox(
                  width: width,
                  height: height - width,
                  child: Stack(
                    children: [
                      ValueListenableBuilder(
                        valueListenable: _lyricsOrPlayQueueNotifier,
                        builder: (context, value, child) {
                          if (value) {
                            return ScrollConfiguration(
                              behavior: ScrollConfiguration.of(
                                context,
                              ).copyWith(scrollbars: false),
                              child: currentSong == null
                                  ? SizedBox()
                                  : LyricsListView(
                                      key: ValueKey(currentSong),
                                      expanded: false,
                                      lines: currentSong.parsedLyrics!.lines,
                                      isKaraoke:
                                          currentSong.parsedLyrics!.isKaraoke,
                                    ),
                            );
                          }
                          return height - width > 60
                              ? PlayQueuePage()
                              : SizedBox();
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget coverView() {
    bool isDragging = false;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) async {
        isDragging = true;
        await windowManager.startDragging();
        isDragging = false;
      },

      child: MouseRegion(
        onEnter: (event) {
          miniModeDisplayOthersNotifier.value = true;
          miniModeHideOthersTimer?.cancel();
          miniModeHideOthersTimer = null;
        },
        onExit: (event) async {
          if (isDragging) {
            return;
          }
          miniModeHideOthersTimer ??= Timer(
            const Duration(milliseconds: 1000),
            () {
              miniModeDisplayOthersNotifier.value = false;
            },
          );
        },
        child: ValueListenableBuilder(
          valueListenable: currentSongNotifier,
          builder: (context, currentSong, child) {
            return ValueListenableBuilder(
              valueListenable: miniModeDisplayOthersNotifier,
              builder: (context, displayOthers, child) {
                return Stack(
                  fit: StackFit.expand,

                  children: [
                    CoverArtWidget(song: currentSong),

                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      height: 100,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              currentCoverArtColor.withAlpha(0),

                              currentCoverArtColor,
                            ],
                          ),
                        ),
                      ),
                    ),

                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 250,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              currentCoverArtColor.withAlpha(0),

                              currentCoverArtColor,
                            ],
                          ),
                        ),
                      ),
                    ),

                    if (displayOthers) ...[
                      topControls(),
                      centerListTile(currentSong),
                      seekBar(),
                      bottomControls(),
                    ],
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget listTileView(BuildContext context) {
    bool isDragging = false;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) async {
        isDragging = true;
        await windowManager.startDragging();
        isDragging = false;
      },

      child: MouseRegion(
        onEnter: (event) {
          miniModeDisplayOthersNotifier.value = true;
          miniModeHideOthersTimer?.cancel();
          miniModeHideOthersTimer = null;
        },
        onExit: (event) async {
          if (isDragging) {
            return;
          }
          miniModeHideOthersTimer ??= Timer(
            const Duration(milliseconds: 1000),
            () {
              miniModeDisplayOthersNotifier.value = false;
            },
          );
        },
        child: Stack(
          children: [
            ValueListenableBuilder(
              valueListenable: miniModeDisplayOthersNotifier,
              builder: (context, value, child) {
                if (value) {
                  return topControls();
                }
                return ValueListenableBuilder(
                  valueListenable: currentSongNotifier,
                  builder: (context, currentSong, child) {
                    return topListTile(currentSong);
                  },
                );
              },
            ),

            seekBar(),
            bottomControls(),
          ],
        ),
      ),
    );
  }

  Widget topControls() {
    return Positioned(
      top: 5,
      left: 10,
      right: 10,
      child: ValueListenableBuilder(
        valueListenable: miniViewForegroundColor.valueNotifier,
        builder: (context, foregroundColor, child) {
          return Row(
            children: [
              Speaker(color: foregroundColor),
              SizedBox(
                height: 20,
                width: 120,
                child: VolumeBar(activeColor: foregroundColor),
              ),
              Spacer(),
              IconButton(
                color: foregroundColor,
                onPressed: () async {
                  await windowManager.hide();

                  if (!Platform.isLinux) {
                    await windowManager.resetMaximumSize();
                  }
                  if (Platform.isWindows) {
                    await windowManager.setMinimumSize(
                      Size(1050 + 16, 700 + 9),
                    );
                    await windowManager.setSize(Size(1050 + 16, 700 + 9));
                  } else {
                    await windowManager.setMinimumSize(Size(1050, 700));
                    await windowManager.setSize(Size(1050, 700));
                  }
                  miniModeNotifier.value = false;
                  await Future.delayed(Duration(milliseconds: 200));
                  await windowManager.show();
                },
                icon: ImageIcon(miniModeImage),
              ),
              IconButton(
                color: foregroundColor,

                onPressed: () {
                  windowManager.minimize();
                },
                icon: ImageIcon(minimizeImage),
              ),

              IconButton(
                color: foregroundColor,

                onPressed: () {
                  windowManager.close();
                },
                icon: ImageIcon(closeImage),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget topListTile(MyAudioMetadata? currentSong) {
    return Positioned(
      top: 5,
      left: 0,
      right: 0,
      child: ValueListenableBuilder(
        valueListenable: miniViewForegroundColor.valueNotifier,
        builder: (context, foregroundColor, child) {
          return ListTile(
            leading: CoverArtWidget(
              song: currentSong,
              size: 50,
              borderRadius: 5,
            ),
            title: Text(
              getTitle(currentSong),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                overflow: .ellipsis,
                color: foregroundColor,
              ),
            ),
            subtitle: Text(
              "${getArtist(currentSong)} - ${getAlbum(currentSong)}",
              style: TextStyle(
                fontSize: 12,
                overflow: .ellipsis,
                color: foregroundColor,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget centerListTile(MyAudioMetadata? currentSong) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 70,
      child: ValueListenableBuilder(
        valueListenable: miniViewForegroundColor.valueNotifier,
        builder: (context, foregroundColor, child) {
          return ListTile(
            title: Text(
              getTitle(currentSong),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                overflow: .ellipsis,
                color: foregroundColor,
              ),
            ),
            subtitle: Text(
              "${getArtist(currentSong)} - ${getAlbum(currentSong)}",
              style: TextStyle(
                fontSize: 12,
                overflow: .ellipsis,
                color: foregroundColor,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget seekBar() {
    return Positioned(
      bottom: 45,
      left: 15,
      right: 15,
      child: ValueListenableBuilder(
        valueListenable: miniViewForegroundColor.valueNotifier,
        builder: (context, foregroundColor, child) {
          return SeekBar(
            color: foregroundColor,
            isMiniMode: true,
            widgetHeight: 50,
            seekBarHeight: 10,
          );
        },
      ),
    );
  }

  Widget bottomControls() {
    return Positioned(
      bottom: 0,
      left: 10,
      right: 10,
      child: ValueListenableBuilder(
        valueListenable: miniViewForegroundColor.valueNotifier,
        builder: (context, foregroundColor, child) {
          return Row(
            children: [
              Spacer(),
              playModeButton(25, iconColor: foregroundColor),

              Spacer(),

              IconButton(
                onPressed: () async {
                  final size = await windowManager.getSize();
                  if (_lyricsOrPlayQueueNotifier.value &&
                      size.height > size.width) {
                    windowManager.setSize(Size(size.width, size.width));
                    return;
                  }
                  _lyricsOrPlayQueueNotifier.value = true;
                  if (size.height <= size.width) {
                    windowManager.setSize(Size(size.width, size.width + 300));
                  }
                },
                icon: ImageIcon(lyricsImage),
                color: foregroundColor,
              ),
              Spacer(),

              skip2PreviousButton(25, iconColor: foregroundColor),

              Spacer(),

              playOrPauseButton(35, iconColor: foregroundColor),

              Spacer(),

              skip2NextButton(25, iconColor: foregroundColor),

              Spacer(),

              IconButton(
                onPressed: () async {
                  final size = await windowManager.getSize();
                  if (!_lyricsOrPlayQueueNotifier.value &&
                      size.height > size.width) {
                    windowManager.setSize(Size(size.width, size.width));
                    return;
                  }

                  _lyricsOrPlayQueueNotifier.value = false;

                  if (size.height <= size.width) {
                    if (Platform.isWindows) {
                      windowManager.setSize(
                        Size(size.width, size.width + 316 - 7),
                      );
                    } else {
                      windowManager.setSize(Size(size.width, size.width + 316));
                    }
                  }
                },
                icon: const ImageIcon(playQueueImage, size: 25),
                color: foregroundColor,
              ),
              Spacer(),

              IconButton(
                onPressed: () async {
                  if (lyricsWindowVisible) {
                    await lyricsWindowController!.hide();
                  } else {
                    await updateDesktopLyrics();
                    await lyricsWindowController!.show();
                  }
                  lyricsWindowVisible = !lyricsWindowVisible;
                },
                icon: const ImageIcon(desktopLyricsImage, size: 25),

                color: foregroundColor,
              ),
              Spacer(),
            ],
          );
        },
      ),
    );
  }
}
