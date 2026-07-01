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
            'outputDeviceName': 'USB DAC',
            'outputSampleRate': 96000,
            'outputEncoding': 'pcm_24bit_packed',
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
      expect(status.outputDeviceName, 'USB DAC');
      expect(status.outputSampleRate, 96000);
      expect(status.outputEncoding, 'pcm_24bit_packed');
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
            'outputSampleRate': 96000,
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

  test('native USB added event updates status and event notifier', () async {
    UsbAudioService(channel: channel, isAndroid: true);

    final eventStatus = {
      'supported': true,
      'androidSdk': 35,
      'activeDeviceId': 18,
      'preferredApplied': false,
      'preferredSampleRate': null,
      'preferredEncoding': null,
      'preferredBitPerfect': false,
      'outputDeviceName': 'USB DAC',
      'outputSampleRate': 48000,
      'outputEncoding': 'pcm_16bit',
      'message': 'USB audio device detected.',
      'devices': [
        {
          'id': 18,
          'name': 'USB DAC',
          'type': 'usb_device',
          'address': 'dac-18',
          'sampleRates': [44100, 48000, 96000],
          'encodings': ['pcm_16bit', 'pcm_24bit_packed'],
          'channelCounts': [2],
          'supportedMixerSampleRates': [44100, 48000, 96000],
          'supportsBitPerfectMixer': true,
        },
      ],
    };

    await messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('onUsbAudioDeviceEvent', {
          'type': 'added',
          'deviceId': 18,
          'status': eventStatus,
        }),
      ),
      (_) {},
    );

    final event = usbAudioEventNotifier.value;
    expect(event, isNotNull);
    expect(event!.type, UsbAudioDeviceEventType.added);
    expect(event.deviceId, 18);
    expect(event.status.supported, isTrue);
    expect(event.status.devices.single.name, 'USB DAC');
    expect(usbAudioStatusNotifier.value.activeDeviceId, 18);
  });

  test('probeExclusiveAccess maps native USB claim result', () async {
    final service = UsbAudioService(channel: channel, isAndroid: true);

    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'probeExclusiveAccess') {
        return {
          'supported': true,
          'permissionGranted': true,
          'deviceName': 'USB DAC',
          'deviceId': 21,
          'audioInterfaceCount': 2,
          'claimedInterfaceCount': 1,
          'rawDescriptorLength': 257,
          'message': 'USB Audio interface can be claimed.',
        };
      }
      throw PlatformException(code: 'unexpected_method');
    });

    final result = await service.probeExclusiveAccess();

    expect(result.supported, isTrue);
    expect(result.permissionGranted, isTrue);
    expect(result.deviceName, 'USB DAC');
    expect(result.deviceId, 21);
    expect(result.audioInterfaceCount, 2);
    expect(result.claimedInterfaceCount, 1);
    expect(result.interfaceClaimed, isTrue);
    expect(result.rawDescriptorLength, 257);
  });

  test(
    'getExclusiveCapabilities maps native exclusive USB capabilities',
    () async {
      final service = UsbAudioService(channel: channel, isAndroid: true);

      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getExclusiveCapabilities') {
          return {
            'available': true,
            'permissionGranted': true,
            'deviceName': 'iBasso Macaron',
            'deviceId': 31,
            'interfaceNumber': 1,
            'alternateSetting': 1,
            'endpointAddress': 1,
            'maxPacketSize': 196,
            'sampleRates': [44100, 48000, 96000],
            'bitDepths': [16, 24, 32],
            'channelCounts': [2],
            'message': 'USB exclusive endpoint is available.',
          };
        }
        throw PlatformException(code: 'unexpected_method');
      });

      final capability = await service.getExclusiveCapabilities();

      expect(capability.available, isTrue);
      expect(capability.permissionGranted, isTrue);
      expect(capability.deviceName, 'iBasso Macaron');
      expect(capability.deviceId, 31);
      expect(capability.interfaceNumber, 1);
      expect(capability.alternateSetting, 1);
      expect(capability.endpointAddress, 1);
      expect(capability.maxPacketSize, 196);
      expect(capability.sampleRates, [44100, 48000, 96000]);
      expect(capability.bitDepths, [16, 24, 32]);
      expect(capability.channelCounts, [2]);
    },
  );

  test(
    'startExclusivePlayback sends playback request to native layer',
    () async {
      final service = UsbAudioService(channel: channel, isAndroid: true);
      Object? receivedArguments;

      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'startExclusivePlayback') {
          receivedArguments = call.arguments;
          return {
            'active': true,
            'playing': true,
            'positionMs': 0,
            'durationMs': 180000,
            'sampleRate': 44100,
            'bitDepth': 24,
            'format': 'flac',
            'message': 'USB exclusive playback started.',
          };
        }
        throw PlatformException(code: 'unexpected_method');
      });

      final state = await service.startExclusivePlayback(
        const UsbExclusivePlaybackRequest(
          filePath: '/music/test.flac',
          title: 'Test',
          sourceFormat: 'flac',
          sampleRate: 44100,
          bitDepth: 24,
          startPaused: false,
        ),
      );

      expect(receivedArguments, {
        'filePath': '/music/test.flac',
        'title': 'Test',
        'sourceFormat': 'flac',
        'sampleRate': 44100,
        'bitDepth': 24,
        'startPaused': false,
      });
      expect(state.active, isTrue);
      expect(state.playing, isTrue);
      expect(state.position, Duration.zero);
      expect(state.duration, const Duration(minutes: 3));
      expect(state.sampleRate, 44100);
      expect(state.bitDepth, 24);
      expect(state.format, 'flac');
      expect(usbExclusivePlaybackStateNotifier.value, state);
    },
  );

  test('native exclusive state event updates playback notifier', () async {
    UsbAudioService(channel: channel, isAndroid: true);

    await messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('onUsbExclusiveStateChanged', {
          'active': true,
          'playing': false,
          'positionMs': 42000,
          'durationMs': 240000,
          'sampleRate': 48000,
          'bitDepth': 24,
          'format': 'flac',
          'message': 'Paused.',
        }),
      ),
      (_) {},
    );

    final state = usbExclusivePlaybackStateNotifier.value;
    expect(state.active, isTrue);
    expect(state.playing, isFalse);
    expect(state.position, const Duration(seconds: 42));
    expect(state.duration, const Duration(minutes: 4));
    expect(state.sampleRate, 48000);
    expect(state.bitDepth, 24);
  });
}
