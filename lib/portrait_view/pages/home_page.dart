part of '../../layer/home_layer.dart';

extension HomePage on HomeLayerState {
  Widget pageView(BuildContext context) {
    return myScaffold(
      context: context,
      body: content(context),
      title: AppLocalizations.of(context).home,
    );
  }
}
