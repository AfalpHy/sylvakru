part of '../../base/widgets/song_list.dart';

extension _SongListPage on _SongListState {
  Widget pageView(BuildContext context) {
    return myScaffold(
      context: context,
      body: contentWithStack(),
      label: rootLabel,
      actions: [
        ValueListenableBuilder(
          valueListenable: currentSongListNotifier,
          builder: (context, value, child) {
            return MySearchField(
              key: ValueKey(getFirstSong(songList)),
              hintText: AppLocalizations.of(context).searchSongs,
              textController: textController,
              useCurrentSong: false,
            );
          },
        ),
        moreButton(context),
        SizedBox(width: 10),
      ],
    );
  }

  Widget moreButton(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return GlassMenu(
      trigger: Container(
        color: Colors.transparent,
        width: 40,
        height: 40,
        child: Icon(Icons.more_vert_rounded),
      ),
      settings: LiquidGlassSettings(glassColor: glassColor.value),
      menuWidth: 250,
      items: [
        GlassMenuItem(
          title: l10n.select,
          icon: const ImageIcon(selectImage),
          iconColor: iconColor.value,
          iconSize: 24,
          onTap: () {
            for (var e in isSelectedNotifierMap.values) {
              e.value = false;
            }
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ValueListenableBuilder(
                  valueListenable: currentSongListNotifier,
                  builder: (context, currentSongList, child) {
                    return SelectableSongListPage(
                      songList: currentSongList,
                      playlist: playlist,
                      folder: folder,
                      isFrequently: isFrequently,
                      isRecently: isRecently,
                      isLibrary: isLibrary,
                      reorderable: reorderable,
                      isSelectedNotifierMap: isSelectedNotifierMap,
                    );
                  },
                ),
              ),
            );
          },
        ),

        if (!isFrequently && !isRecently)
          GlassMenuItem(
            title: l10n.sortSongs,
            icon: const ImageIcon(sequenceImage),
            iconColor: iconColor.value,
            iconSize: 24,
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                useRootNavigator: true,
                builder: (context) {
                  List<String> orderText = [
                    l10n.defaultText,
                    l10n.titleAscending,
                    l10n.titleDescending,
                    l10n.artistAscending,
                    l10n.artistDescending,
                    l10n.albumAscending,
                    l10n.albumDescending,
                    l10n.durationAscending,
                    l10n.durationDescending,
                  ];
                  if (isLibrary && (isNotStreamSource) || folder != null) {
                    orderText.add(l10n.modifiedTimeAscending);
                    orderText.add(l10n.modifiedTimedescending);
                    orderText.add(l10n.randomizeTemp);
                    orderText.add(l10n.randomizePermanent);
                  }
                  List<Widget> orderWidget = [];
                  for (int i = 0; i < orderText.length; i++) {
                    String text = orderText[i];
                    orderWidget.add(
                      ValueListenableBuilder(
                        valueListenable: sortTypeNotifier,
                        builder: (context, value, child) {
                          return ListTile(
                            title: Text(text),
                            onTap: () async {
                              if (i == 12) {
                                if (!await showConfirmDialog(
                                  context,
                                  l10n.cannotBeUndone,
                                )) {
                                  return;
                                }
                                sortTypeNotifier.value = 0;
                                if (isLibrary) {
                                  library.shuffle();
                                } else {
                                  folder!.shuffle();
                                }
                              } else {
                                if (i == 11 && sortTypeNotifier.value == 11) {
                                  updateSongList();
                                }
                                sortTypeNotifier.value = i;
                              }
                            },
                            trailing: value == i ? Icon(Icons.check) : null,
                            visualDensity: VisualDensity(
                              horizontal: 0,
                              vertical: -4,
                            ),
                          );
                        },
                      ),
                    );
                  }
                  return MySheet(
                    Column(
                      children: [
                        ListTile(title: Text(l10n.selectSortingType)),
                        MyDivider(
                          thickness: 0.5,
                          height: 1,
                          color: dividerColor,
                        ),

                        Expanded(
                          child: ListView(
                            children: [...orderWidget, SizedBox(height: 50)],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),

        if (playlist != null && playlist!.isNotFavorite)
          GlassMenuItem(
            title: l10n.delete,
            icon: const ImageIcon(deleteImage),
            iconColor: iconColor.value,
            iconSize: 24,
            onTap: () async {
              if (await showConfirmDialog(context, l10n.delete)) {
                layersManager.removeLayerIfNeed(playlist!);
                playlistManager.deletePlaylist(playlist!);
              }
            },
          ),
      ],
    );
  }

  Widget contentWithStack() {
    return Stack(
      children: [
        NotificationListener<UserScrollNotification>(
          onNotification: (notification) {
            if (notification.direction != ScrollDirection.idle) {
              listIsScrollingNotifier.value = true;
              if (timer != null) {
                timer!.cancel();
                timer = null;
              }
            } else {
              if (listIsScrollingNotifier.value) {
                timer ??= Timer(const Duration(milliseconds: 3000), () {
                  listIsScrollingNotifier.value = false;
                  timer = null;
                });
              }
            }
            return false;
          },
          child: pageContent(),
        ),
        Positioned(
          right: 30,
          bottom: 180,
          child: ValueListenableBuilder(
            valueListenable: listIsScrollingNotifier,
            builder: (context, value, child) {
              if (!value) {
                return SizedBox.shrink();
              }
              return IconButton(
                onPressed: () {
                  scrollController.animateTo(
                    0,
                    duration: Duration(milliseconds: 250),
                    curve: Curves.linear,
                  );
                },
                icon: ImageIcon(topArrowImage),
              );
            },
          ),
        ),

        Positioned(
          right: 30,
          bottom: 120,
          child: MyLocation(
            scrollController: scrollController,
            listIsScrollingNotifier: listIsScrollingNotifier,
            currentSongListNotifier: currentSongListNotifier,
            offset: 300 - MediaQuery.heightOf(context) / 2,
          ),
        ),
      ],
    );
  }

  Widget pageHeader() {
    final l10n = AppLocalizations.of(context);
    final size = MediaQuery.of(context).size;
    final shortSide = size.shortestSide;

    bool isPhone = shortSide < 600;

    return Column(
      children: [
        SizedBox(height: 10),
        Row(
          children: [
            SizedBox(width: 20),
            mainCover(isPhone ? 120 : 160),
            Expanded(
              child: ListTile(
                title: AutoSizeText(
                  getTitleText(l10n),
                  maxLines: 1,
                  minFontSize: 20,
                  maxFontSize: 20,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: ValueListenableBuilder(
                  valueListenable: currentSongListNotifier,
                  builder: (context, currentSongList, child) {
                    String prefix = getSourceTypeDisplayName(l10n, sourceType);
                    return Text(
                      "$prefix: ${l10n.songCount(currentSongList.length)}",
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 20),
      ],
    );
  }

  Widget pageContent() {
    return CustomScrollView(
      controller: scrollController,
      slivers: [
        SliverToBoxAdapter(child: pageHeader()),
        ValueListenableBuilder(
          valueListenable: currentSongListNotifier,
          builder: (context, currentSongList, child) {
            if (prepareing) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(color: iconColor.value),
                ),
              );
            }
            return SliverFixedExtentList.builder(
              itemExtent: 60,
              itemCount: currentSongList.length,
              itemBuilder: (context, index) {
                return Center(child: songListTile(index, currentSongList));
              },
            );
          },
        ),
        SliverToBoxAdapter(child: SizedBox(height: 90)),
      ],
    );
  }

  Widget songListTile(int index, List<MyAudioMetadata> currentSongList) {
    final song = currentSongList[index];
    return ValueListenableBuilder(
      valueListenable: song.updateNotifier,
      builder: (context, value, child) {
        return ListTile(
          contentPadding: EdgeInsets.fromLTRB(20, 0, 0, 0),
          leading: CoverArtWidget(
            size: 40,
            borderRadius: 4,
            picture: song.picture,
          ),
          title: ValueListenableBuilder(
            valueListenable: currentSongNotifier,
            builder: (_, currentSong, _) {
              return ValueListenableBuilder(
                valueListenable: highlightTextColor.valueNotifier,
                builder: (context, value, child) {
                  return Text(
                    getTitle(song),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: song == currentSong ? value : null,
                      fontWeight: song == currentSong ? FontWeight.bold : null,
                    ),
                  );
                },
              );
            },
          ),

          subtitle: Row(
            children: [
              ValueListenableBuilder(
                valueListenable: song.isFavoriteNotifier,
                builder: (_, value, _) {
                  return value
                      ? SizedBox(
                          width: 20,
                          child: Icon(
                            Icons.star_rounded,
                            color: Colors.red,
                            size: 15,
                          ),
                        )
                      : SizedBox();
                },
              ),
              Expanded(
                child: Text(
                  "${getArtist(song)} - ${getAlbum(song)}",
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
          onTap: () =>
              audioHandler.setPlayQueue(currentSongList, 0, targetIndex: index),
          trailing: isFrequently && sourceType != .emby
              ? SizedBox(
                  width: 100,
                  child: Row(
                    children: [
                      Spacer(),
                      ImageIcon(playOutlinedImage, size: 15),
                      Text(song.playCount.toString()),
                      songOptionsButton(index, song),
                      SizedBox(width: 10),
                    ],
                  ),
                )
              : SizedBox(
                  width: 60,
                  child: Row(
                    children: [
                      Spacer(),
                      songOptionsButton(index, song),
                      SizedBox(width: 10),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget songOptionsButton(int index, MyAudioMetadata song) {
    final l10n = AppLocalizations.of(context);

    return GlassMenu(
      trigger: Container(
        color: Colors.transparent,
        width: 40,
        height: 40,
        child: Icon(Icons.more_vert_rounded, size: 20),
      ),
      settings: LiquidGlassSettings(glassColor: glassColor.value),
      menuWidth: 250,
      items: [
        if (reorderable)
          GlassMenuItem(
            title: l10n.move2Top,
            icon: const Icon(Icons.vertical_align_top_rounded),
            iconColor: iconColor.value,
            iconSize: 24,
            onTap: () {
              moveToTop(index);
            },
          ),

        GlassMenuItem(
          title: l10n.playNow,
          icon: const Icon(Icons.play_arrow_rounded),
          iconColor: iconColor.value,
          iconSize: 24,

          onTap: () {
            audioHandler.singlePlay(song);
            audioHandler.saveAllStates();
          },
        ),

        GlassMenuItem(
          title: l10n.playNext,
          icon: const Icon(Icons.navigate_next_rounded),
          iconColor: iconColor.value,
          iconSize: 24,
          onTap: () {
            if (playQueue.isEmpty) {
              audioHandler.singlePlay(song);
            } else {
              audioHandler.insert2Next(song);
            }
            audioHandler.saveAllStates();
          },
        ),

        GlassMenuItem(
          title: l10n.add2Queue,
          icon: const Icon(Icons.playlist_add_rounded),
          iconColor: iconColor.value,
          iconSize: 24,
          onTap: () {
            if (playQueue.isEmpty) {
              audioHandler.singlePlay(song);
            } else {
              audioHandler.add2Last(song);
            }
            audioHandler.saveAllStates();
          },
        ),

        GlassMenuItem(
          title: l10n.add2Playlist,
          icon: const Icon(Icons.add_rounded),
          iconColor: iconColor.value,
          iconSize: 24,
          onTap: () {
            showAddPlaylistDialog(context, [song]);
          },
        ),

        if (artist == null)
          GlassMenuItem(
            title: l10n.go2Artist,
            icon: const Icon(Icons.people),
            iconColor: iconColor.value,
            iconSize: 24,
            onTap: () {
              goToArtist(song, context);
            },
          )
        else if (artist!.name != song.artist)
          GlassMenuItem(
            title: l10n.go2Artist,
            icon: const Icon(Icons.people),
            iconColor: iconColor.value,
            iconSize: 24,
            onTap: () {
              goToArtist(song, context, excludedArtist: artist!.name);
            },
          ),

        if (album == null)
          GlassMenuItem(
            title: l10n.go2Album,
            icon: const Icon(Icons.album_rounded),
            iconColor: iconColor.value,
            iconSize: 24,
            onTap: () {
              goToAlbum(song);
            },
          ),

        GlassMenuItem(
          title: l10n.songInfo,
          icon: const Icon(Icons.info_outline_rounded),
          iconColor: iconColor.value,
          iconSize: 24,
          onTap: () {
            showAnimationDialog(
              context: context,
              child: SongInfo(song: song),
            );
          },
        ),

        if (sourceType == .local && artist == null && album == null)
          GlassMenuItem(
            title: l10n.editMetadata,
            icon: const Icon(Icons.edit_rounded),
            iconColor: iconColor.value,
            iconSize: 24,
            onTap: () {
              showAnimationDialog(
                context: context,
                child: EditMetadata(song: song),
              );
            },
          ),
        if (playlist != null)
          GlassMenuItem(
            title: l10n.delete,
            icon: const Icon(Icons.delete_rounded),
            iconColor: iconColor.value,
            iconSize: 24,
            onTap: () async {
              if (await showConfirmDialog(context, l10n.delete)) {
                playlist!.remove([song]);
              }
            },
          ),
      ],
    );
  }
}
