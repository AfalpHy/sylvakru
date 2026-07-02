part of '../../layer/audio_output_settings_layer.dart';

extension _AudioOutputSettingsPage on _AudioOutputSettingsLayerState {
  Widget pageView(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: customAppBarLeading(context, label: 'settings'),
        backgroundColor: Colors.transparent,
        systemOverlayStyle: mainPageThemeNotifier.value == .dark
            ? .light
            : .dark,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(_title),
        centerTitle: true,
      ),
      body: _content(),
    );
  }
}
