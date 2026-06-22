part of "../../layer/artists_layer.dart";

extension _ArtistsPanel on _ArtistsLayerState {
  Widget panelView(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        TitleBar(
          hintText: l10n.searchArtists,
          textController: textController,
          scrollToTop: () {
            scrollController.animateTo(
              0,
              duration: Duration(milliseconds: 250),
              curve: Curves.linear,
            );
          },
        ),
        Expanded(child: contentWidget(context)),
      ],
    );
  }

  Widget contentWidget(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return CustomScrollView(
      controller: scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: ListTile(
              leading: ValueListenableBuilder(
                valueListenable: iconColor.valueNotifier,
                builder: (context, value, child) {
                  return ImageIcon(artistImage, size: 50, color: value);
                },
              ),
              title: Text(
                l10n.artists,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              subtitle: ValueListenableBuilder(
                valueListenable: currentArtistListNotifier,
                builder: (context, list, child) {
                  return Text(
                    l10n.artistCount(list.length),
                    style: TextStyle(fontSize: 12),
                  );
                },
              ),
              trailing: LayoutBuilder(
                builder: (context, constraints) {
                  // avoid triggering assertion
                  if (constraints.maxWidth < 325) {
                    return SizedBox();
                  }
                  return SizedBox(
                    width: 325,
                    child: Column(
                      children: [
                        SizedBox(height: 20),
                        Row(
                          children: [
                            Spacer(),

                            ValueListenableBuilder(
                              valueListenable: randomizeNotifier,
                              builder: (context, value, child) {
                                if (value) {
                                  return SizedBox.shrink();
                                }
                                return MySwitch(
                                  trueText: l10n.ascending,
                                  falseText: l10n.descending,
                                  valueNotifier: isAscendingNotifier,
                                  onToggleCallBack: () {
                                    setting.save();

                                    artistAlbumManager.sortArtists();

                                    updateCurrentList();
                                  },
                                );
                              },
                            ),

                            SizedBox(width: 5),

                            MySwitch(
                              trueText: l10n.randomize,
                              falseText: l10n.normal,
                              valueNotifier: randomizeNotifier,
                              onToggleCallBack: () {
                                updateCurrentList();
                              },
                            ),

                            SizedBox(width: 5),

                            MySwitch(
                              trueText: l10n.large,
                              falseText: l10n.small,
                              valueNotifier: useLargePictureNotifier,
                              onToggleCallBack: () {
                                setting.save();
                              },
                            ),
                            SizedBox(width: 5),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: MyDivider(
            thickness: 0.5,
            height: 0.5,
            indent: 30,
            endIndent: 30,
            color: dividerColor,
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: 15)),

        panelGridView(),
      ],
    );
  }

  Widget panelGridView() {
    final panelWidth = (MediaQuery.widthOf(context) - 300);

    return ValueListenableBuilder(
      valueListenable: Loader.syncStateNotifier,
      builder: (context, value, child) {
        if (Loader.syncing) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: CircularProgressIndicator(color: iconColor.value),
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 40),

          sliver: ValueListenableBuilder(
            valueListenable: useLargePictureNotifier,
            builder: (context, value, child) {
              int crossAxisCount;
              double coverArtWidth;
              if (value) {
                crossAxisCount = (panelWidth / 240).toInt();
                coverArtWidth = panelWidth / crossAxisCount - 45;
              } else {
                crossAxisCount = (panelWidth / 120).toInt();
                coverArtWidth = panelWidth / crossAxisCount - 35;
              }
              return ValueListenableBuilder(
                valueListenable: currentArtistListNotifier,
                builder: (context, list, child) {
                  return SliverGrid.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: 1.05,
                    ),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      return Column(
                        children: [
                          InkWell(
                            mouseCursor: SystemMouseCursors.click,
                            focusColor: Colors.transparent,
                            splashColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            highlightColor: Colors.transparent,

                            child: ValueListenableBuilder(
                              valueListenable: list[index]
                                  .songListManager
                                  .sourceTypeNotifier,
                              builder: (context, value, child) {
                                final coverSong = list[index].getCoverSong();
                                return ValueListenableBuilder(
                                  valueListenable: coverSong.updateNotifier,
                                  builder: (_, _, _) {
                                    return Hero(
                                      tag: coverSong.id + list[index].name,
                                      child: CoverArtWidget(
                                        size: coverArtWidth,
                                        borderRadius: coverArtWidth / 10,
                                        song: coverSong,
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                            onTap: () {
                              layersManager.pushDetail('artists', list[index]);
                            },
                          ),
                          SizedBox(
                            width: coverArtWidth - 5,
                            child: Center(
                              child: Text(
                                list[index].name,
                                style: TextStyle(
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
