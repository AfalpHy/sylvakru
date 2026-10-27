import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sylvakru/base/services/logger.dart';
import 'package:win32/win32.dart' as win32;

// System proxy detected from the OS (null = none configured, traffic direct).
// The routing decision per request is left entirely to the proxy client's own
// rules (e.g. Clash rule mode), so nothing here inspects domains.
({String host, int port})? systemProxy;

const _channel = MethodChannel('com.afalphy.system_proxy');

class _SystemProxyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);

    client.findProxy = (uri) {
      final proxy = systemProxy;

      if (proxy == null) {
        return HttpClient.findProxyFromEnvironment(uri);
      }

      return 'PROXY ${proxy.host}:${proxy.port}';
    };

    return client;
  }
}

Future<void> initSystemProxy() async {
  await _detectSystemProxy();

  // dart:io never reads the OS proxy itself; every HttpClient created after
  // this point (Dio's IOHttpClientAdapter, Flutter network images) consults
  // these overrides. The findProxy closure reads the global per request, so
  // re-detections apply without recreating any client.
  HttpOverrides.global = _SystemProxyHttpOverrides();

  // Proxy apps are often toggled while the app is open.
  AppLifecycleListener(
    onResume: () {
      _detectSystemProxy();
    },
  );
}

Future<void> _detectSystemProxy() async {
  ({String host, int port})? detected;

  for (var attempt = 1;; attempt++) {
    try {
      if (Platform.isIOS || Platform.isMacOS || Platform.isAndroid) {
        detected = _parseProxyUrl(
          await _channel.invokeMethod<String>('getProxy'),
        );
      } else if (Platform.isWindows) {
        detected = _detectWindowsProxy();
      } else if (Platform.isLinux) {
        detected = _detectEnvProxy();
      }
      break;
    } on MissingPluginException catch (e) {
      // Seen when Dart code runs against a runner built without the native
      // handler (e.g. hot restart in a session opened before the native side
      // was rebuilt). Retry briefly, then fall back to a direct connection;
      // a full stop + rebuild of the app makes the channel available again.
      if (attempt >= 3) {
        systemProxy = null;
        logger.output('[SystemProxy] channel unavailable, going direct: $e');
        return;
      }
      await Future.delayed(const Duration(milliseconds: 250));
    } catch (e) {
      systemProxy = null;
      logger.output('[SystemProxy] detect error: $e');
      return;
    }
  }

  systemProxy = detected;

  if (detected != null) {
    logger.output('[SystemProxy] ${detected.host}:${detected.port}');
  }
}

({String host, int port})? _parseProxyUrl(String? url) {
  if (url == null || url.isEmpty) {
    return null;
  }

  final uri = Uri.tryParse(url);

  if (uri == null || uri.host.isEmpty || uri.port == 0) {
    return null;
  }

  return (host: uri.host, port: uri.port);
}

({String host, int port})? _detectEnvProxy() {
  final env = Platform.environment;

  final url =
      env['https_proxy'] ??
      env['HTTPS_PROXY'] ??
      env['http_proxy'] ??
      env['HTTP_PROXY'];

  return _parseProxyUrl(url);
}

// Reads ProxyEnable/ProxyServer from the WinInet key that proxy apps
// ("System Proxy" toggle) write to.
({String host, int port})? _detectWindowsProxy() {
  return using((arena) {
    final phkResult = arena<Pointer>();

    final open = win32.RegOpenKeyEx(
      win32.HKEY_CURRENT_USER,
      r'Software\Microsoft\Windows\CurrentVersion\Internet Settings'.toPcwstr(
        allocator: arena,
      ),
      0,
      win32.KEY_READ,
      phkResult,
    );

    if (open.isError) {
      return null;
    }

    final hkey = win32.HKEY(phkResult.value);

    try {
      final type = arena<Uint32>();
      final data = arena<Uint8>(4);
      final dataSize = arena<Uint32>()..value = 4;

      final enabled = win32.RegQueryValueEx(
        hkey,
        'ProxyEnable'.toPcwstr(allocator: arena),
        type,
        data,
        dataSize,
      );

      if (enabled.isError || data.cast<Uint32>().value != 1) {
        return null;
      }

      // First call with no data buffer returns the required size.
      final serverSize = arena<Uint32>();

      if (win32
          .RegQueryValueEx(
            hkey,
            'ProxyServer'.toPcwstr(allocator: arena),
            null,
            null,
            serverSize,
          )
          .isError) {
        return null;
      }

      if (serverSize.value == 0) {
        return null;
      }

      final server = arena<Uint16>(serverSize.value ~/ 2 + 1);
      final serverSize2 = arena<Uint32>()..value = serverSize.value;

      final read = win32.RegQueryValueEx(
        hkey,
        'ProxyServer'.toPcwstr(allocator: arena),
        null,
        server.cast<Uint8>(),
        serverSize2,
      );

      if (read.isError) {
        return null;
      }

      return _parseProxyServer(server.cast<Utf16>().toDartString());
    } finally {
      win32.RegCloseKey(hkey);
    }
  });
}

// ProxyServer is either "host:port" (all protocols) or per-protocol
// "http=host:port;https=host:port;...".
({String host, int port})? _parseProxyServer(String server) {
  String? entry;

  if (server.contains('=')) {
    for (final part in server.split(';')) {
      final value = part.trim();

      if (value.startsWith('https=')) {
        entry = value.substring('https='.length);
        break;
      } else if (value.startsWith('http=')) {
        entry = value.substring('http='.length);
      }
    }
  } else {
    entry = server.trim();
  }

  if (entry == null || entry.isEmpty) {
    return null;
  }

  return _parseProxyUrl('http://$entry');
}
