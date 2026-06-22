part of '../../layer/playlists_layer.dart';

extension _PlaylistsPanel on _PlaylistsLayerState {
  Widget panelView(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        TitleBar(
          hintText: l10n.searchPlaylists,
          textController: textController,
        ),
        Expanded(child: contentWidget(context)),
      ],
    );
  }

  Widget contentWidget(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: ListTile(
                    leading: ValueListenableBuilder(
                      valueListenable: iconColor.valueNotifier,
                      builder: (_, value, _) {
                        return ImageIcon(
                          playlistsImage,
                          size: 50,
                          color: value,
                        );
                      },
                    ),
                    title: Text(
                      l10n.playlists,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: ValueListenableBuilder(
                      valueListenable: playlistsNotifier,
                      builder: (context, playlists, child) {
                        return Text(
                          l10n.playlistCount(playlists.length),
                          style: TextStyle(fontSize: 12),
                        );
                      },
                    ),
                    trailing: SizedBox(
                      width: 120,
                      child: Column(
                        children: [
                          SizedBox(height: 20),
                          Row(
                            children: [
                              Spacer(),
                              MySwitch(
                                trueText: l10n.large,
                                falseText: l10n.small,
                                valueNotifier:
                                    playlistManager.useLargePictureNotifier,
                                onToggleCallBack: () => setting.save(),
                              ),
                              SizedBox(width: 10),
                            ],
                          ),
                        ],
                      ),
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

              grid(),
            ],
          ),
        ),
      ],
    );
  }

  Widget grid() {
    final panelWidth = (MediaQuery.widthOf(context) - 300);
    final l10n = AppLocalizations.of(context);

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 40),

      sliver: ValueListenableBuilder(
        valueListenable: playlistManager.useLargePictureNotifier,
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
            valueListenable: playlistsNotifier,
            builder: (context, playlists, child) {
              return SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: 1.05,
                ),
                itemCount: playlists.length,
                itemBuilder: (context, index) {
                  final playlist = playlists[index];
                  return ValueListenableBuilder(
                    valueListenable: playlist.songListManager.changeNotifier,
                    builder: (context, _, child) {
                      final coverSong = playlist.getCoverSong();

                      return Column(
                        children: [
                          InkWell(
                            mouseCursor: SystemMouseCursors.click,
                            focusColor: Colors.transparent,
                            splashColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            highlightColor: Colors.transparent,

                            child: ListenableBuilder(
                              listenable: Listenable.merge([
                                coverSong?.updateNotifier,
                              ]),
                              builder: (_, _) {
                                return Hero(
                                  tag:
                                      (coverSong == null
                                          ? playlist
                                                .songListManager
                                                .sourceTypeName
                                          : coverSong.id) +
                                      playlist.name,
                                  curve: Curves.easeInOutCubic,
                                  flightShuttleBuilder:
                                      (
                                        flightContext,
                                        animation,
                                        flightDirection,
                                        fromHeroContext,
                                        toHeroContext,
                                      ) => FittedBox(
                                        child: toHeroContext.widget,
                                      ),
                                  child: CoverArtWidget(
                                    size: coverArtWidth,
                                    borderRadius: coverArtWidth / 10,
                                    song: coverSong,
                                  ),
                                );
                              },
                            ),
                            onTap: () {
                              layersManager.pushDetail('playlists', playlist);
                            },
                          ),
                          SizedBox(
                            width: coverArtWidth - 5,
                            child: Center(
                              child: Text(
                                playlist == playlistManager.playlists[0]
                                    ? l10n.favorites
                                    : playlist.name,
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
          );
        },
      ),
    );
  }
}
