import 'package:flutter/material.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/data/setting.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/services/usb_audio_preferences.dart';
import 'package:sylvakru/base/widgets/audio_output_panel.dart';
import 'package:sylvakru/base/widgets/my_switch.dart';
import 'package:sylvakru/base/utils/media_query.dart';
import 'package:sylvakru/landscape_view/title_bar.dart';
import 'package:sylvakru/layer/layers_manager.dart';
import 'package:sylvakru/layer/settings_layer.dart';
import 'package:sylvakru/portrait_view/custom_appbar_leading.dart';

enum AudioOutputSettingsPageKind { overview, fixedSampleRate, dsdMode }

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
    return Column(
      children: [
        _section(
          children: [
            _tile(
              title: 'USB Audio 性能模式',
              subtitle: '连接 DAC 后启用独占提示与高优先级输出策略',
              info: true,
              trailing: SizedBox(
                width: 52,
                child: MySwitch(
                  valueNotifier: prefs.performanceModeNotifier,
                  onToggleCallBack: setting.save,
                ),
              ),
            ),
            _navTile(
              title: '固定采样率输出',
              value: prefs.fixedSampleRateEnabledNotifier.value
                  ? formatSampleRate(prefs.fixedSampleRateNotifier.value)
                  : '关闭',
              onTap: () {
                layersManager.pushDetail('settings', 'usb_fixed_sample_rate');
              },
            ),
            _navTile(
              title: 'DSD 模式',
              value: _dsdModeLabel(prefs.dsdModeNotifier.value),
              onTap: () {
                layersManager.pushDetail('settings', 'usb_dsd_mode');
              },
            ),
            _choiceTile<UsbVolumeLockMode>(
              title: 'USB Audio 音量锁定',
              info: true,
              notifier: prefs.volumeLockModeNotifier,
              values: UsbVolumeLockMode.values,
              label: _volumeLockLabel,
            ),
            _choiceTile<int>(
              title: 'USB Audio DSD 增益补偿',
              info: true,
              notifier: prefs.dsdGainCompensationNotifier,
              values: const [-12, -9, -6, -3, 0, 3, 6],
              label: (value) => '${value}dB',
            ),
            _choiceTile<UsbBusSpeedMode>(
              title: 'USB Audio 总线速度',
              info: true,
              notifier: prefs.busSpeedModeNotifier,
              values: UsbBusSpeedMode.values,
              label: _busSpeedLabel,
            ),
            _choiceTile<UsbBitDepthMode>(
              title: 'USB Audio 位深',
              info: true,
              notifier: prefs.bitDepthModeNotifier,
              values: UsbBitDepthMode.values,
              label: _bitDepthModeLabel,
            ),
            _tile(
              title: '播放后释放 USB 带宽',
              subtitle: '停止播放后允许系统回收 USB 音频资源',
              info: true,
              trailing: SizedBox(
                width: 52,
                child: MySwitch(
                  valueNotifier: prefs.releaseUsbBandwidthAfterPlaybackNotifier,
                  onToggleCallBack: setting.save,
                ),
              ),
            ),
            _tile(
              title: '保持后台活动',
              subtitle: '减少后台播放时 USB 输出被系统中断的概率',
              info: true,
              trailing: SizedBox(
                width: 52,
                child: MySwitch(
                  valueNotifier: prefs.keepAliveInBackgroundNotifier,
                  onToggleCallBack: setting.save,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _fixedSampleRate() {
    final prefs = usbAudioPreferences;
    return Column(
      children: [
        _section(
          children: [
            _tile(
              title: '启用',
              trailing: SizedBox(
                width: 52,
                child: MySwitch(
                  valueNotifier: prefs.fixedSampleRateEnabledNotifier,
                  onToggleCallBack: setting.save,
                ),
              ),
            ),
            for (final rate in UsbAudioPreferences.sampleRates)
              ValueListenableBuilder<int?>(
                valueListenable: prefs.fixedSampleRateNotifier,
                builder: (context, selectedRate, _) {
                  return _radioTile<int>(
                    title: rate.toString(),
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
      children: [
        _section(
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
        const SizedBox(height: 14),
        _sectionTitle('DSD to PCM'),
        _section(
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

  Widget _section({required List<Widget> children}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: menuColor.value,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(children: children),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            color: textColor.value.withAlpha(180),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _tile({
    required String title,
    String? subtitle,
    Widget? trailing,
    bool info = false,
  }) {
    return ListTile(
      title: _titleWithInfo(title, info),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: trailing,
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

  Widget _titleWithInfo(String title, bool info) {
    if (!info) return Text(title);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(title)),
        const SizedBox(width: 6),
        Icon(
          Icons.info_outline_rounded,
          size: 16,
          color: textColor.value.withAlpha(90),
        ),
      ],
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
    bool info = false,
    required ValueNotifier<T> notifier,
    required List<T> values,
    required String Function(T value) label,
  }) {
    return ValueListenableBuilder<T>(
      valueListenable: notifier,
      builder: (context, value, _) {
        return ListTile(
          title: _titleWithInfo(title, info),
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
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Material(
          color: menuColor.value,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            child: ListView(
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
          ),
        );
      },
    );
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
      UsbDsdMode.native => '保留 Native DSD 策略，需底层链路支持',
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
