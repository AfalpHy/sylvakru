import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

final usbAudioService = UsbAudioService();
final usbAudioStatusNotifier = ValueNotifier(UsbAudioStatus.unavailable());
final usbAudioEventNotifier = ValueNotifier<UsbAudioDeviceEvent?>(null);

enum UsbAudioDeviceEventType { added, removed }

class UsbAudioService {
  static const MethodChannel _defaultChannel = MethodChannel(
    'com.afalphy.sylvakru/usb_audio',
  );

  final MethodChannel _channel;
  final bool _isAndroid;

  UsbAudioService({MethodChannel channel = _defaultChannel, bool? isAndroid})
    : _channel = channel,
      _isAndroid = isAndroid ?? Platform.isAndroid {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  Future<UsbAudioStatus> refreshStatus() async {
    if (!_isAndroid) {
      final status = UsbAudioStatus.unavailable(
        message: 'USB audio optimization is only available on Android.',
      );
      usbAudioStatusNotifier.value = status;
      return status;
    }

    return _invokeStatus('getStatus');
  }

  Future<UsbAudioStatus> applyPreferredOutput({
    int? deviceId,
    int? sampleRate,
    String encoding = 'pcm_24bit_packed',
    bool bitPerfect = true,
  }) async {
    if (!_isAndroid) {
      final status = UsbAudioStatus.unavailable(
        message: 'USB audio optimization is only available on Android.',
      );
      usbAudioStatusNotifier.value = status;
      return status;
    }

    return _invokeStatus('applyPreferredOutput', {
      'deviceId': ?deviceId,
      'sampleRate': ?sampleRate,
      'encoding': encoding,
      'bitPerfect': bitPerfect,
    });
  }

  Future<UsbAudioStatus> clearPreferredOutput() async {
    if (!_isAndroid) {
      final status = UsbAudioStatus.unavailable(
        message: 'USB audio optimization is only available on Android.',
      );
      usbAudioStatusNotifier.value = status;
      return status;
    }

    return _invokeStatus('clearPreferredOutput');
  }

  Future<UsbExclusiveProbeResult> probeExclusiveAccess() async {
    if (!_isAndroid) {
      return const UsbExclusiveProbeResult(
        supported: false,
        permissionGranted: false,
        deviceName: null,
        deviceId: null,
        audioInterfaceCount: 0,
        claimedInterfaceCount: 0,
        rawDescriptorLength: 0,
        message: 'USB exclusive access probing is only available on Android.',
      );
    }

    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        'probeExclusiveAccess',
      );
      return UsbExclusiveProbeResult.fromMap(result ?? const {});
    } on PlatformException catch (error) {
      return UsbExclusiveProbeResult(
        supported: false,
        permissionGranted: false,
        deviceName: null,
        deviceId: null,
        audioInterfaceCount: 0,
        claimedInterfaceCount: 0,
        rawDescriptorLength: 0,
        message: error.message,
      );
    }
  }

  Future<UsbAudioStatus> _invokeStatus(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        method,
        arguments,
      );
      final status = UsbAudioStatus.fromMap(result ?? const {});
      usbAudioStatusNotifier.value = status;
      return status;
    } on PlatformException catch (error) {
      final status = UsbAudioStatus.unavailable(message: error.message);
      usbAudioStatusNotifier.value = status;
      return status;
    }
  }

  Future<Object?> _handleNativeCall(MethodCall call) async {
    if (call.method != 'onUsbAudioDeviceEvent') {
      throw PlatformException(
        code: 'unimplemented',
        message: 'Unknown USB audio callback: ${call.method}',
      );
    }

    final event = UsbAudioDeviceEvent.fromMap(
      (call.arguments as Map).cast<String, Object?>(),
    );
    usbAudioStatusNotifier.value = event.status;
    usbAudioEventNotifier.value = event;
    return null;
  }
}

@immutable
class UsbExclusiveProbeResult {
  final bool supported;
  final bool permissionGranted;
  final String? deviceName;
  final int? deviceId;
  final int audioInterfaceCount;
  final int claimedInterfaceCount;
  final int rawDescriptorLength;
  final String? message;

  const UsbExclusiveProbeResult({
    required this.supported,
    required this.permissionGranted,
    required this.deviceName,
    required this.deviceId,
    required this.audioInterfaceCount,
    required this.claimedInterfaceCount,
    required this.rawDescriptorLength,
    required this.message,
  });

  factory UsbExclusiveProbeResult.fromMap(Map<String, Object?> map) {
    return UsbExclusiveProbeResult(
      supported: map['supported'] == true,
      permissionGranted: map['permissionGranted'] == true,
      deviceName: map['deviceName'] as String?,
      deviceId: _asInt(map['deviceId']),
      audioInterfaceCount: _asInt(map['audioInterfaceCount']) ?? 0,
      claimedInterfaceCount: _asInt(map['claimedInterfaceCount']) ?? 0,
      rawDescriptorLength: _asInt(map['rawDescriptorLength']) ?? 0,
      message: map['message'] as String?,
    );
  }

  bool get interfaceClaimed => claimedInterfaceCount > 0;
}

@immutable
class UsbAudioDeviceEvent {
  final UsbAudioDeviceEventType type;
  final int? deviceId;
  final UsbAudioStatus status;

  const UsbAudioDeviceEvent({
    required this.type,
    required this.deviceId,
    required this.status,
  });

  factory UsbAudioDeviceEvent.fromMap(Map<String, Object?> map) {
    return UsbAudioDeviceEvent(
      type: map['type'] == 'removed'
          ? UsbAudioDeviceEventType.removed
          : UsbAudioDeviceEventType.added,
      deviceId: _asInt(map['deviceId']),
      status: UsbAudioStatus.fromMap(
        (map['status'] as Map?)?.cast<String, Object?>() ?? const {},
      ),
    );
  }
}

@immutable
class UsbAudioStatus {
  final bool supported;
  final int androidSdk;
  final int? activeDeviceId;
  final bool preferredApplied;
  final int? preferredSampleRate;
  final String? preferredEncoding;
  final bool preferredBitPerfect;
  final String? outputDeviceName;
  final int? outputSampleRate;
  final String? outputEncoding;
  final String? message;
  final List<UsbAudioDevice> devices;

  const UsbAudioStatus({
    required this.supported,
    required this.androidSdk,
    required this.activeDeviceId,
    required this.preferredApplied,
    required this.preferredSampleRate,
    required this.preferredEncoding,
    required this.preferredBitPerfect,
    required this.outputDeviceName,
    required this.outputSampleRate,
    required this.outputEncoding,
    required this.message,
    required this.devices,
  });

  factory UsbAudioStatus.unavailable({String? message}) {
    return UsbAudioStatus(
      supported: false,
      androidSdk: 0,
      activeDeviceId: null,
      preferredApplied: false,
      preferredSampleRate: null,
      preferredEncoding: null,
      preferredBitPerfect: false,
      outputDeviceName: null,
      outputSampleRate: null,
      outputEncoding: null,
      message: message,
      devices: const [],
    );
  }

  factory UsbAudioStatus.fromMap(Map<String, Object?> map) {
    final devicesRaw = map['devices'];
    final devices = devicesRaw is List
        ? devicesRaw
              .whereType<Map>()
              .map(
                (device) =>
                    UsbAudioDevice.fromMap(device.cast<String, Object?>()),
              )
              .toList(growable: false)
        : const <UsbAudioDevice>[];

    return UsbAudioStatus(
      supported: map['supported'] == true,
      androidSdk: _asInt(map['androidSdk']) ?? 0,
      activeDeviceId: _asInt(map['activeDeviceId']),
      preferredApplied: map['preferredApplied'] == true,
      preferredSampleRate: _asInt(map['preferredSampleRate']),
      preferredEncoding: map['preferredEncoding'] as String?,
      preferredBitPerfect: map['preferredBitPerfect'] == true,
      outputDeviceName: map['outputDeviceName'] as String?,
      outputSampleRate: _asInt(map['outputSampleRate']),
      outputEncoding: map['outputEncoding'] as String?,
      message: map['message'] as String?,
      devices: devices,
    );
  }

  int? get bestAvailableDeviceId {
    if (activeDeviceId != null) {
      return activeDeviceId;
    }
    return devices.isEmpty ? null : devices.first.id;
  }

  int? get bestAvailableSampleRate {
    final deviceId = bestAvailableDeviceId;
    if (deviceId == null) {
      return null;
    }
    for (final device in devices) {
      if (device.id == deviceId) {
        return device.bestSampleRate;
      }
    }
    return null;
  }
}

@immutable
class UsbAudioDevice {
  final int id;
  final String name;
  final String type;
  final String? address;
  final List<int> sampleRates;
  final List<String> encodings;
  final List<int> channelCounts;
  final List<int> supportedMixerSampleRates;
  final bool supportsBitPerfectMixer;

  const UsbAudioDevice({
    required this.id,
    required this.name,
    required this.type,
    required this.address,
    required this.sampleRates,
    required this.encodings,
    required this.channelCounts,
    required this.supportedMixerSampleRates,
    required this.supportsBitPerfectMixer,
  });

  factory UsbAudioDevice.fromMap(Map<String, Object?> map) {
    return UsbAudioDevice(
      id: _asInt(map['id']) ?? -1,
      name: (map['name'] as String?)?.trim().isNotEmpty == true
          ? map['name'] as String
          : 'USB audio device',
      type: map['type'] as String? ?? 'unknown',
      address: map['address'] as String?,
      sampleRates: _asIntList(map['sampleRates']),
      encodings: _asStringList(map['encodings']),
      channelCounts: _asIntList(map['channelCounts']),
      supportedMixerSampleRates: _asIntList(map['supportedMixerSampleRates']),
      supportsBitPerfectMixer: map['supportsBitPerfectMixer'] == true,
    );
  }

  int? get bestSampleRate {
    final candidates = supportedMixerSampleRates.isNotEmpty
        ? supportedMixerSampleRates
        : sampleRates;
    if (candidates.isEmpty) {
      return null;
    }
    final sorted = [...candidates]..sort();
    return sorted.last;
  }
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

List<int> _asIntList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value.map(_asInt).whereType<int>().toList(growable: false);
}

List<String> _asStringList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value.whereType<String>().toList(growable: false);
}
