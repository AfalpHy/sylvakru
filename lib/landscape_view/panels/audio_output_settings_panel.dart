part of '../../layer/audio_output_settings_layer.dart';

extension _AudioOutputSettingsPanel on _AudioOutputSettingsLayerState {
  Widget panelView(BuildContext context) {
    return Column(
      children: [
        TitleBar(backToRoot: () => layersManager.popDetail('settings')),
        Expanded(child: _content()),
      ],
    );
  }
}
