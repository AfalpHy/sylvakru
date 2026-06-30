import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/services/interaction.dart';
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

class AudioOutputChip extends StatelessWidget {
  final MyAudioMetadata? song;
  final Color color;

  const AudioOutputChip({super.key, required this.song, required this.color});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: usbAudioStatusNotifier,
      builder: (context, status, child) {
        final sourceRate = formatSampleRate(song?.samplerate);
        final outputName = _shortOutputName(status);
        final bitDepth = _bitDepthLabel(status);

        return Center(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () {
                tryVibrate();
                showAudioOutputSheet(context, song);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 320),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(62),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: color.withAlpha(62)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _PulseDot(active: status.supported),
                        const SizedBox(width: 9),
                        Flexible(
                          child: Text(
                            '$sourceRate  |  $bitDepth  |  $outputName',
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
    backgroundColor: Colors.transparent,
    builder: (context) => _AudioOutputSheet(song: song),
  );
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
    final foreground = Colors.white.withAlpha(235);
    final muted = Colors.white.withAlpha(150);

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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.heightOf(context) * 0.82,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xE6111114),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withAlpha(18)),
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
                        _OutputGlyph(active: status.supported),
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
                      accent: const Color(0xFFFFCF33),
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
                      accent: const Color(0xFF8E8E94),
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
                      rows: [
                        _InfoRow('输出端口', _outputPortLabel(status)),
                        _InfoRow(
                          '输出采样率',
                          formatSampleRate(status.preferredSampleRate),
                        ),
                        _InfoRow(
                          '编码',
                          status.preferredEncoding ?? 'PCM / 系统默认',
                        ),
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
                            onTap: () => _applySampleRate(rate),
                          ),
                      ],
                    ),
                    if (!status.supported) ...[
                      const SizedBox(height: 14),
                      Text(
                        '未检测到 USB DAC。当前只能显示音频源信息，采样率选择会在连接 USB 音频设备后启用。',
                        style: TextStyle(
                          color: Colors.white.withAlpha(128),
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ],
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

class _SignalSection extends StatelessWidget {
  final String title;
  final Color accent;
  final List<_InfoRow> rows;

  const _SignalSection({
    required this.title,
    required this.accent,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha(16)),
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
                    color: Colors.white.withAlpha(232),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                for (final row in rows) _InfoLine(row: row),
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

  const _InfoLine({required this.row});

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
              style: TextStyle(
                color: Colors.white.withAlpha(126),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              row.value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withAlpha(222),
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
  final VoidCallback onTap;

  const _SampleRateChoice({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.applying,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = selected ? const Color(0xFFFFCF33) : Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: enabled && !applying ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFFFCF33).withAlpha(42)
                : Colors.white.withAlpha(13),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: accent.withAlpha(selected ? 160 : 38)),
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
                    color: accent,
                  ),
                ),
                const SizedBox(width: 7),
              ],
              Text(
                label,
                style: TextStyle(
                  color: enabled ? accent.withAlpha(230) : Colors.white54,
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

  const _OutputGlyph({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFFFFCF33).withAlpha(45)
            : Colors.white.withAlpha(18),
        shape: BoxShape.circle,
        border: Border.all(
          color: active ? const Color(0xFFFFCF33) : Colors.white24,
        ),
      ),
      child: Icon(
        active ? Icons.usb_rounded : Icons.graphic_eq_rounded,
        color: active ? const Color(0xFFFFCF33) : Colors.white70,
      ),
    );
  }
}

class _PulseDot extends StatelessWidget {
  final bool active;

  const _PulseDot({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? const Color(0xFFFFCF33) : Colors.white54,
        boxShadow: active
            ? [
                BoxShadow(
                  color: const Color(0xFFFFCF33).withAlpha(130),
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
  if (!status.supported) {
    return 'Android';
  }
  for (final device in status.devices) {
    if (device.id == status.bestAvailableDeviceId) {
      return device.name;
    }
  }
  return 'USB DAC';
}

String _bitDepthLabel(UsbAudioStatus status) {
  final encoding = status.preferredEncoding;
  if (encoding == 'pcm_32bit') return '32 bits';
  if (encoding == 'pcm_24bit_packed') return '24 bits';
  if (encoding == 'pcm_16bit') return '16 bits';
  return '未知';
}

String _outputPortLabel(UsbAudioStatus status) {
  if (!status.supported) {
    return 'Android';
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
