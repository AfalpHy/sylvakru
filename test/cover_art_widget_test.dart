import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sylvakru/base/widgets/cover_art_widget.dart';

void main() {
  test('CoverArtWidget uses requested cache width for image decoding', () {
    final coverArt = CoverArtWidget(
      picturePath: 'F:\\Symusic\\cover.png',
      cacheWidth: 160,
      filterQuality: FilterQuality.low,
    );

    final image = coverArt.imageWidget('F:\\Symusic\\cover.png') as Image;

    final imageProvider = image.image;

    expect(imageProvider, isA<ResizeImage>());
    expect((imageProvider as ResizeImage).width, 160);
    expect(image.filterQuality, FilterQuality.low);
  });
}
