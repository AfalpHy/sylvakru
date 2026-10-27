import CFNetwork
import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var menuChannel: FlutterMethodChannel?

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationShouldHandleReopen(
    _ sender: NSApplication,
    hasVisibleWindows flag: Bool
  ) -> Bool {

    if !flag {
      if let window = mainFlutterWindow {
        window.makeKeyAndOrderFront(self)
        NSApp.activate(ignoringOtherApps: true)
      }
    }

    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    let controller = mainFlutterWindow?.contentViewController as? FlutterViewController

    menuChannel = FlutterMethodChannel(
      name: "com.afalphy.menu",
      binaryMessenger: controller!.engine.binaryMessenger
    )

    menuChannel?.setMethodCallHandler { (call, result) in
      if call.method == "showNativeMenu" {
        let args = call.arguments as? [String: Any]
        let items = args?["items"] as? [[String: Any]] ?? []
        self.showNativeMenu(items: items)
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    // Reports the system HTTP proxy (written by proxy apps' "System Proxy"
    // toggle); Dart reads it via the com.afalphy.system_proxy channel to
    // route Dio and libmpv.
    let systemProxyChannel = FlutterMethodChannel(
      name: "com.afalphy.system_proxy",
      binaryMessenger: controller!.engine.binaryMessenger
    )

    systemProxyChannel.setMethodCallHandler { (call, result) in
      if call.method == "getProxy" {
        result(Self.getSystemProxy())
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    super.applicationDidFinishLaunching(notification)
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

  func showNativeMenu(items: [[String: Any]]) {
    let menu = NSMenu()

    for (index, item) in items.enumerated() {
      let isDivider = item["isDivider"] as? Bool ?? false

      if isDivider {
        menu.addItem(NSMenuItem.separator())
      } else {
        let title = item["text"] as? String ?? ""

        let menuItem = NSMenuItem(
          title: title,
          action: #selector(menuItemClicked(_:)),
          keyEquivalent: ""
        )

        if let iconData = item["iconBytes"] as? FlutterStandardTypedData {
          menuItem.image = NSImage(data: iconData.data)
          menuItem.image?.size = NSSize(width: 18, height: 18)

          if #available(macOS 27.0, *) {
            menuItem.preferredImageVisibility = .visible
          }
        }

        menuItem.tag = index
        menuItem.target = self

        menu.addItem(menuItem)
      }
    }

    menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
  }

  @objc
  func menuItemClicked(_ sender: NSMenuItem) {
    menuChannel?.invokeMethod(
      "onMenuItemSelected",
      arguments: sender.tag
    )
  }
}
