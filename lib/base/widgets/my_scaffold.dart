import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/portrait_view/custom_appbar_leading.dart';

Widget myScaffold({
  required BuildContext context,
  required Widget body,
  String label = '',
  String? title,
  List<Widget>? actions,
}) {
  return Scaffold(
    backgroundColor: Colors.transparent,
    resizeToAvoidBottomInset: false,
    appBar: AppBar(
      automaticallyImplyLeading: false,
      leading: customAppBarLeading(context, label: label),
      backgroundColor: Colors.transparent,
      systemOverlayStyle: mainPageThemeNotifier.value == .dark ? .light : .dark,
      elevation: 0,
      title: title != null ? Text(title, style: .new()) : null,
      scrolledUnderElevation: 0,
      centerTitle: true,
      actions: actions,
    ),
    body: body,
  );
}
