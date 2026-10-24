part of '../../layer/home_layer.dart';

extension HomePanel on HomeLayerState {
  Widget panelView(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        TitleBar(
          hintText: l10n.searchHome,
          textController: textController,
        ),

        Expanded(child: content(context)),
      ],
    );
  }
}
