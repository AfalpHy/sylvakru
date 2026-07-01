import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sylvakru/base/services/usb_audio_preferences.dart';
import 'package:sylvakru/base/services/usb_audio_service.dart';
import 'package:sylvakru/layer/audio_output_settings_layer.dart';

void main() {
  tearDown(() {
    usbAudioPreferences.resetForTest();
    usbAudioStatusNotifier.value = UsbAudioStatus.unavailable();
    usbExclusivePlaybackStateNotifier.value =
        UsbExclusivePlaybackState.inactive();
  });

  testWidgets('传输状态卡使用水位表达且隐藏采样率和缓冲设置值', (tester) async {
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
      position: Duration(milliseconds: 195),
      duration: Duration(minutes: 3),
      sampleRate: 96000,
      bitDepth: 24,
      format: 'PCM',
      message: null,
    );

    await tester.pumpWidget(
      const MaterialApp(home: AudioOutputSettingsLayer()),
    );

    expect(find.text('传输状态'), findsOneWidget);
    expect(find.text('195 ms'), findsOneWidget);
    expect(find.text('缓冲区水位'), findsOneWidget);
    expect(find.text('ISO 0'), findsOneWidget);
    expect(find.text('目标 200 ms'), findsOneWidget);
    expect(find.text('最低 195 ms'), findsOneWidget);
    expect(find.text('采样率'), findsNothing);
    expect(find.text('缓冲'), findsNothing);
  });
}
