import 'dart:convert';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:particle_music/base/services/emby_client.dart';
import 'package:particle_music/base/services/webdav_client.dart';
import 'package:particle_music/base/utils/color_manager.dart';
import 'package:particle_music/base/app.dart';
import 'package:particle_music/base/utils/logger.dart';
import 'package:particle_music/base/utils/lyric.dart';
import 'package:particle_music/base/widgets/equalizer.dart';
import 'package:particle_music/base/widgets/lyric_list_view.dart';
import 'package:particle_music/base/data/history.dart';
import 'package:particle_music/landscape_view/desktop_lyrics.dart';
import 'package:particle_music/base/extensions/window_controller_extension.dart';
import 'package:particle_music/layer/layers_manager.dart';
import 'package:particle_music/base/utils/contrast_color_generator.dart';
import 'package:particle_music/base/data/library.dart';
import 'package:particle_music/base/my_audio_metadata.dart';
import 'package:particle_music/base/services/navidrome_client.dart';
import 'package:particle_music/base/utils/metadata.dart';
import 'dart:async';

import 'package:particle_music/portrait_view/sleep_timer.dart';

late AudioSession _session;

late MyAudioHandler audioHandler;

List<MyAudioMetadata> playQueue = [];

final ValueNotifier<MyAudioMetadata?> currentSongNotifier = ValueNotifier(null);
final isPlayingNotifier = ValueNotifier(false);
final playModeNotifier = ValueNotifier(0);
final volumeNotifier = ValueNotifier(0.3);

final autoPlayOnStartupNotifier = ValueNotifier(false);

Future<void> initAudioService() async {
  MediaKit.ensureInitialized();
  audioHandler = await AudioService.init(
    builder: () => MyAudioHandler(),

    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.afalphy.particle_music',
      androidNotificationChannelName: 'Particle Music',
      androidNotificationOngoing: true,
    ),
  );
  _session = await AudioSession.instance;
  await _session.configure(AudioSessionConfiguration.music());

  _session.becomingNoisyEventStream.listen((_) {
    audioHandler.pause();
  });

  _session.interruptionEventStream.listen((event) {
    if (event.begin) {
      audioHandler.pause();
    }
  });
}

class MyAudioHandler extends BaseAudioHandler {
  final _player = Player();
  bool _started = false;
  int currentIndex = -1;
  List<MyAudioMetadata> _playQueueTmp = [];
  int _tmpPlayMode = 0;
  DateTime? _playLastSyncTime;
  Duration _playedDuration = Duration.zero;

  late final File _playQueueState;
  late final File _playState;
  late final File _equalizerState;

  bool isLoading = false;

  MyAudioHandler() {
    // avoid reading .lrc files
    (_player.platform as NativePlayer).setProperty('sub-auto', 'no');
    // clear invalid cache
    if (Platform.isLinux || Platform.isAndroid) {
      for (final f in tmpDir.listSync()) {
        if (f.path.contains('particle_music_cover')) {
          f.deleteSync();
        }
      }
    }
    _player.stream.error.listen((onData) {
      logger.output("player error:$onData");
    });

    _player.stream.completed.listen((completed) async {
      if (completed) {
        bool needPauseTmp = needPause;

        if (playModeNotifier.value == 2) {
          // repeat
          await load();
        } else {
          await skipToNext(); // automatically go to next song
        }

        if (needPauseTmp) {
          await pause();
        }
      }
    });

    currentSongNotifier.addListener(() {
      needPause = false;
      layersManager.updateBackground();
    });

    _player.stream.position.listen((position) {
      if (isLoading) {
        return;
      }
      _tryUpdateDesktopLyrics(position);
    });
  }

  void _tryUpdateDesktopLyrics(Duration position) {
    final currentSong = currentSongNotifier.value;
    if (currentSong == null || currentSong.parsedLyrics == null) {
      return;
    }
    ParsedLyrics parsedLyrics = currentSong.parsedLyrics!;

    List<LyricLine> lines = parsedLyrics.lines;

    int current = 0;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (position < line.start) {
        break;
      }
      if (line.start > lines[current].start) {
        current = i;
      }
    }

    final tmpLyricLine = currentLyricLine;

    currentLyricLine = lines[current];
    currentLyricLineIsKaraoke = parsedLyrics.isKaraoke;

    if (lyricsWindowVisible && currentLyricLine != tmpLyricLine) {
      updateDesktopLyrics();
    }
  }

  void updateIsPlaying(bool isPlaying) {
    if (isPlaying) {
      _playLastSyncTime = DateTime.now();
    } else if (_playLastSyncTime != null) {
      _playedDuration += DateTime.now().difference(_playLastSyncTime!);
      _playLastSyncTime = null;
    }
    needPause = false;
    isPlayingNotifier.value = isPlaying;

    lyricsWindowController?.sendPlaying(isPlaying);
  }

  void updatePlaybackState({Duration? postion, bool stop = false}) {
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          isPlayingNotifier.value ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: {MediaAction.seek},
        playing: isPlayingNotifier.value,
        processingState: stop ? .idle : .ready,
        speed: _player.state.rate,
        updatePosition: postion ?? _player.state.position,
      ),
    );
  }

  void initStateFiles() {
    _playQueueState = File("${appSupportDir.path}/play_queue_state.json");
    if (!(_playQueueState.existsSync())) {
      _savePlayQueueState();
    }
    _playState = File("${appSupportDir.path}/play_state.json");
    if (!(_playState.existsSync())) {
      savePlayState();
    }
    _equalizerState = File("${appSupportDir.path}/equalizer_state.json");
    if (!(_equalizerState.existsSync())) {
      saveEqualizerState();
    }
  }

  List<MyAudioMetadata> _restoreQueue(List<dynamic>? rawList) {
    final result = <MyAudioMetadata>[];

    for (final id in rawList ?? []) {
      final song = library.id2Song[id];
      if (song != null) result.add(song);
    }

    return result;
  }

  Future<void> loadPlayQueueState() async {
    final content = await _playQueueState.readAsString();

    final json = jsonDecode(content) as Map<String, dynamic>;

    _playQueueTmp.addAll(_restoreQueue(json['playQueueTmp']));
    playQueue.addAll(_restoreQueue(json['playQueue']));
  }

  void _savePlayQueueState() {
    _playQueueState.writeAsStringSync(
      jsonEncode({
        'playQueueTmp': _playQueueTmp.map((e) => e.id).toList(),
        'playQueue': playQueue.map((e) => e.id).toList(),
      }),
    );
  }

  Future<void> loadPlayState() async {
    final content = await _playState.readAsString();
    final Map<String, dynamic> json =
        jsonDecode(content) as Map<String, dynamic>;

    currentIndex = json['currentIndex'] as int? ?? -1;
    playModeNotifier.value = json['playMode'] as int? ?? 0;
    _tmpPlayMode = json['tmpPlayMode'] as int? ?? 0;

    volumeNotifier.value = json['volume'] as double? ?? 0.3;

    if (!_started) {
      _started = true;
      if (autoPlayOnStartupNotifier.value) {
        if (playQueue.isEmpty) {
          currentIndex = 0;
          playQueue = List.from(library.songListManager.getSongList());
        }
        if (playQueue.isNotEmpty) {
          isPlayingNotifier.value = true;
        } else {
          currentIndex = -1;
        }
      }
    }

    if (currentIndex != -1 && playQueue.isNotEmpty) {
      // reload may make some songs not in the library to be removed
      if (currentIndex >= playQueue.length) {
        currentIndex = 0;
      }
      await load();
    }
    if (!isMobile) {
      setVolume(volumeNotifier.value);
    }
  }

  void savePlayState() {
    _playState.writeAsStringSync(
      jsonEncode({
        'currentIndex': currentIndex,
        'playMode': playModeNotifier.value,
        'tmpPlayMode': _tmpPlayMode,
        'volume': volumeNotifier.value,
      }),
    );
  }

  Future<void> loadEqualizerState() async {
    final content = await _equalizerState.readAsString();
    gains = (jsonDecode(content) as List<dynamic>).cast();
    applyEqualizer();
  }

  void saveEqualizerState() {
    _equalizerState.writeAsStringSync(jsonEncode(gains));
  }

  void saveAllStates() {
    audioHandler.savePlayState();
    audioHandler._savePlayQueueState();
  }

  bool insert2Next(MyAudioMetadata song) {
    int songIndex = playQueue.indexOf(song);
    if (songIndex != -1) {
      if (songIndex == currentIndex) {
        return false;
      }
      if (songIndex < currentIndex) {
        playQueue.removeAt(songIndex);
        playQueue.insert(currentIndex, song);
        currentIndex -= 1;
      } else {
        playQueue.removeAt(songIndex);
        playQueue.insert(currentIndex + 1, song);
      }
    } else {
      playQueue.insert(currentIndex + 1, song);
      if (playModeNotifier.value == 1 ||
          (playModeNotifier.value == 2 && audioHandler._tmpPlayMode == 1)) {
        _playQueueTmp.add(song);
      }
    }
    return true;
  }

  bool add2Last(MyAudioMetadata song) {
    int songIndex = playQueue.indexOf(song);
    if (songIndex != -1) {
      if (songIndex == currentIndex) {
        return false;
      }
      if (songIndex < currentIndex) {
        currentIndex -= 1;
      }
      playQueue.removeAt(songIndex);
      playQueue.add(song);
    } else {
      playQueue.add(song);
      if (playModeNotifier.value == 1 ||
          (playModeNotifier.value == 2 && audioHandler._tmpPlayMode == 1)) {
        _playQueueTmp.add(song);
      }
    }
    return true;
  }

  void singlePlay(MyAudioMetadata song) async {
    if (insert2Next(song)) {
      await skipToNext();
      play();
    }
  }

  Future<void> setPlayQueue(List<MyAudioMetadata> source) async {
    playQueue = List.from(source);
    if (playModeNotifier.value == 1 ||
        (playModeNotifier.value == 2 && audioHandler._tmpPlayMode == 1)) {
      shuffle();
    }
    _savePlayQueueState();
  }

  void reversePlayQueue() {
    if (playQueue.isEmpty) {
      return;
    }
    playQueue = playQueue.reversed.toList();
    currentIndex = playQueue.indexOf(currentSongNotifier.value!);
    saveAllStates();
  }

  void shuffle() {
    if (playQueue.isEmpty) {
      return;
    }
    _playQueueTmp = List.from(playQueue);
    final others = List.of(playQueue)..removeAt(currentIndex);
    others.shuffle();
    playQueue = [playQueue[currentIndex], ...others];
    currentIndex = 0;
  }

  void changePlayMode(int newPlayMode) {
    if (newPlayMode == playModeNotifier.value) {
      return;
    }

    switch (newPlayMode) {
      case 0:
        if (_playQueueTmp.isNotEmpty) {
          playQueue = List.from(_playQueueTmp);
          _playQueueTmp = [];
          currentIndex = playQueue.indexOf(currentSongNotifier.value!);
          _savePlayQueueState();
        }
        break;
      case 1:
        if (_playQueueTmp.isEmpty) {
          shuffle();
          _savePlayQueueState();
        }
        break;
      default:
        break;
    }

    playModeNotifier.value = newPlayMode;

    savePlayState();
  }

  void switchPlayMode() {
    int playMode = playModeNotifier.value;
    playMode += 1;
    playMode %= 2;
    playModeNotifier.value = playMode;
    if (playMode == 0) {
      playQueue = List.from(_playQueueTmp);
      _playQueueTmp = [];
      currentIndex = playQueue.indexOf(currentSongNotifier.value!);
      _savePlayQueueState();
    } else if (playMode == 1) {
      shuffle();
      _savePlayQueueState();
    }
    savePlayState();
  }

  void toggleRepeat() {
    if (playModeNotifier.value != 2) {
      _tmpPlayMode = playModeNotifier.value;
      playModeNotifier.value = 2;
    } else {
      playModeNotifier.value = _tmpPlayMode;
    }
    savePlayState();
  }

  void delete(int index) {
    MyAudioMetadata tmp = playQueue[index];
    if (_playQueueTmp.isNotEmpty) {
      _playQueueTmp.remove(tmp);
    }
    playQueue.removeAt(index);
  }

  Future<void> clear() async {
    stop();
    playQueue = [];
    _playQueueTmp = [];
    currentLyricLine = null;
    if (!isMobile) {
      await updateDesktopLyrics();
    }
    currentIndex = -1;
    currentSongNotifier.value = null;
    currentCoverArtColor = Colors.grey;
    _savePlayQueueState();
    savePlayState();
  }

  Future<void> clearForReload() async {
    stop();
    playQueue = [];
    _playQueueTmp = [];
    currentLyricLine = null;
    if (!isMobile) {
      await updateDesktopLyrics();
    }
    currentSongNotifier.value = null;
    currentCoverArtColor = Colors.grey;
  }

  Future<void> load() async {
    if (currentSongNotifier.value != null) {
      if (_playLastSyncTime != null) {
        _playedDuration += DateTime.now().difference(_playLastSyncTime!);
      }
      if (currentSongNotifier.value!.duration != null) {
        double times =
            _playedDuration.inSeconds /
            currentSongNotifier.value!.duration!.inSeconds;
        if (times > 0.5) {
          library.tryAddCache(currentSongNotifier.value!);
          history.addSongTimes(currentSongNotifier.value!, times.round());
        }
      }

      _playLastSyncTime = null;
      _playedDuration = Duration.zero;
    }

    // save currentIndex
    savePlayState();

    final currentSong = playQueue[currentIndex];

    await setParsedLyrics(currentSong);
    currentCoverArtColor = await computeCoverArtColor(currentSong);
    if (lyricsPageThemeNotifier.value == .vivid) {
      lyricsPageBackgroundColor.updateColor();
      contrastColorTheme = ContrastColorGenerator.generate(
        currentCoverArtColor,
      );
      lyricsPageForegroundColor.updateColor();
      lyricsPageHighlightTextColor.updateColor();
      lyricsPageButtonColor.updateColor();
      lyricsPageDividerColor.updateColor();
      lyricsPageSelectedItemColor.updateColor();
    }

    currentSongNotifier.value = currentSong;

    isLoading = true;
    try {
      if (currentSong.cachePath != null) {
        await _player.open(
          Media(currentSong.cachePath!),
          play: isPlayingNotifier.value,
        );
      } else {
        switch (currentSong.sourceType) {
          case .navidrome:
            currentSong.path ??= navidromeClient!.getStreamUrl(currentSong.id);
            break;
          case .emby:
            currentSong.path ??= embyClient!.audioUrl(currentSong.id);
            break;
          default:
            break;
        }

        await _player.open(
          Media(
            currentSong.path!,
            httpHeaders: currentSong.sourceType == .webdav
                ? webdavClient?.headers
                : null,
          ),
          play: isPlayingNotifier.value,
        );
      }

      if (isPlayingNotifier.value) {
        _playLastSyncTime = DateTime.now();
      }
    } catch (error) {
      logger.output("[${currentSong.title}] $error");
    }
    isLoading = false;

    Uri? artUri;

    if (currentSong.pictureBytes != null) {
      String tmpPath = "${tmpDir.path}/particle_music_cover";
      // only doing this can update the picture
      if (Platform.isLinux || Platform.isAndroid) {
        tmpPath += currentSong.hashCode.toString();
      }
      final tmpFile = File(tmpPath);
      await tmpFile.writeAsBytes(currentSong.pictureBytes!);
      artUri = tmpFile.uri;
    }

    mediaItem.add(
      MediaItem(
        id: currentSong.id,
        title: getTitle(currentSong),
        artist: getArtist(currentSong),
        album: getAlbum(currentSong),
        artUri: artUri, // file:// URI
        duration: currentSong.duration,
      ),
    );
    updatePlaybackState(postion: Duration.zero);
    _tryUpdateDesktopLyrics(Duration.zero);
  }

  @override
  Future<void> play() async {
    if (playQueue.isEmpty) return;
    _player.play();

    updateIsPlaying(true);
    updatePlaybackState();
  }

  @override
  Future<void> pause() async {
    _player.pause();
    updateIsPlaying(false);
    updatePlaybackState();
  }

  @override
  Future<void> stop() async {
    _player.stop();
    updateIsPlaying(false);
    updatePlaybackState(stop: true);
  }

  @override
  Future<void> seek(Duration position) async {
    updatePlaybackState(postion: position);
    await _player.seek(position);
    // ensure position is updated
    await Future.delayed(Duration(milliseconds: 50));
    updateLyricsNotifier.value++;
  }

  @override
  Future<void> skipToNext() async {
    if (playQueue.isEmpty) return;

    currentIndex = (currentIndex + 1) % playQueue.length;
    await load();
  }

  @override
  Future<void> skipToPrevious() async {
    if (playQueue.isEmpty) return;

    currentIndex = (currentIndex + playQueue.length - 1) % playQueue.length;
    await load();
  }

  void togglePlay() {
    if (isPlayingNotifier.value) {
      pause();
    } else {
      play();
    }
  }

  Stream<Duration> getPositionStream() {
    return _player.stream.position;
  }

  Duration getPosition() {
    return _player.state.position;
  }

  void setVolume(double volume) {
    _player.setVolume(volume * 100);
  }

  void applyEqualizer() async {
    final af = [
      'aformat=sample_fmts=fltp',

      ...List.generate(freqs.length, (i) {
        return 'equalizer=f=${freqs[i]}:t=o:w=1:g=${gains[i]}';
      }),
    ].join(',');
    await (_player.platform as NativePlayer).setProperty('af', af);
    saveEqualizerState();
  }
}
