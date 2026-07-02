import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/data/library.dart';
import 'package:sylvakru/base/services/webdav_client.dart';

bool isFileProviderStorePath(String path) {
  return path.contains('File Provider Storage/');
}

// full path to short path
String convertIOSPath(String path) {
  if (path.contains('File Provider Storage/')) {
    return path.split('File Provider Storage/').last;
  } else {
    path = path.substring(path.indexOf('Documents'));
    return path.replaceFirst('Documents', 'Sylvakru');
  }
}

// short path to full path
String revertIOSPath(String path) {
  if (path.startsWith('Sylvakru')) {
    return "${appDocsDir.parent.path}/${path.replaceFirst('Sylvakru', 'Documents')}";
  } else {
    if (library.iosFileProviderStorage == null) {
      return '';
    }
    return library.iosFileProviderStorage! + path;
  }
}

// full path to short path
String convertIOSSupportPath(String path) {
  return path.split('Application Support/').last;
}

// short path to full path
String revertIOSSupportPath(String path) {
  return "${appSupportDir.path}/$path";
}

void initFile(File file, bool isList) {
  if (!file.existsSync()) {
    file.createSync(recursive: true);
    file.writeAsStringSync(isList ? '[]' : '{}');
  }
}

String getFolderConfigPath(SourceType sourceType) {
  return '${appSupportDir.path}/${sourceType.name}/folder_config';
}

String getPlaylistConfigPath(SourceType sourceType) {
  return '${appSupportDir.path}/${sourceType.name}/playlist_config';
}

String getCachesPath(SourceType sourceType) {
  return '${appSupportDir.path}/${sourceType.name}/caches';
}

String getPicturesPath(SourceType sourceType) {
  return '${appSupportDir.path}/${sourceType.name}/pictures';
}

final _httpClient = http.Client();

Future<String?> convertToRealPathIfNeed(String path) async {
  final uri = Uri.tryParse(path);
  if (uri == null ||
      !(uri.isScheme('http') || uri.isScheme('https')) ||
      !uri.hasAuthority ||
      uri.host.isEmpty) {
    return null;
  }

  final request = http.Request('HEAD', uri)
    ..followRedirects = false
    ..headers.addAll(webdavClient?.headers ?? {});

  final response = await _httpClient.send(request);

  if (response.statusCode == 302) {
    final realLocation = response.headers['location'];
    if (realLocation != null) {
      return realLocation;
    }
  }
  return null;
}
