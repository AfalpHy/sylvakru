import CFNetwork
import Flutter
import UIKit
import WidgetKit
import home_widget

@main
@objc class AppDelegate: FlutterAppDelegate, UIContextMenuInteractionDelegate {

  private var activeBookmarks: [String: URL] = [:]

  // Tracks background tasks begun from Flutter (song downloads/loads) so each
  // begin/end pair maps to one UIBackgroundTaskIdentifier.
  private var flutterBackgroundTasks: [Int: UIBackgroundTaskIdentifier] = [:]
  private var nextFlutterBackgroundTaskId = 1

  private weak var flutterView: UIView?
  private var currentMenuActions: [[String: Any]] = []
  private var menuChannel: FlutterMethodChannel?

  private var currentMenuRect: CGRect = .zero
  private var previewImageView: UIImageView?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // Retries the context-menu attachment whenever the app becomes active,
    // covering cold starts performed in the background by widget taps.
    // (Notification-based: FlutterAppDelegate does not expose
    // applicationDidBecomeActive for a Swift super call.)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(onDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )

    let registrar = self.registrar(forPlugin: "NativeBridge")

    audioControlChannel = FlutterMethodChannel(
      name: "com.afalphy.audio_control",
      binaryMessenger: registrar!.messenger()
    )

    let bookmarkChannel = FlutterMethodChannel(
      name: "com.afalphy.bookmark_manager",
      binaryMessenger: registrar!.messenger())

    bookmarkChannel.setMethodCallHandler({
      [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      guard let self = self else { return }

      switch call.method {
      case "getBookmarkFromPath":
        guard let args = call.arguments as? [String: Any],
          let path = args["path"] as? String
        else {
          result(FlutterError(code: "ARG_ERROR", message: "Path is required", details: nil))
          return
        }

        let url = URL(fileURLWithPath: path)
        let bookmarkData = try? url.bookmarkData(
          options: .minimalBookmark,
          includingResourceValuesForKeys: nil,
          relativeTo: nil)

        if let data = bookmarkData {
          result(data.base64EncodedString())
        } else {
          result(
            FlutterError(code: "CREATE_FAILED", message: "Failed to create bookmark", details: nil))
        }

      case "activateAndGetPath":
        guard let args = call.arguments as? [String: Any],
          let bookmarkBase64 = args["bookmark"] as? String,
          let bookmarkData = Data(base64Encoded: bookmarkBase64)
        else {
          result(FlutterError(code: "ARG_ERROR", message: "Invalid data", details: nil))
          return
        }

        var isStale = false
        do {
          let url = try URL(
            resolvingBookmarkData: bookmarkData, options: [], relativeTo: nil,
            bookmarkDataIsStale: &isStale)

          if url.startAccessingSecurityScopedResource() {
            self.activeBookmarks[bookmarkBase64] = url
            result(url.path)
          } else {
            result(FlutterError(code: "DENIED", message: "iOS denied access", details: nil))
          }
        } catch {
          result(
            FlutterError(code: "RESOLVE_FAILED", message: error.localizedDescription, details: nil))
        }

      default:
        result(FlutterMethodNotImplemented)
      }
    })

    let menuChannel = FlutterMethodChannel(
      name: "com.afalphy.menu",
      binaryMessenger: registrar!.messenger())
    self.menuChannel = menuChannel

    menuChannel.setMethodCallHandler({
      [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      guard let self = self else {
        result(nil)
        return
      }

      switch call.method {
      case "initNativeMenu":
        // Attach interaction to FlutterView when possible. A background start
        // (widget tap) has no foreground-active scene yet, so Dart's startup
        // call lands before the UI is active; the retry on every activation
        // below registers it once the app is actually opened.
        self.attachContextMenuInteraction()
        result(nil)
      case "showNativeMenu":
        guard let args = call.arguments as? [String: Any],
          let items = args["items"] as? [[String: Any]]
        else {
          result(
            FlutterError(code: "ARG_ERROR", message: "Invalid menu items payload", details: nil))
          return
        }

        // Sync payload data to memory. The interaction is already attached to FlutterView at startup.
        DispatchQueue.main.async {
          self.currentMenuActions = items

          let x = args["x"] as? CGFloat ?? 0.0
          let y = args["y"] as? CGFloat ?? 0.0
          let width = args["width"] as? CGFloat ?? 100.0
          let height = args["height"] as? CGFloat ?? 100.0
          self.currentMenuRect = CGRect(x: x, y: y, width: width, height: height)

          result(true)
        }

      default:
        result(FlutterMethodNotImplemented)
      }
    })

    // Reports which widgets of a given kind are actually placed on the home
    // screen (one entry per instance, so multiple sizes are all listed).
    let widgetConfigChannel = FlutterMethodChannel(
      name: "com.afalphy.widget_config",
      binaryMessenger: registrar!.messenger())

    widgetConfigChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      switch call.method {
      case "getInstalledWidgetFamilies":
        guard let kind = call.arguments as? String else {
          result(FlutterError(code: "ARG_ERROR", message: "Widget kind is required", details: nil))
          return
        }

        WidgetCenter.shared.getCurrentConfigurations { configuration in
          DispatchQueue.main.async {
            switch configuration {
            case .success(let widgetInfos):
              let families =
                widgetInfos
                .filter { $0.kind == kind }
                .map { $0.family.rawValue }
              result(families)
            case .failure(let error):
              result(
                FlutterError(
                  code: "UNAVAILABLE", message: error.localizedDescription, details: nil))
            }
          }
        }

      default:
        result(FlutterMethodNotImplemented)
      }
    })

    // Grants extra CPU time when the app is backgrounded (e.g. while a song
    // download or load is in flight) so iOS does not suspend it mid-operation.
    // Each "begin" returns a token that the matching "end" must pass back; the
    // expiration handler ends the task itself or iOS terminates the app.
    let backgroundTaskChannel = FlutterMethodChannel(
      name: "com.afalphy.background_task",
      binaryMessenger: registrar!.messenger())

    backgroundTaskChannel.setMethodCallHandler({
      [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      guard let self = self else {
        result(nil)
        return
      }

      switch call.method {
      case "begin":
        let taskId = self.nextFlutterBackgroundTaskId
        self.nextFlutterBackgroundTaskId += 1
        self.flutterBackgroundTasks[taskId] = UIApplication.shared.beginBackgroundTask(
          withName: "flutter_\(taskId)"
        ) {
          DispatchQueue.main.async {
            self.endFlutterBackgroundTask(taskId: taskId)
          }
        }
        result(taskId)

      case "end":
        guard let args = call.arguments as? [String: Any],
          let taskId = args["taskId"] as? Int
        else {
          result(FlutterError(code: "ARG_ERROR", message: "taskId is required", details: nil))
          return
        }
        self.endFlutterBackgroundTask(taskId: taskId)
        result(nil)

      default:
        result(FlutterMethodNotImplemented)
      }
    })

    // Reports the system HTTP proxy (e.g. a Wi-Fi/global HTTP proxy set by a
    // proxy app); Dart reads it via the com.afalphy.system_proxy channel to
    // route Dio and libmpv. VPN-mode (TUN) proxies capture traffic
    // transparently without setting these keys, so this returns nil then.
    let systemProxyChannel = FlutterMethodChannel(
      name: "com.afalphy.system_proxy",
      binaryMessenger: registrar!.messenger())

    systemProxyChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      switch call.method {
      case "getProxy":
        result(Self.getSystemProxy())
      default:
        result(FlutterMethodNotImplemented)
      }
    })

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // HTTPEnable/HTTPProxy/HTTPPort mirror the global HTTP proxy in the system
  // proxy settings (CFNetworkCopySystemProxySettings aggregate dictionary).
  private static func getSystemProxy() -> String? {
    guard
      let settings = CFNetworkCopySystemProxySettings()?.takeRetainedValue()
        as? [String: Any]
    else { return nil }

    let candidates: [(enable: String, host: String, port: String)] = [
      ("HTTPEnable", "HTTPProxy", "HTTPPort"),
      ("HTTPSEnable", "HTTPSProxy", "HTTPSPort"),
    ]

    for candidate in candidates {
      if (settings[candidate.enable] as? NSNumber)?.intValue == 1,
        let host = settings[candidate.host] as? String,
        let port = (settings[candidate.port] as? NSNumber)?.intValue
      {
        return "http://\(host):\(port)"
      }
    }

    return nil
  }

  // Idempotently attaches the long-press context menu to the Flutter view.
  // Widget taps can start the app in the background, where Dart startup still
  // runs but no scene is foreground-active yet; without the activation retry
  // the menu would stay unregistered for that process lifetime.
  private func attachContextMenuInteraction() {
    guard flutterView == nil else { return }

    guard
      let windowScene = UIApplication.shared.connectedScenes
        .first(where: { $0.activationState == .foregroundActive })
        as? UIWindowScene,
      let window = windowScene.windows.first(where: { $0.isKeyWindow }),
      let rootVC = window.rootViewController,
      let flutterView = rootVC.view
    else { return }

    self.flutterView = flutterView
    flutterView.addInteraction(UIContextMenuInteraction(delegate: self))
  }

  @objc private func onDidBecomeActive() {
    attachContextMenuInteraction()
  }

  private func endFlutterBackgroundTask(taskId: Int) {
    guard let identifier = flutterBackgroundTasks.removeValue(forKey: taskId) else { return }
    if identifier != .invalid {
      UIApplication.shared.endBackgroundTask(identifier)
    }
  }

  func contextMenuInteraction(
    _ interaction: UIContextMenuInteraction,
    configurationForMenuAtLocation location: CGPoint
  ) -> UIContextMenuConfiguration? {
    // Smart Routing: Trigger context menu only if the physical long-press coordinate falls within the active Flutter Widget bounds.
    // If coordinates mismatch or no actions available, return nil to pass gestures back to Flutter.
    guard !self.currentMenuActions.isEmpty, self.currentMenuRect.contains(location) else {
      return nil
    }

    return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) {
      [weak self] (suggestedActions) -> UIMenu? in
      guard let self = self else { return UIMenu(title: "", children: []) }

      // Core Logic for Menu Dividers
      var topLevelElements: [UIMenuElement] = []
      var currentGroupActions: [UIAction] = []

      for (index, actionData) in self.currentMenuActions.enumerated() {
        let isDivider = actionData["isDivider"] as? Bool ?? false

        if isDivider {
          // Wrap accumulated actions into an inline flat menu to create a native separator line.
          if !currentGroupActions.isEmpty {
            let groupMenu = UIMenu(
              title: "", options: .displayInline, children: currentGroupActions)
            topLevelElements.append(groupMenu)
            currentGroupActions.removeAll()  // Clear the group array for the next batch.
          }
          continue  // Skip the divider item itself.
        }

        let title = actionData["text"] as? String ?? ""
        var iconImage: UIImage? = nil

        if let iconBytesData = actionData["iconBytes"] as? FlutterStandardTypedData {
          iconImage = UIImage(data: iconBytesData.data, scale: 4.0)
        }

        let action = UIAction(title: title, image: iconImage, identifier: nil) { [weak self] _ in
          self?.menuChannel?.invokeMethod("onMenuItemSelected", arguments: index)
          // Reset data contexts after execution.
          self?.currentMenuActions = []
          self?.currentMenuRect = .zero
        }
        currentGroupActions.append(action)
      }

      // Add remaining actions after looping through the items array.
      if !currentGroupActions.isEmpty {
        let groupMenu = UIMenu(title: "", options: .displayInline, children: currentGroupActions)
        topLevelElements.append(groupMenu)
      }

      // Return composite menus packed with submenus. iOS renders native thin gray lines between groups automatically.
      return UIMenu(title: "", children: topLevelElements)
    }
  }

  func contextMenuInteraction(
    _ interaction: UIContextMenuInteraction,
    previewForHighlightingMenuWithConfiguration configuration: UIContextMenuConfiguration
  ) -> UITargetedPreview? {

    guard let flutterView = self.flutterView,
      self.currentMenuRect != .zero
    else { return nil }

    UIGraphicsBeginImageContextWithOptions(self.currentMenuRect.size, false, UIScreen.main.scale)
    let contextOffset = CGPoint(
      x: -self.currentMenuRect.origin.x, y: -self.currentMenuRect.origin.y)
    flutterView.drawHierarchy(
      in: CGRect(origin: contextOffset, size: flutterView.bounds.size), afterScreenUpdates: false)
    let snapshotImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()

    let mockView = UIImageView(image: snapshotImage)
    mockView.frame = self.currentMenuRect

    flutterView.addSubview(mockView)
    self.previewImageView = mockView

    let parameters = UIPreviewParameters()
    parameters.backgroundColor = .clear

    let relativeRect = CGRect(origin: .zero, size: self.currentMenuRect.size)
    parameters.visiblePath = UIBezierPath(roundedRect: relativeRect, cornerRadius: 12)

    let targetCenter = CGPoint(x: self.currentMenuRect.midX, y: self.currentMenuRect.midY)
    let target = UIPreviewTarget(container: flutterView, center: targetCenter)

    return UITargetedPreview(view: mockView, parameters: parameters, target: target)
  }

  func contextMenuInteraction(
    _ interaction: UIContextMenuInteraction,
    willEndFor configuration: UIContextMenuConfiguration,
    animator: UIContextMenuInteractionAnimating?
  ) {
    // Zero-Delay Dismissal: Instantly rip the mock view out of the host view tree when the dismissal starts.
    // This breaks the rendering pipe, avoiding lingering artifacts while the system closes out the menu.
    if let preview = self.previewImageView {
      preview.removeFromSuperview()  // Unmount from host FlutterView layout tree.
      self.previewImageView = nil
    }

    self.currentMenuRect = .zero
    self.currentMenuActions = []

  }

}
