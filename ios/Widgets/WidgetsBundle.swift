//
//  WidgetsBundle.swift
//  Widgets
//
//  Created by wuhangyu on 2026/9/29.
//

import ImageIO
import SwiftUI
import WidgetKit

@main
struct WidgetsBundle: WidgetBundle {
  var body: some Widget {
    NowPlayingWidget()
    PlaylistsWidget()
  }
}

// iOS 26's Clear/Tinted widget appearance renders content in accented mode:
// bitmaps flatten to a white silhouette, which turned the covers solid
// white. Covers opt out via .fullColor so they keep their real colors; SF
// Symbols are monochrome by design and look correct accented, so they stay.
// The modifier is Image-only, so call it right after .resizable() and
// before aspect-fitting. No-op before iOS 18, where it doesn't exist.
extension Image {
  @ViewBuilder
  func fullColorRendering() -> some View {
    if #available(iOS 18.0, *) {
      self.widgetAccentedRenderingMode(.fullColor)
    } else {
      self
    }
  }
}

// Premium state is written by the app on every launch and on purchase
// (config.dart syncWidgetPremium). A missing key means the app never ran yet
// (widget gallery, fresh install) - show the full design in that case.
func widgetIsPremium() -> Bool {
  UserDefaults(suiteName: "group.com.afalphy.sylvakru")?
    .object(forKey: "isPremium") as? Bool ?? true
}

// WidgetKit fails the timeline render when the decoded bitmap blows past
// the widget's memory/archive limits - a large cover killed the widget even
// with aspect-fit display. Decode straight to a bounded thumbnail with
// ImageIO instead of materializing the full-resolution image first: the
// aspect ratio is preserved, nothing is cropped, and EXIF orientation is
// applied.
func widgetImage(
  at path: String,
  maxPixels: CGFloat
) -> UIImage? {
  let options: [CFString: Any] = [
    kCGImageSourceCreateThumbnailFromImageAlways: true,
    kCGImageSourceCreateThumbnailWithTransform: true,
    kCGImageSourceShouldCacheImmediately: true,
    kCGImageSourceThumbnailMaxPixelSize: maxPixels,
  ]

  guard
    let source = CGImageSourceCreateWithURL(
      URL(fileURLWithPath: path) as CFURL,
      nil
    ),
    let cgImage = CGImageSourceCreateThumbnailAtIndex(
      source,
      0,
      options as CFDictionary
    )
  else {
    return nil
  }

  return UIImage(cgImage: cgImage)
}

// Every timeline rebuild re-decodes whatever covers the view shows; without
// a cache each page flip re-reads them all from disk. NSCache is already
// thread-safe (timeline providers for multiple placed families rebuild
// concurrently) and evicts on its own under memory pressure.
final class WidgetImageCache {
  static let shared = WidgetImageCache()

  private let cache = NSCache<NSString, UIImage>()

  private init() {
    cache.countLimit = 48
  }

  func image(
    at path: String,
    maxPixels: CGFloat
  ) -> UIImage? {
    guard !path.isEmpty else { return nil }

    var key = path
    if let attributes = try? FileManager.default.attributesOfItem(atPath: path),
      let modified = attributes[.modificationDate] as? Date
    {
      key += "#\(modified.timeIntervalSince1970)"
    }

    if let hit = cache.object(forKey: key as NSString) {
      return hit
    }

    guard let image = widgetImage(at: path, maxPixels: maxPixels) else {
      return nil
    }

    cache.setObject(image, forKey: key as NSString)
    return image
  }
}

// Overlay for sizes that require premium: NowPlaying above systemSmall,
// Playlists above systemMedium. The scrim keeps the hint readable over any
// cover. NOTE: covering the view does NOT disable widget buttons - they are
// handled by a native interaction layer above the rendered content - so the
// widgets render their controls as plain images while this overlay is shown.
struct PremiumOverlay: View {
  var background: Color
  var foreground: Color

  var body: some View {
    ZStack {
      background.opacity(0.85)

      VStack(spacing: 6) {
        Image(systemName: "lock.fill")
          .font(.system(size: 24, weight: .medium))
          .foregroundColor(foreground)

        Text(String(localized: "Unlock with Premium"))
          .font(.system(size: 12, weight: .medium))
          .foregroundColor(foreground.opacity(0.7))
          .multilineTextAlignment(.center)
          .padding(.horizontal, 12)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .ignoresSafeArea()
    .contentShape(Rectangle())
  }
}
