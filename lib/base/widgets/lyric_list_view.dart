import 'dart:async';
import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/services/lyric.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:smooth_corner/smooth_corner.dart';

final lyricsFontSizeOffsetNotifier = ValueNotifier(0.0);
final lyricsFontWeightNotifier = ValueNotifier(FontWeight.bold);

/// Whether the line-by-line wave rides on the glide. Off = the whole list
/// moves as one rigid spring.
final lyricWaveEnabledNotifier = ValueNotifier(true);

final updateLyricsNotifier = ValueNotifier(0);

/// Delayed-signal wave behind the Apple-Music-style staggered line motion:
/// the viewport spring glides rigidly, and each row additionally hangs
/// behind by its distance from the anchor line — its visual offset is the
/// anchor's traveled distance sampled `distance * stagger` ago minus the
/// current one, i.e. how far the wave has yet to reach this row. The signal
/// (cumulative travel) is continuous across retargets, so rapid line
/// changes never snap the rows. The lag is a pure function of time and row
/// distance (no per-row state), so rows entering the viewport mid-glide are
/// consistent automatically and every lag decays to zero once the glide
/// settles.
class LyricGlideWave extends ChangeNotifier {
  static const int staggerMs = 40;
  static const int maxDelayMs = 600;
  static const int _maxSamples = 110;

  final List<(Duration, double)> _samples = [];
  bool active = false;
  int anchorItemIndex = -1;

  void begin() {
    if (active) {
      return; // retarget mid-glide: keep the buffer for continuity
    }
    active = true;
    _samples.clear();
    notifyListeners();
  }

  void sample(Duration elapsed, double traveled) {
    _samples.add((elapsed, traveled));
    if (_samples.length > _maxSamples) {
      _samples.removeAt(0);
    }
    notifyListeners();
  }

  void end() {
    if (!active) {
      return;
    }
    active = false;
    _samples.clear();
    notifyListeners();
  }

  /// Visual offset for the row laid out at [itemIndex]: how far behind the
  /// rigid motion this row hangs, in px (positive = lower on screen).
  double lagFor(int itemIndex) {
    if (!active || _samples.isEmpty) {
      return 0;
    }
    final (now, current) = _samples.last;
    var delayMs = (itemIndex - anchorItemIndex).abs() * staggerMs;
    if (delayMs > maxDelayMs) {
      delayMs = maxDelayMs;
    }
    final sampleTime = now - Duration(milliseconds: delayMs);
    var delayed = _samples.first.$2;
    for (final (at, error) in _samples) {
      if (at <= sampleTime) {
        delayed = error;
      } else {
        break;
      }
    }
    return delayed - current;
  }
}

class LyricsListView extends StatefulWidget {
  final bool expanded;
  final List<LyricLine> lines;
  final bool isKaraoke;
  const LyricsListView({
    super.key,
    required this.expanded,
    required this.lines,
    required this.isKaraoke,
  });

  @override
  State<LyricsListView> createState() => LyricsListViewState();
}

class LyricsListViewState extends State<LyricsListView>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final ItemScrollController itemScrollController = ItemScrollController();
  final ItemPositionsListener itemPositionsListener =
      ItemPositionsListener.create();
  final ScrollOffsetController scrollOffsetController =
      ScrollOffsetController();

  bool userDragging = false;

  List<LyricLine> lines = [];
  bool jump = true;
  Timer? timer;

  // Apple-Music-style line glide: a critically damped spring pulls the
  // current line to its anchor (the rigid backbone), while [LyricGlideWave]
  // makes rows hang behind by their distance from the anchor so the motion
  // propagates line by line. Raise/lower _glideOmega to make the glide
  // snappier or slower (settle time ≈ 4.6 / _glideOmega).
  static const double _glideOmega = 11.0;
  static const double _glideSettledError = 1.0; // px
  static const double _glideSettledVelocity = 10.0; // px/s
  static const int _waveDrainMs = 700;

  final LyricGlideWave _wave = LyricGlideWave();
  Ticker? _glideTicker;
  int _glideTargetIndex = -1;
  bool _springActive = false;
  bool _waveHandedOff = false;
  double _glideVelocity = 0; // px/s along the measured error
  double _waveTraveled = 0; // px the anchor has traveled (wave signal)
  Duration? _lastGlideTick;
  Duration _lastMotionElapsed = Duration.zero;
  double _prevGlideError = 0;
  int _stalledFrames = 0;
  double _viewportHeight = 0;

  double get _anchor => widget.expanded ? 0.25 : 0.4;

  bool get _waveOn => lyricWaveEnabledNotifier.value;

  void scroll2CurrentIndex() {
    final currentIndex = currentLyricsIndexNotifier.value;
    if (!userDragging && currentIndex < lines.length && !loadingSong) {
      if (itemScrollController.isAttached) {
        if (jump) {
          _endWave();
          itemScrollController.jumpTo(
            index: currentIndex + 1,
            alignment: _anchor,
          );
        } else if (currentIndex < 0) {
          // Before the first line: one-shot scroll to the top (the spring
          // would stall against the edge clamp).
          _endWave();
          itemScrollController.scrollTo(
            index: 0,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOutCubic,
            alignment: _anchor,
          );
        } else {
          final itemIndex = currentIndex + 1;
          final isLaidOut = itemPositionsListener.itemPositions.value.any(
            (position) => position.index == itemIndex,
          );
          if (isLaidOut) {
            _startGlide(itemIndex);
          } else {
            // Far seek: the package cross-fades between viewports.
            _endWave();
            itemScrollController.scrollTo(
              index: itemIndex,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOutCubic,
              alignment: _anchor,
            );
          }
        }
      }
    }
    jump = false;
  }

  void _startGlide(int itemIndex) {
    _glideTargetIndex = itemIndex;
    _springActive = true;
    _waveHandedOff = false;
    if (_waveOn) {
      _wave.anchorItemIndex = itemIndex;
      _wave.begin();
    } else {
      _wave.end(); // rigid mode: no per-row lag at all
    }
    _lastMotionElapsed = Duration.zero;
    _glideTicker ??= createTicker(_glideTick);
    if (!_glideTicker!.isActive) {
      _lastGlideTick = null;
      _glideTicker!.start();
    }
  }

  /// Stops the spring and snaps the wave to zero (jump, user drag, dispose).
  void _endWave() {
    _springActive = false;
    _wave.end();
    _glideTicker?.stop();
    _lastGlideTick = null;
    _glideVelocity = 0;
    _stalledFrames = 0;
  }

  void _glideTick(Duration elapsed) {
    if (!mounted || !itemScrollController.isAttached) {
      _endWave();
      return;
    }

    if (userDragging || loadingSong) {
      // The user took over (or the song is switching): manual scrolling is
      // rigid, so stop pushing and snap the wave.
      _endWave();
      return;
    }

    ItemPosition? target;
    for (final position in itemPositionsListener.itemPositions.value) {
      if (position.index == _glideTargetIndex) {
        target = position;
        break;
      }
    }
    if (target == null) {
      // The target left the laid-out window (a far seek mid-glide): hand
      // the move over to the package's cross-fade scroll and drain.
      _springActive = false;
      _glideVelocity = 0;
      if (!_waveHandedOff) {
        _waveHandedOff = true;
        itemScrollController.scrollTo(
          index: _glideTargetIndex,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
          alignment: _anchor,
        );
      }
    }

    final error = target != null && _viewportHeight > 0
        ? (target.itemLeadingEdge - _anchor) * _viewportHeight
        : null;

    // The wave signal must match what is actually on screen: the emitted
    // animateTo lands on the next vsync, so sample the traveled value from
    // BEFORE this frame's integration. Sampling the fresh value rides one
    // frame ahead of the real scroll, which makes lagging rows drift
    // downward during the spring's accelerating frames (the "down before
    // up" artifact) and adds a velocity-proportional wobble all glide long.
    final waveSignal = _waveTraveled;

    if (_springActive && error != null) {
      var dt = _lastGlideTick == null
          ? 0.0
          : (elapsed - _lastGlideTick!).inMicroseconds / 1e6;
      if (dt > 0) {
        dt = dt.clamp(0.0, 0.032);

        // Positive error: the target line's top sits below the anchor.
        // Growing the scroll offset pulls the line up, so the emitted
        // scroll delta is the negative of the spring's motion.
        final accel =
            -_glideOmega * _glideOmega * error -
            2 * _glideOmega * _glideVelocity;
        _glideVelocity += accel * dt;
        _waveTraveled += _glideVelocity * dt;

        if (error.abs() < _glideSettledError &&
            _glideVelocity.abs() < _glideSettledVelocity) {
          // Settled: stop pushing but keep ticking so the wave drains.
          _springActive = false;
          _glideVelocity = 0;
        } else if ((error - _prevGlideError).abs() < 0.5 &&
            _glideVelocity.abs() > 50) {
          // Edge clamps (top of the list, songs shorter than the viewport)
          // can make the target unreachable: if the error stops changing
          // while the spring is still pushing, give up and drain.
          _stalledFrames++;
          if (_stalledFrames > 5) {
            _springActive = false;
            _glideVelocity = 0;
          }
        } else {
          _stalledFrames = 0;
        }
        _prevGlideError = error;

        if (_springActive) {
          // Animate over (a hair less than) the measured frame interval, so
          // each delta lands fully before the next frame supersedes it — a
          // fixed duration undershoots on 120 Hz displays and the mismatch
          // reads as jitter.
          scrollOffsetController.animateScroll(
            offset: -_glideVelocity * dt,
            duration: Duration(microseconds: (dt * 0.9e6).round()),
            curve: Curves.linear,
          );
        }
      }
    }
    _lastGlideTick = elapsed;

    // Wave sampling: each row's lag is the delayed travel signal, so keep
    // feeding it even after the spring stops until the lag has drained.
    // Toggling the setting off mid-glide snaps to rigid immediately.
    if (!_waveOn && _wave.active) {
      _wave.end();
    }
    if (_springActive) {
      _lastMotionElapsed = elapsed;
    }
    if (_waveOn && _wave.active) {
      _wave.sample(elapsed, waveSignal);
    }
    final drained =
        _waveOn && _wave.active
        ? elapsed - _lastMotionElapsed >
              const Duration(milliseconds: _waveDrainMs)
        : true;
    if (!_springActive && drained) {
      _endWave();
      return;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    lines = widget.lines;
    currentLyricsIndexNotifier.addListener(scroll2CurrentIndex);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    currentLyricsIndexNotifier.removeListener(scroll2CurrentIndex);

    _endWave();
    _glideTicker?.dispose();
    _glideTicker = null;
    _wave.dispose();
    timer?.cancel();
    timer = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        jump = true;
        scroll2CurrentIndex();
        currentLyricsIndexNotifier.addListener(scroll2CurrentIndex);
        break;
      case AppLifecycleState.paused:
        currentLyricsIndexNotifier.removeListener(scroll2CurrentIndex);
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // scrolling to current index while resizing
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (currentLyricsIndexNotifier.value == -1) {
        return;
      }
      jump = true;
      scroll2CurrentIndex();
    });
    return LayoutBuilder(
      builder: (context, constraints) {
        final parentHeight = constraints.maxHeight; // height of the parent
        _viewportHeight = parentHeight;
        return NotificationListener<UserScrollNotification>(
          onNotification: (notification) {
            if (notification.direction != ScrollDirection.idle) {
              userDragging = true;
              timer?.cancel();
              timer = null;
            } else {
              timer ??= Timer(const Duration(milliseconds: 2000), () {
                userDragging = false;
                timer = null;
              });
            }
            return false;
          },
          child: ScrollablePositionedList.builder(
            physics: ClampingScrollPhysics(),
            itemCount: lines.length + 2,
            itemScrollController: itemScrollController,
            itemPositionsListener: itemPositionsListener,
            scrollOffsetController: scrollOffsetController,
            itemBuilder: (context, index) {
              if (index == 0) {
                return SizedBox(
                  height: widget.expanded
                      ? parentHeight * 0.25
                      : parentHeight * 0.4,
                );
              } else if (index == lines.length + 1) {
                return SizedBox(
                  height: widget.expanded
                      ? parentHeight * 0.65
                      : parentHeight * 0.45,
                );
              }
              return LyricLineWidget(
                index: index - 1,
                line: lines[index - 1],
                expanded: widget.expanded,
                isKaraoke: widget.isKaraoke,
                wave: _wave,
              );
            },
          ),
        );
      },
    );
  }
}

/// Each lyric line listens to lyricsPositionNotifier and stays lit for its
/// own activity window, so simultaneous duet lines light up together. During
/// the glide it also hangs behind the rigid motion by its distance from the
/// anchor line ([LyricGlideWave]), producing the line-by-line wave.
class LyricLineWidget extends StatelessWidget {
  final int index;
  final LyricLine line;
  final bool expanded;
  final bool isKaraoke;
  final LyricGlideWave wave;

  const LyricLineWidget({
    super.key,
    required this.line,
    required this.index,
    required this.expanded,
    required this.isKaraoke,
    required this.wave,
  });

  @override
  Widget build(BuildContext context) {
    double paddingHeight = 15;
    double fontSizeOffset = 0;
    if (!isMobile) {
      final pageHeight = MediaQuery.heightOf(context);
      final pageWidth = MediaQuery.widthOf(context);
      paddingHeight += (pageHeight - 700) * 0.025;
      fontSizeOffset = min(
        (pageHeight - 700) * 0.075,
        (pageWidth - 1050) * 0.025,
      ).clamp(0, double.maxFinite);
    }
    final row = Material(
      color: Colors.transparent,
      child: InkWell(
        mouseCursor: SystemMouseCursors.click,
        onTap: () {
          // add 1ms offset to avoid seeking to last lyric
          audioHandler.seek(line.start + Duration(milliseconds: 1));
        },
        customBorder: SmoothRectangleBorder(
          smoothness: 1,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: expanded
              ? EdgeInsets.fromLTRB(25, paddingHeight, 30, paddingHeight)
              : const EdgeInsets.symmetric(vertical: 5, horizontal: 15),
          child: ListenableBuilder(
            listenable: Listenable.merge([
              lyricsFontSizeOffsetNotifier,
              lyricsFontWeightNotifier,
              lyricsPositionNotifier,
            ]),
            builder: (context, _) {
              // A line stays lit for its whole activity window, so
              // simultaneous duet lines highlight and sweep together.
              final position = lyricsPositionNotifier.value;
              final isCurrent =
                  position >= line.start &&
                  (line.end == null || position < line.end!);

              double fontSize = 16 + lyricsFontSizeOffsetNotifier.value;

              if (expanded) {
                fontSize += isMobile ? 16 : 8;
              }

              fontSize += fontSizeOffset;

              final textColor = viewModeNotifier.value == .mini
                  ? miniViewForegroundColor.value
                  : lyricsPageForegroundColor.value;

              // Duet voices align left/right in every view; ordinary lines
              // keep the view's default placement.
              final crossAlign = switch (line.align) {
                LyricAlign.left => CrossAxisAlignment.start,
                LyricAlign.right => CrossAxisAlignment.end,
                LyricAlign.center =>
                  expanded ? CrossAxisAlignment.start : CrossAxisAlignment.center,
              };
              final textAlign = switch (line.align) {
                LyricAlign.left => TextAlign.left,
                LyricAlign.right => TextAlign.right,
                LyricAlign.center => expanded ? TextAlign.left : TextAlign.center,
              };
              final scaleAlignment = switch (line.align) {
                LyricAlign.left => Alignment.centerLeft,
                LyricAlign.right => Alignment.centerRight,
                LyricAlign.center =>
                  expanded ? Alignment.centerLeft : Alignment.center,
              };

              return AnimatedScale(
                scale: isCurrent ? 1.05 : 0.95,
                duration: Duration(milliseconds: 300),
                alignment: scaleAlignment,
                child: Column(
                  crossAxisAlignment: crossAlign,
                  children: [
                    if (isCurrent && isKaraoke)
                      ValueListenableBuilder(
                        valueListenable: updateLyricsNotifier,
                        builder: (context, value, child) {
                          return KaraokeText(
                            key: UniqueKey(),
                            line: line,
                            position: audioHandler.getPosition(),
                            fontSize: fontSize,
                            align: line.align,
                            expanded: expanded,
                          );
                        },
                      )
                    else
                      Text(
                        line.text,
                        textAlign: textAlign,
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: lyricsFontWeightNotifier.value,
                          color: isCurrent
                              ? textColor
                              : textColor.withAlpha(128),
                        ),
                      ),
                    for (final translate in line.translates)
                      Text(
                        translate,
                        textAlign: textAlign,
                        style: TextStyle(
                          fontSize: fontSize - (expanded ? 8 : 4),
                          fontWeight: lyricsFontWeightNotifier.value,
                          color: textColor.withAlpha(128),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );

    // The wave rides on top of the rigid scroll: each row hangs behind by
    // its distance from the anchor line. The lag is a pure per-frame
    // function (no per-row state), so it needs no commit step and decays
    // to zero on its own once the glide settles.
    return AnimatedBuilder(
      animation: wave,
      child: row,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, wave.lagFor(index + 1)),
        child: child,
      ),
    );
  }
}

class KaraokeText extends StatefulWidget {
  final LyricLine line;
  final Duration position;
  final double fontSize;
  final bool expanded;
  final LyricAlign align;
  final bool isDesktopLyrics;

  const KaraokeText({
    super.key,
    required this.line,
    required this.position,
    required this.fontSize,
    required this.expanded,
    this.align = LyricAlign.center,
    this.isDesktopLyrics = false,
  });

  @override
  State<KaraokeText> createState() => KaraokeTextState();
}

class KaraokeTextState extends State<KaraokeText>
    with SingleTickerProviderStateMixin {
  late final Ticker ticker;

  Duration displayPosition = Duration.zero;
  DateTime lastSyncTime = DateTime.now();

  late Color textColor;

  void _playStateListener() {
    if (isPlayingNotifier.value) {
      lastSyncTime = DateTime.now();
      if (!ticker.isActive) {
        ticker.start();
      }
    } else {
      if (ticker.isActive) {
        ticker.stop();
      }
    }
  }

  @override
  void initState() {
    super.initState();

    displayPosition = widget.position;
    ticker = createTicker((_) {
      final now = DateTime.now();

      setState(() {
        displayPosition += now.difference(lastSyncTime);
        lastSyncTime = now;
      });
    });

    isPlayingNotifier.addListener(_playStateListener);

    if (isPlayingNotifier.value) {
      ticker.start();
    }

    textColor = widget.isDesktopLyrics
        ? Colors.white
        : viewModeNotifier.value == .mini
        ? miniViewHighlightTextColor.value
        : lyricsPageHighlightTextColor.value;
  }

  @override
  void dispose() {
    isPlayingNotifier.removeListener(_playStateListener);
    ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textAlign = switch (widget.align) {
      LyricAlign.left => TextAlign.left,
      LyricAlign.right => TextAlign.right,
      LyricAlign.center => widget.expanded ? TextAlign.left : TextAlign.center,
    };
    return RichText(
      textAlign: textAlign,
      text: TextSpan(children: widget.line.tokens.map(buildTokenSpan).toList()),
    );
  }

  InlineSpan buildTokenSpan(LyricToken token) {
    final start = token.start;
    final end = token.end;

    double progress;
    final position =
        displayPosition +
        Duration(
          milliseconds: currentSongNotifier.value?.lyricsTimeOffset ?? 0,
        );
    if (position <= start) {
      progress = 0;
    } else if (position >= end!) {
      progress = 1;
    } else {
      progress =
          (position - start).inMilliseconds / (end - start).inMilliseconds;
    }

    final style = TextStyle(
      fontSize: widget.fontSize,
      fontWeight: lyricsFontWeightNotifier.value,
      color: textColor,
    );

    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: Stack(
        children: [
          Text(
            token.text,
            style: TextStyle(
              fontSize: widget.fontSize,
              color: Colors.transparent,
              shadows: widget.isDesktopLyrics
                  ? [
                      Shadow(
                        offset: Offset(2, 2),
                        blurRadius: isMobile ? 5 : 1,
                        color: isMobile ? Colors.black87 : Colors.black54,
                      ),
                    ]
                  : null,
            ),
          ),
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) {
              final p = progress.clamp(0.0, 1.0);
              return LinearGradient(
                colors: [textColor, textColor.withAlpha(128)],
                stops: [p, p],
              ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height));
            },
            child: Text(token.text, style: style),
          ),
        ],
      ),
    );
  }
}
