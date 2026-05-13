import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:particle_music/base/utils/logger.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

WebDavClient? webdavClient;

class WebDavFile {
  final String path;
  final String name;
  final bool isDirectory;

  final DateTime? modified;
  final DateTime? created;

  final String? etag;

  WebDavFile({
    required this.path,
    required this.name,
    required this.isDirectory,
    this.modified,
    this.created,
    this.etag,
  });
}

class WebDavClient {
  final String baseUrl;
  final String username;
  final String password;

  late final Dio dio;

  WebDavClient({
    required this.baseUrl,
    required this.username,
    required this.password,
  }) {
    dio = Dio(BaseOptions(baseUrl: baseUrl));
    _applyAuth();
  }

  void _applyAuth() {
    dio.options.headers['authorization'] =
        'Basic ${base64Encode(utf8.encode('$username:$password'))}';
  }

  Map<String, String> get headers {
    return Map<String, String>.from(dio.options.headers);
  }

  String _safeDecodeUri(String value) {
    try {
      return Uri.decodeFull(value);
    } catch (_) {
      return value;
    }
  }

  bool _isSelfPath(String requestPath, String href) {
    String normalize(String path) {
      path = _safeDecodeUri(path);

      if (path.endsWith('/') && path.length > 1) {
        path = path.substring(0, path.length - 1);
      }

      if (path.isEmpty) {
        path = '/';
      }

      return path;
    }

    return normalize(requestPath) == normalize(href);
  }

  Future<bool> ping() async {
    try {
      final response = await dio.request(
        '/',
        options: Options(method: 'OPTIONS'),
      );

      return response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 400;
    } catch (_) {
      return false;
    }
  }

  Future<List<WebDavFile>> list(String remotePath) async {
    if (!remotePath.endsWith('/')) {
      remotePath += '/';
    }
    final response = await dio.request(
      remotePath,
      data: '''
<?xml version="1.0" encoding="utf-8"?>
<d:propfind xmlns:d="DAV:">
  <d:allprop />
</d:propfind>
''',
      options: Options(
        method: 'PROPFIND',
        headers: {'Depth': '1', 'Content-Type': 'text/xml; charset=utf-8'},
      ),
    );

    final document = XmlDocument.parse(response.data);

    final responses = document
        .findAllElements('*')
        .where((e) => e.name.local == 'response');

    final result = <WebDavFile>[];

    for (final item in responses) {
      final hrefElement = item.children.whereType<XmlElement>().firstWhere(
        (e) => e.name.local == 'href',
      );

      final href = _safeDecodeUri(hrefElement.innerText);

      if (_isSelfPath(remotePath, href)) {
        continue;
      }

      final isDir = item
          .findAllElements('*')
          .any((e) => e.name.local == 'collection');

      final modifiedElement = item
          .findAllElements('*')
          .where((e) => e.name.local == 'getlastmodified')
          .firstOrNull;

      DateTime? modified;

      if (modifiedElement != null) {
        try {
          modified = HttpDate.parse(modifiedElement.innerText).toLocal();
        } catch (_) {}
      }

      final cleanPath = href.endsWith('/')
          ? href.substring(0, href.length - 1)
          : href;

      final name = p.basename(cleanPath);

      result.add(
        WebDavFile(
          path: href,
          name: name,
          isDirectory: isDir,
          modified: modified,
        ),
      );
    }
    return result;
  }

  Stream<WebDavFile> listStream(
    String remotePath, {
    bool recursive = false,
  }) async* {
    final files = await list(remotePath);

    for (final file in files) {
      yield file;

      if (recursive && file.isDirectory) {
        yield* listStream(file.path, recursive: true);
      }
    }
  }

  Future<List<String>> listSubDirectories(String root) async {
    List<String> dirList = [];
    Queue<String> dirQueue = Queue();
    dirQueue.add(root);
    while (dirQueue.isNotEmpty) {
      String dir = dirQueue.first;
      dirQueue.removeFirst();
      final fileList = await list(dir);
      for (final f in fileList) {
        if (f.isDirectory) {
          dirList.add(f.path);
          dirQueue.add(f.path);
        }
      }
    }
    return dirList;
  }

  Future<void> download({
    required String remotePath,
    required String localPath,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      await dio.download(
        remotePath,
        localPath,
        onReceiveProgress: onReceiveProgress,
      );
    } catch (e) {
      logger.output(e.toString());
    }
  }

  Future<void> upload({
    required String localPath,
    required String remotePath,
    ProgressCallback? onSendProgress,
  }) async {
    final file = File(localPath);

    await dio.put(
      remotePath,
      data: file.openRead(),
      options: Options(
        headers: {Headers.contentLengthHeader: await file.length()},
      ),
      onSendProgress: onSendProgress,
    );
  }

  Future<void> mkdir(String remotePath) async {
    await dio.request(remotePath, options: Options(method: 'MKCOL'));
  }

  Future<void> delete(String remotePath) async {
    await dio.delete(remotePath);
  }

  Future<void> move({
    required String source,
    required String destination,
  }) async {
    await dio.request(
      source,
      options: Options(
        method: 'MOVE',
        headers: {'Destination': '$baseUrl$destination'},
      ),
    );
  }

  Future<void> copy({
    required String source,
    required String destination,
  }) async {
    await dio.request(
      source,
      options: Options(
        method: 'COPY',
        headers: {'Destination': '$baseUrl$destination'},
      ),
    );
  }
}
