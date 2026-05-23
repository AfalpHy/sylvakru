import 'package:flutter/material.dart';
import 'package:sylvakru/landscape_view/title_bar.dart';
import 'package:sylvakru/base/widgets/settings_list.dart';

class SettingsPanel extends StatefulWidget {
  const SettingsPanel({super.key});

  @override
  State<StatefulWidget> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TitleBar(),
        Expanded(child: SettingsList()),
      ],
    );
  }
}
