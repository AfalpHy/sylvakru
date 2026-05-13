import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:particle_music/base/audio_handler.dart';
import 'package:particle_music/base/data/config.dart';
import 'package:particle_music/base/services/emby_client.dart';
import 'package:particle_music/base/utils/color_manager.dart';
import 'package:particle_music/base/app.dart';
import 'package:particle_music/base/asset_images.dart';
import 'package:particle_music/base/utils/interaction.dart';
import 'package:particle_music/base/utils/logger.dart';
import 'package:particle_music/base/services/webdav_client.dart';
import 'package:particle_music/base/widgets/custom_text_field.dart';
import 'package:particle_music/base/widgets/equalizer.dart';
import 'package:particle_music/base/widgets/my_divider.dart';
import 'package:particle_music/base/widgets/tv_dir_picker.dart';
import 'package:particle_music/base/data/setting.dart';
import 'package:particle_music/layer/layers_manager.dart';
import 'package:particle_music/base/widgets/manage_music_folders.dart';
import 'package:particle_music/base/data/library.dart';
import 'package:particle_music/base/data/loader.dart';
import 'package:particle_music/portrait_view/sleep_timer.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/base/widgets/my_switch.dart';
import 'package:particle_music/base/services/navidrome_client.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsList extends StatelessWidget {
  final double? iconSize;
  const SettingsList({super.key, this.iconSize});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    bool isLandscape =
        !isMobile || MediaQuery.of(context).orientation == .landscape;
    return CustomScrollView(
      slivers: [
        if (isLandscape)
          sliverBox(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),

              child: Focus(
                child: ListTile(
                  leading: ImageIcon(settingImage, size: 50),
                  title: Text(
                    l10n.settings,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    l10n.settingCount(
                      isTV
                          ? 13
                          : Platform.isAndroid
                          ? 15
                          : Platform.isIOS
                          ? 14
                          : 13,
                    ),
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ),
          ),

        if (isLandscape)
          sliverBox(
            MyDivider(
              thickness: 0.5,
              height: 0.5,
              indent: 20,
              endIndent: 20,
              color: dividerColor,
            ),
          ),

        if (isLandscape) sliverBox(const SizedBox(height: 10)),

        sliverBox(
          paddingIfNeed(
            isLandscape,
            ListTile(
              leading: ImageIcon(
                infoImage,
                size: isLandscape ? null : iconSize,
              ),
              title: Text(l10n.openSourceLicense),
              onTap: () {
                layersManager.pushLayer('license');
              },
            ),
          ),
        ),

        sliverBox(
          paddingIfNeed(isLandscape, selectMusicFoldersListTile(context, l10n)),
        ),
        sliverBox(paddingIfNeed(isLandscape, navidromeListTile(context, l10n))),
        sliverBox(paddingIfNeed(isLandscape, webdavListTile(context, l10n))),
        sliverBox(paddingIfNeed(isLandscape, embyListTile(context, l10n))),

        sliverBox(paddingIfNeed(isLandscape, reloadListTile(context, l10n))),

        sliverBox(
          paddingIfNeed(isLandscape, cleanCacheListTile(context, l10n)),
        ),

        sliverBox(paddingIfNeed(isLandscape, languageListTile(context, l10n))),

        if (isMobile && !isTV)
          sliverBox(paddingIfNeed(isLandscape, vibrationListTile(l10n))),

        if (isMobile && !isTV)
          sliverBox(
            paddingIfNeed(
              isLandscape,
              sleepTimerListTile(context, l10n, iconSize: iconSize),
            ),
          ),

        sliverBox(paddingIfNeed(isLandscape, themeListTile(context, l10n))),
        sliverBox(paddingIfNeed(isLandscape, paletteListTile(context, l10n))),

        sliverBox(paddingIfNeed(isLandscape, equalizerListTile(context, l10n))),

        sliverBox(paddingIfNeed(isLandscape, autoPlayOnStartupListTile(l10n))),

        if (!isMobile)
          sliverBox(
            paddingForLandscape(exitOnClose(l10n)),
          ), // always landscape style

        sliverBox(paddingIfNeed(isLandscape, checkUpdate(context, l10n))),

        if (Platform.isAndroid)
          sliverBox(
            paddingIfNeed(isLandscape, exportLogListTile(context, l10n)),
          ),

        if (!isLandscape) sliverBox(const SizedBox(height: 100)),
      ],
    );
  }

  Widget paddingIfNeed(bool isLandscape, Widget child) {
    return isLandscape ? paddingForLandscape(child) : child;
  }

  Widget sliverBox(Widget child) => SliverToBoxAdapter(child: child);

  Widget paddingForLandscape(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: SmoothClipRRect(
        smoothness: 1,
        borderRadius: BorderRadius.circular(10),
        child: Material(color: Colors.transparent, child: child),
      ),
    );
  }

  Widget reloadListTile(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(reloadImage, size: iconSize),
      title: Text(l10n.reload),
      onTap: () async {
        if (await showConfirmDialog(context, l10n.reload)) {
          await Loader.reload();
        }
      },
    );
  }

  Widget selectMusicFoldersListTile(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return ListTile(
      leading: ImageIcon(folderImage, size: iconSize),
      title: Text(l10n.manageMusicFolder),
      onTap: () {
        showAnimationDialog(context: context, child: ManageMusicFolders());
      },
    );
  }

  Widget navidromeListTile(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(navidromeImage, size: iconSize),
      title: Text(l10n.connect2Navidrome),
      onTap: () {
        final baseUrlTmp = TextEditingController(
          text: navidromeClient?.baseUrl ?? '',
        );
        final usernameTmp = TextEditingController(
          text: navidromeClient?.username ?? '',
        );
        final passwordTmp = TextEditingController(
          text: navidromeClient?.password ?? '',
        );

        showAnimationDialog(
          context: context,
          child: SizedBox(
            height: 300,
            width: 300,
            child: Padding(
              padding: .fromLTRB(20, 15, 20, 15),
              child: Column(
                children: [
                  Spacer(),
                  SizedBox(
                    child: Text(
                      'Navidrome',
                      style: .new(fontWeight: .bold, fontSize: 18),
                    ),
                  ),

                  SizedBox(height: 10),
                  CustomTextField('Url', baseUrlTmp),

                  SizedBox(height: 10),
                  CustomTextField(l10n.username, usernameTmp),

                  SizedBox(height: 10),
                  CustomTextField(l10n.password, passwordTmp),

                  SizedBox(height: isMobile ? 10 : 20),
                  Builder(
                    builder: (context) {
                      return ValueListenableBuilder(
                        valueListenable: buttonColor.valueNotifier,
                        builder: (context, value, child) {
                          return Row(
                            children: [
                              Spacer(),
                              ElevatedButton(
                                onPressed: () async {
                                  if (!await showConfirmDialog(
                                    context,
                                    l10n.clear,
                                  )) {
                                    return;
                                  }

                                  navidromeClient = null;
                                  setting.save();
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                  }
                                  Loader.reload();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: value,
                                ),
                                child: Text(l10n.clear),
                              ),
                              SizedBox(width: 20),
                              ElevatedButton(
                                onPressed: () async {
                                  final tmp = navidromeClient;
                                  try {
                                    navidromeClient = NavidromeClient(
                                      baseUrl: baseUrlTmp.text,
                                      username: usernameTmp.text,
                                      password: passwordTmp.text,
                                    );
                                  } catch (e) {
                                    navidromeClient = tmp;
                                    showCenterMessage(
                                      context,
                                      e.toString(),
                                      duration: 5000,
                                    );
                                    return;
                                  }
                                  if (await navidromeClient!.ping()) {
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                    }

                                    config.save();

                                    await Loader.reload();
                                  } else {
                                    navidromeClient = tmp;
                                    if (context.mounted) {
                                      showCenterMessage(
                                        context,
                                        "Failed to connect to Navidrome",
                                        duration: 2000,
                                      );
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: value,
                                ),
                                child: Text(l10n.confirm),
                              ),
                              Spacer(),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  Spacer(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget webdavListTile(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(navidromeImage, size: iconSize),
      title: Text(l10n.connect2WebDAV),
      onTap: () {
        final baseUrlTmp = TextEditingController(
          text: webdavClient?.baseUrl ?? '',
        );
        final usernameTmp = TextEditingController(
          text: webdavClient?.username ?? '',
        );
        final passwordTmp = TextEditingController(
          text: webdavClient?.password ?? '',
        );

        showAnimationDialog(
          context: context,

          child: SizedBox(
            height: 300,
            width: 300,
            child: Padding(
              padding: .fromLTRB(20, 15, 20, 15),
              child: Column(
                children: [
                  Spacer(),
                  SizedBox(
                    child: Text(
                      'WebDAV',
                      style: .new(fontWeight: .bold, fontSize: 18),
                    ),
                  ),

                  SizedBox(height: 10),
                  CustomTextField('Url', baseUrlTmp),

                  SizedBox(height: 10),
                  CustomTextField(l10n.username, usernameTmp),

                  SizedBox(height: 10),
                  CustomTextField(l10n.password, passwordTmp),

                  SizedBox(height: isMobile ? 10 : 20),
                  Builder(
                    builder: (context) {
                      return ValueListenableBuilder(
                        valueListenable: buttonColor.valueNotifier,
                        builder: (context, value, child) {
                          return Row(
                            children: [
                              Spacer(),
                              ElevatedButton(
                                onPressed: () async {
                                  if (!await showConfirmDialog(
                                    context,
                                    l10n.clear,
                                  )) {
                                    return;
                                  }
                                  webdavClient = null;
                                  setting.save();
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                  }
                                  Loader.reload();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: value,
                                ),
                                child: Text(l10n.clear),
                              ),
                              SizedBox(width: 20),
                              ElevatedButton(
                                onPressed: () async {
                                  webdavClient = WebDavClient(
                                    baseUrl: baseUrlTmp.text,
                                    username: usernameTmp.text,
                                    password: passwordTmp.text,
                                  );
                                  if (!await webdavClient!.ping()) {
                                    if (context.mounted) {
                                      showCenterMessage(
                                        context,
                                        'Can not connect to WebDAV',
                                        duration: 2000,
                                      );
                                    }
                                    return;
                                  }
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    showCenterMessage(
                                      context,
                                      'Successfully connect to WebDAV',
                                      duration: 2000,
                                    );
                                  }
                                  config.save();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: value,
                                ),
                                child: Text(l10n.confirm),
                              ),
                              Spacer(),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  Spacer(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget embyListTile(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(navidromeImage, size: iconSize),
      title: Text(l10n.connect2Emby),
      onTap: () {
        final baseUrlTmp = TextEditingController(
          text: embyClient?.baseUrl ?? '',
        );
        final usernameTmp = TextEditingController(
          text: embyClient?.username ?? '',
        );
        final passwordTmp = TextEditingController(
          text: embyClient?.password ?? '',
        );

        showAnimationDialog(
          context: context,

          child: SizedBox(
            height: 300,
            width: 300,
            child: Padding(
              padding: .fromLTRB(20, 15, 20, 15),
              child: Column(
                children: [
                  Spacer(),
                  SizedBox(
                    child: Text(
                      'Emby',
                      style: .new(fontWeight: .bold, fontSize: 18),
                    ),
                  ),

                  SizedBox(height: 10),
                  CustomTextField('Url', baseUrlTmp),

                  SizedBox(height: 10),
                  CustomTextField(l10n.username, usernameTmp),

                  SizedBox(height: 10),
                  CustomTextField(l10n.password, passwordTmp),

                  SizedBox(height: isMobile ? 10 : 20),
                  Builder(
                    builder: (context) {
                      return ValueListenableBuilder(
                        valueListenable: buttonColor.valueNotifier,
                        builder: (context, value, child) {
                          return Row(
                            children: [
                              Spacer(),
                              ElevatedButton(
                                onPressed: () async {
                                  if (!await showConfirmDialog(
                                    context,
                                    l10n.clear,
                                  )) {
                                    return;
                                  }
                                  embyClient = null;
                                  setting.save();
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                  }
                                  Loader.reload();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: value,
                                ),
                                child: Text(l10n.clear),
                              ),
                              SizedBox(width: 20),
                              ElevatedButton(
                                onPressed: () async {
                                  embyClient = EmbyClient(
                                    baseUrl: baseUrlTmp.text,
                                    username: usernameTmp.text,
                                    password: passwordTmp.text,
                                  );
                                  await embyClient!.login();
                                  if (!await embyClient!.ping()) {
                                    embyClient = null;
                                    if (context.mounted) {
                                      showCenterMessage(
                                        context,
                                        'Can not connect to Emby',
                                        duration: 2000,
                                      );
                                    }
                                    return;
                                  }

                                  // print(meta.toString());
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    showCenterMessage(
                                      context,
                                      'Successfully connect to Emby',
                                      duration: 2000,
                                    );
                                  }
                                  config.save();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: value,
                                ),
                                child: Text(l10n.confirm),
                              ),
                              Spacer(),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  Spacer(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget cleanCacheListTile(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(cacheImage, size: iconSize),
      title: Text(l10n.clearCache),
      onTap: () async {
        if (await showConfirmDialog(context, l10n.clear)) {
          library.clearCache();
        }
      },
      trailing: ValueListenableBuilder(
        valueListenable: library.cacheSizeNotifier,
        builder: (context, value, child) {
          // use blank as placeholders
          return Text("${value.toStringAsFixed(1)}MB  ");
        },
      ),
    );
  }

  Widget languageListTile(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(languageImage, size: iconSize),
      title: Text(l10n.language),
      onTap: () {
        showAnimationDialog(
          context: context,

          child: SizedBox(
            width: 300,
            height: 300,
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: ValueListenableBuilder(
                valueListenable: localeNotifier,
                builder: (context, value, child) {
                  final l10n = AppLocalizations.of(context);

                  return ListView(
                    children: [
                      ListTile(
                        title: Text(l10n.followSystem),
                        onTap: () {
                          localeNotifier.value = null;
                          setting.save();
                        },
                        trailing: value == null ? Icon(Icons.check) : null,
                      ),
                      ListTile(
                        title: Text('English'),
                        onTap: () {
                          localeNotifier.value = Locale('en');
                          setting.save();
                        },
                        trailing: value == Locale('en')
                            ? Icon(Icons.check)
                            : null,
                      ),
                      ListTile(
                        title: Text('中文'),
                        onTap: () {
                          localeNotifier.value = Locale('zh');
                          setting.save();
                        },
                        trailing: value == Locale('zh')
                            ? Icon(Icons.check)
                            : null,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget vibrationListTile(AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(vibrationImage, size: iconSize),
      title: Text(l10n.vibration),
      trailing: SizedBox(
        width: 50,
        child: MySwitch(
          valueNotifier: vibrationOnNoitifier,
          onToggleCallBack: () {
            setting.save();
          },
        ),
      ),
    );
  }

  void _updateMainPageTheme() {
    setting.save();
    colorManager.updateMainPageColors();
  }

  void _updateLyricsPageTheme() {
    setting.save();
    colorManager.updateLyricsPageColors();
  }

  Widget themeListTile(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(themeImage, size: iconSize),
      title: Text(l10n.theme),
      onTap: () async {
        mainPageThemeNotifier.addListener(_updateMainPageTheme);
        lyricsPageThemeNotifier.addListener(_updateLyricsPageTheme);
        await showAnimationDialog(
          context: context,

          child: OrientationBuilder(
            builder: (context, orientation) {
              final appHeight = MediaQuery.heightOf(context);

              late double height;
              if (isMobile && orientation == Orientation.portrait) {
                height = 460;
              } else {
                if (isMobile) {
                  height = appHeight > 600 ? 460 : 350;
                } else {
                  height = 400;
                }
              }
              return SizedBox(
                width: 300,
                height: height,
                child: Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: CustomScrollView(
                    slivers: [
                      sliverBox(
                        ValueListenableBuilder(
                          valueListenable: mainPageThemeNotifier,
                          builder: (context, value, child) {
                            final l10n = AppLocalizations.of(context);
                            return Column(
                              children: [
                                Text(
                                  l10n.mainPageTheme,
                                  style: .new(fontSize: 16),
                                ),
                                ListTile(
                                  dense: true,
                                  title: Text(l10n.vividMode),
                                  onTap: () {
                                    mainPageThemeNotifier.value = .vivid;
                                  },
                                  trailing: value == .vivid
                                      ? Icon(Icons.check)
                                      : null,
                                ),
                                ListTile(
                                  dense: true,
                                  title: Text(l10n.lightMode),
                                  onTap: () {
                                    mainPageThemeNotifier.value = .light;
                                  },
                                  trailing: value == .light
                                      ? Icon(Icons.check)
                                      : null,
                                ),
                                ListTile(
                                  dense: true,
                                  title: Text(l10n.darkMode),
                                  onTap: () {
                                    mainPageThemeNotifier.value = .dark;
                                  },
                                  trailing: value == .dark
                                      ? Icon(Icons.check)
                                      : null,
                                ),
                                ListTile(
                                  dense: true,
                                  title: Text(l10n.customMode),
                                  onTap: () {
                                    mainPageThemeNotifier.value = .custom;
                                  },
                                  trailing: value == .custom
                                      ? Icon(Icons.check)
                                      : null,
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      sliverBox(
                        ValueListenableBuilder(
                          valueListenable: lyricsPageThemeNotifier,
                          builder: (context, value, child) {
                            final l10n = AppLocalizations.of(context);
                            return Column(
                              children: [
                                Text(
                                  l10n.lyricsPageTheme,
                                  style: .new(fontSize: 16),
                                ),
                                ListTile(
                                  dense: true,
                                  title: Text(l10n.vividMode),
                                  onTap: () {
                                    lyricsPageThemeNotifier.value = .vivid;
                                  },
                                  trailing: value == .vivid
                                      ? Icon(Icons.check)
                                      : null,
                                ),
                                ListTile(
                                  dense: true,
                                  title: Text(l10n.lightMode),
                                  onTap: () {
                                    lyricsPageThemeNotifier.value = .light;
                                  },
                                  trailing: value == .light
                                      ? Icon(Icons.check)
                                      : null,
                                ),
                                ListTile(
                                  dense: true,
                                  title: Text(l10n.darkMode),
                                  onTap: () {
                                    lyricsPageThemeNotifier.value = .dark;
                                  },
                                  trailing: value == .dark
                                      ? Icon(Icons.check)
                                      : null,
                                ),
                                ListTile(
                                  dense: true,
                                  title: Text(l10n.customMode),
                                  onTap: () {
                                    lyricsPageThemeNotifier.value = .custom;
                                  },
                                  trailing: value == .custom
                                      ? Icon(Icons.check)
                                      : null,
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
        mainPageThemeNotifier.removeListener(_updateMainPageTheme);
        lyricsPageThemeNotifier.removeListener(_updateLyricsPageTheme);
      },
    );
  }

  Widget colorListTile(
    BuildContext context,
    String title,
    AppLocalizations l10n,
    MyColor myColor,
  ) {
    ValueNotifier changeNotifier = ValueNotifier(0);
    return ValueListenableBuilder(
      valueListenable: changeNotifier,
      builder: (context, value, child) {
        Color pikerColor = myColor.customValue;
        return ListTile(
          title: Text(title),
          trailing: Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 5, 0),
            child: Material(
              color: Colors.transparent,
              elevation: 3,
              shape: SmoothRectangleBorder(
                smoothness: 1,
                borderRadius: BorderRadius.circular(3),
              ),
              child: InkWell(
                mouseCursor: SystemMouseCursors.click,
                child: SmoothClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Container(height: 35, width: 35, color: pikerColor),
                ),
                onTap: () {
                  final colorNotifier = ValueNotifier(pikerColor);
                  showAnimationDialog(
                    context: context,

                    child: SizedBox(
                      height: isMobile ? 380 : 430,
                      width: isMobile ? 320 : 400,
                      child: Column(
                        children: [
                          Spacer(),
                          ColorPicker(
                            color: pikerColor,
                            padding: .zero,
                            pickersEnabled: const {
                              ColorPickerType.wheel: true,
                              ColorPickerType.accent: false,
                              ColorPickerType.primary: false,
                            },
                            width: isMobile ? 25 : 30,
                            height: isMobile ? 25 : 30,
                            enableOpacity: true,
                            opacityTrackHeight: 10,
                            opacityThumbRadius: 12,
                            opacityTrackWidth: isMobile ? 310 : 360,
                            wheelDiameter: isMobile ? 160 : 200,
                            onColorChanged: (color) {
                              colorNotifier.value = color;
                            },
                          ),

                          ValueListenableBuilder(
                            valueListenable: colorNotifier,
                            builder: (context, value, child) {
                              return Text(
                                '$title: 0x${value.value32bit.toRadixString(16).toUpperCase().padLeft(8, '0')}',
                              );
                            },
                          ),
                          SizedBox(height: 15),
                          ValueListenableBuilder(
                            valueListenable: buttonColor.valueNotifier,
                            builder: (context, value, child) {
                              return Row(
                                children: [
                                  Spacer(),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: value,
                                    ),
                                    child: Text(l10n.cancel),
                                  ),
                                  SizedBox(width: 20),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      myColor.customValue = colorNotifier.value;
                                      myColor.updateColor();
                                      changeNotifier.value++;
                                      colorManager.saveCustomColors();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: value,
                                    ),
                                    child: Text(l10n.confirm),
                                  ),
                                  Spacer(),
                                ],
                              );
                            },
                          ),
                          Spacer(),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget paletteListTile(BuildContext context, AppLocalizations l10n) {
    final nameMap = colorManager.getNameMap(l10n);
    final resetNotifier = ValueNotifier(0);
    return ListTile(
      leading: ImageIcon(paletteImage, size: iconSize),
      title: Text(l10n.palette),
      onTap: () async {
        showAnimationDialog(
          context: context,

          child: OrientationBuilder(
            builder: (context, orientation) {
              final size = MediaQuery.of(context).size;
              final shortSide = size.shortestSide;

              bool isPhone = shortSide < 600;
              return SizedBox(
                height: max(350, size.height * 0.7),
                width: isPhone ? 300 : 400,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                  child: ValueListenableBuilder(
                    valueListenable: resetNotifier,
                    builder: (context, value, child) {
                      return ListView(
                        children: [
                          for (final color in colorManager.myColors)
                            if (color.type == 0 ||
                                (color.type == 1 && isMobile) ||
                                (color.type == 2 && !isMobile))
                              colorListTile(
                                context,
                                nameMap[color.name]!,
                                l10n,
                                color,
                              ),

                          ListTile(
                            title: Text(l10n.reset),
                            onTap: () {
                              for (final color in colorManager.myColors) {
                                color.resetCustomValue();
                              }
                              colorManager.updateColors();
                              resetNotifier.value++;
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget equalizerListTile(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(equalizerImage, size: iconSize),
      title: Text(l10n.equalizer),
      onTap: () {
        showAnimationDialog(
          context: context,
          child: OrientationBuilder(
            builder: (context, orientation) {
              final size = MediaQuery.of(context).size;
              final shortSide = size.shortestSide;

              bool isPhone = shortSide < 600;
              if (isMobile && orientation == .portrait) {
                return SizedBox(
                  height: 500,
                  width: isPhone ? 300 : 400,
                  child: EqualizerWidget(),
                );
              } else {
                return SizedBox(
                  height: isPhone ? 350 : 400,
                  width: 540,
                  child: EqualizerWidget(),
                );
              }
            },
          ),
        );
      },
    );
  }

  Widget autoPlayOnStartupListTile(AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(playOutlinedImage, size: iconSize),

      title: Text(l10n.autoPlayOnStartup),
      trailing: SizedBox(
        width: 50,
        child: MySwitch(
          valueNotifier: autoPlayOnStartupNotifier,
          onToggleCallBack: () {
            setting.save();
          },
        ),
      ),
    );
  }

  Widget exitOnClose(AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(powerOffImage),

      title: Text(l10n.closeAction),
      trailing: SizedBox(
        width: 150,
        child: Row(
          children: [
            Spacer(),
            MySwitch(
              trueText: l10n.exit,
              falseText: l10n.hide,
              valueNotifier: exitOnCloseNotifier,
              onToggleCallBack: () {
                setting.save();
              },
            ),
          ],
        ),
      ),
    );
  }

  int _compareVersion(String a, String b) {
    final aParts = a.split('.').map(int.parse).toList();
    final bParts = b.split('.').map(int.parse).toList();

    final length = aParts.length > bParts.length
        ? aParts.length
        : bParts.length;

    for (int i = 0; i < length; i++) {
      final aVal = i < aParts.length ? aParts[i] : 0;
      final bVal = i < bParts.length ? bParts[i] : 0;

      if (aVal != bVal) {
        return aVal.compareTo(bVal);
      }
    }
    return 0;
  }

  Widget checkUpdate(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(checkUpdateImage, size: iconSize),
      title: Text(l10n.checkUpdate),
      onTap: () async {
        final url = Uri.parse(
          'https://api.github.com/repos/AfalpHy/ParticleMusic/releases/latest',
        );

        try {
          final response = await http
              .get(url)
              .timeout(const Duration(seconds: 3));
          if (response.statusCode != 200) {
            if (context.mounted) {
              showCenterMessage(
                context,
                'Failed to fetch GitHub release:${response.statusCode}',
                duration: 2000,
              );
            }
            return;
          }
          final data = jsonDecode(response.body);
          String latestVersion = (data['tag_name'] as String).replaceFirst(
            'v',
            '',
          );
          if (_compareVersion(latestVersion, versionNumber) > 0) {
            if (context.mounted) {
              showAnimationDialog(
                context: context,

                child: SizedBox(
                  height: isMobile ? 350 : 400,
                  width: isMobile ? 320 : 400,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 30),
                            child: ListView(
                              children: [
                                Center(
                                  child: Text(
                                    data['tag_name'] as String,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: .bold,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 10),

                                Text(data['body'] as String),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                        ValueListenableBuilder(
                          valueListenable: buttonColor.valueNotifier,
                          builder: (context, value, child) {
                            return Row(
                              children: [
                                Spacer(),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: value,
                                  ),
                                  child: Text(l10n.cancel),
                                ),
                                SizedBox(width: 20),
                                ElevatedButton(
                                  onPressed: () => launchUrl(
                                    Uri.parse(
                                      "https://github.com/AfalpHy/ParticleMusic/releases/latest",
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: value,
                                  ),
                                  child: Text(l10n.go2Download),
                                ),
                                Spacer(),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
          } else {
            if (context.mounted) {
              showCenterMessage(context, l10n.alreadyLatest, duration: 2000);
            }
          }
        } catch (e) {
          if (context.mounted) {
            showCenterMessage(
              context,
              'Failed to fetch GitHub release:$e',
              duration: 5000,
            );
          }
        }
      },
    );
  }

  Widget exportLogListTile(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(exportLogImage, size: iconSize),

      title: Text(l10n.exportLog),
      onTap: () async {
        String? result;
        if (isTV) {
          result = await showAnimationDialog(
            context: context,
            child: SizedBox(height: 350, width: 300, child: TvDirPicker()),
          );
        } else {
          result = await FilePicker.getDirectoryPath();
        }
        if (result == null) {
          return;
        }
        logger.export2Directory(result);
      },
    );
  }
}
