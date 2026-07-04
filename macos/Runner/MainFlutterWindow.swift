import Cocoa
import FlutterMacOS
import window_manager
import LaunchAtLogin

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Add FlutterMethodChannel platform code - launch at startup
    FlutterMethodChannel(
      name: "launch_at_startup", binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    .setMethodCallHandler { (_ call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "launchAtStartupIsEnabled":
        result(LaunchAtLogin.isEnabled)
      case "launchAtStartupSetEnabled":
        if let arguments = call.arguments as? [String: Any] {
          LaunchAtLogin.isEnabled = arguments["setEnabledValue"] as! Bool
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // Dock visibility channel - hide/show from macOS Dock
    FlutterMethodChannel(
      name: "com.hiddify/dock_visibility", binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    .setMethodCallHandler { (_ call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "setDockVisibility":
        if let args = call.arguments as? [String: Any],
           let visible = args["visible"] as? Bool {
          DispatchQueue.main.async {
            if visible {
              NSApp.setActivationPolicy(.regular)
            } else {
              NSApp.setActivationPolicy(.accessory)
            }
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

    // Widget sync channel - communicates with Control Center widget via shared App Group UserDefaults
    let widgetChannel = FlutterMethodChannel(
      name: "com.hiddify/widget_sync", binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    widgetChannel.setMethodCallHandler { (_ call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "updateStatus":
        if let args = call.arguments as? [String: Any],
           let connected = args["connected"] as? Bool,
           let delay = args["delay"] as? Int {
          let defaults = UserDefaults(suiteName: "group.com.pulsevpn.app")
          defaults?.set(connected, forKey: "vpnConnected")
          defaults?.set(delay, forKey: "vpnDelay")
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
        }
      case "checkToggleRequest":
        let defaults = UserDefaults(suiteName: "group.com.pulsevpn.app")
        let toggled = defaults?.bool(forKey: "vpnToggled") ?? false
        if toggled {
          defaults?.set(false, forKey: "vpnToggled")
          result(true)
        } else {
          result(false)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  // window manager hidden at launch
  override public func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
    super.order(place, relativeTo: otherWin)
    hiddenWindowAtLaunch()
  }
}
