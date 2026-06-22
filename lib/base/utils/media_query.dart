import 'package:flutter/material.dart';

bool isPortrait(BuildContext context) {
  return MediaQuery.orientationOf(context) == .portrait;
}
