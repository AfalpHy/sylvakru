import 'package:flutter_test/flutter_test.dart';
import 'package:sylvakru/base/services/usb_audio_service.dart';
import 'package:sylvakru/base/widgets/audio_output_panel.dart';

void main() {
  test('formatSampleRate displays source rate as kHz', () {
    expect(formatSampleRate(44100), '44.1 kHz');
    expect(formatSampleRate(96000), '96 kHz');
    expect(formatSampleRate(null), '未知');
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
}
