import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:sylvakru/base/services/picture_service.dart';
import 'package:sylvakru/base/widgets/cover_art_widget.dart';

// 预模糊结果缓存：重开页面或来回切歌时直接复用，避免重复解码和模糊
final _blurredCoverCache = <(MyPicture, int, String), ui.Image>{};
final _blurredCoverCacheKeys = <(MyPicture, int, String)>[];
final _blurredCoverPending = <(MyPicture, int, String), Future<void>>{};
const _blurredCoverCacheLimit = 12;

/// vivid 背景专用的预模糊封面。
///
/// 将封面按背景尺寸裁剪、缩小并模糊后缓存，减少背景重复绘制时的模糊计算。
/// sigmaX/sigmaY 使用逻辑像素，生成小图时按画布比例换算。
class BlurredCoverArtWidget extends StatefulWidget {
  final MyPicture? picture;
  final Color color;
  final double sigmaX;
  final double sigmaY;

  const BlurredCoverArtWidget({
    super.key,
    required this.picture,
    required this.color,
    required this.sigmaX,
    required this.sigmaY,
  });

  @override
  State<BlurredCoverArtWidget> createState() => _BlurredCoverArtWidgetState();
}

class _BlurredCoverArtWidgetState extends State<BlurredCoverArtWidget> {
  // 展示用的克隆句柄，生命周期独立于缓存，缓存淘汰不影响正在显示的图
  ui.Image? _image;
  (MyPicture, int, String)? _renderedKey;
  (MyPicture, int, String)? _pendingKey;

  @override
  void initState() {
    super.initState();
    widget.picture?.changeNotifier.addListener(_pictureChanged);
  }

  @override
  void didUpdateWidget(BlurredCoverArtWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.picture != widget.picture) {
      oldWidget.picture?.changeNotifier.removeListener(_pictureChanged);
      widget.picture?.changeNotifier.addListener(_pictureChanged);
    }
  }

  void _pictureChanged() {
    setState(() {
      _pendingKey = null;
    });
  }

  @override
  void dispose() {
    widget.picture?.changeNotifier.removeListener(_pictureChanged);
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final picture = widget.picture;
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        if (picture == null || width <= 0 || height <= 0) {
          _pendingKey = null;
        } else {
          // 限制生成图片的短边尺寸，sigma 按同比例换算。
          final scale = min(1.0, 270 / min(width, height));
          final canvasWidth = max(1, (width * scale).round());
          final canvasHeight = max(1, (height * scale).round());
          final sigmaX = widget.sigmaX * scale;
          final sigmaY = widget.sigmaY * scale;

          final key = (
            picture,
            picture.changeNotifier.value,
            '${picture.path}|${canvasWidth}x$canvasHeight'
                '|${sigmaX.toStringAsFixed(1)}|${sigmaY.toStringAsFixed(1)}'
                '|${widget.color.toARGB32()}',
          );
          if (key == _renderedKey) {
            // 切回已显示的封面时，丢弃中途切歌留下的异步结果。
            _pendingKey = null;
          } else if (key != _pendingKey) {
            _pendingKey = key;
            final color = widget.color;
            // 微任务里再取图，避免在 build 期间同步 setState
            Future.microtask(
              () => _prepare(
                key,
                picture,
                color,
                canvasWidth,
                canvasHeight,
                sigmaX,
                sigmaY,
              ),
            );
          }

          // 换歌时保留旧图直到新图就绪，对齐原 Image 的 gaplessPlayback 行为。
          if (_image != null) {
            return RawImage(image: _image, fit: BoxFit.fill);
          }
        }
        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              CoverArtWidget(picture: picture, color: widget.color),
              BackdropFilter(
                filter: ui.ImageFilter.blur(
                  sigmaX: widget.sigmaX,
                  sigmaY: widget.sigmaY,
                ),
                child: const SizedBox.expand(),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _prepare(
    (MyPicture, int, String) key,
    MyPicture picture,
    Color color,
    int canvasWidth,
    int canvasHeight,
    double sigmaX,
    double sigmaY,
  ) async {
    try {
      if (!mounted || key != _pendingKey) {
        return;
      }
      var cached = _blurredCoverCache[key];
      while (cached == null) {
        await loadPictureSafe(picture);
        // 页面已切走时，不再为旧背景启动解码和模糊。
        if (!mounted || key != _pendingKey) {
          return;
        }
        if (!picture.isExist) {
          _setImage(null, key);
          return;
        }
        // 加载期间其他页面可能已经生成了同一背景。
        cached = _blurredCoverCache[key];
        if (cached != null) {
          break;
        }
        await _blurredCoverPending.putIfAbsent(key, () async {
          try {
            final image = await _renderBlurred(
              picture.path,
              color,
              canvasWidth,
              canvasHeight,
              sigmaX,
              sigmaY,
            );
            _blurredCoverCache[key] = image;
            _blurredCoverCacheKeys.add(key);
            if (_blurredCoverCacheKeys.length > _blurredCoverCacheLimit) {
              _blurredCoverCache
                  .remove(_blurredCoverCacheKeys.removeAt(0))
                  ?.dispose();
            }
          } finally {
            _blurredCoverPending.remove(key);
          }
        });
        if (!mounted || key != _pendingKey) {
          return;
        }
        // 重新读取缓存，避免等待期间结果被淘汰后使用已释放的图像。
        cached = _blurredCoverCache[key];
      }
      _blurredCoverCacheKeys.remove(key);
      _blurredCoverCacheKeys.add(key);
      _setImage(cached.clone(), key);
    } catch (_) {
      _setImage(null, key);
    }
  }

  void _setImage(ui.Image? image, (MyPicture, int, String) key) {
    if (!mounted || key != _pendingKey) {
      image?.dispose();
      return;
    }
    setState(() {
      _image?.dispose();
      _image = image;
      _renderedKey = key;
      _pendingKey = null;
    });
  }

  Future<ui.Image> _renderBlurred(
    String path,
    Color color,
    int canvasWidth,
    int canvasHeight,
    double sigmaX,
    double sigmaY,
  ) async {
    final bytes = await File(path).readAsBytes();
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? cover;
    ui.Picture? recordedPicture;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      // 只解码到画布所需分辨率，避免整幅解码大图
      final decodeScale = max(
        canvasWidth / descriptor.width,
        canvasHeight / descriptor.height,
      );
      codec = await descriptor.instantiateCodec(
        targetWidth: max(1, (descriptor.width * decodeScale).ceil()),
        targetHeight: max(1, (descriptor.height * decodeScale).ceil()),
      );
      final frame = await codec.getNextFrame();
      cover = frame.image;
      final rect = Rect.fromLTWH(
        0,
        0,
        canvasWidth.toDouble(),
        canvasHeight.toDouble(),
      );
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, rect);
      // 底色与原 CoverArtWidget 的 Material 底色一致
      canvas.drawRect(rect, Paint()..color = color);
      canvas.saveLayer(
        rect,
        Paint()
          ..imageFilter = ui.ImageFilter.blur(
            sigmaX: sigmaX,
            sigmaY: sigmaY,
            tileMode: TileMode.clamp,
          ),
      );
      // 与原全屏 BoxFit.cover 相同的居中裁剪
      final coverWidth = cover.width.toDouble();
      final coverHeight = cover.height.toDouble();
      final srcScale = min(
        coverWidth / canvasWidth,
        coverHeight / canvasHeight,
      );
      final srcWidth = canvasWidth * srcScale;
      final srcHeight = canvasHeight * srcScale;
      final src = Rect.fromLTWH(
        (coverWidth - srcWidth) / 2,
        (coverHeight - srcHeight) / 2,
        srcWidth,
        srcHeight,
      );
      canvas.drawImageRect(
        cover,
        src,
        rect,
        Paint()..filterQuality = FilterQuality.medium,
      );
      canvas.restore();
      recordedPicture = recorder.endRecording();
      return await recordedPicture.toImage(canvasWidth, canvasHeight);
    } finally {
      recordedPicture?.dispose();
      cover?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }
}
