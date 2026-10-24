part of '../../layer/home_layer.dart';

extension HomePage on HomeLayerState {
  Widget pageView(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return myScaffold(
      context: context,
      body: content(context),
      title: l10n.home,
      actions: [
        MySearchField(hintText: l10n.searchHome, textController: textController),
      ],
    );
  }
}
