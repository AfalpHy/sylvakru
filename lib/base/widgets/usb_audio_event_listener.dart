import 'package:flutter/material.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/services/usb_audio_service.dart';
import 'package:sylvakru/base/widgets/audio_output_panel.dart';

class UsbAudioEventListener extends StatefulWidget {
  final Widget child;

  const UsbAudioEventListener({super.key, required this.child});

  @override
  State<UsbAudioEventListener> createState() => _UsbAudioEventListenerState();
}

class _UsbAudioEventListenerState extends State<UsbAudioEventListener> {
  UsbAudioDeviceEvent? _lastEvent;
  int? _lastPromptedDeviceId;
  bool _showingPrompt = false;

  @override
  void initState() {
    super.initState();
    usbAudioEventNotifier.addListener(_handleUsbAudioEvent);
  }

  @override
  void dispose() {
    usbAudioEventNotifier.removeListener(_handleUsbAudioEvent);
    super.dispose();
  }

  void _handleUsbAudioEvent() {
    final event = usbAudioEventNotifier.value;
    if (event == null || identical(event, _lastEvent)) {
      return;
    }
    _lastEvent = event;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      switch (event.type) {
        case UsbAudioDeviceEventType.added:
          _showDetectedPrompt(event);
          break;
        case UsbAudioDeviceEventType.removed:
          _showRemovedMessage();
          break;
      }
    });
  }

  Future<void> _showDetectedPrompt(UsbAudioDeviceEvent event) async {
    if (_showingPrompt || event.status.supported == false) {
      return;
    }
    if (event.deviceId != null && event.deviceId == _lastPromptedDeviceId) {
      return;
    }

    _showingPrompt = true;
    _lastPromptedDeviceId = event.deviceId;
    await showUsbAudioDetectedSheet(
      context,
      event.status,
      currentSongNotifier.value,
    );
    _showingPrompt = false;
  }

  void _showRemovedMessage() {
    _lastPromptedDeviceId = null;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('USB DAC 已断开，已恢复 Android 系统输出'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
