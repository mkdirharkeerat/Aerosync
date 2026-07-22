import SwiftUI
import AppKit

@main
struct AeroSyncApp: App {
    @StateObject private var bridge = BridgeServer.shared
    @StateObject private var scrcpy = ScrcpyManager.shared
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 780, minHeight: 520)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        
        MenuBarExtra("AeroSync", systemImage: bridge.clientConnected ? "iphone.badge.checkmark" : "iphone") {
            VStack(alignment: .leading, spacing: 6) {
                Text("AeroSync — Android Continuity")
                    .font(.headline)
                
                Divider()
                
                if bridge.clientConnected {
                    Text("Device: \(bridge.device.name)")
                    Text("Battery: \(bridge.device.batteryLevel)%")
                    if let ip = bridge.device.tailscaleIp {
                        Text("Tailscale: \(ip)")
                    }
                } else {
                    Text("No Phone Connected")
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                if scrcpy.isRunning {
                    Button("Stop Screen Mirror") {
                        scrcpy.stopScrcpy()
                    }
                } else {
                    Button("Launch Screen Mirror") {
                        scrcpy.launchScrcpy()
                    }
                }
                
                if let call = bridge.currentCall {
                    Divider()
                    Text("📞 Call: \(call.contactName ?? call.phoneNumber)")
                    Button("Answer Call") {
                        bridge.answerCall()
                    }
                    Button("Decline Call") {
                        bridge.rejectCall()
                    }
                }
                
                Divider()
                
                Button("Quit AeroSync") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
    }
}
