# Sylvakru v3.1.1 页面切换掉帧 / GPU 占用过高优化建议

## 1. 问题概述

在 Android 高刷新率设备上，例如骁龙 8 至尊平台，Sylvakru v3.1.1 在页面切换、进入播放页、切换详情页时出现明显掉帧。录屏观察中，静止首页可以接近 120 FPS，但页面切换期间帧率会明显下降，同时 GPU 占用接近打满。

初步判断：这不是 CPU 性能不足，也不是单纯 Flutter 无法胜任，而是当前 UI 实现中存在多处高 GPU 成本操作叠加：

- 全屏 `BackdropFilter + ImageFilter.blur(sigmaX: 30, sigmaY: 30)`
- 全屏或大面积透明层合成
- `Clip.antiAliasWithSaveLayer`
- 页面切换时非 opaque route 叠加
- Hero 封面动画、阴影、圆角裁剪同时参与合成
- vivid 主题下背景封面与模糊层在多个页面重复存在

这些组合在 60Hz 下可能只是轻微卡顿，但在 120Hz 下每帧预算只有约 8.33ms，非常容易让 Raster/GPU 线程超时。

---

## 2. 重点风险点

### 2.1 播放页使用全屏 BackdropFilter

`lib/portrait_view/pages/portrait_lyrics_page.dart`

当前结构大致为：

```dart
if (lyricsPageThemeNotifier.value == .vivid) ...[
  CoverArtWidget(
    song: currentSong,
    color: colorManager.getSpecificLyricsPageCoverArtBaseColor(),
  ),
  BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
    child: AnimatedContainer(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      color: currentCoverArtColor.withAlpha(180),
    ),
  ),
],
```

问题：

- `BackdropFilter` 会对其后方已经绘制的内容进行滤镜处理。
- `sigma 30` 对移动端全屏实时模糊来说非常重。
- 页面切换过程中，背景、裁剪区域、透明层、Hero 动画都在变化，难以有效缓存。
- 如果这个页面还叠加在非 opaque route 上，GPU 需要同时处理上下层页面。

### 2.2 首页 / layer 页面也使用全屏 BackdropFilter

`lib/layer/layers_manager.dart`

当前结构大致为：

```dart
CoverArtWidget(
  song: layerInfo.backgroundSong,
  color: layerInfo.backgroundCoverArtColor,
);

ClipRect(
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
    child: Container(
      color: layerInfo.backgroundCoverArtColor.withAlpha(180),
    ),
  ),
);
```

问题：

- 首页和播放页都使用类似的全屏封面模糊背景。
- 页面切换时，旧页面和新页面可能同时存在，从而出现双层甚至多层全屏 blur。
- vivid 主题下该问题尤其明显。

### 2.3 播放页根节点使用 antiAliasWithSaveLayer

`lib/portrait_view/pages/portrait_lyrics_page.dart`

当前结构中存在：

```dart
Material(
  color: Colors.transparent,
  shape: SmoothRectangleBorder(...),
  clipBehavior: .antiAliasWithSaveLayer,
  child: Stack(...),
)
```

问题：

- `antiAliasWithSaveLayer` 会触发离屏缓冲区。
- 离屏缓冲区再叠加 `BackdropFilter`、透明色、阴影、圆角裁剪，会显著增加 GPU 压力。
- 如果只是为了圆角裁剪，大多数情况下不应使用 `saveLayer`。

### 2.4 图片没有针对背景模糊做降采样

`CoverArtWidget` 当前主要通过 `Image.file` 显示原图：

```dart
Image.file(
  File(path),
  width: size,
  height: size,
  fit: BoxFit.cover,
)
```

如果用于背景模糊，原图清晰度并不重要。使用原图进行全屏模糊属于浪费。背景只需要低频色块和氛围感，应当使用低分辨率版本。

---

## 3. 优化目标

建议优化目标：

1. 页面切换期间尽量稳定 120 FPS。
2. vivid 主题开启时 GPU 占用明显下降。
3. 静态页面不牺牲主要视觉效果。
4. 播放页进入 / 返回 / 详情页切换不再出现明显掉帧。
5. 尽量减少全屏 `saveLayer`、全屏 `BackdropFilter` 和重复背景合成。

---

## 4. 优先级最高的修改

### 4.1 将全屏 BackdropFilter 改为 ImageFiltered

如果只是想“把封面图做成模糊背景”，不需要 `BackdropFilter`。  
`BackdropFilter` 适合毛玻璃，也就是模糊背后已经绘制好的内容；但这里更像是模糊某一张封面图。

建议改成：

```dart
if (lyricsPageThemeNotifier.value == .vivid) ...[
  ImageFiltered(
    imageFilter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
    child: CoverArtWidget(
      song: currentSong,
      color: colorManager.getSpecificLyricsPageCoverArtBaseColor(),
    ),
  ),
  AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeInOutCubic,
    color: currentCoverArtColor.withAlpha(180),
  ),
],
```

优点：

- 只模糊封面图本身，不需要读取和处理整个后方场景。
- 合成成本明显低于 `BackdropFilter`。
- 对当前视觉效果影响较小。
- 更容易被 Flutter 缓存和复用。

首页 / layer 页面同理：

```dart
ImageFiltered(
  imageFilter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
  child: CoverArtWidget(
    song: layerInfo.backgroundSong,
    color: layerInfo.backgroundCoverArtColor,
  ),
),
Container(
  color: layerInfo.backgroundCoverArtColor.withAlpha(180),
),
```

### 4.2 降低 blur sigma

当前 `sigmaX: 30, sigmaY: 30` 偏高。建议先测试以下档位：

```dart
sigmaX: 12,
sigmaY: 12,
```

或：

```dart
sigmaX: 16,
sigmaY: 16,
```

如果配合半透明遮罩，视觉上依然能保持足够的氛围感，但 GPU 成本会明显下降。

推荐默认：

```dart
const double backgroundBlurSigma = 16;
```

并在设置里加入低 / 中 / 高三档：

```dart
enum BackgroundBlurQuality {
  off,
  low,    // sigma 8
  medium, // sigma 16
  high,   // sigma 24
}
```

不建议默认使用 sigma 30。

### 4.3 去掉 antiAliasWithSaveLayer

把播放页根节点的：

```dart
clipBehavior: Clip.antiAliasWithSaveLayer,
```

改为：

```dart
clipBehavior: Clip.antiAlias,
```

如果视觉没有明显问题，应保留该修改。

如果某些地方确实需要 `saveLayer`，建议缩小裁剪范围，只包裹真正需要特殊裁剪的局部组件，而不是整页。

### 4.4 页面切换期间禁用或冻结背景模糊

进入播放页 / 详情页动画期间，可以先显示静态背景或低成本背景，动画结束后再启用高质量模糊。

示例：

```dart
final bool enableExpensiveEffects = !isPageTransitioning;

ImageFiltered(
  enabled: enableExpensiveEffects,
  imageFilter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
  child: CoverArtWidget(...),
)
```

如果仍然卡顿，可以进一步处理：

- 页面切换时只显示纯色动态取色背景。
- 页面稳定后再淡入模糊封面。
- 或提前生成一张静态模糊背景图，切换期间直接显示图片。

---

## 5. 中优先级优化

### 5.1 为背景封面生成低分辨率缓存

背景模糊不需要原图清晰度。可以生成一个低分辨率背景缓存，例如：

- 64px / 96px / 128px 宽度
- 根据封面路径和修改时间缓存
- 切歌时异步生成
- UI 层只显示缓存图并放大

示例方向：

```dart
Image.file(
  File(blurredBackgroundPath),
  fit: BoxFit.cover,
  filterQuality: FilterQuality.low,
)
```

或者在 `Image.file` 中根据背景用途传入 `cacheWidth`：

```dart
Image.file(
  File(path),
  fit: BoxFit.cover,
  cacheWidth: 160,
  filterQuality: FilterQuality.low,
)
```

注意：封面展示本体仍然可以使用高清图；只有背景图需要降采样。

### 5.2 给背景层加 RepaintBoundary

背景封面、遮罩层、歌词列表、播放控制区建议分离 repaint 边界，避免一个小控件变化导致整页重绘。

示例：

```dart
RepaintBoundary(
  child: _BlurredBackground(...),
)
```

尤其是：

- 背景层
- 歌词列表
- 播放控制按钮区域
- 进度条区域

这些区域的刷新频率不同，不应该互相拖累。

### 5.3 避免不必要的 UniqueKey

播放页标题和副标题中有：

```dart
MyAutoSizeText(
  key: UniqueKey(),
  ...
)
```

`UniqueKey()` 会让 Flutter 每次 build 都认为这是一个全新的 widget，导致状态和布局缓存无法复用。建议改成稳定 key 或直接去掉 key。

例如：

```dart
MyAutoSizeText(
  getTitle(currentSong),
  maxLines: 1,
  ...
)
```

或者：

```dart
key: ValueKey(currentSong?.id ?? currentSong?.path),
```

### 5.4 减少 ValueListenableBuilder 嵌套重建范围

当前页面中多个 `ValueListenableBuilder` 直接包裹较大的 UI 结构。建议拆分成更小组件，让颜色变化、播放状态变化、歌词变化分别只刷新必要区域。

例如播放按钮只监听播放状态，不应该带动整行控制区重建。

---

## 6. 推荐修改方案

### 方案 A：低风险快速优化

适合快速验证性能问题来源。

修改点：

1. 所有全屏 `BackdropFilter sigma 30` 改为 `ImageFiltered sigma 16`。
2. `Clip.antiAliasWithSaveLayer` 改为 `Clip.antiAlias`。
3. 背景封面图使用 `cacheWidth: 160` 或低分辨率缓存。
4. 去掉标题和副标题的 `UniqueKey()`。

预期效果：

- 页面切换掉帧明显改善。
- GPU 占用下降。
- 视觉变化较小。
- 改动范围较可控。

### 方案 B：中等改造，体验更稳

在方案 A 基础上增加：

1. 页面切换期间禁用高成本 blur。
2. 动画结束后再淡入模糊背景。
3. 背景层、歌词层、控制层分离 `RepaintBoundary`。
4. vivid 主题增加“性能模式”。

预期效果：

- 高刷新率设备上更容易稳定 120 FPS。
- 中端设备也能获得明显收益。
- 适合发布为正式性能优化版本。

### 方案 C：彻底优化

在方案 B 基础上增加：

1. 异步预生成模糊背景图。
2. 切歌时缓存背景图。
3. 页面切换期间完全使用静态位图。
4. 只在封面变化时重新生成背景，不在每帧实时滤镜。
5. 根据设备性能自动选择 blur 档位。

预期效果：

- GPU 压力最低。
- 页面切换最稳定。
- 实现成本较高，但最适合音乐播放器长期维护。

---

## 7. 建议验证方式

### 7.1 使用 Flutter Performance Overlay

运行：

```bash
flutter run --profile --trace-skia
```

或至少使用 profile 包测试，不要用 debug 包判断性能。

重点观察：

- UI thread 是否稳定
- Raster thread 是否超时
- 页面切换期间 Raster 是否明显高于 8.33ms
- vivid 主题开启 / 关闭的差异

### 7.2 对比测试项

建议分别测试以下组合：

| 测试项 | 目的 |
|---|---|
| 关闭 vivid 主题 | 验证是否为背景模糊导致 |
| 注释 BackdropFilter | 验证 blur 成本 |
| sigma 30 改 16 | 验证 blur 强度影响 |
| BackdropFilter 改 ImageFiltered | 验证滤镜类型影响 |
| antiAliasWithSaveLayer 改 antiAlias | 验证 saveLayer 成本 |
| 关闭 Hero / elevation | 验证动画合成成本 |
| 背景图 cacheWidth 降采样 | 验证图片采样成本 |

### 7.3 目标数据

以 120Hz 设备为目标：

- 页面静止：Raster 平均 < 4ms
- 页面切换：Raster 尽量 < 8ms
- 最差帧：尽量不要频繁超过 16ms
- GPU 占用：页面切换时不应长期接近 100%

---

## 8. 结论

当前掉帧的核心原因不是设备性能不足，而是 vivid 主题下 UI 合成成本过高。  
尤其是全屏 `BackdropFilter sigma 30`、`antiAliasWithSaveLayer`、透明层、Hero 动画和页面切换叠加，导致 GPU/Raster 线程压力过大。

最建议优先处理：

1. `BackdropFilter` 改为 `ImageFiltered`
2. `sigma 30` 降到 `12~16`
3. 去掉整页 `antiAliasWithSaveLayer`
4. 背景图降采样
5. 页面切换期间冻结或降低背景特效

这几项改完后，骁龙 8 至尊这类设备理论上不应该再出现明显页面切换掉帧。
