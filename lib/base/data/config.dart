import 'dart:convert';
import 'dart:io';

import 'package:particle_music/base/app.dart';
import 'package:particle_music/base/services/emby_client.dart';
import 'package:particle_music/base/services/navidrome_client.dart';
import 'package:particle_music/base/services/webdav_client.dart';

final config = Config();

class Config {
  late final File file;

  Future<void> load() async {
    file = File("${appSupportDir.path}/config.json");
    if (!(file.existsSync())) {
      return;
    }

    final content = await file.readAsString();

    final Map<String, dynamic> map =
        jsonDecode(content) as Map<String, dynamic>;

    final webdavMap = map['webdav'] as Map<String, dynamic>?;
    if (webdavMap != null) {
      webdavClient = WebDavClient(
        baseUrl: webdavMap['baseUrl'],
        username: webdavMap['username'],
        password: webdavMap['password'],
      );
    }

    final navidromeMap = map['navidrome'] as Map<String, dynamic>?;
    if (navidromeMap != null) {
      navidromeClient = NavidromeClient(
        baseUrl: navidromeMap['baseUrl'],
        username: navidromeMap['username'],
        password: navidromeMap['password'],
      );
    }

    final embyMap = map['emby'] as Map<String, dynamic>?;
    if (embyMap != null) {
      embyClient = EmbyClient(
        baseUrl: embyMap['baseUrl'],
        username: embyMap['username'],
        password: embyMap['password'],
      );
      await embyClient!.login();
    }
  }

  void save() {
    file.writeAsStringSync(
      jsonEncode({
        if (webdavClient != null)
          'webdav': {
            'baseUrl': webdavClient!.baseUrl,
            'username': webdavClient!.username,
            'password': webdavClient!.password,
          },

        if (navidromeClient != null)
          'navidrome': {
            'baseUrl': navidromeClient!.baseUrl,
            'username': navidromeClient!.username,
            'password': navidromeClient!.password,
          },

        if (embyClient != null)
          'emby': {
            'baseUrl': embyClient!.baseUrl,
            'username': embyClient!.username,
            'password': embyClient!.password,
          },
      }),
    );
  }
}
