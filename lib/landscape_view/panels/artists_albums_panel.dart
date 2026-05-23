import 'package:flutter/material.dart';
import 'package:sylvakru/base/data/artist_album.dart';
import 'package:sylvakru/base/data/loader.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/asset_images.dart';
import 'package:sylvakru/base/widgets/cover_art_widget.dart';
import 'package:sylvakru/base/widgets/my_divider.dart';
import 'package:sylvakru/base/data/setting.dart';
import 'package:sylvakru/landscape_view/title_bar.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/base/widgets/my_switch.dart';
import 'package:sylvakru/layer/layers_manager.dart';

class ArtistsAlbumsPanel extends StatefulWidget {
  final bool isArtist;

  const ArtistsAlbumsPanel({super.key, required this.isArtist});

  @override
  State<StatefulWidget> createState() => _ArtistsAlbumsPanelState();
}

class _ArtistsAlbumsPanelState extends State<ArtistsAlbumsPanel> {
  late bool isArtist;

  late final ValueNotifier<List<ArtistAlbumBase>>
  currentArtistAlbumListNotifier;

  final textController = TextEditingController();

  final ScrollController scrollController = ScrollController();

  late ValueNotifier<bool> randomizeNotifier;
  late ValueNotifier<bool> isAscendingNotifier;
  late ValueNotifier<bool> useLargePictureNotifier;

  void updateCurrentList() {
    final value = textController.text;
    currentArtistAlbumListNotifier.value = artistAlbumManager
        .getArtistAlbumList(isArtist)
        .where((e) => (e.name.toLowerCase().contains(value.toLowerCase())))
        .toList();
    if (randomizeNotifier.value) {
      currentArtistAlbumListNotifier.value.shuffle();
    }
  }

  @override
  void initState() {
    super.initState();
    isArtist = widget.isArtist;
    currentArtistAlbumListNotifier = ValueNotifier(
      artistAlbumManager.getArtistAlbumList(isArtist),
    );

    randomizeNotifier = artistAlbumManager.getIsRandomizeNotifier(isArtist);

    isAscendingNotifier = artistAlbumManager.getIsAscendingNotifier(isArtist);

    useLargePictureNotifier = artistAlbumManager.getUseLargePictureNotifier(
      isArtist,
    );

    updateCurrentList();
    textController.addListener(updateCurrentList);
    artistAlbumManager.updateNotifier.addListener(updateCurrentList);
  }

  @override
  void dispose() {
    textController.dispose();
    artistAlbumManager.updateNotifier.removeListener(updateCurrentList);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        TitleBar(
          hintText: isArtist ? l10n.searchArtists : l10n.searchAlbums,
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
    final panelWidth = (MediaQuery.widthOf(context) - 300);
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
                  return isArtist
                      ? ImageIcon(artistImage, size: 50, color: value)
                      : ImageIcon(albumImage, size: 50, color: value);
                },
              ),
              title: Text(
                isArtist ? l10n.artists : l10n.albums,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              subtitle: ValueListenableBuilder(
                valueListenable: currentArtistAlbumListNotifier,
                builder: (context, list, child) {
                  return Text(
                    isArtist
                        ? l10n.artistCount(list.length)
                        : l10n.albumCount(list.length),
                    style: TextStyle(fontSize: 12),
                  );
                },
              ),
              trailing: SizedBox(
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
                                if (isArtist) {
                                  artistAlbumManager.sortArtists();
                                } else {
                                  artistAlbumManager.sortAlbums();
                                }
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

        ValueListenableBuilder(
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
                    crossAxisCount = (panelWidth / (isTV ? 150 : 240)).toInt();
                    coverArtWidth = panelWidth / crossAxisCount - 45;
                  } else {
                    crossAxisCount = (panelWidth / (isTV ? 100 : 120)).toInt();
                    coverArtWidth = panelWidth / crossAxisCount - 35;
                  }
                  return ValueListenableBuilder(
                    valueListenable: currentArtistAlbumListNotifier,
                    builder: (context, list, child) {
                      return SliverGrid.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: 1.05,
                        ),
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          FocusNode focusNode = FocusNode();
                          return StatefulBuilder(
                            builder: (context, setState) {
                              return AnimatedScale(
                                duration: Duration(milliseconds: 250),
                                curve: Curves.easeOutCubic,
                                scale: focusNode.hasFocus ? 1.1 : 1.0,
                                child: Column(
                                  children: [
                                    InkWell(
                                      focusNode: focusNode,
                                      onFocusChange: (value) {
                                        setState(() {});
                                      },
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
                                          final displaySong = list[index]
                                              .getCoverSong();
                                          return ValueListenableBuilder(
                                            valueListenable:
                                                displaySong.updateNotifier,
                                            builder: (_, _, _) {
                                              return CoverArtWidget(
                                                size: coverArtWidth,
                                                borderRadius:
                                                    coverArtWidth / 10,
                                                song: displaySong,
                                              );
                                            },
                                          );
                                        },
                                      ),
                                      onTap: () {
                                        layersManager.pushLayer(
                                          isArtist ? 'artists' : 'albums',
                                          content: list[index].name,
                                        );
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
                                ),
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
          },
        ),
      ],
    );
  }
}
