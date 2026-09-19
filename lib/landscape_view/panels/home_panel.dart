part of '../../layer/home_layer.dart';

extension HomePanel on HomeLayer {
  Widget panelView(BuildContext context) {
    return Column(
      children: [
        TitleBar(),
        Expanded(child: content(context)),
      ],
    );
  }
}
