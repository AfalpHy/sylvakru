import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/widgets/cover_art_widget.dart';
import 'package:sylvakru/landscape_view/bottom_control.dart';
import 'package:sylvakru/landscape_view/sidebar.dart';
import 'package:sylvakru/layer/layers_manager.dart';

const double _backgroundBlurSigma = 16;
const int _backgroundCoverCacheWidth = 160;

class LandscapeView extends StatelessWidget {
  const LandscapeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,

      children: [
        ValueListenableBuilder(
          valueListenable: mainPageThemeNotifier,
          builder: (context, value, child) {
            if (value != .vivid) {
              return SizedBox.shrink();
            }
            return ValueListenableBuilder(
              valueListenable: layersManager.backgroundChangeNotifier,
              builder: (context, value, child) {
                return RepaintBoundary(
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(
                      sigmaX: _backgroundBlurSigma,
                      sigmaY: _backgroundBlurSigma,
                    ),
                    child: CoverArtWidget(
                      song: backgroundSong,
                      color: colorManager.getSpecificBgBaseColor(),
                      cacheWidth: _backgroundCoverCacheWidth,
                      filterQuality: FilterQuality.low,
                    ),
                  ),
                );
              },
            );
          },
        ),
        ValueListenableBuilder(
          valueListenable: mainPageThemeNotifier,
          builder: (context, value, child) {
            if (value != .vivid) {
              return SizedBox.shrink();
            }

            return ValueListenableBuilder(
              valueListenable: layersManager.backgroundChangeNotifier,
              builder: (context, value, child) {
                return AnimatedContainer(
                  duration: Duration(milliseconds: 500),
                  curve: Curves.easeInOutCubic,
                  color: backgroundCoverArtColor.withAlpha(180),
                );
              },
            );
          },
        ),
        Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Sidebar(),

                  Expanded(
                    child: ValueListenableBuilder(
                      valueListenable: panelColor.valueNotifier,
                      builder: (context, value, child) {
                        return Material(color: value, child: child);
                      },
                      child: ValueListenableBuilder(
                        valueListenable: layersManager.switchNotifier,
                        builder: (context, value, child) {
                          return Stack(
                            children: layersManager.rootLayerMap.values.map((
                              layer,
                            ) {
                              return Visibility(
                                visible: layer == layersManager.topRootLayer,
                                maintainState: true,
                                child: layer,
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            BottomControl(),
          ],
        ),
      ],
    );
  }
}
