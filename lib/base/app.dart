import 'dart:io';

import 'package:flutter/material.dart';
import 'package:screen_corner_radius/screen_corner_radius.dart';

const String versionNumber = '2.3.0';

late final Directory appDocsDir;
late final Directory appSupportDir;
late final Directory tmpDir;
late final Directory localFolderConfigDir;
late final Directory localPlaylistConfigDir;
late final Directory webdavFolderConfigDir;
late final Directory webdavPlaylistConfigDir;
late final Directory cacheConfigDir;

final isMobile = Platform.isAndroid || Platform.isIOS;
const isTV = bool.fromEnvironment('TV', defaultValue: false);

late final ScreenRadius? screenRadius;

enum ThemeType { vivid, light, dark, custom }

final mainPageThemeNotifier = ValueNotifier(ThemeType.vivid);
final lyricsPageThemeNotifier = ValueNotifier(ThemeType.vivid);

final ValueNotifier<Locale?> localeNotifier = ValueNotifier(null);

enum SourceType { local, webdav, navidrome, emby }
