import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/services/logger.dart';
import 'package:sylvakru/base/services/usb_audio_preferences.dart';

final usbAudioService = UsbAudioService();
final usbAudioStatusNotifier = ValueNotifier(UsbAudioStatus.unavailable());
final usbAudioEventNotifier = ValueNotifier<UsbAudioDeviceEvent?>(null);
final usbExclusivePlaybackStateNotifier = ValueNotifier(
  UsbExclusivePlaybackState.inactive(),
);
final usbTransportTelemetryNotifier = ValueNotifier(
  UsbTransportTelemetry.inactive(),
);

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

  Future<UsbExclusiveCapability> getExclusiveCapabilities() async {
    if (!_isAndroid) {
      return const UsbExclusiveCapability(
        available: false,
        permissionGranted: false,
        deviceName: null,
        deviceId: null,
        interfaceNumber: null,
        alternateSetting: null,
        endpointAddress: null,
        maxPacketSize: null,
        sampleRates: [],
        bitDepths: [],
        channelCounts: [],
        message: 'USB exclusive playback is only available on Android.',
      );
    }

    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        'getExclusiveCapabilities',
      );
      return UsbExclusiveCapability.fromMap(result ?? const {});
    } on PlatformException catch (error) {
      return UsbExclusiveCapability.unavailable(message: error.message);
    }
  }

  Future<UsbExclusivePlaybackState> startExclusivePlayback(
    UsbExclusivePlaybackRequest request,
  ) {
    return _invokeExclusiveState('startExclusivePlayback', request.toMap());
  }

  Future<UsbExclusivePlaybackState> pauseExclusivePlayback() {
    return _invokeExclusiveState('pauseExclusivePlayback');
  }

  Future<UsbExclusivePlaybackState> resumeExclusivePlayback() {
    return _invokeExclusiveState('resumeExclusivePlayback');
  }

  Future<void> setExclusiveTargetBufferMs(int targetBufferMs) async {
    if (!_isAndroid) {
      return;
    }

    await _channel.invokeMethod<void>('setExclusiveTargetBufferMs', {
      'targetBufferMs': targetBufferMs.clamp(50, 5000),
    });
  }

  Future<UsbExclusivePlaybackState> seekExclusivePlayback(Duration position) {
    return _invokeExclusiveState('seekExclusivePlayback', {
      'positionMs': position.inMilliseconds,
    });
  }

  Future<UsbExclusivePlaybackState> stopExclusivePlayback() {
    return _invokeExclusiveState('stopExclusivePlayback');
  }

  Future<UsbExclusivePlaybackState> releaseExclusiveDevice() {
    return _invokeExclusiveState('releaseExclusiveDevice');
  }

  /// 生成一键复制/导出的 DAC 适配诊断报告（纯文本 Markdown）。
  /// 报告不要求 DAC 在线：未连接设备时也会带上环境、偏好与最近日志。
  Future<String> getDiagnosticsReport() async {
    Map<String, Object?> native = const {};
    if (_isAndroid) {
      try {
        native =
            await _channel.invokeMapMethod<String, Object?>(
              'getUsbDiagnosticsReport',
            ) ??
            const {};
      } on PlatformException catch (error) {
        native = {'error': error.message};
      }
    }
    return buildUsbDiagnosticsReport(native, platformSupported: _isAndroid);
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

  Future<UsbExclusivePlaybackState> _invokeExclusiveState(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    if (!_isAndroid) {
      final state = UsbExclusivePlaybackState.inactive(
        message: 'USB exclusive playback is only available on Android.',
      );
      usbExclusivePlaybackStateNotifier.value = state;
      return state;
    }

    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        method,
        arguments,
      );
      final state = UsbExclusivePlaybackState.fromMap(result ?? const {});
      usbExclusivePlaybackStateNotifier.value = state;
      return state;
    } on PlatformException catch (error) {
      final state = UsbExclusivePlaybackState.inactive(message: error.message);
      usbExclusivePlaybackStateNotifier.value = state;
      return state;
    }
  }

  Future<Object?> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onUsbAudioDeviceEvent') {
      final event = UsbAudioDeviceEvent.fromMap(
        (call.arguments as Map).cast<String, Object?>(),
      );
      usbAudioStatusNotifier.value = event.status;
      usbAudioEventNotifier.value = event;
      return null;
    }

    if (call.method == 'onUsbExclusiveStateChanged' ||
        call.method == 'onUsbExclusivePosition' ||
        call.method == 'onUsbExclusiveError') {
      final state = UsbExclusivePlaybackState.fromMap(
        (call.arguments as Map?)?.cast<String, Object?>() ?? const {},
      );
      usbExclusivePlaybackStateNotifier.value = state;
      return null;
    }

    if (call.method == 'onUsbTransportTelemetryChanged') {
      final telemetry = UsbTransportTelemetry.fromMap(
        (call.arguments as Map?)?.cast<String, Object?>() ?? const {},
      );
      usbTransportTelemetryNotifier.value = telemetry;
      return null;
    }

    throw PlatformException(
      code: 'unimplemented',
      message: 'Unknown USB audio callback: ${call.method}',
    );
  }
}

@immutable
class UsbExclusiveCapability {
  final bool available;
  final bool permissionGranted;
  final String? deviceName;
  final int? deviceId;
  final int? interfaceNumber;
  final int? alternateSetting;
  final int? endpointAddress;
  final int? maxPacketSize;
  final List<int> sampleRates;
  final List<int> bitDepths;
  final List<int> channelCounts;
  final String? message;

  const UsbExclusiveCapability({
    required this.available,
    required this.permissionGranted,
    required this.deviceName,
    required this.deviceId,
    required this.interfaceNumber,
    required this.alternateSetting,
    required this.endpointAddress,
    required this.maxPacketSize,
    required this.sampleRates,
    required this.bitDepths,
    required this.channelCounts,
    required this.message,
  });

  factory UsbExclusiveCapability.unavailable({String? message}) {
    return UsbExclusiveCapability(
      available: false,
      permissionGranted: false,
      deviceName: null,
      deviceId: null,
      interfaceNumber: null,
      alternateSetting: null,
      endpointAddress: null,
      maxPacketSize: null,
      sampleRates: const [],
      bitDepths: const [],
      channelCounts: const [],
      message: message,
    );
  }

  factory UsbExclusiveCapability.fromMap(Map<String, Object?> map) {
    return UsbExclusiveCapability(
      available: map['available'] == true,
      permissionGranted: map['permissionGranted'] == true,
      deviceName: map['deviceName'] as String?,
      deviceId: _asInt(map['deviceId']),
      interfaceNumber: _asInt(map['interfaceNumber']),
      alternateSetting: _asInt(map['alternateSetting']),
      endpointAddress: _asInt(map['endpointAddress']),
      maxPacketSize: _asInt(map['maxPacketSize']),
      sampleRates: _asIntList(map['sampleRates']),
      bitDepths: _asIntList(map['bitDepths']),
      channelCounts: _asIntList(map['channelCounts']),
      message: map['message'] as String?,
    );
  }
}

@immutable
class UsbExclusivePlaybackRequest {
  final String filePath;
  final String? title;
  final String? sourceFormat;
  final int? sampleRate;
  final int? bitDepth;
  final int? targetBufferMs;
  final bool startPaused;

  const UsbExclusivePlaybackRequest({
    required this.filePath,
    required this.title,
    required this.sourceFormat,
    required this.sampleRate,
    required this.bitDepth,
    required this.targetBufferMs,
    required this.startPaused,
  });

  Map<String, Object?> toMap() {
    return {
      'filePath': filePath,
      'title': title,
      'sourceFormat': sourceFormat,
      'sampleRate': sampleRate,
      'bitDepth': bitDepth,
      'targetBufferMs': targetBufferMs,
      'startPaused': startPaused,
    };
  }
}

@immutable
class UsbExclusivePlaybackState {
  final bool active;
  final bool playing;
  final Duration position;
  final Duration? duration;
  final int? sampleRate;
  final int? bitDepth;
  final String? format;
  final String? message;

  const UsbExclusivePlaybackState({
    required this.active,
    required this.playing,
    required this.position,
    required this.duration,
    required this.sampleRate,
    required this.bitDepth,
    required this.format,
    required this.message,
  });

  factory UsbExclusivePlaybackState.inactive({String? message}) {
    return UsbExclusivePlaybackState(
      active: false,
      playing: false,
      position: Duration.zero,
      duration: null,
      sampleRate: null,
      bitDepth: null,
      format: null,
      message: message,
    );
  }

  factory UsbExclusivePlaybackState.fromMap(Map<String, Object?> map) {
    return UsbExclusivePlaybackState(
      active: map['active'] == true,
      playing: map['playing'] == true,
      position: Duration(milliseconds: _asInt(map['positionMs']) ?? 0),
      duration: _asInt(map['durationMs']) == null
          ? null
          : Duration(milliseconds: _asInt(map['durationMs'])!),
      sampleRate: _asInt(map['sampleRate']),
      bitDepth: _asInt(map['bitDepth']),
      format: map['format'] as String?,
      message: map['message'] as String?,
    );
  }
}

@immutable
class UsbTransportTelemetry {
  final bool active;
  final Duration bufferLevel;
  final Duration? minimumBufferLevel;
  final Duration? targetBuffer;
  final int isoPacketCount;
  final int pendingUrbs;
  final int underrunCount;
  final int updatedAtMs;

  const UsbTransportTelemetry({
    required this.active,
    required this.bufferLevel,
    required this.minimumBufferLevel,
    required this.targetBuffer,
    required this.isoPacketCount,
    required this.pendingUrbs,
    required this.underrunCount,
    required this.updatedAtMs,
  });

  factory UsbTransportTelemetry.inactive() {
    return const UsbTransportTelemetry(
      active: false,
      bufferLevel: Duration.zero,
      minimumBufferLevel: null,
      targetBuffer: null,
      isoPacketCount: 0,
      pendingUrbs: 0,
      underrunCount: 0,
      updatedAtMs: 0,
    );
  }

  factory UsbTransportTelemetry.fromMap(Map<String, Object?> map) {
    return UsbTransportTelemetry(
      active: map['active'] == true,
      bufferLevel: Duration(
        milliseconds: _asInt(map['bufferLevelMs'])?.clamp(0, 60000) ?? 0,
      ),
      minimumBufferLevel: _durationFromMs(map['minimumBufferLevelMs']),
      targetBuffer: _durationFromMs(map['targetBufferMs']),
      isoPacketCount: _asInt(map['isoPacketCount']) ?? 0,
      pendingUrbs: _asInt(map['pendingUrbs']) ?? 0,
      underrunCount: _asInt(map['underrunCount']) ?? 0,
      updatedAtMs: _asInt(map['updatedAtMs']) ?? 0,
    );
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
    final validRates = candidates
        .where(UsbAudioPreferences.sampleRates.contains)
        .toSet();
    for (final rate in const [48000, 44100, 96000, 88200, 192000, 176400]) {
      if (validRates.contains(rate)) {
        return rate;
      }
    }
    return null;
  }
}

/// 把原生侧采集的诊断数据与 Dart 侧的偏好/状态/日志拼装成单个纯文本报告。
/// 首行固定为版本标识，便于后续解析工具识别。抽成顶层函数便于单元测试。
String buildUsbDiagnosticsReport(
  Map<String, Object?> native, {
  bool platformSupported = true,
}) {
  final buffer = StringBuffer();
  buffer.writeln('Sylvakru USB 诊断报告 v1');

  final error = native['error'];
  if (error != null) {
    buffer.writeln();
    buffer.writeln('> 采集原生数据失败: $error');
  }

  // 1. 环境
  buffer.writeln();
  buffer.writeln('## 环境');
  buffer.writeln('- App 版本: $versionNumber');
  if (!platformSupported) {
    buffer.writeln('- 平台: 非 Android（原生 USB 数据不可用）');
  } else {
    final release = native['androidRelease'] ?? '未知';
    final sdk = _asInt(native['androidSdk']) ?? '未知';
    buffer.writeln('- Android: $release (SDK $sdk)');
    buffer.writeln(
      '- 机型: ${'${native['manufacturer'] ?? '未知'} ${native['model'] ?? ''}'.trim()}',
    );
  }
  buffer.writeln('- 生成时间: ${_formatTimestamp(native['generatedAtMs'])}');

  // 2. USB 设备标识
  buffer.writeln();
  buffer.writeln('## USB 设备标识');
  final device = native['device'];
  if (device is Map) {
    final d = device.cast<String, Object?>();
    buffer.writeln(
      '- VID/PID: ${d['vendorIdHex'] ?? d['vendorId']} / ${d['productIdHex'] ?? d['productId']}',
    );
    buffer.writeln('- 厂商: ${d['manufacturerName'] ?? '未知'}');
    buffer.writeln('- 产品: ${d['productName'] ?? '未知'}');
    buffer.writeln(
      '- deviceClass/subclass: ${d['deviceClass']} / ${d['deviceSubclass']}',
    );
    buffer.writeln(
      '- 接口总数 / Audio 接口数: ${d['interfaceCount']} / ${d['audioInterfaceCount']}',
    );
    buffer.writeln('- 序列号(脱敏): ${d['serialTail'] ?? '不可用'}');
    buffer.writeln(
      '- USB 权限: ${native['permissionGranted'] == true ? '已授权' : '未授权'}',
    );
    buffer.writeln('> 序列号仅显示末 4 位，不包含完整序列号。');
  } else {
    buffer.writeln('- 未检测到 USB 音频设备。');
  }

  final diagnostics =
      (native['diagnostics'] as Map?)?.cast<String, Object?>() ?? const {};

  // 3. 原始描述符 hex dump（离线还原设备行为的核心数据）
  buffer.writeln();
  buffer.writeln('## 原始描述符 (hex dump)');
  final hex = diagnostics['rawDescriptorsHex'];
  if (hex is String && hex.isNotEmpty) {
    buffer.writeln('长度: ${diagnostics['rawDescriptorLength'] ?? '未知'} bytes');
    buffer.writeln('```');
    buffer.writeln(hex);
    buffer.writeln('```');
  } else {
    buffer.writeln('- ${diagnostics['message'] ?? '描述符不可用。'}');
  }

  // 4. App 解析结果
  buffer.writeln();
  buffer.writeln('## App 解析结果');
  buffer.writeln('### AS 格式');
  _writeListSection(buffer, diagnostics['streamingFormats']);
  buffer.writeln('### 输出候选 (alt/maxPacket/attr/feedback/bits/format)');
  _writeListSection(buffer, diagnostics['outputCandidates']);
  buffer.writeln('- UAC2 时钟源 id: ${diagnostics['clockSourceId'] ?? '未知'}');
  buffer.writeln('- 最近一次 probe: ${native['lastProbe'] ?? '无'}');

  // 5. 系统侧能力
  buffer.writeln();
  buffer.writeln('## 系统侧能力');
  final status = (native['systemStatus'] as Map?)?.cast<String, Object?>();
  final devices = status?['devices'];
  if (devices is List && devices.isNotEmpty) {
    for (final dev in devices) {
      buffer.writeln('- $dev');
    }
  } else {
    buffer.writeln('- 无 USB 音频输出设备。');
  }

  // 6. 偏好快照
  buffer.writeln();
  buffer.writeln('## 偏好快照');
  usbAudioPreferences.toMap().forEach((key, value) {
    buffer.writeln('- $key: $value');
  });

  // 7. 运行状态快照
  buffer.writeln();
  buffer.writeln('## 运行状态快照');
  final state = usbExclusivePlaybackStateNotifier.value;
  buffer.writeln(
    '- 独占: active=${state.active}, playing=${state.playing}, '
    'format=${state.format}, sampleRate=${state.sampleRate}, '
    'bitDepth=${state.bitDepth}, position=${state.position.inMilliseconds}ms',
  );
  buffer.writeln('  message=${state.message}');
  final telemetry = usbTransportTelemetryNotifier.value;
  buffer.writeln(
    '- telemetry: active=${telemetry.active}, '
    'buffer=${telemetry.bufferLevel.inMilliseconds}ms, '
    'min=${telemetry.minimumBufferLevel?.inMilliseconds}, '
    'target=${telemetry.targetBuffer?.inMilliseconds}, '
    'iso=${telemetry.isoPacketCount}, pendingUrbs=${telemetry.pendingUrbs}, '
    'underrun=${telemetry.underrunCount}',
  );

  // 8. 最近日志
  buffer.writeln();
  buffer.writeln('## 最近日志 (Kotlin/native)');
  _writeLogLines(buffer, native['logs']);
  final nativeLog = native['nativeLogcat'];
  if (nativeLog is List && nativeLog.isNotEmpty) {
    buffer.writeln();
    buffer.writeln('### native logcat (SylvakruUsbExclusive)');
    _writeLogLines(buffer, nativeLog);
  }

  buffer.writeln();
  buffer.writeln('## 最近日志 (Dart)');
  final dartLogs = logger.tailContaining('usb', max: 200);
  if (dartLogs.isEmpty) {
    buffer.writeln('（无）');
  } else {
    for (final l in dartLogs) {
      buffer.writeln(l);
    }
  }

  return buffer.toString();
}

void _writeListSection(StringBuffer buffer, Object? value) {
  if (value is List && value.isNotEmpty) {
    for (final item in value) {
      buffer.writeln('- $item');
    }
  } else {
    buffer.writeln('- 无');
  }
}

void _writeLogLines(StringBuffer buffer, Object? value) {
  if (value is List && value.isNotEmpty) {
    for (final line in value) {
      buffer.writeln(line.toString());
    }
  } else {
    buffer.writeln('（无）');
  }
}

String _formatTimestamp(Object? millis) {
  final ms = _asInt(millis);
  if (ms == null || ms == 0) {
    return DateTime.now().toString();
  }
  return DateTime.fromMillisecondsSinceEpoch(ms).toString();
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

Duration? _durationFromMs(Object? value) {
  final milliseconds = _asInt(value);
  if (milliseconds == null) return null;
  return Duration(milliseconds: milliseconds.clamp(0, 60000));
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
