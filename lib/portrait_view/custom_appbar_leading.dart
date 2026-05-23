import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sylvakru/layer/layers_manager.dart';
import 'package:sylvakru/portrait_view/portrait_view.dart';

Widget customAppBarLeading(BuildContext context) {
  return IconButton(
    icon: Icon(
      Platform.isAndroid ? Icons.menu : Icons.arrow_back_ios_new_rounded,
    ),
    onPressed: () => Platform.isAndroid
        ? portraitKey.currentState?.openDrawer()
        : layersManager.popLayer(),
  );
}
