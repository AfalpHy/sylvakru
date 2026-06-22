part of '../../layer/font_picker_layer.dart';

extension _FontPickerPanel on _FontPickerLayerState {
  Widget panelView(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        TitleBar(
          hintText: l10n.searchFonts,
          textController: textController,
          backToRoot: () {
            layersManager.popDetail('settings');
          },
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
              return panelContent(context, fonts);
            },
          ),
        ),
      ],
    );
  }

  Widget panelContent(BuildContext context, List<String> fonts) {
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

              trailing: LayoutBuilder(
                builder: (context, constraints) {
                  // avoid triggering assertion
                  if (constraints.maxWidth < 325) {
                    return SizedBox();
                  }
                  return SizedBox(
                    width: 325,
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
                  );
                },
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
                      rebuild();
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
