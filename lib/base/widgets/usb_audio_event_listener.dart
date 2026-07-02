import 'package:flutter/material.dart';
import 'package:sylvakru/base/services/usb_audio_service.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';

class UsbAudioEventListener extends StatefulWidget {
  final Widget child;

  const UsbAudioEventListener({super.key, required this.child});

  @override
  State<UsbAudioEventListener> createState() => _UsbAudioEventListenerState();
}

class _UsbAudioEventListenerState extends State<UsbAudioEventListener> {
  UsbAudioDeviceEvent? _lastEvent;

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
          break;
        case UsbAudioDeviceEventType.removed:
          _showRemovedMessage();
          break;
      }
    });
  }

  void _showRemovedMessage() {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).usbDacDisconnected),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
