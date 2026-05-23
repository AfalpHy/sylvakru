import 'package:flutter/material.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/landscape_view/panels/settings_panel.dart';
import 'package:sylvakru/portrait_view/pages/settings_page.dart';

class SettingsLayer extends StatelessWidget {
  const SettingsLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (isMobile && orientation == Orientation.portrait) {
          return SettingsPage();
        } else {
          return SettingsPanel();
        }
      },
    );
  }
}
