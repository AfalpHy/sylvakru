import 'package:flutter/foundation.dart';

final usbAudioPreferences = UsbAudioPreferences();

int preferredUsbExclusiveTargetBufferMs({required bool background}) {
  if (background && usbAudioPreferences.keepAliveInBackgroundNotifier.value) {
    return usbAudioPreferences.backgroundBufferMsNotifier.value;
  }
  return usbAudioPreferences.foregroundBufferMsNotifier.value;
}

int? preferredUsbExclusiveBitDepth() {
  return switch (usbAudioPreferences.bitDepthModeNotifier.value) {
    UsbBitDepthMode.auto => null,
    UsbBitDepthMode.pcm16 => 16,
    UsbBitDepthMode.pcm24 => 24,
    UsbBitDepthMode.pcm32 => 32,
  };
}

enum UsbDsdMode { pcm, dop, native }

enum UsbVolumeLockMode { off, dsdOnly, always }

enum UsbBusSpeedMode { auto, full, high, superSpeed }

enum UsbBitDepthMode { auto, pcm16, pcm24, pcm32 }

class UsbAudioPreferences {
  static const sampleRates = [44100, 48000, 88200, 96000, 176400, 192000];

  final fixedSampleRateEnabledNotifier = ValueNotifier(false);
  final fixedSampleRateNotifier = ValueNotifier<int?>(null);
  final dsdModeNotifier = ValueNotifier(UsbDsdMode.dop);
  final dsd64PcmRateNotifier = ValueNotifier(88200);
  final dsd128PcmRateNotifier = ValueNotifier(88200);
  final dsd256PcmRateNotifier = ValueNotifier(88200);
  final dsd512PcmRateNotifier = ValueNotifier(88200);
  final performanceModeNotifier = ValueNotifier(true);
  final volumeLockModeNotifier = ValueNotifier(UsbVolumeLockMode.dsdOnly);
  final dsdGainCompensationNotifier = ValueNotifier(0);
  final busSpeedModeNotifier = ValueNotifier(UsbBusSpeedMode.auto);
  final bitDepthModeNotifier = ValueNotifier(UsbBitDepthMode.auto);
  final releaseUsbBandwidthAfterPlaybackNotifier = ValueNotifier(false);
  final keepAliveInBackgroundNotifier = ValueNotifier(true);
  final bitDepthCompatNotifier = ValueNotifier(true);
  final sampleRateCompatNotifier = ValueNotifier(true);
  final channelCompatNotifier = ValueNotifier(true);
  final tpdfDitherNotifier = ValueNotifier(false);
  final foregroundBufferMsNotifier = ValueNotifier(200);
  final backgroundBufferMsNotifier = ValueNotifier(1500);
  final volumeSmoothHandoffNotifier = ValueNotifier(true);
  final delayedUsbLinkNotifier = ValueNotifier(false);

  void load(Map<String, dynamic> json) {
    fixedSampleRateEnabledNotifier.value =
        json['usbFixedSampleRateEnabled'] as bool? ?? false;
    fixedSampleRateNotifier.value = _validRate(
      json['usbFixedSampleRate'] as int?,
    );
    dsdModeNotifier.value = _enumByName(
      UsbDsdMode.values,
      json['usbDsdMode'] as String?,
      UsbDsdMode.dop,
    );
    dsd64PcmRateNotifier.value =
        _validRate(json['usbDsd64PcmRate'] as int?) ?? 88200;
    dsd128PcmRateNotifier.value =
        _validRate(json['usbDsd128PcmRate'] as int?) ?? 88200;
    dsd256PcmRateNotifier.value =
        _validRate(json['usbDsd256PcmRate'] as int?) ?? 88200;
    dsd512PcmRateNotifier.value =
        _validRate(json['usbDsd512PcmRate'] as int?) ?? 88200;
    performanceModeNotifier.value = json['usbPerformanceMode'] as bool? ?? true;
    volumeLockModeNotifier.value = _enumByName(
      UsbVolumeLockMode.values,
      json['usbVolumeLockMode'] as String?,
      UsbVolumeLockMode.dsdOnly,
    );
    dsdGainCompensationNotifier.value =
        json['usbDsdGainCompensation'] as int? ?? 0;
    busSpeedModeNotifier.value = _enumByName(
      UsbBusSpeedMode.values,
      json['usbBusSpeedMode'] as String?,
      UsbBusSpeedMode.auto,
    );
    bitDepthModeNotifier.value = _enumByName(
      UsbBitDepthMode.values,
      json['usbBitDepthMode'] as String?,
      UsbBitDepthMode.auto,
    );
    releaseUsbBandwidthAfterPlaybackNotifier.value =
        json['usbReleaseBandwidthAfterPlayback'] as bool? ?? false;
    keepAliveInBackgroundNotifier.value =
        json['usbKeepAliveInBackground'] as bool? ?? true;
    bitDepthCompatNotifier.value = json['usbBitDepthCompat'] as bool? ?? true;
    sampleRateCompatNotifier.value =
        json['usbSampleRateCompat'] as bool? ?? true;
    channelCompatNotifier.value = json['usbChannelCompat'] as bool? ?? true;
    tpdfDitherNotifier.value = json['usbTpdfDither'] as bool? ?? false;
    foregroundBufferMsNotifier.value = _validBufferMs(
      json['usbForegroundBufferMs'] as int?,
      200,
    );
    backgroundBufferMsNotifier.value = _validBufferMs(
      json['usbBackgroundBufferMs'] as int?,
      1500,
    );
    volumeSmoothHandoffNotifier.value =
        json['usbVolumeSmoothHandoff'] as bool? ?? true;
    delayedUsbLinkNotifier.value = json['usbDelayedUsbLink'] as bool? ?? false;
  }

  Map<String, Object?> toMap() {
    return {
      'usbFixedSampleRateEnabled': fixedSampleRateEnabledNotifier.value,
      'usbFixedSampleRate': fixedSampleRateNotifier.value,
      'usbDsdMode': dsdModeNotifier.value.name,
      'usbDsd64PcmRate': dsd64PcmRateNotifier.value,
      'usbDsd128PcmRate': dsd128PcmRateNotifier.value,
      'usbDsd256PcmRate': dsd256PcmRateNotifier.value,
      'usbDsd512PcmRate': dsd512PcmRateNotifier.value,
      'usbPerformanceMode': performanceModeNotifier.value,
      'usbVolumeLockMode': volumeLockModeNotifier.value.name,
      'usbDsdGainCompensation': dsdGainCompensationNotifier.value,
      'usbBusSpeedMode': busSpeedModeNotifier.value.name,
      'usbBitDepthMode': bitDepthModeNotifier.value.name,
      'usbReleaseBandwidthAfterPlayback':
          releaseUsbBandwidthAfterPlaybackNotifier.value,
      'usbKeepAliveInBackground': keepAliveInBackgroundNotifier.value,
      'usbBitDepthCompat': bitDepthCompatNotifier.value,
      'usbSampleRateCompat': sampleRateCompatNotifier.value,
      'usbChannelCompat': channelCompatNotifier.value,
      'usbTpdfDither': tpdfDitherNotifier.value,
      'usbForegroundBufferMs': foregroundBufferMsNotifier.value,
      'usbBackgroundBufferMs': backgroundBufferMsNotifier.value,
      'usbVolumeSmoothHandoff': volumeSmoothHandoffNotifier.value,
      'usbDelayedUsbLink': delayedUsbLinkNotifier.value,
    };
  }

  int? preferredFixedSampleRate() {
    if (!fixedSampleRateEnabledNotifier.value) {
      return null;
    }
    return _validRate(fixedSampleRateNotifier.value);
  }

  String preferredEncoding() {
    return switch (bitDepthModeNotifier.value) {
      UsbBitDepthMode.pcm16 => 'pcm_16bit',
      UsbBitDepthMode.pcm24 => 'pcm_24bit_packed',
      UsbBitDepthMode.pcm32 => 'pcm_32bit',
      UsbBitDepthMode.auto => 'pcm_24bit_packed',
    };
  }

  void resetForTest() {
    load(const {});
  }

  T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
    for (final value in values) {
      if (value.name == name) {
        return value;
      }
    }
    return fallback;
  }

  int? _validRate(int? rate) {
    if (rate == null) return null;
    return sampleRates.contains(rate) ? rate : null;
  }

  int _validBufferMs(int? value, int fallback) {
    if (value == null) return fallback;
    return value.clamp(50, 5000);
  }
}
