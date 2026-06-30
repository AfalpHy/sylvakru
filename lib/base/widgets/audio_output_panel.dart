import 'package:flutter/material.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/base/services/usb_audio_preferences.dart';
import 'package:sylvakru/base/services/usb_audio_service.dart';

String formatSampleRate(int? sampleRate) {
  if (sampleRate == null || sampleRate <= 0) {
    return '未知';
  }

  final khz = sampleRate / 1000.0;
  if (khz == khz.roundToDouble()) {
    return '${khz.round()} kHz';
  }
  return '${khz.toStringAsFixed(1)} kHz';
}

String formatOutputSampleRate(UsbAudioStatus status) {
  final exclusive = usbExclusivePlaybackStateNotifier.value;
  if (exclusive.active && exclusive.sampleRate != null) {
    return formatSampleRate(exclusive.sampleRate);
  }

  return formatSampleRate(
    status.preferredSampleRate ?? status.outputSampleRate,
  );
}

String formatBitrate(int? bitrate) {
  if (bitrate == null || bitrate <= 0) {
    return '未知';
  }
  return '${(bitrate / 1000).round()} kbps';
}

List<int?> buildSampleRateOptions(
  UsbAudioStatus status,
  int? sourceSampleRate,
) {
  final options = <int?>[null];
  final deviceId = status.bestAvailableDeviceId;
  UsbAudioDevice? activeDevice;

  for (final device in status.devices) {
    if (device.id == deviceId) {
      activeDevice = device;
      break;
    }
  }

  final preferredRates =
      activeDevice?.supportedMixerSampleRates.isNotEmpty == true
      ? activeDevice!.supportedMixerSampleRates
      : activeDevice?.sampleRates ?? const <int>[];
  final sortedRates = preferredRates.toSet().toList()..sort();

  options.addAll(sortedRates);
  if (sourceSampleRate != null &&
      sourceSampleRate > 0 &&
      !options.contains(sourceSampleRate)) {
    options.add(sourceSampleRate);
  }
  return options;
}

int? preferredExclusiveSampleRate(
  UsbAudioStatus status,
  int? sourceSampleRate,
) {
  final fixedRate = usbAudioPreferences.preferredFixedSampleRate();
  if (fixedRate != null) {
    return fixedRate;
  }

  final deviceRates = buildSampleRateOptions(status, null).whereType<int>();
  if (sourceSampleRate != null &&
      sourceSampleRate > 0 &&
      deviceRates.contains(sourceSampleRate)) {
    return sourceSampleRate;
  }
  return status.bestAvailableSampleRate;
}

Future<UsbAudioStatus> applyExclusiveOutputForSong(
  UsbAudioStatus status,
  MyAudioMetadata? song,
) {
  return usbAudioService.applyPreferredOutput(
    deviceId: status.bestAvailableDeviceId,
    sampleRate: preferredExclusiveSampleRate(status, song?.samplerate),
    encoding: usbAudioPreferences.preferredEncoding(),
  );
}

class AudioOutputChip extends StatelessWidget {
  final MyAudioMetadata? song;
  final Color color;

  const AudioOutputChip({super.key, required this.song, required this.color});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: usbAudioStatusNotifier,
      builder: (context, status, child) {
        final outputRate = formatOutputSampleRate(status);
        final outputName = _shortOutputName(status);
        final bitDepth = _bitDepthLabel(status);
        final chipColor = _chipColor(color);

        return Center(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () {
                tryVibrate();
                showAudioOutputSheet(context, song);
              },
              child: Container(
                constraints: const BoxConstraints(maxWidth: 320),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: chipColor,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: color.withAlpha(62)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(34),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PulseDot(active: status.supported, color: color),
                    const SizedBox(width: 9),
                    Flexible(
                      child: Text(
                        '$outputRate  |  $bitDepth  |  $outputName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color.withAlpha(232),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Icon(
                      Icons.tune_rounded,
                      size: 17,
                      color: color.withAlpha(214),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

Future<void> showAudioOutputSheet(
  BuildContext context,
  MyAudioMetadata? song,
) async {
  await usbAudioService.refreshStatus();
  if (!context.mounted) return;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    barrierColor: _barrierColor(),
    backgroundColor: Colors.transparent,
    builder: (context) => RepaintBoundary(child: _AudioOutputSheet(song: song)),
  );
}

Future<void> showUsbAudioDetectedSheet(
  BuildContext context,
  UsbAudioStatus status,
  MyAudioMetadata? song,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    barrierColor: _barrierColor(),
    backgroundColor: Colors.transparent,
    builder: (context) => RepaintBoundary(
      child: _UsbAudioDetectedSheet(
        parentContext: context,
        initialStatus: status,
        song: song,
      ),
    ),
  );
}

class _UsbAudioDetectedSheet extends StatefulWidget {
  final BuildContext parentContext;
  final UsbAudioStatus initialStatus;
  final MyAudioMetadata? song;

  const _UsbAudioDetectedSheet({
    required this.parentContext,
    required this.initialStatus,
    required this.song,
  });

  @override
  State<_UsbAudioDetectedSheet> createState() => _UsbAudioDetectedSheetState();
}

class _UsbAudioDetectedSheetState extends State<_UsbAudioDetectedSheet> {
  bool _applying = false;
  late UsbAudioStatus _status = widget.initialStatus;

  Future<void> _enableExclusive() async {
    setState(() {
      _applying = true;
    });

    final nextStatus = await applyExclusiveOutputForSong(_status, widget.song);
    if (!mounted) return;

    setState(() {
      _status = nextStatus;
      _applying = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final foreground = lyricsPageForegroundColor.value;
    final highlight = lyricsPageHighlightTextColor.value;
    final background = _panelBackgroundColor(foreground);
    final surface = _panelSurfaceColor(background, foreground);
    final border = foreground.withAlpha(28);
    final muted = foreground.withAlpha(150);
    final canRequestExclusive =
        _status.supported &&
        _status.androidSdk >= 34 &&
        _activeUsbDevice(_status)?.supportsBitPerfectMixer == true;

    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
      ),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(45),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _OutputGlyph(active: true, accent: highlight),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '检测到 USB DAC',
                          style: TextStyle(
                            color: foreground,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _exclusiveStatusLabel(_status),
                          style: TextStyle(color: muted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SignalSection(
                title: '设备',
                accent: highlight,
                foreground: foreground,
                muted: muted,
                surface: surface,
                border: border,
                rows: [
                  _InfoRow('名称', _shortOutputName(_status)),
                  _InfoRow('输出采样率', formatOutputSampleRate(_status)),
                  _InfoRow('支持采样率', _supportedRatesLabel(_status)),
                  _InfoRow('当前歌曲', formatSampleRate(widget.song?.samplerate)),
                ],
              ),
              const SizedBox(height: 12),
              _SignalSection(
                title: '独占',
                accent: canRequestExclusive
                    ? const Color(0xFF50D890)
                    : const Color(0xFFFFA33A),
                foreground: foreground,
                muted: muted,
                surface: surface,
                border: border,
                rows: [
                  _InfoRow('Android', 'API ${_status.androidSdk}'),
                  _InfoRow('Bit-perfect', _bitPerfectSupportLabel(_status)),
                  _InfoRow(
                    '请求采样率',
                    formatSampleRate(
                      preferredExclusiveSampleRate(
                        _status,
                        widget.song?.samplerate,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (widget.parentContext.mounted) {
                            showAudioOutputSheet(
                              widget.parentContext,
                              widget.song,
                            );
                          }
                        });
                      },
                      child: const Text('查看链路'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: canRequestExclusive && !_applying
                          ? _enableExclusive
                          : null,
                      icon: _applying
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: foreground,
                              ),
                            )
                          : const Icon(Icons.lock_rounded, size: 18),
                      label: Text(_applying ? '请求中' : '启用独占'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AudioOutputSheet extends StatefulWidget {
  final MyAudioMetadata? song;

  const _AudioOutputSheet({required this.song});

  @override
  State<_AudioOutputSheet> createState() => _AudioOutputSheetState();
}

class _AudioOutputSheetState extends State<_AudioOutputSheet> {
  int? _applyingRate;

  Future<void> _applySampleRate(int? sampleRate) async {
    setState(() {
      _applyingRate = sampleRate ?? -1;
    });

    final status = usbAudioStatusNotifier.value;
    final nextStatus = await usbAudioService.applyPreferredOutput(
      deviceId: status.bestAvailableDeviceId,
      sampleRate: sampleRate,
    );

    if (!mounted) return;
    setState(() {
      _applyingRate = null;
    });

    final message = nextStatus.message ?? '已发送采样率请求';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final foreground = lyricsPageForegroundColor.value;
    final highlight = lyricsPageHighlightTextColor.value;
    final background = _panelBackgroundColor(foreground);
    final surface = _panelSurfaceColor(background, foreground);
    final border = foreground.withAlpha(28);
    final muted = foreground.withAlpha(150);

    return ValueListenableBuilder(
      valueListenable: usbAudioStatusNotifier,
      builder: (context, status, child) {
        final selectedRate = status.preferredSampleRate;
        final options = buildSampleRateOptions(status, widget.song?.samplerate);

        return Padding(
          padding: EdgeInsets.only(
            left: 12,
            right: 12,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
          ),
          child: Material(
            color: background,
            borderRadius: BorderRadius.circular(28),
            clipBehavior: Clip.antiAlias,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.heightOf(context) * 0.82,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: border),
              ),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(45),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _OutputGlyph(active: status.supported, accent: highlight),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '音频输出',
                              style: TextStyle(
                                color: foreground,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              status.message ?? '查看当前音频链路与采样率',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: muted, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _SignalSection(
                    title: '音频源',
                    accent: highlight,
                    foreground: foreground,
                    muted: muted,
                    surface: surface,
                    border: border,
                    rows: [
                      _InfoRow('文件', _sourcePathLabel(widget.song)),
                      _InfoRow(
                        '输入采样率',
                        formatSampleRate(widget.song?.samplerate),
                      ),
                      _InfoRow(
                        '格式',
                        widget.song?.format?.toUpperCase() ?? '未知',
                      ),
                      _InfoRow('码率', formatBitrate(widget.song?.bitrate)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SignalSection(
                    title: '处理链',
                    accent: muted,
                    foreground: foreground,
                    muted: muted,
                    surface: surface,
                    border: border,
                    rows: const [
                      _InfoRow('均衡器', '关闭'),
                      _InfoRow('PEQ', '关闭'),
                      _InfoRow('DSP 插件', '未接入'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SignalSection(
                    title: '信号输出',
                    accent: status.supported
                        ? const Color(0xFF50D890)
                        : const Color(0xFFFFA33A),
                    foreground: foreground,
                    muted: muted,
                    surface: surface,
                    border: border,
                    rows: [
                      _InfoRow('输出端口', _outputPortLabel(status)),
                      _InfoRow('输出采样率', formatOutputSampleRate(status)),
                      _InfoRow('编码', _outputEncodingLabel(status)),
                      _InfoRow(
                        'Bit-perfect',
                        status.preferredBitPerfect
                            ? '已请求'
                            : status.supported
                            ? '未启用'
                            : '不可用',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '采样率',
                    style: TextStyle(
                      color: foreground,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final rate in options)
                        _SampleRateChoice(
                          label: rate == null ? '自动' : formatSampleRate(rate),
                          selected:
                              rate == selectedRate ||
                              (rate == null && selectedRate == null),
                          enabled: status.supported,
                          applying: _applyingRate == (rate ?? -1),
                          accent: highlight,
                          foreground: foreground,
                          surface: surface,
                          onTap: () => _applySampleRate(rate),
                        ),
                    ],
                  ),
                  if (!status.supported) ...[
                    const SizedBox(height: 14),
                    Text(
                      '未检测到 USB DAC。当前显示 Android 系统输出信息；采样率选择会在连接 USB 音频设备后启用。',
                      style: TextStyle(
                        color: muted,
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SignalSection extends StatelessWidget {
  final String title;
  final Color accent;
  final Color foreground;
  final Color muted;
  final Color surface;
  final Color border;
  final List<_InfoRow> rows;

  const _SignalSection({
    required this.title,
    required this.accent,
    required this.foreground,
    required this.muted,
    required this.surface,
    required this.border,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 2,
                height: 78,
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: accent.withAlpha(76),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: foreground.withAlpha(232),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                for (final row in rows)
                  _InfoLine(row: row, foreground: foreground, muted: muted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final _InfoRow row;
  final Color foreground;
  final Color muted;

  const _InfoLine({
    required this.row,
    required this.foreground,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text(
              row.label,
              style: TextStyle(color: muted.withAlpha(150), fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              row.value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground.withAlpha(222),
                fontSize: 13,
                height: 1.25,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SampleRateChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final bool applying;
  final Color accent;
  final Color foreground;
  final Color surface;
  final VoidCallback onTap;

  const _SampleRateChoice({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.applying,
    required this.accent,
    required this.foreground,
    required this.surface,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayColor = selected ? accent : foreground;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: enabled && !applying ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? accent.withAlpha(42) : surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: displayColor.withAlpha(selected ? 160 : 42),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (applying) ...[
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: displayColor,
                  ),
                ),
                const SizedBox(width: 7),
              ],
              Text(
                label,
                style: TextStyle(
                  color: enabled
                      ? displayColor.withAlpha(230)
                      : foreground.withAlpha(96),
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutputGlyph extends StatelessWidget {
  final bool active;
  final Color accent;

  const _OutputGlyph({required this.active, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: active
            ? accent.withAlpha(45)
            : lyricsPageForegroundColor.value.withAlpha(18),
        shape: BoxShape.circle,
        border: Border.all(
          color: active
              ? accent
              : lyricsPageForegroundColor.value.withAlpha(62),
        ),
      ),
      child: Icon(
        active ? Icons.usb_rounded : Icons.graphic_eq_rounded,
        color: active ? accent : lyricsPageForegroundColor.value.withAlpha(180),
      ),
    );
  }
}

class _PulseDot extends StatelessWidget {
  final bool active;
  final Color color;

  const _PulseDot({required this.active, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? color : color.withAlpha(120),
        boxShadow: active
            ? [
                BoxShadow(
                  color: color.withAlpha(120),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
    );
  }
}

class _InfoRow {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);
}

String _shortOutputName(UsbAudioStatus status) {
  final exclusive = usbExclusivePlaybackStateNotifier.value;
  if (exclusive.active) {
    return 'USB 真独占';
  }

  if (!status.supported) {
    return status.outputDeviceName ?? 'Android';
  }
  final device = _activeUsbDevice(status);
  if (device != null) return device.name;
  return status.outputDeviceName ?? 'USB DAC';
}

UsbAudioDevice? _activeUsbDevice(UsbAudioStatus status) {
  for (final device in status.devices) {
    if (device.id == status.bestAvailableDeviceId) {
      return device;
    }
  }
  return null;
}

String _supportedRatesLabel(UsbAudioStatus status) {
  final device = _activeUsbDevice(status);
  final rates = device?.supportedMixerSampleRates.isNotEmpty == true
      ? device!.supportedMixerSampleRates
      : device?.sampleRates ?? const <int>[];
  if (rates.isEmpty) return '未知';
  return rates.map(formatSampleRate).join(' / ');
}

String _bitPerfectSupportLabel(UsbAudioStatus status) {
  if (!status.supported) return '不可用';
  if (status.androidSdk < 34) return '需要 Android 14+';
  final device = _activeUsbDevice(status);
  if (device?.supportsBitPerfectMixer == true) {
    return status.preferredBitPerfect ? '已请求' : '可用';
  }
  return '设备未声明支持';
}

String _exclusiveStatusLabel(UsbAudioStatus status) {
  if (!status.supported) return '未连接 USB 音频设备';
  if (status.androidSdk < 34) return '当前系统不支持 USB 独占请求';
  if (status.preferredBitPerfect && status.preferredSampleRate != null) {
    return '已请求 USB 独占输出';
  }
  if (_activeUsbDevice(status)?.supportsBitPerfectMixer == true) {
    return '可启用 USB 独占输出';
  }
  return '已连接 USB DAC，但未确认支持独占';
}

String _bitDepthLabel(UsbAudioStatus status) {
  final exclusive = usbExclusivePlaybackStateNotifier.value;
  if (exclusive.active && exclusive.bitDepth != null) {
    return '${exclusive.bitDepth} bits';
  }

  final encoding = status.preferredEncoding ?? status.outputEncoding;
  if (encoding == 'pcm_float') return '32 bits';
  if (encoding == 'pcm_32bit') return '32 bits';
  if (encoding == 'pcm_24bit_packed') return '24 bits';
  if (encoding == 'pcm_16bit') return '16 bits';
  return '未知';
}

String _outputEncodingLabel(UsbAudioStatus status) {
  final encoding = status.preferredEncoding ?? status.outputEncoding;
  if (encoding == null) return 'PCM / 系统默认';
  final bitDepth = _bitDepthLabel(status);
  return bitDepth == '未知' ? encoding : 'PCM / $bitDepth';
}

String _outputPortLabel(UsbAudioStatus status) {
  if (!status.supported) {
    return status.outputDeviceName ?? 'Android';
  }
  final name = _shortOutputName(status);
  return status.preferredApplied ? '$name · 已应用偏好' : '$name · 系统输出';
}

String _sourcePathLabel(MyAudioMetadata? song) {
  final path = song?.cachePath ?? song?.path;
  if (path == null || path.isEmpty) {
    return '未知';
  }
  if (path.length <= 48) {
    return path;
  }
  return '...${path.substring(path.length - 45)}';
}

Color _chipColor(Color foreground) {
  final background = _panelBackgroundColor(foreground);
  return Color.alphaBlend(foreground.withAlpha(18), background.withAlpha(220));
}

Color _panelBackgroundColor(Color foreground) {
  final tint = _panelTintColor();
  final lightForeground = foreground.computeLuminance() > 0.45;
  final neutral = lightForeground
      ? const Color(0xFF24252B)
      : const Color(0xFFF0F0F2);
  return Color.alphaBlend(tint.withAlpha(lightForeground ? 96 : 136), neutral);
}

Color _panelSurfaceColor(Color background, Color foreground) {
  final lightForeground = foreground.computeLuminance() > 0.45;
  return Color.alphaBlend(
    foreground.withAlpha(lightForeground ? 18 : 14),
    background,
  );
}

Color _barrierColor() {
  final tint = _panelTintColor();
  return Color.alphaBlend(tint.withAlpha(30), Colors.black.withAlpha(70));
}

Color _panelTintColor() {
  final pageBackground = lyricsPageBackgroundColor.value;
  return pageBackground == Colors.transparent
      ? currentCoverArtColor
      : pageBackground;
}
