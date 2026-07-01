import 'package:flutter/material.dart';
import 'package:sylvakru/base/utils/media_query.dart';
import 'package:sylvakru/landscape_view/pages/landscape_lyrics_page.dart';
import 'package:sylvakru/portrait_view/pages/portrait_lyrics_page.dart';

bool displayLyricsPage = false;

class LyricsPageLayer extends StatefulWidget {
  const LyricsPageLayer({super.key});

  @override
  State<StatefulWidget> createState() => _LyricsPageLayerState();
}

class _LyricsPageLayerState extends State<LyricsPageLayer> {
  @override
  void initState() {
    super.initState();
    displayLyricsPage = true;
  }

  @override
  void dispose() {
    displayLyricsPage = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isTooNarrow(context)) {
      return PortraitLyricsPage();
    }
    return LandscapeLyricsPage();
  }
}
