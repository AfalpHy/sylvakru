import 'package:flutter_test/flutter_test.dart';
import 'package:sylvakru/base/services/usb_audio_preferences.dart';

void main() {
  tearDown(() {
    usbAudioPreferences.resetForTest();
  });

  test('loads and serializes USB audio preferences', () {
    usbAudioPreferences.load({
      'usbFixedSampleRateEnabled': true,
      'usbFixedSampleRate': 96000,
      'usbDsdMode': 'native',
      'usbDsd64PcmRate': 176400,
      'usbPerformanceMode': false,
      'usbVolumeLockMode': 'always',
      'usbDsdGainCompensation': -6,
      'usbBusSpeedMode': 'high',
      'usbBitDepthMode': 'pcm32',
      'usbReleaseBandwidthAfterPlayback': true,
      'usbKeepAliveInBackground': false,
    });

    expect(usbAudioPreferences.preferredFixedSampleRate(), 96000);
    expect(usbAudioPreferences.dsdModeNotifier.value, UsbDsdMode.native);
    expect(usbAudioPreferences.dsd64PcmRateNotifier.value, 176400);
    expect(usbAudioPreferences.performanceModeNotifier.value, isFalse);
    expect(
      usbAudioPreferences.volumeLockModeNotifier.value,
      UsbVolumeLockMode.always,
    );
    expect(usbAudioPreferences.dsdGainCompensationNotifier.value, -6);
    expect(
      usbAudioPreferences.busSpeedModeNotifier.value,
      UsbBusSpeedMode.high,
    );
    expect(usbAudioPreferences.preferredEncoding(), 'pcm_32bit');
    expect(
      usbAudioPreferences.releaseUsbBandwidthAfterPlaybackNotifier.value,
      isTrue,
    );
    expect(usbAudioPreferences.keepAliveInBackgroundNotifier.value, isFalse);
    expect(usbAudioPreferences.toMap()['usbDsdMode'], 'native');
  });

  test('ignores unsupported fixed sample rate', () {
    usbAudioPreferences.load({
      'usbFixedSampleRateEnabled': true,
      'usbFixedSampleRate': 12345,
    });

    expect(usbAudioPreferences.preferredFixedSampleRate(), isNull);
  });
}
