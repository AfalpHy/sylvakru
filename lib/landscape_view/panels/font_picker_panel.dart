import 'package:flutter/material.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/asset_images.dart';
import 'package:sylvakru/base/data/setting.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/base/widgets/font_picker_base.dart';
import 'package:sylvakru/base/widgets/my_divider.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/landscape_view/title_bar.dart';
import 'package:smooth_corner/smooth_corner.dart';

class FontPickerPanel extends FontPickerBase {
  const FontPickerPanel({super.key});

  @override
  State<StatefulWidget> createState() => _FontPickerPanelState();
}

class _FontPickerPanelState extends FontPickerBaseState {
  final ScrollController scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        TitleBar(
          hintText: l10n.searchFonts,
          textController: textController,
          scrollToTop: () {
            scrollController.animateTo(
              0,
              duration: Duration(milliseconds: 250),
              curve: Curves.linear,
            );
          },
        ),
        Expanded(
          child: ValueListenableBuilder(
            valueListenable: fontsNotifier,
            builder: (context, fonts, child) {
              return _content(context, fonts);
            },
          ),
        ),
      ],
    );
  }

  Widget _content(BuildContext context, List<String> fonts) {
    final l10n = AppLocalizations.of(context);

    return CustomScrollView(
      controller: scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: ListTile(
              leading: ImageIcon(fontImage, size: 50),
              title: Text(
                l10n.fonts,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                l10n.fontCount(fonts.length),
                style: TextStyle(fontSize: 12),
              ),

              trailing: SizedBox(
                width: 320,
                child: ValueListenableBuilder(
                  valueListenable: buttonColor.valueNotifier,

                  builder: (context, value, child) {
                    final l10n = AppLocalizations.of(context);
                    final buttonStyle = ElevatedButton.styleFrom(
                      backgroundColor: value,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.all(10),
                    );
                    return Row(
                      mainAxisAlignment: .end,
                      children: [
                        ElevatedButton(
                          onPressed: restoreDefaultAction,
                          style: buttonStyle,
                          child: Text(l10n.restoreDefault),
                        ),
                        SizedBox(width: 5),

                        ElevatedButton(
                          onPressed: () => addFontAction(context),
                          style: buttonStyle,

                          child: Text(l10n.addFont),
                        ),

                        SizedBox(width: 5),

                        ElevatedButton(
                          onPressed: () => deleteFontAction(context),
                          style: buttonStyle,
                          child: Text(l10n.deleteFont),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: MyDivider(
            thickness: 0.5,
            height: 0.5,
            indent: 30,
            endIndent: 30,
            color: dividerColor,
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: 15)),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: oneFontPreview(
              '${l10n.currentFont}:${fontFamilyNotifier.value ?? l10n.defaultText}',
              fontFamilyNotifier.value,
            ),
          ),
        ),

        SliverToBoxAdapter(child: SizedBox(height: 15)),

        SliverList.builder(
          itemBuilder: (context, index) {
            final font = fonts[index];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Material(
                color: Colors.transparent,
                shape: SmoothRectangleBorder(
                  smoothness: 1,
                  borderRadius: .all(.circular(15)),
                ),
                clipBehavior: .antiAlias,
                child: ListTile(
                  contentPadding: .zero,
                  title: oneFontPreview(font, font),

                  onTap: () async {
                    if (await showConfirmDialog(context, l10n.setFont)) {
                      await Future.delayed(Duration(milliseconds: 250));
                      fontFamilyNotifier.value = font;
                      setting.save();
                      setState(() {});
                    }
                  },
                ),
              ),
            );
          },
          itemCount: fonts.length,
        ),
      ],
    );
  }

  Widget oneFontPreview(String title, String? font) {
    return Column(
      children: [
        Text(title, style: TextStyle(fontFamily: font, fontSize: 16)),

        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: .center,
          children: [
            Expanded(
              child: Center(
                child: Text(
                  previewText,
                  style: TextStyle(
                    fontFamily: font,
                    fontWeight: FontWeight.w300,
                    fontSize: 24,
                  ),
                ),
              ),
            ),

            Expanded(
              child: Center(
                child: Text(
                  previewText,
                  style: TextStyle(
                    fontFamily: font,
                    fontWeight: FontWeight.normal,
                    fontSize: 24,
                  ),
                ),
              ),
            ),

            Expanded(
              child: Center(
                child: Text(
                  previewText,
                  style: TextStyle(
                    fontFamily: font,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
