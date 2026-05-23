import 'package:flutter/material.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/landscape_view/panels/font_picker_panel.dart';
import 'package:sylvakru/portrait_view/pages/font_picker_page.dart';

class FontPickerLayer extends StatelessWidget {
  const FontPickerLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (isMobile && orientation == Orientation.portrait) {
          return FontPickerPage();
        } else {
          return FontPickerPanel();
        }
      },
    );
  }
}
