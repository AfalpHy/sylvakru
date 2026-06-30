import 'package:flutter_test/flutter_test.dart';
import 'package:sylvakru/base/services/usb_audio_preferences.dart';
import 'package:sylvakru/base/services/usb_audio_service.dart';
import 'package:sylvakru/base/widgets/audio_output_panel.dart';

void main() {
  tearDown(() {
    usbAudioPreferences.resetForTest();
  });

  test('formatSampleRate displays source rate as kHz', () {
    expect(formatSampleRate(44100), '44.1 kHz');
    expect(formatSampleRate(96000), '96 kHz');
    expect(formatSampleRate(null), '未知');
  });

  test('formatOutputSampleRate falls back to Android system output rate', () {
    const status = UsbAudioStatus(
      supported: false,
      androidSdk: 35,
      activeDeviceId: null,
      preferredApplied: false,
      preferredSampleRate: null,
      preferredEncoding: null,
      preferredBitPerfect: false,
      outputDeviceName: '内置扬声器',
      outputSampleRate: 48000,
      outputEncoding: 'pcm_16bit',
      message: null,
      devices: [],
    );

    expect(formatOutputSampleRate(status), '48 kHz');
  });

  test('buildSampleRateOptions prefers USB supported mixer rates', () {
    const status = UsbAudioStatus(
      supported: true,
      androidSdk: 35,
      activeDeviceId: 7,
      preferredApplied: true,
      preferredSampleRate: 96000,
      preferredEncoding: 'pcm_24bit_packed',
      preferredBitPerfect: true,
      outputDeviceName: 'USB DAC',
      outputSampleRate: 96000,
      outputEncoding: 'pcm_24bit_packed',
      message: null,
      devices: [
        UsbAudioDevice(
          id: 7,
          name: 'USB DAC',
          type: 'usb_device',
          address: 'dac',
          sampleRates: [44100, 48000],
          encodings: ['pcm_16bit'],
          channelCounts: [2],
          supportedMixerSampleRates: [48000, 96000, 192000],
          supportsBitPerfectMixer: true,
        ),
      ],
    );

    expect(buildSampleRateOptions(status, 44100), [
      null,
      48000,
      96000,
      192000,
      44100,
    ]);
  });

  test('exclusive sample rate prefers current song rate when supported', () {
    const status = UsbAudioStatus(
      supported: true,
      androidSdk: 35,
      activeDeviceId: 7,
      preferredApplied: false,
      preferredSampleRate: null,
      preferredEncoding: null,
      preferredBitPerfect: false,
      outputDeviceName: 'USB DAC',
      outputSampleRate: 48000,
      outputEncoding: 'pcm_16bit',
      message: null,
      devices: [
        UsbAudioDevice(
          id: 7,
          name: 'USB DAC',
          type: 'usb_device',
          address: 'dac',
          sampleRates: [48000, 96000],
          encodings: ['pcm_16bit'],
          channelCounts: [2],
          supportedMixerSampleRates: [44100, 48000, 96000],
          supportsBitPerfectMixer: true,
        ),
      ],
    );

    expect(preferredExclusiveSampleRate(status, 44100), 44100);
    expect(preferredExclusiveSampleRate(status, 88200), 96000);
  });

  test('exclusive sample rate prefers configured fixed rate', () {
    usbAudioPreferences.load({
      'usbFixedSampleRateEnabled': true,
      'usbFixedSampleRate': 192000,
    });

    const status = UsbAudioStatus(
      supported: true,
      androidSdk: 35,
      activeDeviceId: 7,
      preferredApplied: false,
      preferredSampleRate: null,
      preferredEncoding: null,
      preferredBitPerfect: false,
      outputDeviceName: 'USB DAC',
      outputSampleRate: 48000,
      outputEncoding: 'pcm_16bit',
      message: null,
      devices: [
        UsbAudioDevice(
          id: 7,
          name: 'USB DAC',
          type: 'usb_device',
          address: 'dac',
          sampleRates: [44100, 48000, 96000],
          encodings: ['pcm_16bit'],
          channelCounts: [2],
          supportedMixerSampleRates: [44100, 48000, 96000, 192000],
          supportsBitPerfectMixer: true,
        ),
      ],
    );

    expect(preferredExclusiveSampleRate(status, 44100), 192000);
  });
}
