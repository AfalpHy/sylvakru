part of '../../layer/home_layer.dart';

extension HomePage on HomeLayer {
  Widget pageView(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: customAppBarLeading(context),
        backgroundColor: Colors.transparent,
        systemOverlayStyle: mainPageThemeNotifier.value == .dark
            ? .light
            : .dark,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      body: content(context),
    );
  }
}
