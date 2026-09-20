part of '../../layer/about_layer.dart';

extension _AboutPage on _AboutLayerState {
  Widget pageView(BuildContext context) {
    return myScaffold(
      context: context,
      body: content(),
      label: 'settings',
      title: AppLocalizations.of(context).about,
    );
  }
}
