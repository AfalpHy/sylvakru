import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sylvakru/base/app.dart' as app;
import 'package:sylvakru/base/services/picture_load_scheduler.dart';
import 'package:sylvakru/base/services/picture_service.dart';
import 'package:sylvakru/base/services/stream_client.dart';
import 'package:sylvakru/base/widgets/blurred_cover_art_widget.dart';
import 'package:sylvakru/base/widgets/cover_art_widget.dart';

class _PictureClient extends Fake implements StreamClient {
  Uint8List bytes;

  _PictureClient(this.bytes);

  @override
  Future<Uint8List?> getPictureBytes(String songId) async => bytes;
}

Uint8List _png(int red, int blue) {
  final image = img.Image(width: 2, height: 2);
  for (final pixel in image) {
    pixel.setRgb(red, 0, blue);
  }
  return img.encodePng(image);
}

Widget _backgrounds(MyPicture picture) => Directionality(
  textDirection: TextDirection.ltr,
  child: Row(
    children: List.generate(
      2,
      (_) => Expanded(
        child: BlurredCoverArtWidget(
          picture: picture,
          color: Colors.grey,
          sigmaX: 30,
          sigmaY: 30,
        ),
      ),
    ),
  ),
);

final _cachedImages = find.byWidgetPredicate(
  (widget) => widget is RawImage && widget.fit == BoxFit.fill,
);

Future<void> _waitForColor(WidgetTester tester, int red, int blue) async {
  List<int>? color;
  await tester.runAsync(() async {
    for (var attempt = 0; attempt < 100; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await tester.pump();
      final images = tester
          .renderObjectList<RenderImage>(_cachedImages)
          .toList();
      if (images.length != 2) continue;
      final image = images[0].image!;
      final bytes = await image.toByteData();
      final offset = (image.height ~/ 2 * image.width + image.width ~/ 2) * 4;
      color = [bytes!.getUint8(offset), bytes.getUint8(offset + 2)];
      if (color![0] == red && color![1] == blue) {
        expect(image.isCloneOf(images[1].image!), isTrue);
        return;
      }
    }
  });
  expect(color, [red, blue]);
}

void main() {
  setUpAll(() async {
    app.appSupportDir = await Directory.systemTemp.createTemp('blurred_cover_');
    app.sourceType = app.SourceType.feiniu;
  });

  tearDown(() {
    pictureLoadScheduler.clear();
    streamClient = null;
  });

  tearDownAll(() => app.appSupportDir.delete(recursive: true));

  testWidgets('背景共享缓存，封面重置和对象替换后更新图片', (tester) async {
    final client = _PictureClient(_png(255, 0));
    streamClient = client;
    final picture = MyPicture('refresh');
    await tester.pumpWidget(_backgrounds(picture));
    await _waitForColor(tester, 255, 0);

    client.bytes = _png(0, 255);
    picture.reset();
    await tester.pump();
    // 只等待原来的组件刷新，不重新 pumpWidget。
    await _waitForColor(tester, 0, 255);

    await tester.runAsync(() => File(picture.path).delete());
    pictureLoadScheduler.clear();
    client.bytes = _png(255, 0);
    await tester.pumpWidget(_backgrounds(MyPicture('refresh')));
    await _waitForColor(tester, 255, 0);
    await tester.pumpWidget(const SizedBox());
    picture.reset();
    expect(tester.takeException(), isNull);
  });

  testWidgets('损坏封面使用原回退，更新有效封面后恢复', (tester) async {
    final client = _PictureClient(Uint8List.fromList([1, 2, 3]));
    streamClient = client;
    final picture = MyPicture('invalid');
    await tester.pumpWidget(_backgrounds(picture));
    await tester.runAsync(() async {
      for (var attempt = 0; attempt < 100; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
        if (find.byType(ImageIcon).evaluate().length == 2) return;
      }
    });
    expect(find.byType(ImageIcon), findsNWidgets(2));
    expect(find.byType(CoverArtWidget), findsNWidgets(2));
    expect(_cachedImages, findsNothing);
    expect(tester.takeException(), isNull);

    client.bytes = _png(0, 255);
    picture.reset();
    await tester.pump();
    await _waitForColor(tester, 0, 255);
    expect(find.byType(CoverArtWidget), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
