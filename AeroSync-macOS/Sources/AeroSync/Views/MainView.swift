import SwiftUI

public enum NavigationTab: String, CaseIterable, Identifiable {
    case mirror = "Screen Mirror"
    case dialer = "Phone & Dialer"
    case notifications = "Notifications"
    case terminal = "Terminal & Shell"
    case settings = "Settings"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .mirror: return "iphone.gen3"
        case .dialer: return "phone.fill"
        case .notifications: return "bell.badge.fill"
        case .terminal: return "terminal.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

public struct MainView: View {
    @ObservedObject var bridge = BridgeServer.shared
    @State private var selectedTab: NavigationTab? = .mirror
    
    public init() {}
    
    public var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                // Device Status Card in Sidebar Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Image(systemName: "iphone")
                            .font(.title2)
                            .foregroundColor(bridge.clientConnected ? .green : .secondary)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(bridge.device.name)
                                .font(.headline)
                                .lineLimit(1)
                            
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(bridge.clientConnected ? Color.green : Color.red)
                                    .frame(width: 6, height: 6)
                                Text(bridge.clientConnected ? "Connected" : "Waiting for companion...")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    if bridge.clientConnected {
                        HStack(spacing: 12) {
                            Label("\(bridge.device.batteryLevel)%", systemImage: batteryIcon(for: bridge.device.batteryLevel, charging: bridge.device.isCharging))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            if let ip = bridge.device.tailscaleIp {
                                Text("Mesh: \(ip)")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.04))
                
                Divider()
                
                // Sidebar Navigation Items
                List(NavigationTab.allCases, selection: $selectedTab) { tab in
                    NavigationLink(value: tab) {
                        Label {
                            HStack {
                                Text(tab.rawValue)
                                Spacer()
                                if tab == .notifications && !bridge.notifications.isEmpty {
                                    Text("\(bridge.notifications.count)")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Color.red))
                                        .foregroundColor(.white)
                                }
                                if tab == .dialer && bridge.currentCall != nil {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 8, height: 8)
                                }
                            }
                        } icon: {
                            Image(systemName: tab.icon)
                        }
                    }
                }
                .listStyle(.sidebar)
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 300)
        } detail: {
            Group {
                switch selectedTab {
                case .mirror:
                    ScreenMirrorView()
                case .dialer:
                    DialerView()
                case .notifications:
                    NotificationsView()
                case .terminal:
                    TerminalView()
                case .settings:
                    SettingsView()
                case .none:
                    Text("Select an item")
                }
            }
            .frame(minWidth: 500, minHeight: 450)
        }
        .onAppear {
            if !bridge.isServerRunning {
                bridge.startServer()
            }
        }
    }
    
    private func batteryIcon(for level: Int, charging: Bool) -> String {
        if charging { return "battery.100.bolt" }
        switch level {
        case 75...100: return "battery.100"
        case 50..<75: return "battery.75"
        case 25..<50: return "battery.50"
        default: return "battery.25"
        }
    }
}
