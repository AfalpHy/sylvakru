import 'dart:io';

import 'package:corner_radius_plugin/corner_radius_plugin.dart';
import 'package:material_ui/material_ui.dart';

const String versionNumber = '4.3.0';

late final Directory appDocsDir;
late final Directory appSupportDir;
late final Directory tmpDir;
String? iosFileProviderStorage;

final isMobile = Platform.isAndroid || Platform.isIOS;
const isTV = bool.fromEnvironment('TV', defaultValue: false);

final globalNavigatorKey = GlobalKey<NavigatorState>();

late final CornerRadius screenRadius;

enum ThemeType { vivid, light, dark, custom }

final mainPageThemeNotifier = ValueNotifier(ThemeType.vivid);
final lyricsPageThemeNotifier = ValueNotifier(ThemeType.vivid);

final ValueNotifier<Locale?> localeNotifier = ValueNotifier(null);

enum SourceType { local, webdav, navidrome, emby, feiniu }

SourceType sourceType = .local;

bool isStreamSource = false;
bool isNotStreamSource = !isStreamSource;

final ValueNotifier<String?> fontFamilyNotifier = ValueNotifier(null);

final List<String> importedFonts = [];

final isPremiumNotifier = ValueNotifier(true);

enum ViewMode { normal, mini, bigPicture }

final viewModeNotifier = ValueNotifier(ViewMode.normal);

final immersiveWideLayoutNotifier = ValueNotifier(true);
