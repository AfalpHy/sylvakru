import 'package:flutter/material.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/landscape_view/panels/ranking_panel.dart';
import 'package:sylvakru/portrait_view/pages/ranking_page.dart';

class RankingLayer extends StatelessWidget {
  const RankingLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (isMobile && orientation == Orientation.portrait) {
          return RankingPage();
        } else {
          return RankingPanel();
        }
      },
    );
  }
}
