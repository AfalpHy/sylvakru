part of '../../layer/home_layer.dart';

extension HomePage on HomeLayer {
  Widget pageView(BuildContext context) {
    return myScaffold(
      context: context,
      body: content(context),
      title: AppLocalizations.of(context).home,
    );
  }
}
