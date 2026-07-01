import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/data/setting.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/services/usb_audio_preferences.dart';
import 'package:sylvakru/base/services/usb_audio_service.dart';
import 'package:sylvakru/base/utils/media_query.dart';
import 'package:sylvakru/base/widgets/audio_output_panel.dart';
import 'package:sylvakru/base/widgets/my_sheet.dart';
import 'package:sylvakru/base/widgets/my_switch.dart';
import 'package:sylvakru/landscape_view/title_bar.dart';
import 'package:sylvakru/layer/layers_manager.dart';
import 'package:sylvakru/layer/settings_layer.dart';
import 'package:sylvakru/portrait_view/custom_appbar_leading.dart';

enum AudioOutputSettingsPageKind { overview, fixedSampleRate, dsdMode }

enum _TransportHealth { idle, paused, stable, low, underrun }

_TransportHealth _transportHealth({
  required bool active,
  required bool playing,
  required int levelMs,
  required int? minimumMs,
  required int targetMs,
  required int underrunCount,
}) {
  if (!active) {
    return _TransportHealth.idle;
  }
  if (!playing) {
    return _TransportHealth.paused;
  }
  if (underrunCount > 0) {
    return _TransportHealth.underrun;
  }

  final lowWatermark = (targetMs * 0.35).round().clamp(20, 250);
  if (levelMs < lowWatermark ||
      (minimumMs != null && minimumMs < lowWatermark)) {
    return _TransportHealth.low;
  }
  return _TransportHealth.stable;
}

String _transportHealthLabel(_TransportHealth health) {
  return switch (health) {
    _TransportHealth.idle => '待机',
    _TransportHealth.paused => '暂停',
    _TransportHealth.stable => '稳定',
    _TransportHealth.low => '偏低',
    _TransportHealth.underrun => '欠载',
  };
}

Color _transportHealthAccent(_TransportHealth health) {
  return switch (health) {
    _TransportHealth.stable => const Color(0xFF50D890),
    _TransportHealth.low => const Color(0xFFFFB454),
    _TransportHealth.underrun => const Color(0xFFFF6B6B),
    _TransportHealth.idle ||
    _TransportHealth.paused => highlightTextColor.value,
  };
}

class AudioOutputSettingsLayer extends StatefulWidget {
  final AudioOutputSettingsPageKind pageKind;

  const AudioOutputSettingsLayer({
    super.key,
    this.pageKind = AudioOutputSettingsPageKind.overview,
  });

  @override
  State<AudioOutputSettingsLayer> createState() =>
      _AudioOutputSettingsLayerState();
}

class _AudioOutputSettingsLayerState extends State<AudioOutputSettingsLayer> {
  UsbExclusiveProbeResult? _exclusiveProbeResult;
  bool _probingExclusive = false;
  bool _refreshingStatus = false;

  @override
  Widget build(BuildContext context) {
    if (isTooNarrow(context)) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: customAppBarLeading(context, label: 'settings'),
          backgroundColor: Colors.transparent,
          systemOverlayStyle: mainPageThemeNotifier.value == .dark
              ? .light
              : .dark,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(_title),
          centerTitle: true,
        ),
        body: _content(),
      );
    }

    return ValueListenableBuilder<bool>(
      valueListenable: settingsVisibleNotifier,
      builder: (context, visible, child) {
        return Opacity(
          opacity: visible ? 0 : 1,
          child: Column(
            children: [
              TitleBar(backToRoot: () => layersManager.popDetail('settings')),
              Expanded(child: _content()),
            ],
          ),
        );
      },
    );
  }

  String get _title {
    return switch (widget.pageKind) {
      AudioOutputSettingsPageKind.overview => 'USB 输出设置',
      AudioOutputSettingsPageKind.fixedSampleRate => '固定采样率输出',
      AudioOutputSettingsPageKind.dsdMode => 'DSD 模式',
    };
  }

  Widget _content() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: ValueListenableBuilder(
          valueListenable: mainPageThemeNotifier,
          builder: (context, value, child) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              children: [
                switch (widget.pageKind) {
                  AudioOutputSettingsPageKind.overview => _overview(),
                  AudioOutputSettingsPageKind.fixedSampleRate =>
                    _fixedSampleRate(),
                  AudioOutputSettingsPageKind.dsdMode => _dsdMode(),
                },
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _overview() {
    final prefs = usbAudioPreferences;
    return ValueListenableBuilder<UsbAudioStatus>(
      valueListenable: usbAudioStatusNotifier,
      builder: (context, status, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _deviceStatusCard(status),
            const SizedBox(height: 12),
            _transportStatusCard(status),
            const SizedBox(height: 18),
            _sectionTitle('输出格式'),
            _settingsCard(
              children: [
                _sourceFileTile(),
                _infoTile(
                  'DAC 端点',
                  _dacEndpointLabel(status),
                  '播放后显示真实 DAC 端点格式',
                ),
                _switchTile(
                  title: '位深兼容',
                  subtitle: '设备不支持源位深时自动回退。',
                  notifier: prefs.bitDepthCompatNotifier,
                ),
                _switchTile(
                  title: '采样率兼容',
                  subtitle: '设备不支持源采样率时自动回退。',
                  notifier: prefs.sampleRateCompatNotifier,
                ),
                _switchTile(
                  title: '声道兼容',
                  subtitle: '设备不支持源声道时自动回退到可用声道。',
                  notifier: prefs.channelCompatNotifier,
                ),
                _switchTile(
                  title: 'TPDF 抖动',
                  subtitle: '高位深转 16-bit 时加入极低电平随机噪声，降低量化失真。',
                  notifier: prefs.tpdfDitherNotifier,
                ),
                _navTile(
                  title: '固定采样率输出',
                  value: prefs.fixedSampleRateEnabledNotifier.value
                      ? formatSampleRate(prefs.fixedSampleRateNotifier.value)
                      : '关闭',
                  onTap: () {
                    layersManager.pushDetail(
                      'settings',
                      'usb_fixed_sample_rate',
                    );
                  },
                ),
                _navTile(
                  title: 'DSD 模式',
                  value: _dsdModeLabel(prefs.dsdModeNotifier.value),
                  onTap: () {
                    layersManager.pushDetail('settings', 'usb_dsd_mode');
                  },
                ),
                _choiceTile<UsbBitDepthMode>(
                  title: 'PCM 位深',
                  notifier: prefs.bitDepthModeNotifier,
                  values: UsbBitDepthMode.values,
                  label: _bitDepthModeLabel,
                ),
              ],
            ),
            const SizedBox(height: 18),
            _sectionTitle('后台稳定性'),
            _settingsCard(
              children: [
                _noticeTile(
                  icon: Icons.battery_alert_rounded,
                  title: '建议关闭电池优化',
                  subtitle: '否则后台播放或切到大型 App 时，USB 独占链路可能被系统暂停。',
                  actionLabel: '打开设置',
                  onTap: openAppSettings,
                ),
                _switchTile(
                  title: 'USB 独占模式',
                  subtitle: '连接 DAC 后启用独占提示与高优先级输出策略。',
                  notifier: prefs.performanceModeNotifier,
                ),
                _switchTile(
                  title: '保持后台活动',
                  subtitle: '减少后台播放时 USB 输出被系统中断的概率。',
                  notifier: prefs.keepAliveInBackgroundNotifier,
                ),
              ],
            ),
            const SizedBox(height: 18),
            _sectionTitle('传输缓冲'),
            _settingsCard(
              children: [
                _bufferSlider(
                  title: '前台缓冲区',
                  notifier: prefs.foregroundBufferMsNotifier,
                  min: 50,
                  max: 1000,
                  divisions: 19,
                ),
                _bufferSlider(
                  title: '后台缓冲区',
                  notifier: prefs.backgroundBufferMsNotifier,
                  min: 500,
                  max: 5000,
                  divisions: 18,
                ),
                _hintTile('后台打开大型 App 出现卡顿时优先提高后台缓冲；数值越大越稳定，切歌与暂停响应可能稍慢。'),
              ],
            ),
            const SizedBox(height: 18),
            _sectionTitle('音量'),
            _settingsCard(
              children: [
                _choiceTile<UsbVolumeLockMode>(
                  title: '音量控制',
                  notifier: prefs.volumeLockModeNotifier,
                  values: UsbVolumeLockMode.values,
                  label: _volumeLockLabel,
                ),
                _choiceTile<int>(
                  title: 'DSD 增益补偿',
                  notifier: prefs.dsdGainCompensationNotifier,
                  values: const [-12, -9, -6, -3, 0, 3, 6],
                  label: (value) => '$value dB',
                ),
                _infoTile('当前媒体音量', '播放开始后检测', '硬件音量与 DAC 反馈可用后显示'),
                _switchTile(
                  title: '音量平滑交接',
                  subtitle: '切换数字音量与 DAC 硬件音量时保持响度连续。',
                  notifier: prefs.volumeSmoothHandoffNotifier,
                ),
              ],
            ),
            const SizedBox(height: 18),
            _sectionTitle('兼容性'),
            _settingsCard(
              children: [
                _switchTile(
                  title: '延迟建立 USB 输出链路',
                  subtitle: '播放开始时再建立独占会话，适合部分 DAC 卡死或控制界面异常的使用场景。',
                  notifier: prefs.delayedUsbLinkNotifier,
                ),
                _choiceTile<UsbBusSpeedMode>(
                  title: 'USB 总线速度',
                  notifier: prefs.busSpeedModeNotifier,
                  values: UsbBusSpeedMode.values,
                  label: _busSpeedLabel,
                ),
                _switchTile(
                  title: '播放后释放 USB 带宽',
                  subtitle: '停止播放后允许系统回收 USB 音频资源。',
                  notifier: prefs.releaseUsbBandwidthAfterPlaybackNotifier,
                ),
              ],
            ),
            const SizedBox(height: 18),
            _sectionTitle('支持'),
            _settingsCard(
              children: [
                _actionTile(
                  icon: Icons.fact_check_rounded,
                  title: 'USB 独占后台诊断',
                  subtitle: _exclusiveProbeSummary(),
                  actionLabel: _probingExclusive ? '检测中' : '开始检测',
                  onTap: _probingExclusive ? null : _runExclusiveProbe,
                ),
                _actionTile(
                  icon: Icons.feedback_rounded,
                  title: 'USB 独占模式反馈',
                  subtitle: '复制当前设备与输出链路信息，方便继续排查 DAC 兼容问题。',
                  actionLabel: '查看状态',
                  onTap: () => _showStatusSnack(status),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _deviceStatusCard(UsbAudioStatus status) {
    return ValueListenableBuilder<UsbExclusivePlaybackState>(
      valueListenable: usbExclusivePlaybackStateNotifier,
      builder: (context, exclusive, _) {
        final device = _activeUsbDevice(status);
        final supported = status.supported;
        final accent = supported ? const Color(0xFF50D890) : textColor.value;
        final foreground = textColor.value;
        final background = Color.alphaBlend(
          accent.withAlpha(mainPageThemeNotifier.value == .dark ? 34 : 20),
          menuColor.value,
        );
        final title = supported ? device?.name ?? 'USB DAC' : '未识别 USB 设备';
        final subtitle = supported
            ? _exclusiveStatusLabel(status)
            : '连接 DAC 后显示设备信息';
        final statusLabel = supported ? '已连接' : '未连接';
        final linkLabel = supported
            ? (exclusive.active ? '独占播放' : '运行中')
            : '待连接';
        final formatLabel = 'PCM ${formatOutputSampleRate(status)}'.replaceAll(
          '未知',
          '系统默认',
        );

        return DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withAlpha(70)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.usb_rounded, color: foreground.withAlpha(170)),
                    const SizedBox(width: 10),
                    Text(
                      'USB EXCLUSIVE',
                      style: TextStyle(
                        color: foreground.withAlpha(150),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: supported ? accent : foreground.withAlpha(100),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        color: foreground.withAlpha(165),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    _refreshingStatus
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            tooltip: '刷新 USB 状态',
                            onPressed: _refreshStatus,
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 24,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground.withAlpha(150),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: supported ? accent : foreground.withAlpha(100),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'OUTPUT LINK',
                      style: TextStyle(
                        color: foreground.withAlpha(135),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      linkLabel,
                      style: TextStyle(
                        color: foreground.withAlpha(190),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(child: _metricColumn('FORMAT', formatLabel)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _metricColumn('DEPTH', _compactDepthLabel(status)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _metricColumn('USB ID', _usbIdLabel(device)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _transportStatusCard(UsbAudioStatus status) {
    return ValueListenableBuilder<UsbExclusivePlaybackState>(
      valueListenable: usbExclusivePlaybackStateNotifier,
      builder: (context, exclusive, _) {
        return ValueListenableBuilder<UsbTransportTelemetry>(
          valueListenable: usbTransportTelemetryNotifier,
          builder: (context, telemetry, _) {
            final active = exclusive.active || telemetry.active;
            final targetMs =
                telemetry.targetBuffer?.inMilliseconds ??
                usbAudioPreferences.foregroundBufferMsNotifier.value;
            final levelMs = telemetry.active
                ? telemetry.bufferLevel.inMilliseconds
                : 0;
            final minimumMs = telemetry.minimumBufferLevel?.inMilliseconds;
            final clampedLevel = levelMs.clamp(0, targetMs);
            final progress = targetMs <= 0 ? 0.0 : clampedLevel / targetMs;
            final health = _transportHealth(
              active: active,
              playing: exclusive.playing,
              levelMs: levelMs,
              minimumMs: minimumMs,
              targetMs: targetMs,
              underrunCount: telemetry.underrunCount,
            );
            final accent = _transportHealthAccent(health);
            final foreground = textColor.value;
            final background = Color.alphaBlend(
              accent.withAlpha(mainPageThemeNotifier.value == .dark ? 36 : 24),
              menuColor.value,
            );

            return DecoratedBox(
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accent.withAlpha(60)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '传输状态',
                            style: TextStyle(
                              color: foreground,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          _transportHealthLabel(health),
                          style: TextStyle(
                            color: active ? accent : foreground.withAlpha(170),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(
                          flex: 4,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.bottomLeft,
                            child: Text(
                              '$levelMs ms',
                              style: TextStyle(
                                color: foreground,
                                fontSize: 34,
                                height: 0.95,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text(
                              '缓冲区水位',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: foreground.withAlpha(145),
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            'ISO ${telemetry.active ? telemetry.isoPacketCount : 0}',
                            style: TextStyle(
                              color: foreground.withAlpha(175),
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: foreground.withAlpha(28),
                        valueColor: AlwaysStoppedAnimation<Color>(accent),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            active ? '目标 $targetMs ms' : '播放时建立目标水位',
                            style: TextStyle(
                              color: foreground.withAlpha(135),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          active && minimumMs != null
                              ? '最低 $minimumMs ms'
                              : '最低 --',
                          style: TextStyle(
                            color: foreground.withAlpha(135),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _fixedSampleRate() {
    final prefs = usbAudioPreferences;
    return Column(
      children: [
        _settingsCard(
          children: [
            _switchTile(
              title: '启用固定采样率',
              subtitle: '开启后 USB 输出优先使用下方选定采样率。',
              notifier: prefs.fixedSampleRateEnabledNotifier,
            ),
            for (final rate in UsbAudioPreferences.sampleRates)
              ValueListenableBuilder<int?>(
                valueListenable: prefs.fixedSampleRateNotifier,
                builder: (context, selectedRate, _) {
                  return _radioTile<int>(
                    title: formatSampleRate(rate),
                    value: rate,
                    groupValue: selectedRate,
                    onTap: () {
                      prefs.fixedSampleRateNotifier.value = rate;
                      setting.save();
                    },
                  );
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _dsdMode() {
    final prefs = usbAudioPreferences;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('DSD 输出策略'),
        _settingsCard(
          children: [
            for (final mode in UsbDsdMode.values)
              ValueListenableBuilder<UsbDsdMode>(
                valueListenable: prefs.dsdModeNotifier,
                builder: (context, selectedMode, _) {
                  return _radioTile<UsbDsdMode>(
                    title: _dsdModeLabel(mode),
                    subtitle: _dsdModeHint(mode),
                    value: mode,
                    groupValue: selectedMode,
                    onTap: () {
                      prefs.dsdModeNotifier.value = mode;
                      setting.save();
                    },
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: 18),
        _sectionTitle('DSD to PCM'),
        _settingsCard(
          children: [
            _dsdPcmRateTile('DSD64', prefs.dsd64PcmRateNotifier),
            _dsdPcmRateTile('DSD128', prefs.dsd128PcmRateNotifier),
            _dsdPcmRateTile('DSD256', prefs.dsd256PcmRateNotifier),
            _dsdPcmRateTile('DSD512', prefs.dsd512PcmRateNotifier),
          ],
        ),
      ],
    );
  }

  Widget _dsdPcmRateTile(String title, ValueNotifier<int> notifier) {
    return _choiceTile<int>(
      title: title,
      notifier: notifier,
      values: UsbAudioPreferences.sampleRates,
      label: (value) => '${formatSampleRate(value)} PCM',
    );
  }

  Widget _settingsCard({required List<Widget> children}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: menuColor.value,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1) _divider(),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            color: textColor.value.withAlpha(150),
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _switchTile({
    required String title,
    required String subtitle,
    required ValueNotifier<bool> notifier,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: SizedBox(
        width: 52,
        child: MySwitch(
          valueNotifier: notifier,
          onToggleCallBack: setting.save,
        ),
      ),
    );
  }

  Widget _navTile({
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return ListTile(
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(color: textColor.value.withAlpha(150))),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _infoTile(String title, String value, String subtitle) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 190),
        child: Text(
          value,
          textAlign: TextAlign.right,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: textColor.value.withAlpha(210),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _sourceFileTile() {
    return ValueListenableBuilder<MyAudioMetadata?>(
      valueListenable: currentSongNotifier,
      builder: (context, song, _) {
        return _infoTile(
          '源文件',
          _sourceFileTitle(song),
          _sourceFileSubtitle(song),
        );
      },
    );
  }

  Widget _noticeTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: _iconBox(icon, const Color(0xFFFF6868), compact: true),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: TextButton(onPressed: onTap, child: Text(actionLabel)),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback? onTap,
  }) {
    return ListTile(
      leading: _iconBox(icon, highlightTextColor.value, compact: true),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: TextButton(onPressed: onTap, child: Text(actionLabel)),
    );
  }

  Widget _hintTile(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Text(
        text,
        style: TextStyle(color: textColor.value.withAlpha(130), fontSize: 12),
      ),
    );
  }

  Widget _bufferSlider({
    required String title,
    required ValueNotifier<int> notifier,
    required double min,
    required double max,
    required int divisions,
  }) {
    return ValueListenableBuilder<int>(
      valueListenable: notifier,
      builder: (context, value, _) {
        final sliderValue = value.toDouble().clamp(min, max);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    '${sliderValue.round()} ms',
                    style: TextStyle(
                      color: textColor.value.withAlpha(180),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Slider(
                value: sliderValue,
                min: min,
                max: max,
                divisions: divisions,
                label: '${sliderValue.round()} ms',
                onChanged: (next) {
                  notifier.value = next.round();
                },
                onChangeEnd: (_) => setting.save(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _radioTile<T>({
    required String title,
    String? subtitle,
    required T value,
    required T? groupValue,
    required VoidCallback onTap,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: groupValue == value
          ? Icon(Icons.check_rounded, color: highlightTextColor.value)
          : Icon(Icons.circle_outlined, color: textColor.value.withAlpha(120)),
      onTap: onTap,
    );
  }

  Widget _choiceTile<T>({
    required String title,
    required ValueNotifier<T> notifier,
    required List<T> values,
    required String Function(T value) label,
  }) {
    return ValueListenableBuilder<T>(
      valueListenable: notifier,
      builder: (context, value, _) {
        return ListTile(
          title: Text(title),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label(value),
                style: TextStyle(color: textColor.value.withAlpha(150)),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
          onTap: () => _showChoiceSheet<T>(
            title: title,
            notifier: notifier,
            values: values,
            label: label,
          ),
        );
      },
    );
  }

  void _showChoiceSheet<T>({
    required String title,
    required ValueNotifier<T> notifier,
    required List<T> values,
    required String Function(T value) label,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return MySheet(
          ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
            children: [
              ListTile(
                title: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              for (final value in values)
                ValueListenableBuilder<T>(
                  valueListenable: notifier,
                  builder: (context, currentValue, _) {
                    return ListTile(
                      title: Text(label(value)),
                      trailing: currentValue == value
                          ? Icon(
                              Icons.check_rounded,
                              color: highlightTextColor.value,
                            )
                          : null,
                      onTap: () {
                        notifier.value = value;
                        setting.save();
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _iconBox(IconData icon, Color color, {bool compact = false}) {
    final size = compact ? 34.0 : 42.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(compact ? 10 : 13),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Icon(icon, color: color, size: compact ? 18 : 22),
    );
  }

  Widget _metricColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: textColor.value.withAlpha(125),
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: textColor.value.withAlpha(215),
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _divider() {
    return Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: textColor.value.withAlpha(22),
    );
  }

  Future<void> _refreshStatus() async {
    setState(() {
      _refreshingStatus = true;
    });
    await usbAudioService.refreshStatus();
    if (!mounted) return;
    setState(() {
      _refreshingStatus = false;
    });
  }

  Future<void> _runExclusiveProbe() async {
    setState(() {
      _probingExclusive = true;
    });

    final result = await usbAudioService.probeExclusiveAccess();
    if (!mounted) return;

    setState(() {
      _exclusiveProbeResult = result;
      _probingExclusive = false;
    });
  }

  void _showStatusSnack(UsbAudioStatus status) {
    final device = _activeUsbDevice(status);
    final message = device == null
        ? '当前未检测到 USB DAC。'
        : 'USB DAC: ${device.name} · ${_supportedRatesLabel(status)} · ${_bitDepthLabel(status)}';
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _exclusiveProbeSummary() {
    final result = _exclusiveProbeResult;
    if (result == null) return '检查 USB 权限、Audio Class 描述符与接口 claim 能力。';
    if (!result.permissionGranted) return '等待 USB 授权。';
    if (result.interfaceClaimed) {
      return '可 claim · ${result.audioInterfaceCount} 个 Audio Interface';
    }
    return result.message ?? '未能 claim USB Audio Interface。';
  }

  String _dacEndpointLabel(UsbAudioStatus status) {
    final exclusive = usbExclusivePlaybackStateNotifier.value;
    if (exclusive.active) {
      return '${formatSampleRate(exclusive.sampleRate)} / ${exclusive.bitDepth ?? '未知'} bits';
    }
    final device = _activeUsbDevice(status);
    if (device == null) return '播放后显示';
    return '${_supportedRatesLabel(status)} · ${_bitDepthLabel(status)}';
  }

  String _sourceFileTitle(MyAudioMetadata? song) {
    if (song == null) return '等待播放';
    return formatSourceFileName(song.path ?? song.cachePath);
  }

  String _sourceFileSubtitle(MyAudioMetadata? song) {
    if (song == null) return '采样率未知 · 格式未知 · 码率未知';
    final parts = [
      formatSampleRate(song.samplerate),
      if (song.format?.isNotEmpty == true)
        song.format!.toUpperCase()
      else
        '格式未知',
      formatBitrate(song.bitrate),
    ];
    return parts.join(' · ');
  }

  String _compactDepthLabel(UsbAudioStatus status) {
    return _bitDepthLabel(status).replaceAll(' bits', '-bit');
  }

  String _usbIdLabel(UsbAudioDevice? device) {
    if (device == null) return '等待连接';
    final address = device.address;
    if (address != null && address.isNotEmpty) return '$address · ${device.id}';
    return '${device.type} · ${device.id}';
  }

  String _dsdModeLabel(UsbDsdMode mode) {
    return switch (mode) {
      UsbDsdMode.pcm => 'PCM',
      UsbDsdMode.dop => 'DoP',
      UsbDsdMode.native => 'Native',
    };
  }

  String _dsdModeHint(UsbDsdMode mode) {
    return switch (mode) {
      UsbDsdMode.pcm => '将 DSD 转换为 PCM 输出',
      UsbDsdMode.dop => '以 PCM 帧封装 DSD，设备支持时使用',
      UsbDsdMode.native => '保留 Native DSD 策略，需要底层链路支持',
    };
  }

  String _volumeLockLabel(UsbVolumeLockMode mode) {
    return switch (mode) {
      UsbVolumeLockMode.off => '关闭',
      UsbVolumeLockMode.dsdOnly => '只锁 DSD 音量',
      UsbVolumeLockMode.always => '始终锁定',
    };
  }

  String _busSpeedLabel(UsbBusSpeedMode mode) {
    return switch (mode) {
      UsbBusSpeedMode.auto => '自动',
      UsbBusSpeedMode.full => 'Full',
      UsbBusSpeedMode.high => 'High',
      UsbBusSpeedMode.superSpeed => 'Super',
    };
  }

  String _bitDepthModeLabel(UsbBitDepthMode mode) {
    return switch (mode) {
      UsbBitDepthMode.auto => '自动',
      UsbBitDepthMode.pcm16 => '16 bits',
      UsbBitDepthMode.pcm24 => '24 bits',
      UsbBitDepthMode.pcm32 => '32 bits',
    };
  }
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
