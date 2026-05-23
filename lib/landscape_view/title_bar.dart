import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/asset_images.dart';
import 'package:sylvakru/base/services/keyboard.dart';
import 'package:sylvakru/base/services/my_window_listener.dart';
import 'package:sylvakru/layer/layers_manager.dart';
import 'package:sylvakru/layer/lyrics_page_layer.dart';
import 'package:sylvakru/mini_view/mini_view.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'package:window_manager/window_manager.dart';

class TitleBar extends StatefulWidget {
  final bool isMainPage;

  final String? hintText;
  final TextEditingController? textController;
  final Function()? scrollToTop;
  final Function()? findLocation;

  const TitleBar({
    super.key,
    this.isMainPage = true,
    this.hintText,
    this.textController,
    this.scrollToTop,
    this.findLocation,
  });

  @override
  State<StatefulWidget> createState() => _TitleBarState();
}

class _TitleBarState extends State<TitleBar> {
  final displayCancelNotifier = ValueNotifier(false);
  final backNode = FocusNode();
  final inkwellNode = FocusNode();
  final searchFieldNode = FocusNode();
  final scrollToTopNode = FocusNode();
  final findLocationNode = FocusNode();
  final settingNode = FocusNode();
  final List<FocusNode> nodeList = [];

  void displayCancelOrNot() {
    if (widget.textController!.text != '') {
      displayCancelNotifier.value = true;
    } else {
      displayCancelNotifier.value = false;
    }
  }

  @override
  void initState() {
    super.initState();
    widget.textController?.addListener(displayCancelOrNot);
    searchFieldNode.addListener(() {
      isTyping = searchFieldNode.hasFocus;
      if (!searchFieldNode.hasFocus) {
        inkwellNode.requestFocus();
      }
    });
    nodeList.add(backNode);
    nodeList.add(inkwellNode);
    nodeList.add(scrollToTopNode);
    nodeList.add(findLocationNode);
    nodeList.add(settingNode);
  }

  @override
  void dispose() {
    displayCancelNotifier.dispose();
    widget.textController?.removeListener(displayCancelOrNot);
    for (final node in nodeList) {
      node.dispose();
    }
    searchFieldNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 75,
      child: Stack(
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
              if (isFullScreenNotifier.value) {
                return;
              }
              isMaximizedNotifier.value
                  ? windowManager.unmaximize()
                  : windowManager.maximize();
            },
            child: Container(),
          ),

          Center(
            child: Focus(
              canRequestFocus: false,
              onKeyEvent: (node, event) {
                if (!isTV) {
                  return .ignored;
                }
                if (event is KeyDownEvent) {
                  if (inkwellNode.hasFocus) {
                    if (event.logicalKey == .select ||
                        event.logicalKey == .enter) {
                      searchFieldNode.unfocus();
                      Future.delayed(Duration(milliseconds: 100), () {
                        searchFieldNode.requestFocus();
                      });
                      return .handled;
                    } else if (event.logicalKey == .goBack &&
                        searchFieldNode.hasFocus) {
                      // ensure isTyping is true when onPopInvokedWithResult is invoked
                      Future.delayed(Duration(milliseconds: 200), () {
                        searchFieldNode.unfocus();
                      });
                      return .handled;
                    } else if (searchFieldNode.hasFocus) {
                      return .ignored;
                    }
                  }
                  int index = -1;
                  for (int i = 0; i < nodeList.length; i++) {
                    if (nodeList[i].hasFocus) {
                      index = i;
                    }
                  }
                  if (index == -1) {
                    return .ignored;
                  }
                  if (event.logicalKey == .arrowLeft) {
                    for (int i = index - 1; i >= 0; i--) {
                      if (nodeList[i].context != null) {
                        nodeList[i].requestFocus();
                        return .handled;
                      }
                    }
                  } else if (event.logicalKey == .arrowRight) {
                    for (int i = index + 1; i < nodeList.length; i++) {
                      if (nodeList[i].context != null) {
                        nodeList[i].requestFocus();
                        return .handled;
                      }
                    }
                  }
                }
                return .ignored;
              },
              child: content(),
            ),
          ),
        ],
      ),
    );
  }

  Widget content() {
    return Row(
      children: [
        SizedBox(width: 30),

        if (widget.isMainPage)
          IconButton(
            focusNode: backNode,
            onPressed: () {
              layersManager.popLayer();
            },
            icon: Icon(Icons.arrow_back_ios_rounded, size: 20),
          )
        else
          ValueListenableBuilder(
            valueListenable: isFullScreenNotifier,
            builder: (context, isFullScreen, child) {
              return isFullScreen | isMobile
                  ? SizedBox.shrink()
                  : ValueListenableBuilder(
                      valueListenable: lyricsPageForegroundColor.valueNotifier,
                      builder: (context, value, child) {
                        return IconButton(
                          color: value,
                          onPressed: () {
                            displayLyricsPage = false;
                            Navigator.pop(context);
                          },
                          icon: ImageIcon(arrowDownImage),
                        );
                      },
                    );
            },
          ),
        if (widget.isMainPage) SizedBox(width: 10),

        if (widget.hintText != null) SizedBox(child: searchField()),

        if (!widget.isMainPage && !isMobile && !isMaximizedNotifier.value)
          ValueListenableBuilder(
            valueListenable: lyricsPageForegroundColor.valueNotifier,
            builder: (context, value, child) {
              return IconButton(
                color: value,
                onPressed: () async {
                  if (isFullScreenNotifier.value) {
                    await windowManager.setFullScreen(false);
                    isFullScreenNotifier.value = false;
                  } else {
                    await windowManager.setFullScreen(true);
                    isFullScreenNotifier.value = true;
                  }
                },
                icon: ValueListenableBuilder(
                  valueListenable: isFullScreenNotifier,
                  builder: (context, isFullScreen, child) {
                    return ImageIcon(
                      isFullScreen ? fullscreenExitImage : fullscreenImage,
                    );
                  },
                ),
              );
            },
          ),

        Spacer(),

        if (widget.scrollToTop != null)
          IconButton(
            focusNode: scrollToTopNode,
            onPressed: widget.scrollToTop,
            icon: ImageIcon(topArrowImage),
          ),

        if (widget.findLocation != null)
          IconButton(
            focusNode: findLocationNode,
            onPressed: widget.findLocation,
            icon: ImageIcon(locationImage),
          ),

        if (widget.isMainPage)
          IconButton(
            focusNode: settingNode,
            onPressed: () {
              layersManager.pushLayer('settings');
            },
            icon: ImageIcon(settingImage),
          ),

        if (!isMobile) windowControls(),

        SizedBox(width: isMobile ? 10 : 30),
      ],
    );
  }

  Widget searchField() {
    return SizedBox(
      width: 260,
      height: 40,
      child: ListenableBuilder(
        listenable: Listenable.merge([
          iconColor.valueNotifier,
          textColor.valueNotifier,
          searchFieldColor.valueNotifier,
        ]),
        builder: (context, _) {
          return Material(
            color: Colors.transparent,
            shape: SmoothRectangleBorder(
              smoothness: 1,
              borderRadius: .circular(10),
            ),
            clipBehavior: .antiAlias,
            child: AnimatedContainer(
              duration: Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              color: searchFieldColor.value,
              child: InkWell(
                focusNode: inkwellNode,
                onTap: isTV ? () {} : null,
                child: TextField(
                  focusNode: searchFieldNode,
                  controller: widget.textController,
                  style: TextStyle(fontSize: 14, color: textColor.value),
                  onTapOutside: (event) {
                    searchFieldNode.unfocus();
                  },
                  decoration: InputDecoration(
                    hint: Text(
                      widget.hintText!,
                      style: TextStyle(fontSize: 14, color: textColor.value),
                    ),
                    contentPadding: EdgeInsets.zero,
                    prefixIcon: Icon(Icons.search, color: iconColor.value),
                    suffixIcon: ValueListenableBuilder(
                      valueListenable: displayCancelNotifier,
                      builder: (context, value, child) {
                        return value
                            ? IconButton(
                                onPressed: () {
                                  widget.textController!.clear();
                                },
                                icon: Icon(
                                  Icons.close,
                                  size: 20,
                                  color: iconColor.value,
                                ),
                              )
                            : SizedBox.shrink();
                      },
                    ),
                    hoverColor: Colors.transparent,
                    border: OutlineInputBorder(borderSide: BorderSide.none),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget windowControls() {
    return ValueListenableBuilder(
      valueListenable: isFullScreenNotifier,
      builder: (context, isFullScreen, child) {
        if (isFullScreen) {
          return SizedBox.shrink();
        }
        return ListenableBuilder(
          listenable: Listenable.merge([
            iconColor.valueNotifier,
            lyricsPageForegroundColor.valueNotifier,
          ]),
          builder: (context, _) {
            return Row(
              children: [
                if (widget.isMainPage)
                  IconButton(
                    color: widget.isMainPage
                        ? iconColor.value
                        : lyricsPageForegroundColor.value,
                    onPressed: () async {
                      await windowManager.hide();
                      miniModeNotifier.value = true;

                      await Future.delayed(Duration(milliseconds: 200));

                      if (Platform.isWindows) {
                        await windowManager.setMinimumSize(
                          Size(325 + 16, 150 + 9),
                        );
                        await windowManager.setMaximumSize(
                          Size(600 + 16, 950 + 9),
                        );
                        await windowManager.setSize(Size(325 + 16, 325 + 9));
                      } else {
                        await windowManager.setMinimumSize(Size(325, 150));
                        await windowManager.setMaximumSize(Size(600, 950));
                        await windowManager.setSize(Size(325, 325));
                      }
                      await windowManager.show();
                    },
                    icon: ImageIcon(miniModeImage),
                  ),
                IconButton(
                  color: widget.isMainPage
                      ? iconColor.value
                      : lyricsPageForegroundColor.value,
                  onPressed: () {
                    windowManager.minimize();
                  },
                  icon: ImageIcon(minimizeImage),
                ),
                ValueListenableBuilder(
                  valueListenable: isMaximizedNotifier,
                  builder: (context, value, child) {
                    return IconButton(
                      color: widget.isMainPage
                          ? iconColor.value
                          : lyricsPageForegroundColor.value,
                      onPressed: () async {
                        isMaximizedNotifier.value
                            ? windowManager.unmaximize()
                            : windowManager.maximize();
                      },
                      icon: ImageIcon(value ? unmaximizeImage : maximizeImage),
                    );
                  },
                ),
                IconButton(
                  color: widget.isMainPage
                      ? iconColor.value
                      : lyricsPageForegroundColor.value,
                  onPressed: () {
                    windowManager.close();
                  },
                  icon: ImageIcon(closeImage),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
