import AppIntents
import SwiftUI
import UIKit
import WidgetKit

private let appGroupIdentifier =
  "group.com.afalphy.sylvakru"

private let widgetDefaults =
  UserDefaults(
    suiteName: appGroupIdentifier
  )

// Same color scheme as the NowPlaying widget: the contrast color computed
// from the current cover, shared via the "foregroundColor" key.
private var widgetForegroundColor: Color {
  widgetColor("foregroundColor", default: 0xFF00_0000)
}

// integer(forKey:) returns 0 for missing keys, which renders as a fully
// transparent color on a fresh install; treat missing as "no data yet".
private func widgetColor(
  _ key: String,
  default defaultColor: Int
) -> Color {
  Color(
    argb: widgetDefaults?.object(
      forKey: key
    ) as? Int ?? defaultColor
  )
}

private func widgetFilePath(
  _ name: String
) -> String? {
  FileManager.default
    .containerURL(
      forSecurityApplicationGroupIdentifier:
        appGroupIdentifier
    )?
    .appendingPathComponent(name)
    .path
}

// MARK: - Page Index

private enum PageIndexKey {

  static let medium =
    "widget_page_medium"

  static let large =
    "widget_page_large"

  static let extraLarge =
    "widget_page_extra_large"

  static let extraLargePortrait =
    "widget_page_extra_large_portrait"
}

private func pageIndex(
  for family: WidgetFamily
) -> Int {

  switch family {

  case .systemMedium:

    return widgetDefaults?.integer(
      forKey: PageIndexKey.medium
    ) ?? 0

  case .systemLarge:

    return widgetDefaults?.integer(
      forKey: PageIndexKey.large
    ) ?? 0

  case .systemExtraLarge:

    return widgetDefaults?.integer(
      forKey: PageIndexKey.extraLarge
    ) ?? 0

  case .systemExtraLargePortrait:

    if #available(iOS 27.0, *) {

      return widgetDefaults?.integer(
        forKey: PageIndexKey.extraLargePortrait
      ) ?? 0
    }

    return 0

  default:

    return 0
  }
}

private func savePageIndex(
  _ index: Int,
  for family: WidgetFamily
) {

  switch family {

  case .systemMedium:

    widgetDefaults?.set(
      index,
      forKey: PageIndexKey.medium
    )

  case .systemLarge:

    widgetDefaults?.set(
      index,
      forKey: PageIndexKey.large
    )

  case .systemExtraLarge:

    widgetDefaults?.set(
      index,
      forKey: PageIndexKey.extraLarge
    )

  case .systemExtraLargePortrait:

    if #available(iOS 27.0, *) {

      widgetDefaults?.set(
        index,
        forKey: PageIndexKey.extraLargePortrait
      )
    }

  default:

    break
  }
}

// MARK: - Family Key

private enum WidgetFamilyKey {

  static let medium = "medium"

  static let large = "large"

  static let extraLarge = "extraLarge"

  static let extraLargePortrait =
    "extraLargePortrait"
}

private func familyKey(
  for family: WidgetFamily
) -> String {

  switch family {

  case .systemMedium:
    return WidgetFamilyKey.medium

  case .systemLarge:
    return WidgetFamilyKey.large

  case .systemExtraLarge:
    return WidgetFamilyKey.extraLarge

  case .systemExtraLargePortrait:
    return WidgetFamilyKey.extraLargePortrait

  default:
    return ""
  }
}

private func widgetFamily(
  from key: String
) -> WidgetFamily? {

  switch key {

  case WidgetFamilyKey.medium:
    return .systemMedium

  case WidgetFamilyKey.large:
    return .systemLarge

  case WidgetFamilyKey.extraLarge:
    return .systemExtraLarge

  case WidgetFamilyKey.extraLargePortrait:

    if #available(iOS 27.0, *) {
      return .systemExtraLargePortrait
    }

    return nil

  default:
    return nil
  }
}

// MARK: - Widget Page Family

// (No AppEnum here anymore: ChangePageIntent's family parameter is a plain
// String raw value. AppEnum parameter hydration failed on the first intent
// execution in a cold extension process and silently fell back to the
// init() default, so the large widget's first taps wrote the medium page
// key. Plain strings hydrate through Codable and have no registry to miss.)

// MARK: - Items Per Page

private func itemsPerPage(
  for family: WidgetFamily
) -> Int {

  switch family {

  case .systemMedium:

    return 4

  case .systemLarge:

    return 12

  case .systemExtraLarge:

    return 12

  case .systemExtraLargePortrait:

    if #available(iOS 27.0, *) {
      return 20
    }

    return 1

  default:

    return 1
  }
}

// MARK: - Total Pages

private func totalPages(
  itemCount: Int,
  itemsPerPage: Int
) -> Int {

  guard itemsPerPage > 0 else {
    return 1
  }

  return max(
    1,
    (itemCount + itemsPerPage - 1)
      / itemsPerPage
  )
}

// MARK: - Timeline Entry

struct PlaylistsWidgetEntry: TimelineEntry {

  let date: Date

  let coverPaths: [String]

  let playlistNames: [String]

  let family: WidgetFamily

  let isPremium: Bool
}

// MARK: - Timeline Provider

struct PlaylistsWidgetTimelineProvider: TimelineProvider {

  func placeholder(
    in context: Context
  ) -> PlaylistsWidgetEntry {

    let count =
      itemsPerPage(
        for: context.family
      )

    return PlaylistsWidgetEntry(
      date: Date(),

      coverPaths: Array(
        repeating: "",
        count: count
      ),

      playlistNames: Array(
        repeating: String(localized: "Playlist"),
        count: count
      ),

      family: context.family,

      isPremium: widgetIsPremium()

    )
  }

  func getSnapshot(
    in context: Context,
    completion:
      @escaping (
        PlaylistsWidgetEntry
      ) -> Void
  ) {

    completion(
      placeholder(
        in: context
      )
    )
  }

  func getTimeline(
    in context: Context,
    completion:
      @escaping (
        Timeline<PlaylistsWidgetEntry>
      ) -> Void
  ) {

    // MARK: Read playlist data

    // Fresh install: nothing synced yet — render the placeholder instead of
    // a blank widget until the first playlist data arrives.

    if widgetDefaults?.object(forKey: "playlistCount") == nil {

      completion(
        Timeline(
          entries: [placeholder(in: context)],
          policy: .never
        )
      )

      return
    }

    let count =
      widgetDefaults?.integer(
        forKey: "playlistCount"
      ) ?? 0

    var coverPaths: [String] = []

    var playlistNames: [String] = []

    for i in 0..<count {

      let name =
        widgetDefaults?.string(
          forKey: "name\(i)"
        ) ?? ""

      playlistNames.append(
        name
      )

      coverPaths.append(
        widgetDefaults?.string(
          forKey: "cover\(i)"
        ) ?? ""
      )
    }

    // MARK: Validate page

    let pageSize =
      itemsPerPage(
        for: context.family
      )

    let pages =
      totalPages(
        itemCount: count,
        itemsPerPage: pageSize
      )

    let savedPage =
      pageIndex(
        for: context.family
      )

    let validPage =
      min(
        max(
          savedPage,
          0
        ),
        pages - 1
      )

    // Playlist count may have decreased.
    // Correct the persisted page immediately.

    if validPage != savedPage {

      savePageIndex(
        validPage,
        for: context.family
      )
    }

    let entry =
      PlaylistsWidgetEntry(
        date: Date(),
        coverPaths: coverPaths,
        playlistNames: playlistNames,
        family: context.family,
        isPremium: widgetIsPremium()
      )

    let timeline =
      Timeline(
        entries: [entry],
        policy: .never
      )

    completion(
      timeline
    )
  }
}

// MARK: - Page Intent

struct ChangePageIntent: AppIntent {

  static var title: LocalizedStringResource =
    "Switch Widget Page"

  @Parameter(
    title: "Widget Size"
  )
  var family: String

  @Parameter(
    title: "Target Page"
  )
  var targetPage: Int

  init() {

    family =
      WidgetFamilyKey.medium

    targetPage =
      0
  }

  init(
    family: WidgetFamily,
    targetPage: Int
  ) {

    self.family =
      familyKey(
        for: family
      )

    self.targetPage =
      targetPage
  }

  func perform()
    async throws
    -> some IntentResult
  {

    guard
      let widgetFamily =
        widgetFamily(
          from: family
        )
    else {

      return .result()
    }

    savePageIndex(
      max(
        0,
        targetPage
      ),
      for: widgetFamily
    )

    // No manual reloadTimelines here: the system already re-renders the
    // tapped widget when perform() finishes, and reloading the kind would
    // rebuild EVERY placed Playlists widget (each re-decodes its covers),
    // which visibly slowed the page flip.

    return .result()
  }
}

// MARK: - Main Widget View

struct PlaylistsWidgetEntryView: View {

  let entry: PlaylistsWidgetEntry

  var isLocked: Bool {
    !entry.isPremium && entry.family != .systemMedium
  }

  var body: some View {

    Group {

      switch entry.family {

      case .systemMedium:

        GridView(
          entry: entry,
          columns: 4,
          itemsPerPage: 4
        )

      case .systemLarge:

        GridView(
          entry: entry,
          columns: 4,
          itemsPerPage: 12
        )

      case .systemExtraLarge:

        GridView(
          entry: entry,
          columns: 6,
          itemsPerPage: 12
        )

      case .systemExtraLargePortrait:

        if #available(iOS 27.0, *) {

          GridView(
            entry: entry,
            columns: 4,
            itemsPerPage: 20
          )

        } else {

          Text(
            "Unsupported Size"
          )
          .font(
            .caption
          )
          .foregroundColor(
            widgetForegroundColor.opacity(0.5)
          )
        }

      default:

        Text(
          "Unsupported Size"
        )
        .font(
          .caption
        )
        .foregroundColor(
          widgetForegroundColor.opacity(0.5)
        )
      }
    }
    // contentMarginsDisabled moves the old system margin into this manual
    // padding, so the premium overlay below can cover the full widget.
    .padding(20)
    .containerBackground(
      widgetColor("coverColor", default: 0xFFFF_FFFF),
      for: .widget
    )
    .overlay {
      if isLocked {
        PremiumOverlay(
          background: widgetColor("coverColor", default: 0xFFFF_FFFF),
          foreground: widgetForegroundColor
        )
      }
    }
  }
}

// MARK: - Grid View

struct GridView: View {

  let entry: PlaylistsWidgetEntry

  let columns: Int

  let itemsPerPage: Int

  // Same rule as PlaylistsWidgetEntryView.isLocked: the widget buttons are
  // handled by a native interaction layer above the rendered content, so
  // while locked the page buttons must not be rendered as Buttons at all.
  var isLocked: Bool {
    !entry.isPremium && entry.family != .systemMedium
  }

  private let gridSpacing: CGFloat = 12

  private let rowHeight: CGFloat = 80

  var body: some View {

    let currentPage =
      pageIndex(
        for: entry.family
      )

    let itemCount =
      min(
        entry.coverPaths.count,
        entry.playlistNames.count
      )

    let pages =
      totalPages(
        itemCount: itemCount,
        itemsPerPage: itemsPerPage
      )

    // Make sure the page is still valid.

    let validPage =
      min(
        max(
          currentPage,
          0
        ),
        pages - 1
      )

    let startIndex =
      validPage * itemsPerPage

    let endIndex =
      min(
        startIndex + itemsPerPage,
        itemCount
      )

    let currentCovers =
      startIndex < itemCount
      ? Array(
        entry.coverPaths[
          startIndex..<endIndex
        ]
      )
      : []

    let currentNames =
      startIndex < itemCount
      ? Array(
        entry.playlistNames[
          startIndex..<endIndex
        ]
      )
      : []

    let gridColumns =
      Array(
        repeating:
          GridItem(
            .flexible(),
            spacing: 8
          ),
        count: columns
      )

    let maxRows =
      (itemsPerPage
        + columns
        - 1)
      / columns

    // Keep the grid area fixed.
    //
    // This prevents the last page from moving
    // vertically when it contains fewer rows.

    let gridHeight =
      CGFloat(maxRows)
      * rowHeight
      + CGFloat(maxRows - 1)
      * gridSpacing

    VStack {

      // MARK: Playlist Grid

      if currentCovers.isEmpty {

        VStack {

          Spacer()

          Text(
            "No playlists available"
          )
          .font(
            .caption
          )
          .foregroundColor(
            widgetForegroundColor.opacity(0.5)
          )

          Spacer()
        }
        .frame(
          height: gridHeight
        )

      } else {

        LazyVGrid(
          columns: gridColumns,
          spacing: gridSpacing
        ) {

          ForEach(
            0..<currentCovers.count,
            id: \.self
          ) { index in

            VStack(
              alignment: .leading,
              spacing: 2
            ) {

              playlistImage(
                path:
                  currentCovers[index]
              )

              Text(
                currentNames.indices
                  .contains(index)
                  ? currentNames[index]
                  : String(localized: "Unknown")
              )
              .font(
                .system(
                  size: 10,
                  weight: .medium
                )
              )
              .foregroundColor(
                widgetForegroundColor
              )
              .lineLimit(1)
            }
          }

          // Fill empty cells.
          //
          // This forces every page to occupy
          // the same number of grid rows.

          let remainingSlots =
            itemsPerPage
            - currentCovers.count

          if remainingSlots > 0 {

            ForEach(
              0..<remainingSlots,
              id: \.self
            ) { _ in

              VStack(
                alignment: .leading,
                spacing: 2
              ) {

                Color.clear
                  .aspectRatio(
                    1,
                    contentMode: .fit
                  )

                Text("")
                  .font(
                    .system(
                      size: 10,
                      weight: .medium
                    )
                  )
              }
              .hidden()
            }
          }
        }
        .frame(
          maxWidth: .infinity,
          minHeight: gridHeight,
          maxHeight: gridHeight,
          alignment: .top
        )
      }

      Spacer(
        minLength: 0
      )

      // MARK: Pagination

      pagination(
        currentPage: validPage,
        totalPages: pages
      )
    }
  }

  // MARK: Playlist Image

  @ViewBuilder
  private func playlistImage(
    path: String
  ) -> some View {

    if !path.isEmpty,
      let image = WidgetImageCache.shared.image(at: path, maxPixels: 600)
    {

      // A square cell with the cover letterboxed inside it. The explicit
      // ratio in aspectRatio(1, contentMode: .fit) only squares the layout
      // bounds - a resizable image stretches its bitmap to fill them - so
      // the square comes from a Color.clear container and scaledToFit
      // (which preserves the image's own aspect ratio) does the fitting.

      Color.clear
        .aspectRatio(
          1,
          contentMode: .fit
        )
        .overlay {

          Image(
            uiImage: image
          )
          .resizable()
          .fullColorRendering()
          .scaledToFit()
        }
        .clipShape(
          RoundedRectangle(
            cornerRadius: 6
          )
        )

    } else {

      RoundedRectangle(
        cornerRadius: 6
      )
      .fill(
        widgetForegroundColor.opacity(0.25)
      )
      .aspectRatio(
        1,
        contentMode: .fit
      )
      .overlay {

        Image(
          systemName:
            "music.note.list"
        )
        .foregroundColor(
          widgetForegroundColor.opacity(0.5)
        )
        .font(
          .system(size: 14)
        )
      }
    }
  }

  // MARK: Pagination

  private func pagination(
    currentPage: Int,
    totalPages: Int
  ) -> some View {

    HStack {

      pageButton(
        direction: .previous,
        currentPage: currentPage,
        totalPages: totalPages
      )

      Spacer()

      pageIndicators(
        currentPage: currentPage,
        totalPages: totalPages
      )

      Spacer()

      pageButton(
        direction: .next,
        currentPage: currentPage,
        totalPages: totalPages
      )
    }
    .padding(
      .horizontal,
      2
    )
  }

  // MARK: Page Button

  private enum PageDirection {

    case previous

    case next
  }

  private func pageButton(
    direction: PageDirection,
    currentPage: Int,
    totalPages: Int
  ) -> some View {

    let targetPage: Int

    let disabled: Bool

    switch direction {

    case .previous:

      targetPage =
        max(
          0,
          currentPage - 1
        )

      disabled =
        currentPage <= 0

    case .next:

      targetPage =
        min(
          totalPages - 1,
          currentPage + 1
        )

      disabled =
        currentPage >= totalPages - 1
    }

    let arrow = Image(
      systemName:
        direction == .previous
        ? "arrowtriangle.left.fill"
        : "arrowtriangle.right.fill"
    )
    .font(
      .system(
        size: 16,
        weight: .medium
      )
    )
    .foregroundColor(
      disabled
        ? widgetForegroundColor.opacity(0.3)
        : widgetForegroundColor
    )

    return Group {

      if isLocked {

        arrow

      } else {

        Button(
          intent:
            ChangePageIntent(
              family: entry.family,
              targetPage: targetPage
            )
        ) {
          arrow
        }
        .buttonStyle(
          .plain
        )
      }
    }
  }

  // MARK: Page Indicators

  private func pageIndicators(
    currentPage: Int,
    totalPages: Int
  ) -> some View {

    HStack(
      spacing: 5
    ) {

      ForEach(
        0..<totalPages,
        id: \.self
      ) { page in

        Circle()
          .fill(
            page == currentPage
              ? widgetForegroundColor
              : widgetForegroundColor.opacity(0.3)
          )
          .frame(
            width: 6,
            height: 6
          )
      }
    }
  }
}

// MARK: - Widget Configuration

struct PlaylistsWidget: Widget {

  let kind: String =
    "PlaylistsWidget"

  var body: some WidgetConfiguration {

    StaticConfiguration(
      kind: kind,
      provider: PlaylistsWidgetTimelineProvider()
    ) { entry in

      PlaylistsWidgetEntryView(
        entry: entry
      )
    }
    .configurationDisplayName(
      LocalizedStringResource("My Playlists")
    )
    .description(
      LocalizedStringResource(
        "Displays your music playlists with multi-size support and pagination."
      )
    )
    .supportedFamilies(
      supportedFamilies
    )
    .contentMarginsDisabled()
  }

  private var supportedFamilies: [WidgetFamily] {

    if #available(iOS 27.0, *) {

      return [
        .systemMedium,
        .systemLarge,
        .systemExtraLarge,
        .systemExtraLargePortrait,
      ]

    } else {

      return [
        .systemMedium,
        .systemLarge,
        .systemExtraLarge,
      ]
    }
  }
}
