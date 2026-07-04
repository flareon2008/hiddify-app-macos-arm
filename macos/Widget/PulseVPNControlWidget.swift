import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Control Widget (macOS Control Center)

@main
struct PulseVPNControlWidget: Widget {
    static let kind: String = "com.pulsevpn.app.PulseVPNControl"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: PulseVPNProvider()) { entry in
            PulseVPNControlView(entry: entry)
        }
        .configurationDisplayName("Pulse VPN")
        .description("Toggle VPN connection from Control Center")
        .supportedFamilies([.controlCenter])
    }
}

// MARK: - Timeline Provider

struct PulseVPNProvider: TimelineProvider {
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: "group.com.pulsevpn.app")
    }

    func placeholder(in context: Context) -> PulseVPNEntry {
        PulseVPNEntry(date: Date(), isConnected: false, delay: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (PulseVPNEntry) -> Void) {
        let entry = PulseVPNEntry(
            date: Date(),
            isConnected: sharedDefaults?.bool(forKey: "vpnConnected") ?? false,
            delay: sharedDefaults?.integer(forKey: "vpnDelay") ?? 0
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PulseVPNEntry>) -> Void) {
        let entry = PulseVPNEntry(
            date: Date(),
            isConnected: sharedDefaults?.bool(forKey: "vpnConnected") ?? false,
            delay: sharedDefaults?.integer(forKey: "vpnDelay") ?? 0
        )
        let nextUpdate = Calendar.current.date(byAdding: .second, value: 5, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Timeline Entry

struct PulseVPNEntry: TimelineEntry {
    let date: Date
    let isConnected: Bool
    let delay: Int
}

// MARK: - Control View

struct PulseVPNControlView: View {
    let entry: PulseVPNEntry

    var body: some View {
        Button(intent: ToggleVPNIntent()) {
            HStack(spacing: 6) {
                Image(systemName: entry.isConnected ? "shield.fill" : "shield")
                    .foregroundStyle(entry.isConnected ? .green : .secondary)
                if entry.isConnected && entry.delay > 0 {
                    Text("\(entry.delay)ms")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Text(entry.isConnected ? "ON" : "OFF")
                        .font(.caption)
                        .foregroundStyle(entry.isConnected ? .green : .secondary)
                }
            }
        }
    }
}

// MARK: - App Intent

struct ToggleVPNIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Pulse VPN"
    static var description = IntentDescription("Toggles the VPN connection on or off")

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.com.pulsevpn.app")
        let currentConnected = defaults?.bool(forKey: "vpnConnected") ?? false
        defaults?.set(!currentConnected, forKey: "vpnToggled")

        // Post Darwin notification so the main app picks up the toggle
        let name = "com.pulsevpn.app.toggleVPN" as CFString
        notify_post(name)

        return .result()
    }
}
