import 'package:flutter/material.dart';
import 'package:particle_music/base/app.dart';
import 'package:particle_music/base/data/setting.dart';
import 'package:particle_music/base/services/color_manager.dart';
import 'package:particle_music/base/services/interaction.dart';
import 'package:particle_music/base/widgets/font_picker_base.dart';
import 'package:particle_music/base/widgets/my_divider.dart';
import 'package:particle_music/base/widgets/my_sheet.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/portrait_view/custom_appbar_leading.dart';
import 'package:particle_music/portrait_view/my_search_field.dart';

class FontPickerPage extends FontPickerBase {
  const FontPickerPage({super.key});

  @override
  State<StatefulWidget> createState() => _FontPickerPageState();
}

class _FontPickerPageState extends FontPickerBaseState {
  final ValueNotifier<bool> isSearchNotifier = ValueNotifier(false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          customAppBar(context),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: fontsNotifier,
              builder: (context, fonts, child) {
                return _content(fonts);
              },
            ),
          ),

          SizedBox(height: 50),
        ],
      ),
    );
  }

  PreferredSizeWidget customAppBar(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      leading: customAppBarLeading(context),
      backgroundColor: Colors.transparent,
      scrolledUnderElevation: 0,
      actions: [
        MySearchField(
          hintText: AppLocalizations.of(context).searchFonts,
          textController: textController,
          isSearchNotifier: isSearchNotifier,
        ),

        moreButton(context),
      ],
    );
  }

  Widget moreButton(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.more_vert),
      onPressed: () {
        tryVibrate();

        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useRootNavigator: true,
          builder: (context) {
            return moreSheet(context);
          },
        );
      },
    );
  }

  Widget moreSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return MySheet(
      Column(
        children: [
          ListTile(title: Text(l10n.settings)),
          MyDivider(thickness: 0.5, height: 1, color: dividerColor),

          ListTile(
            title: Text(
              l10n.restoreDefault,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onTap: restoreDefaultAction,
          ),

          ListTile(
            title: Text(
              l10n.addFont,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onTap: () => addFontAction(context),
          ),

          ListTile(
            title: Text(
              l10n.deleteFont,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onTap: () => deleteFontAction(context),
          ),
        ],
      ),
    );
  }

  Widget _content(List<String> fonts) {
    final l10n = AppLocalizations.of(context);

    return ListView.builder(
      itemCount: fonts.length + 1,
      padding: .zero,
      itemBuilder: (context, index) {
        String? font;
        late String title;
        if (index == 0) {
          title =
              "${l10n.currentFont}: ${fontFamilyNotifier.value ?? l10n.defaultText}";
          font = fontFamilyNotifier.value;
        } else {
          font = fonts[index - 1];
          title = font;
        }

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),

          title: oneFontPreview(title, font),
          onTap: index > 0
              ? () async {
                  if (await showConfirmDialog(context, l10n.setFont)) {
                    fontFamilyNotifier.value = font;
                    setting.save();
                  }
                }
              : null,
        );
      },
    );
  }

  Widget oneFontPreview(String title, String? font) {
    return Column(
      children: [
        Text(title, style: TextStyle(fontFamily: font, fontSize: 16)),

        const SizedBox(height: 6),

        Text(
          previewText,
          style: TextStyle(
            fontFamily: font,
            fontWeight: FontWeight.w300,
            fontSize: 24,
          ),
        ),

        Text(
          previewText,
          style: TextStyle(
            fontFamily: font,
            fontWeight: FontWeight.normal,
            fontSize: 24,
          ),
        ),

        Text(
          previewText,
          style: TextStyle(
            fontFamily: font,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ],
    );
  }
}
