import SwiftUI

public struct SettingsView: View {
    @ObservedObject var bridge = BridgeServer.shared
    @State private var portText: String = "8920"
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Connection & Setup")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Configure your networking, Tailscale mesh, and Bluetooth audio bridge.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Server Config Card
                VStack(alignment: .leading, spacing: 14) {
                    Text("AeroSync Bridge Server")
                        .font(.headline)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Server Status")
                                .font(.body)
                            Text(bridge.isServerRunning ? "Listening on port \(bridge.serverPort)" : "Server stopped")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        
                        Button(bridge.isServerRunning ? "Restart Server" : "Start Server") {
                            if let port = UInt16(portText) {
                                bridge.stopServer()
                                bridge.startServer(port: port)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    HStack {
                        Text("Port Number:")
                        TextField("8920", text: $portText)
                            .frame(width: 80)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.windowBackgroundColor)))
                
                // Tailscale Mesh Setup Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "network")
                            .foregroundColor(.blue)
                        Text("Tailscale Mesh Connectivity (Mobile Data & Remote Wi-Fi)")
                            .font(.headline)
                    }
                    
                    Text("Tailscale allows your Mac and Android phone to communicate anywhere in the world on cellular 5G/LTE or remote Wi-Fi with no port forwarding.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Label("1. Install Tailscale from Google Play on your Android phone.", systemImage: "1.circle.fill")
                        Label("2. Sign in with the same account on both Mac and phone.", systemImage: "2.circle.fill")
                        Label("3. Enter your Mac's Tailscale IP (100.x.y.z) in the companion app.", systemImage: "3.circle.fill")
                    }
                    .font(.callout)
                    .foregroundColor(.primary)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.windowBackgroundColor)))
                
                // Audio Routing Guide Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "headphones")
                            .foregroundColor(.purple)
                        Text("Call Voice Audio Routing")
                            .font(.headline)
                    }
                    
                    Text("Note on macOS: macOS identifies as an Audio Source / Computer and does not support acting as a Bluetooth Hands-Free (HFP) headset for Android. AeroSync handles complete call signaling (HUD, dialer, answer/decline).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Best setup: Use Multipoint Bluetooth earbuds/headphones connected to both Mac and phone.", systemImage: "star.fill")
                        Label("When you answer/dial on Mac via AeroSync, call audio stays on your headset.", systemImage: "1.circle.fill")
                        Label("Alternatively, select phone speakerphone or connect a physical audio bridge.", systemImage: "2.circle.fill")
                    }
                    .font(.callout)
                    .foregroundColor(.primary)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.windowBackgroundColor)))
                
                // Wireless ADB Pairing Guide Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "terminal")
                            .foregroundColor(.green)
                        Text("Wireless ADB Setup (One-time)")
                            .font(.headline)
                    }
                    
                    Text("For screen mirroring (`scrcpy`) over Wi-Fi on Android 11+:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("1. On phone: `Settings > Developer Options > Wireless Debugging`")
                        Text("2. Tap `Pair device with pairing code`")
                        Text("3. On Mac terminal: `adb pair <IP>:<PORT> <CODE>`")
                        Text("4. Once paired: `adb connect <IP>:<PORT>`")
                    }
                    .font(.system(.caption, design: .monospaced))
                    .padding(8)
                    .background(Color.black.opacity(0.1))
                    .cornerRadius(6)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.windowBackgroundColor)))
            }
            .padding()
        }
    }
}
