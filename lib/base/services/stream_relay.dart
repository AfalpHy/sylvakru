import 'dart:io';

import 'package:sylvakru/base/services/logger.dart';

final streamRelay = StreamRelay();

class _RelayTarget {
  final String url;
  final Map<String, String>? headers;

  _RelayTarget(this.url, this.headers);
}

/// mpv's bundled ffmpeg does TLS with macOS Secure Transport, which never got
/// TLS 1.3 - servers that require it (e.g. Emby behind a modern CDN) kill the
/// handshake before any proxy setting can matter. Dart's HttpClient
/// (BoringSSL) negotiates TLS 1.3 and follows the system proxy, so remote
/// streams are fetched Dart-side and re-served to mpv over plain localhost
/// HTTP: mpv never touches TLS or the proxy at all.
class StreamRelay {
  Future<HttpServer>? _starting;
  String? _baseUrl;
  final _targets = <String, _RelayTarget>{};
  final _client = HttpClient();

  int _counter = 0;

  StreamRelay() {
    _client.connectionTimeout = const Duration(seconds: 10);
  }

  /// Registers [url] (with the auth [headers] mpv would otherwise have sent)
  /// and returns a plain-HTTP localhost URL for mpv to open.
  Future<String> register(String url, Map<String, String>? headers) async {
    await _ensureStarted();

    if (_targets.length > 16) {
      _targets.remove(_targets.keys.first);
    }

    final token = '${DateTime.now().microsecondsSinceEpoch}-${_counter++}';
    _targets[token] = _RelayTarget(url, headers);

    return '$_baseUrl/audio/$token';
  }

  Future<HttpServer> _ensureStarted() {
    return _starting ??= _start();
  }

  Future<HttpServer> _start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);

    _baseUrl = 'http://127.0.0.1:${server.port}';

    server.listen(
      (request) {
        _handle(request);
      },
      onError: (e) {
        logger.output('[StreamRelay] server error: $e');
      },
    );

    return server;
  }

  Future<void> _handle(HttpRequest request) async {
    try {
      final segments = request.uri.pathSegments;
      final target = segments.length == 2 && segments[0] == 'audio'
          ? _targets[segments[1]]
          : null;

      if (target == null) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }

      final upstream = await _client.openUrl('GET', Uri.parse(target.url));
      target.headers?.forEach(upstream.headers.set);

      final range = request.headers.value(HttpHeaders.rangeHeader);
      if (range != null) {
        upstream.headers.set(HttpHeaders.rangeHeader, range);
      }

      final response = await upstream.close();

      request.response.statusCode = response.statusCode;
      for (final name in [
        HttpHeaders.contentTypeHeader,
        HttpHeaders.contentLengthHeader,
        HttpHeaders.contentRangeHeader,
        HttpHeaders.acceptRangesHeader,
        HttpHeaders.lastModifiedHeader,
        HttpHeaders.etagHeader,
      ]) {
        final value = response.headers.value(name);
        if (value != null) {
          request.response.headers.set(name, value);
        }
      }

      if (request.method == 'HEAD') {
        await request.response.close();
        return;
      }

      await for (final chunk in response) {
        request.response.add(chunk);
      }
      await request.response.close();
    } catch (e) {
      // mpv aborts requests mid-stream when seeking or switching tracks;
      // that surfaces here as a write/socket error and is not a problem.
      logger.output('[StreamRelay] request ended: $e');
      try {
        await request.response.close();
      } catch (_) {}
    }
  }
}
