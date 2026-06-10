import 'package:flutter/material.dart';
import 'package:sylvakru/base/widgets/my_navigator.dart';
import 'package:sylvakru/base/widgets/settings_list.dart';
import 'package:sylvakru/landscape_view/title_bar.dart';
import 'package:sylvakru/portrait_view/custom_appbar_leading.dart';

final GlobalKey<NavigatorState> settingsKey = GlobalKey();
final settingsVisibleNotifier = ValueNotifier(true);

class SettingsLayer extends StatelessWidget {
  const SettingsLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return myNavigator(
      key: settingsKey,
      visibleNotifier: settingsVisibleNotifier,
      pageView: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: customAppBarLeading(context),

          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: SettingsList(iconSize: 30),
      ),
      panelView: Column(
        children: [
          TitleBar(),
          Expanded(child: SettingsList()),
        ],
      ),
    );
  }
}
