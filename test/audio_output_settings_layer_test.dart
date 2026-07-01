import 'dart:io';

import 'package:audio_tags_lofty/audio_tags_lofty.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sylvakru/base/app.dart' as app;
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/services/usb_audio_preferences.dart';
import 'package:sylvakru/base/services/usb_audio_service.dart';
import 'package:sylvakru/layer/audio_output_settings_layer.dart';

void main() {
  setUpAll(() {
    app.appSupportDir = Directory.systemTemp.createTempSync(
      'sylvakru_audio_settings_test_',
    );
  });

  tearDown(() {
    usbAudioPreferences.resetForTest();
    usbAudioStatusNotifier.value = UsbAudioStatus.unavailable();
    usbExclusivePlaybackStateNotifier.value =
        UsbExclusivePlaybackState.inactive();
    usbTransportTelemetryNotifier.value = UsbTransportTelemetry.inactive();
    currentSongNotifier.value = null;
  });

  testWidgets('传输状态卡使用 telemetry 水位而不是播放进度', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    usbAudioPreferences.load(const {});
    usbAudioStatusNotifier.value = const UsbAudioStatus(
      supported: true,
      androidSdk: 35,
      activeDeviceId: 7,
      preferredApplied: true,
      preferredSampleRate: 96000,
      preferredEncoding: 'pcm_24bit_packed',
      preferredBitPerfect: true,
      outputDeviceName: 'Macaron',
      outputSampleRate: 96000,
      outputEncoding: 'pcm_24bit_packed',
      message: null,
      devices: [
        UsbAudioDevice(
          id: 7,
          name: 'Macaron',
          type: 'usb_headset',
          address: '/dev/bus/usb/001/002',
          sampleRates: [48000, 96000],
          encodings: ['pcm_16bit', 'pcm_24bit_packed'],
          channelCounts: [2],
          supportedMixerSampleRates: [48000, 96000],
          supportsBitPerfectMixer: true,
        ),
      ],
    );
    usbExclusivePlaybackStateNotifier.value = const UsbExclusivePlaybackState(
      active: true,
      playing: true,
      position: Duration(milliseconds: 248424),
      duration: Duration(minutes: 3),
      sampleRate: 96000,
      bitDepth: 24,
      format: 'PCM',
      message: null,
    );
    usbTransportTelemetryNotifier.value = const UsbTransportTelemetry(
      active: true,
      bufferLevel: Duration(milliseconds: 184),
      minimumBufferLevel: Duration(milliseconds: 120),
      targetBuffer: Duration(milliseconds: 200),
      isoPacketCount: 4096,
      pendingUrbs: 7,
      underrunCount: 0,
      updatedAtMs: 123456,
    );

    await tester.pumpWidget(
      const MaterialApp(home: AudioOutputSettingsLayer()),
    );

    expect(find.text('传输状态'), findsOneWidget);
    expect(find.text('184 ms'), findsOneWidget);
    expect(find.text('248424 ms'), findsNothing);
    expect(find.text('缓冲区水位'), findsOneWidget);
    expect(find.text('ISO 4096'), findsOneWidget);
    expect(find.text('目标 200 ms'), findsOneWidget);
    expect(find.text('最低 120 ms'), findsOneWidget);
    expect(find.text('采样率'), findsNothing);
    expect(find.text('缓冲'), findsNothing);
  });

  testWidgets('传输状态卡低水位时不显示稳定', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    usbAudioPreferences.load(const {});
    usbAudioStatusNotifier.value = const UsbAudioStatus(
      supported: true,
      androidSdk: 35,
      activeDeviceId: 7,
      preferredApplied: true,
      preferredSampleRate: 96000,
      preferredEncoding: 'pcm_24bit_packed',
      preferredBitPerfect: true,
      outputDeviceName: 'Macaron',
      outputSampleRate: 96000,
      outputEncoding: 'pcm_24bit_packed',
      message: null,
      devices: [
        UsbAudioDevice(
          id: 7,
          name: 'Macaron',
          type: 'usb_headset',
          address: '/dev/bus/usb/001/002',
          sampleRates: [48000, 96000],
          encodings: ['pcm_16bit', 'pcm_24bit_packed'],
          channelCounts: [2],
          supportedMixerSampleRates: [48000, 96000],
          supportsBitPerfectMixer: true,
        ),
      ],
    );
    usbExclusivePlaybackStateNotifier.value = const UsbExclusivePlaybackState(
      active: true,
      playing: true,
      position: Duration(milliseconds: 1000),
      duration: Duration(minutes: 3),
      sampleRate: 96000,
      bitDepth: 24,
      format: 'PCM',
      message: null,
    );
    usbTransportTelemetryNotifier.value = const UsbTransportTelemetry(
      active: true,
      bufferLevel: Duration(milliseconds: 52),
      minimumBufferLevel: Duration(milliseconds: 2),
      targetBuffer: Duration(milliseconds: 300),
      isoPacketCount: 4096,
      pendingUrbs: 2,
      underrunCount: 0,
      updatedAtMs: 123456,
    );

    await tester.pumpWidget(
      const MaterialApp(home: AudioOutputSettingsLayer()),
    );

    expect(find.text('偏低'), findsOneWidget);
    expect(find.text('稳定'), findsNothing);
  });

  testWidgets('传输状态卡出现欠载时显示欠载', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    usbAudioPreferences.load(const {});
    usbAudioStatusNotifier.value = const UsbAudioStatus(
      supported: true,
      androidSdk: 35,
      activeDeviceId: 7,
      preferredApplied: true,
      preferredSampleRate: 96000,
      preferredEncoding: 'pcm_24bit_packed',
      preferredBitPerfect: true,
      outputDeviceName: 'Macaron',
      outputSampleRate: 96000,
      outputEncoding: 'pcm_24bit_packed',
      message: null,
      devices: [
        UsbAudioDevice(
          id: 7,
          name: 'Macaron',
          type: 'usb_headset',
          address: '/dev/bus/usb/001/002',
          sampleRates: [48000, 96000],
          encodings: ['pcm_16bit', 'pcm_24bit_packed'],
          channelCounts: [2],
          supportedMixerSampleRates: [48000, 96000],
          supportsBitPerfectMixer: true,
        ),
      ],
    );
    usbExclusivePlaybackStateNotifier.value = const UsbExclusivePlaybackState(
      active: true,
      playing: true,
      position: Duration(milliseconds: 1000),
      duration: Duration(minutes: 3),
      sampleRate: 96000,
      bitDepth: 24,
      format: 'PCM',
      message: null,
    );
    usbTransportTelemetryNotifier.value = const UsbTransportTelemetry(
      active: true,
      bufferLevel: Duration(milliseconds: 320),
      minimumBufferLevel: Duration(milliseconds: 280),
      targetBuffer: Duration(milliseconds: 300),
      isoPacketCount: 4096,
      pendingUrbs: 12,
      underrunCount: 1,
      updatedAtMs: 123456,
    );

    await tester.pumpWidget(
      const MaterialApp(home: AudioOutputSettingsLayer()),
    );

    expect(find.text('欠载'), findsOneWidget);
    expect(find.text('稳定'), findsNothing);
  });

  testWidgets('输出格式显示当前歌曲源文件信息', (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    usbAudioPreferences.load(const {});
    currentSongNotifier.value = MyAudioMetadata(
      AudioMetadata(
        format: 'FLAC',
        title: 'LUCKY',
        bitrate: 822000,
        samplerate: 44100,
      ),
      id: 'lucky',
      path: '/storage/emulated/0/Music/TOMOO - LUCKY.flac',
    );

    await tester.pumpWidget(
      const MaterialApp(home: AudioOutputSettingsLayer()),
    );

    expect(find.text('源文件'), findsOneWidget);
    expect(find.text('TOMOO - LUCKY.flac'), findsOneWidget);
    expect(find.text('44.1 kHz · FLAC · 822 kbps'), findsOneWidget);
    expect(find.text('等待播放'), findsNothing);
  });

  testWidgets('设备状态卡使用样板式状态字段', (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    usbAudioPreferences.load(const {});
    usbAudioStatusNotifier.value = const UsbAudioStatus(
      supported: true,
      androidSdk: 35,
      activeDeviceId: 7,
      preferredApplied: false,
      preferredSampleRate: null,
      preferredEncoding: 'pcm_24bit_packed',
      preferredBitPerfect: false,
      outputDeviceName: 'USB-Audio - Macaron',
      outputSampleRate: 44100,
      outputEncoding: 'pcm_24bit_packed',
      message: null,
      devices: [
        UsbAudioDevice(
          id: 7,
          name: 'USB-Audio - Macaron',
          type: 'usb_headset',
          address: 'usb_headset',
          sampleRates: [44100, 48000],
          encodings: ['pcm_16bit', 'pcm_24bit_packed'],
          channelCounts: [2],
          supportedMixerSampleRates: [44100, 48000],
          supportsBitPerfectMixer: false,
        ),
      ],
    );

    await tester.pumpWidget(
      const MaterialApp(home: AudioOutputSettingsLayer()),
    );

    expect(find.text('USB EXCLUSIVE'), findsOneWidget);
    expect(find.text('已连接'), findsOneWidget);
    expect(find.text('OUTPUT LINK'), findsOneWidget);
    expect(find.text('运行中'), findsOneWidget);
    expect(find.text('FORMAT'), findsOneWidget);
    expect(find.text('DEPTH'), findsOneWidget);
    expect(find.text('USB ID'), findsOneWidget);
  });

  testWidgets('后台稳定性移动到输出格式之后', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    usbAudioPreferences.load(const {});

    await tester.pumpWidget(
      const MaterialApp(home: AudioOutputSettingsLayer()),
    );

    final outputTop = tester.getTopLeft(find.text('输出格式')).dy;
    final stabilityTop = tester.getTopLeft(find.text('后台稳定性')).dy;

    expect(stabilityTop, greaterThan(outputTop));
  });
}
