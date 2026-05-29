import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/asset_images.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/base/widgets/cover_art_widget.dart';
import 'package:sylvakru/base/widgets/my_divider.dart';
import 'package:sylvakru/base/widgets/playlist_widgets.dart';
import 'package:sylvakru/base/data/playlist.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/layer/layers_manager.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'package:super_context_menu/super_context_menu.dart';
import 'package:window_manager/window_manager.dart';

FocusNode songsFocusNode = FocusNode();
final ValueNotifier<String> sidebarHighlighLabel = ValueNotifier('');

class Sidebar extends StatelessWidget {
  final ScrollController _scrollController = ScrollController();
  final void Function()? closeDrawer;
  Sidebar({super.key, this.closeDrawer});

  Widget sidebarItem({
    required String label,
    required Widget leading,
    required String content,
    Widget? trailing,
    EdgeInsetsGeometry? contentPadding,
    required Function() onTap,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10),
      child: ValueListenableBuilder(
        valueListenable: sidebarHighlighLabel,
        builder: (context, highlightLabel, child) {
          return ValueListenableBuilder(
            valueListenable: selectedItemColor.valueNotifier,
            builder: (context, value, _) {
              return Material(
                color: highlightLabel == label ? value : Colors.transparent,
                shape: SmoothRectangleBorder(
                  smoothness: 1,
                  borderRadius: BorderRadius.circular(10),
                ),
                clipBehavior: .antiAlias,
                child: child,
              );
            },
          );
        },
        child: InkWell(
          focusNode: isTV && label == 'songs' ? songsFocusNode : null,
          child: ListTile(
            leading: leading,
            title: Text(
              content,
              style: TextStyle(fontSize: 15, overflow: TextOverflow.ellipsis),
            ),
            contentPadding: contentPadding,
            visualDensity: const VisualDensity(horizontal: 0, vertical: -3.65),
            trailing: trailing,
          ),
          onTap: () async {
            if (closeDrawer != null) {
              closeDrawer!.call();
              await Future.delayed(Duration(milliseconds: 250));
            }
            onTap();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ValueListenableBuilder(
      valueListenable: sidebarColor.valueNotifier,
      builder: (context, value, child) {
        return Material(color: value, child: child);
      },
      child: SizedBox(
        width: 220,
        child: Column(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (details) {
                if (isMobile) {
                  return;
                }
                windowManager.startDragging();
              },
              onDoubleTap: () async {
                if (isMobile) {
                  return;
                }
                await windowManager.isMaximized()
                    ? windowManager.unmaximize()
                    : windowManager.maximize();
              },
              child: SizedBox(
                height: 75,
                child: Center(
                  child: ValueListenableBuilder(
                    valueListenable: highlightTextColor.valueNotifier,
                    builder: (context, value, child) {
                      return Text(
                        'Sylvakru',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: value,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            Expanded(
              child: Scrollbar(
                thickness: 5,
                controller: _scrollController,
                child: CustomScrollView(
                  primary: false,
                  controller: _scrollController,
                  scrollBehavior: ScrollConfiguration.of(
                    context,
                  ).copyWith(scrollbars: false),
                  slivers: [
                    SliverToBoxAdapter(
                      child: sidebarItem(
                        label: 'artists',
                        leading: ImageIcon(artistImage, size: 30),
                        content: l10n.artists,

                        onTap: () {
                          layersManager.pushLayer('artists');
                        },
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: sidebarItem(
                        label: 'albums',

                        leading: ImageIcon(albumImage, size: 30),
                        content: l10n.albums,

                        onTap: () {
                          layersManager.pushLayer('albums');
                        },
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: sidebarItem(
                        label: 'folders',

                        leading: ImageIcon(folderImage, size: 30),
                        content: l10n.folders,

                        onTap: () {
                          layersManager.pushLayer('folders');
                        },
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: sidebarItem(
                        label: 'songs',

                        leading: ImageIcon(songsImage, size: 30),
                        content: l10n.songs,

                        onTap: () {
                          layersManager.pushLayer('songs');
                        },
                      ),
                    ),

                    SliverToBoxAdapter(child: SizedBox(height: 10)),
                    SliverToBoxAdapter(
                      child: MyDivider(
                        thickness: 0.5,
                        height: 1,
                        indent: 20,
                        endIndent: 20,
                        color: dividerColor,
                      ),
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: 10)),

                    SliverToBoxAdapter(
                      child: sidebarItem(
                        label: 'ranking',

                        leading: ImageIcon(rankingImage, size: 30),
                        content: l10n.ranking,

                        onTap: () {
                          layersManager.pushLayer('ranking');
                        },
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: sidebarItem(
                        label: 'recently',

                        leading: ImageIcon(recentlyImage, size: 30),
                        content: l10n.recently,

                        onTap: () {
                          layersManager.pushLayer('recently');
                        },
                      ),
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: 10)),
                    SliverToBoxAdapter(
                      child: MyDivider(
                        thickness: 0.5,
                        height: 1,
                        indent: 20,
                        endIndent: 20,
                        color: dividerColor,
                      ),
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: 10)),

                    SliverToBoxAdapter(
                      child: ContextMenuWidget(
                        previewBuilder: (context, child) {
                          return Material(
                            color: selectedItemColor.value.withAlpha(255),
                            shape: SmoothRectangleBorder(
                              smoothness: 1,
                              borderRadius: .circular(5),
                            ),
                            clipBehavior: .antiAlias,
                            child: child,
                          );
                        },
                        liftBuilder: (context, child) {
                          return Material(
                            color: selectedItemColor.value.withAlpha(255),
                            shape: SmoothRectangleBorder(
                              smoothness: 1,
                              borderRadius: .circular(5),
                            ),
                            clipBehavior: .antiAlias,
                            child: child,
                          );
                        },
                        child: sidebarItem(
                          label: 'playlists',
                          leading: ImageIcon(playlistsImage, size: 30),
                          content: l10n.playlists,
                          contentPadding: EdgeInsets.fromLTRB(16, 0, 8, 0),

                          trailing: IconButton(
                            onPressed: () {
                              showCreatePlaylistDialog(context);
                            },
                            icon: ImageIcon(addImage, size: 20),
                          ),

                          onTap: () {
                            layersManager.pushLayer('playlists');
                          },
                        ),
                        menuProvider: (_) {
                          if (!isMobile) {
                            return null;
                          }
                          return Menu(
                            children: [
                              MenuAction(
                                title: l10n.reorder,
                                callback: () async {
                                  showAnimationDialog(
                                    context: context,

                                    child: OrientationBuilder(
                                      builder: (context, orientation) {
                                        final size = MediaQuery.of(
                                          context,
                                        ).size;
                                        final shortSide = size.shortestSide;

                                        bool isPhone = shortSide < 600;
                                        return SizedBox(
                                          height: max(350, size.height * 0.7),
                                          width: isPhone ? 300 : 400,
                                          child: Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              10,
                                              10,
                                              10,
                                              0,
                                            ),
                                            child: reorderablePlaylistsView(
                                              context,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: 10)),

                    // keep Favorite at top
                    SliverToBoxAdapter(child: playlistItem(context, 0)),

                    ValueListenableBuilder(
                      valueListenable: playlistManager.updateNotifier,
                      builder: (context, _, _) {
                        return SliverReorderableList(
                          onReorderItem: (oldIndex, newIndex) {
                            final item = playlistManager.playlists.removeAt(
                              oldIndex + 1,
                            );
                            playlistManager.playlists.insert(
                              newIndex + 1,
                              item,
                            );
                            playlistManager.update();
                          },
                          itemCount: playlistManager.playlists.length - 1,
                          itemBuilder: (_, index) {
                            return ReorderableDragStartListener(
                              enabled: !isMobile,
                              index: index,
                              key: ValueKey(index),
                              child: playlistItem(context, index + 1),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            if (isMobile &&
                MediaQuery.of(context).orientation != .landscape) ...[
              sidebarItem(
                label: 'settings',
                leading: ImageIcon(settingImage, size: 30),
                content: l10n.settings,
                onTap: () {
                  layersManager.pushLayer('settings');
                },
              ),
              SizedBox(height: 40),
            ],
          ],
        ),
      ),
    );
  }

  Widget playlistItem(BuildContext context, int index) {
    final l10n = AppLocalizations.of(context);
    final playlist = playlistManager.getPlaylistByIndex(index);

    return ListenableBuilder(
      listenable: Listenable.merge([
        iconColor.valueNotifier,
        textColor.valueNotifier,
        selectedItemColor.valueNotifier,
        dividerColor.valueNotifier,
        menuColor.valueNotifier,
      ]),
      builder: (context, child) {
        return ContextMenuWidget(
          desktopMenuWidgetBuilder: CustomDesktopMenuWidgetBuilder(
            backgroundBaseColor: backgroundCoverArtColor,
            backgroundColor: colorManager.getSpecificMenuColor(),
            iconColor: iconColor.value,
            textColor: textColor.value,
            selectedColor: selectedItemColor.value,
            dividerColor: dividerColor.value,
          ),
          previewBuilder: (context, child) {
            return Material(
              color: selectedItemColor.value.withAlpha(255),
              shape: SmoothRectangleBorder(
                smoothness: 1,
                borderRadius: .circular(5),
              ),
              clipBehavior: .antiAlias,
              child: child,
            );
          },
          liftBuilder: (context, child) {
            return Material(
              color: selectedItemColor.value.withAlpha(255),
              shape: SmoothRectangleBorder(
                smoothness: 1,
                borderRadius: .circular(5),
              ),
              clipBehavior: .antiAlias,
              child: child,
            );
          },
          child: child!,
          menuProvider: (_) {
            return Menu(
              children: [
                MenuAction(
                  title: index == 0 ? l10n.favorites : playlist.name,
                  callback: () {},
                ),

                if (playlist.isNotFavorite) MenuSeparator(),
                if (playlist.isNotFavorite)
                  MenuAction(
                    title: l10n.delete,
                    image: MenuImage.icon(Icons.delete),
                    callback: () async {
                      if (await showConfirmDialog(context, l10n.delete)) {
                        if (closeDrawer != null) {
                          closeDrawer!.call();
                          await Future.delayed(Duration(milliseconds: 250));
                        }
                        layersManager.removeLayer(playlist);
                        playlistManager.deletePlaylist(playlist);
                      }
                    },
                  ),
              ],
            );
          },
        );
      },
      child: sidebarItem(
        label: '_${playlist.name}',
        leading: ValueListenableBuilder(
          valueListenable: playlist.songListManager.changeNotifier,
          builder: (_, _, _) {
            final coverSong = playlist.getCoverSong();
            if (coverSong == null) {
              return CoverArtWidget(size: 30, borderRadius: 3, song: null);
            }
            return ValueListenableBuilder(
              valueListenable: coverSong.updateNotifier,
              builder: (_, _, _) {
                return CoverArtWidget(
                  size: 30,
                  borderRadius: 3,
                  song: coverSong,
                );
              },
            );
          },
        ),
        content: index == 0 ? l10n.favorites : playlist.name,

        onTap: () {
          layersManager.pushLayer('_${playlist.name}');
        },
      ),
    );
  }
}
