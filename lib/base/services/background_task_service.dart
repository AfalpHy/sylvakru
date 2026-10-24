import 'dart:io';

import 'package:flutter/services.dart';

class BackgroundTaskService {
  static const MethodChannel _channel = MethodChannel(
    'com.afalphy.background_task',
  );

  BackgroundTaskService._();

  /// Requests extra execution time from the system so work in progress (song
  /// download/load) is not suspended when the app goes to the background.
  /// iOS only; no-op elsewhere. The returned token must be passed to [end]
  /// once the work is done.
  static Future<int?> begin() async {
    if (!Platform.isIOS) {
      return null;
    }
    try {
      return await _channel.invokeMethod<int>('begin');
    } catch (error) {
      // Without the grace period the work may be suspended, but that is
      // preferable to crashing the caller.
      return null;
    }
  }

  /// Releases the execution time requested by [begin]. Safe to call with a
  /// null token, more than once, or on other platforms.
  static Future<void> end(int? token) async {
    if (!Platform.isIOS || token == null) {
      return;
    }
    try {
      await _channel.invokeMethod('end', {'taskId': token});
    } catch (error) {
      // The native expiration handler releases the task on its own.
    }
  }
}
