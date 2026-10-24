import AppIntents
import SwiftUI
import WidgetKit

extension Color {
  init(argb: Int) {
    self.init(
      .sRGB,
      red: Double((argb >> 16) & 0xFF) / 255,
      green: Double((argb >> 8) & 0xFF) / 255,
      blue: Double(argb & 0xFF) / 255,
      opacity: Double((argb >> 24) & 0xFF) / 255
    )
  }
}

// Every timeline reload re-evaluates the whole view; covers come from the
// shared WidgetImageCache (keyed by path + mtime so an overwritten cover
// file invalidates naturally).

struct NowPlayingWidgetEntry: TimelineEntry {
  let date: Date
  let title: String
  let artist: String
  let album: String
  let coverPath: String
  let coverColor: Int
  let foregroundColor: Int
  let isPlaying: Bool
  let isFavorite: Bool
  let postion: Double
  let duration: Double
  let lyrics: String
  let lyricsIndex: Int
  let family: WidgetFamily
  let isPremium: Bool

}

// Shown in the gallery and on the home screen before the app has synced any
// data (fresh install), so the widget never renders blank.
private func placeholderEntry(family: WidgetFamily) -> NowPlayingWidgetEntry {
  NowPlayingWidgetEntry(
    date: Date(),
    title: String(localized: "Title"),
    artist: String(localized: "Artist"),
    album: String(localized: "Album"),
    coverPath: "",
    coverColor: 0xFFFF_FFFF,
    foregroundColor: 0xFF00_0000,
    isPlaying: false,
    isFavorite: false,
    postion: 0,
    duration: 0,
    lyrics: String(localized: "Lyrics"),
    lyricsIndex: 0,
    family: family,
    isPremium: widgetIsPremium()
  )
}

struct NowPlayingWidgetTimelineProvider: TimelineProvider {

  func placeholder(in context: Context) -> NowPlayingWidgetEntry {
    placeholderEntry(family: context.family)
  }

  func makeEntry(in context: Context) -> NowPlayingWidgetEntry {
    let sharedDefaults = UserDefaults(
      suiteName: "group.com.afalphy.sylvakru"
    )

    // Fresh install: nothing synced yet. Missing color keys read back as 0
    // (fully transparent), so render the placeholder instead of a blank
    // widget until the first song data arrives.
    if sharedDefaults?.object(forKey: "title") == nil {
      return placeholderEntry(family: context.family)
    }

    return NowPlayingWidgetEntry(
      date: Date(),
      title: sharedDefaults?.string(forKey: "title") ?? "",
      artist: sharedDefaults?.string(forKey: "artist") ?? "",
      album: sharedDefaults?.string(forKey: "album") ?? "",
      coverPath: sharedDefaults?.string(forKey: "coverPath") ?? "",
      coverColor: sharedDefaults?.integer(forKey: "coverColor") ?? 0xFFFF_FFFF,
      foregroundColor: sharedDefaults?.integer(forKey: "foregroundColor") ?? 0xFF00_0000,
      isPlaying: sharedDefaults?.bool(forKey: "is_playing") ?? false,
      isFavorite: sharedDefaults?.bool(forKey: "is_favorite") ?? false,
      postion: 0,
      duration: 0,
      lyrics: sharedDefaults?.string(forKey: "lyrics") ?? "",
      lyricsIndex: sharedDefaults?.integer(forKey: "lyricsIndex") ?? 0,
      family: context.family,
      isPremium: widgetIsPremium()
    )
  }

  func getSnapshot(
    in context: Context,
    completion: @escaping (NowPlayingWidgetEntry) -> Void
  ) {
    completion(makeEntry(in: context))
  }

  func getTimeline(
    in context: Context,
    completion: @escaping (Timeline<NowPlayingWidgetEntry>) -> Void
  ) {
    let entry = makeEntry(in: context)

    completion(
      Timeline(
        entries: [entry],
        policy: .never
      )
    )
  }
}

// Flutter joins each lyric line and its translations with U+001F (unit
// separator): lines stay newline-separated, translations ride inside the
// line entry so lyricsIndex keeps pointing at the original line.
private let lyricTranslateSeparator = "\u{1F}"

// Centers the row at centerIndex on the container's midline (shifted by
// `offset`, negative moves up) while every row keeps its natural height, so
// long lyric lines wrap to multiple display rows instead of ellipsizing.
// Rows have variable heights once wrapped, so centering must come from the
// measured subview sizes rather than a fixed row pitch.
private struct CenteredLyricsLayout: Layout {
  let centerIndex: Int
  let spacing: CGFloat
  let offset: CGFloat

  func sizeThatFits(
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout ()
  ) -> CGSize {
    CGSize(width: proposal.width ?? 0, height: proposal.height ?? 0)
  }

  func placeSubviews(
    in bounds: CGRect,
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout ()
  ) {
    let sizes = subviews.map {
      $0.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
    }

    var centerY = bounds.midY
    var y = bounds.minY
    for (index, size) in sizes.enumerated() {
      if index == centerIndex {
        centerY = y + size.height / 2
        break
      }
      y += size.height + spacing
    }

    var rowY = bounds.minY + (bounds.midY + offset) - centerY
    for (index, size) in sizes.enumerated() {
      subviews[index].place(
        at: CGPoint(x: bounds.minX, y: rowY),
        proposal: ProposedViewSize(width: bounds.width, height: size.height)
      )
      rowY += size.height + spacing
    }
  }
}

struct NowPlayingWidgetEntryView: View {
  var entry: NowPlayingWidgetTimelineProvider.Entry

  var isLocked: Bool {
    !entry.isPremium && entry.family != .systemSmall
  }

  var lyricsLines: [String] {
    entry.lyrics.components(separatedBy: "\n")
  }

  // Widget buttons are handled by a native interaction layer above the
  // rendered content, so PremiumOverlay can't block them by covering them;
  // while the size is locked, render the controls as plain images instead.
  @ViewBuilder
  private func controlButton(
    function: String,
    @ViewBuilder label: () -> some View
  ) -> some View {
    if isLocked {
      label()
    } else {
      Button(intent: BackgroundIntent(function: function)) {
        label()
      }
      .buttonStyle(.plain)
    }
  }

  func lyricsView(fontSize: CGFloat, offset: CGFloat) -> some View {
    GeometryReader { geometry in
      let lineHeight = fontSize + 6

      let rawCount = max(1, Int(geometry.size.height / lineHeight))
      let visibleLineCount = rawCount % 2 == 0 ? rawCount + 1 : rawCount

      let halfCount = visibleLineCount / 2
      let start = entry.lyricsIndex - halfCount
      let end = start + visibleLineCount

      CenteredLyricsLayout(centerIndex: halfCount, spacing: 6, offset: offset) {
        ForEach(start..<end, id: \.self) { index in
          let isValid = index >= 0 && index < lyricsLines.count
          let parts = (isValid ? lyricsLines[index] : "")
            .components(separatedBy: lyricTranslateSeparator)
          let lineText = parts[0]
          let translates = Array(parts.dropFirst())
          let isCurrent = index == entry.lyricsIndex
          let rowFontSize = isCurrent ? fontSize : fontSize - 3

          VStack(spacing: 2) {
            Text(lineText)
              .font(
                .system(
                  size: rowFontSize,
                  weight: isCurrent ? .bold : .medium
                )
              )
              .foregroundColor(
                Color(argb: entry.foregroundColor)
                  .opacity(isCurrent ? 1.0 : 0.5)
              )
              .multilineTextAlignment(.center)

            // Translations never take the current-line highlight.
            ForEach(translates.indices, id: \.self) { translateIndex in
              Text(translates[translateIndex])
                .font(.system(size: fontSize - 4, weight: .medium))
                .foregroundColor(
                  Color(argb: entry.foregroundColor).opacity(0.5)
                )
                .multilineTextAlignment(.center)
            }
          }
          .frame(maxWidth: .infinity, minHeight: rowFontSize + 6)
          .opacity(isValid ? (isCurrent ? 1.0 : 0.5) : 0.0)
        }
      }
      .clipped()
    }
  }

  var body: some View {
    Group {
      switch entry.family {
      case .systemSmall:
        smallView
      case .systemMedium:
        mediumView
          // The HStack hugs its fixed-height children, so the view ends up
          // shorter than the widget and the premium overlay only covers the
          // content; expand it so the overlay reaches the top/bottom edges.
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      case .systemLarge:
        largeView
      case .systemExtraLarge, .systemExtraLargePortrait:
        extraLargeView
      @unknown default:
        smallView
      }
    }
    .containerBackground(
      Color(argb: entry.coverColor),
      for: .widget
    )
    .overlay {
      if isLocked {
        PremiumOverlay(
          background: Color(argb: entry.coverColor),
          foreground: Color(argb: entry.foregroundColor)
        )
      }
    }
  }

  var smallView: some View {
    VStack {
      HStack(alignment: .top) {
        Group {
          if let uiImage = WidgetImageCache.shared.image(at: entry.coverPath, maxPixels: 600) {
            Image(uiImage: uiImage)
              .resizable()
              .aspectRatio(contentMode: .fit)
          } else {
            Image(systemName: "music.note")
              .resizable()
              .aspectRatio(contentMode: .fit)
              .padding(20)
          }
        }
        .frame(width: 60, height: 60)
        .clipShape(RoundedRectangle(cornerRadius: 6))

        Spacer()

        controlButton(function: "toggleFavorite") {
          Image(systemName: entry.isFavorite ? "star.fill" : "star")
            .font(.system(size: 20))
            .foregroundColor(entry.isFavorite ? .red : Color(argb: entry.foregroundColor))
        }

      }
      .padding(.horizontal, 16)
      .padding(.top, 24)

      VStack(alignment: .leading, spacing: 2) {
        Text(entry.title)
          .font(.system(size: 12, weight: .bold))
          .foregroundColor(Color(argb: entry.foregroundColor))
          .lineLimit(1)

        Text(entry.artist)
          .font(.system(size: 10))
          .foregroundColor(Color(argb: entry.foregroundColor))
          .lineLimit(1)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.leading, 16)
      .padding(.trailing, 12)

      HStack(alignment: .bottom) {
        Spacer()

        controlButton(function: "togglePlay") {
          Image(
            systemName: entry.isPlaying
              ? "pause.circle.fill"
              : "play.circle.fill"
          )
          .font(.system(size: 40))
          .foregroundColor(Color(argb: entry.foregroundColor))
        }
      }
      .padding(.trailing, 8)
      .padding(.bottom, 16)
    }

  }

  var mediumView: some View {
    HStack {
      Group {
        if let uiImage = WidgetImageCache.shared.image(at: entry.coverPath, maxPixels: 600) {
          Image(uiImage: uiImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
        } else {
          Image(systemName: "music.note")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .padding(40)
        }
      }
      .frame(width: 125, height: 125)
      .clipShape(RoundedRectangle(cornerRadius: 12))
      .padding(.leading, 16)
      .padding(.trailing, 4)

      VStack(alignment: .leading) {
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 4) {
            Text(entry.title)
              .font(.system(size: 14, weight: .bold))
              .foregroundColor(Color(argb: entry.foregroundColor))
              .lineLimit(1)

            Text(entry.artist)
              .font(.system(size: 12))
              .foregroundColor(Color(argb: entry.foregroundColor))
              .lineLimit(1)

            Text(entry.album)
              .font(.system(size: 12))
              .foregroundColor(Color(argb: entry.foregroundColor))
              .lineLimit(1)

          }

          Spacer()

          controlButton(function: "toggleFavorite") {
            Image(systemName: entry.isFavorite ? "star.fill" : "star")
              .font(.system(size: 20))
              .foregroundColor(entry.isFavorite ? .red : Color(argb: entry.foregroundColor))
          }
        }

        Spacer()

        HStack {
          controlButton(function: "skipToPrevious") {
            Image(systemName: "backward.fill")
              .font(.system(size: 25))
              .foregroundColor(Color(argb: entry.foregroundColor))
          }

          Spacer()

          controlButton(function: "togglePlay") {
            Image(systemName: entry.isPlaying ? "pause.circle.fill" : "play.circle.fill")
              .font(.system(size: 40))
              .foregroundColor(Color(argb: entry.foregroundColor))
          }

          Spacer()

          controlButton(function: "skipToNext") {
            Image(systemName: "forward.fill")
              .font(.system(size: 25))
              .foregroundColor(Color(argb: entry.foregroundColor))
          }
        }
      }
      .frame(height: 120)
      .padding(.trailing, 12)
    }

  }

  var largeView: some View {
    VStack {
      mediumView
        .frame(height: 140)
        .padding(.top, 10)

      Divider()
        .overlay(Color(argb: entry.foregroundColor).opacity(0.8))
        .padding(.horizontal, 10)

      lyricsView(fontSize: 16, offset: -16)
        .frame(maxHeight: .infinity)
        .padding(.horizontal)
    }
  }

  var extraLargeView: some View {
    VStack {
      mediumView
        .frame(height: 140)
        .padding(.top, 10)

      Divider()
        .overlay(Color(argb: entry.foregroundColor).opacity(0.8))
        .padding(.horizontal, 10)

      lyricsView(fontSize: 18, offset: -24)
        .frame(maxHeight: .infinity)
        .padding(.horizontal)
    }
  }
}

struct NowPlayingWidget: Widget {
  let kind: String = "NowPlayingWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(
      kind: kind,
      provider: NowPlayingWidgetTimelineProvider()
    ) { entry in
      NowPlayingWidgetEntryView(entry: entry)
    }
    .configurationDisplayName(LocalizedStringResource("Now Playing"))
    .description(
      LocalizedStringResource(
        "Shows the currently playing song with lyrics and playback controls."
      )
    )
    .contentMarginsDisabled()
    .supportedFamilies(supportedFamilies)
  }

  private var supportedFamilies: [WidgetFamily] {
    if #available(iOS 27.0, *) {
      return [
        .systemSmall,
        .systemMedium,
        .systemLarge,
        .systemExtraLarge,
        .systemExtraLargePortrait,
      ]
    } else {
      return [
        .systemSmall,
        .systemMedium,
        .systemLarge,
        .systemExtraLarge,
      ]
    }
  }
}
