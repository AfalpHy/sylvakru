import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/base/services/keyboard.dart';
import 'package:sylvakru/landscape_view/landscape_view.dart';
import 'package:sylvakru/landscape_view/pages/landscape_lyrics_page.dart';
import 'package:sylvakru/landscape_view/sidebar.dart';
import 'package:sylvakru/layer/layers_manager.dart';
import 'package:sylvakru/layer/lyrics_page_layer.dart';
import 'package:sylvakru/mini_view/mini_view.dart';
import 'package:sylvakru/portrait_view/portrait_view.dart';

class ViewEntry extends StatefulWidget {
  const ViewEntry({super.key});

  @override
  State<StatefulWidget> createState() => _ViewEntryState();
}

class _ViewEntryState extends State<ViewEntry> with WidgetsBindingObserver {
  bool systemCanPop = false;
  Timer? _exitTimer;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      WidgetsBinding.instance.addObserver(this);
    }
    if (isTV) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        songsFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    if (Platform.isAndroid) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (Platform.isAndroid && state == AppLifecycleState.resumed) {
      systemCanPop = false;
      _exitTimer?.cancel();
      // rebuild PopScope to allow it to handle pop
      setState(() {
        if (isTV) {
          if (displayLyricsPage) {
            playControlScopeNode.requestFocus();
          } else {
            songsFocusNode.requestFocus();
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isAndroid) {
      return PopScope(
        key: UniqueKey(),
        canPop: false,
        onPopInvokedWithResult: (bool didPop, dynamic result) {
          if (didPop || isTyping) return;

          if (isDrawerOpen) {
            portraitKey.currentState?.closeDrawer();
            return;
          }

          if (layersManager.layerHistory.length > 1) {
            layersManager.popLayer();
            return;
          }
          if (!systemCanPop) {
            systemCanPop = true;
            showCenterMessage(
              context,
              AppLocalizations.of(context).tapAgain,
              duration: 1500,
            );
            _exitTimer?.cancel();
            _exitTimer = Timer(const Duration(seconds: 2), () {
              systemCanPop = false;
            });
          } else {
            SystemNavigator.pop();
          }
        },
        child: content(),
      );
    }
    return content();
  }

  Widget content() {
    return ValueListenableBuilder(
      valueListenable: miniModeNotifier,
      builder: (context, miniMode, child) {
        if (miniMode) {
          return MiniView();
        }
        return OrientationBuilder(
          builder: (context, orientation) {
            if (isMobile && orientation == Orientation.portrait) {
              SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
              return PortraitView();
            } else {
              SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
              return LandscapeView();
            }
          },
        );
      },
    );
  }
}
