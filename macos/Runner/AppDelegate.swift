import Cocoa
import FlutterMacOS

import UserNotifications
@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    // https://github.com/leanflutter/window_manager/issues/214
    return false
  }
  
  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
  override func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Request notification authorization
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge]) { granted, error in
            if let error = error {
                print("Error requesting notification authorization: \(error)")
            }
        }
    
    // Set up dock visibility channel
    let controller = NSApplication.shared.mainWindow?.contentViewController as? FlutterViewController
    if let controller = controller {
      let channel = FlutterMethodChannel(name: "com.hiddify/dock_visibility", binaryMessenger: controller.engine.binaryMessenger)
      channel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
        switch call.method {
        case "setDockVisibility":
          if let args = call.arguments as? [String: Any],
             let visible = args["visible"] as? Bool {
            if visible {
              // Show in dock - Regular application
              NSApp.setActivationPolicy(.regular)
            } else {
              // Hide from dock - Accessory application (only menu bar)
              NSApp.setActivationPolicy(.accessory)
            }
            result(nil)
          } else {
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
          }
        case "getDockVisibility":
          let isRegular = NSApp.activationPolicy() == .regular
          result(isRegular)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }

  // // window manager restore from dock: https://leanflutter.dev/blog/click-dock-icon-to-restore-after-closing-the-window
  // override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
  //     if !flag {
  //         for window in NSApp.windows {
  //             if !window.isVisible {
  //                 window.setIsVisible(true)
  //             }
  //             window.makeKeyAndOrderFront(self)
  //             NSApp.activate(ignoringOtherApps: true)
  //         }
  //     }
  //     return true
  // }
}
