import 'package:flutter/material.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/landscape_view/panels/folders_panel.dart';
import 'package:sylvakru/portrait_view/pages/folders_page.dart';

class FoldersLayer extends StatelessWidget {
  const FoldersLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (isMobile && orientation == Orientation.portrait) {
          return FoldersPage();
        } else {
          return FoldersPanel();
        }
      },
    );
  }
}
