import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sylvakru/base/services/usb_audio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.afalphy.sylvakru/usb_audio');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'refreshStatus maps USB device capabilities from platform channel',
    () async {
      final service = UsbAudioService(channel: channel, isAndroid: true);

      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getStatus') {
          return {
            'supported': true,
            'androidSdk': 35,
            'activeDeviceId': 10,
            'preferredApplied': false,
            'preferredSampleRate': 96000,
            'preferredEncoding': 'pcm_24bit_packed',
            'preferredBitPerfect': true,
            'message': 'USB audio device detected',
            'devices': [
              {
                'id': 10,
                'name': 'USB DAC',
                'type': 'usb_device',
                'address': 'bus-001',
                'sampleRates': [44100, 48000, 96000],
                'encodings': ['pcm_16bit', 'pcm_24bit_packed'],
                'channelCounts': [2],
                'supportedMixerSampleRates': [48000, 96000],
                'supportsBitPerfectMixer': true,
              },
            ],
          };
        }
        throw PlatformException(code: 'unexpected_method');
      });

      final status = await service.refreshStatus();

      expect(status.supported, isTrue);
      expect(status.androidSdk, 35);
      expect(status.activeDeviceId, 10);
      expect(status.preferredSampleRate, 96000);
      expect(status.preferredEncoding, 'pcm_24bit_packed');
      expect(status.preferredBitPerfect, isTrue);
      expect(status.devices, hasLength(1));
      expect(status.devices.single.name, 'USB DAC');
      expect(status.devices.single.sampleRates, [44100, 48000, 96000]);
      expect(status.devices.single.supportsBitPerfectMixer, isTrue);
      expect(usbAudioStatusNotifier.value, status);
    },
  );

  test(
    'applyPreferredOutput requests requested sample rate and device id',
    () async {
      final service = UsbAudioService(channel: channel, isAndroid: true);
      Object? receivedArguments;

      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'applyPreferredOutput') {
          receivedArguments = call.arguments;
          return {
            'supported': true,
            'androidSdk': 35,
            'activeDeviceId': 10,
            'preferredApplied': true,
            'message': 'Applied preferred USB mixer attributes',
            'devices': const [],
          };
        }
        throw PlatformException(code: 'unexpected_method');
      });

      final status = await service.applyPreferredOutput(
        deviceId: 10,
        sampleRate: 96000,
      );

      expect(receivedArguments, {
        'deviceId': 10,
        'sampleRate': 96000,
        'encoding': 'pcm_24bit_packed',
        'bitPerfect': true,
      });
      expect(status.preferredApplied, isTrue);
      expect(status.message, 'Applied preferred USB mixer attributes');
    },
  );
}
