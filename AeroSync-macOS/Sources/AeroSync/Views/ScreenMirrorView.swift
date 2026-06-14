import SwiftUI

public struct ScreenMirrorView: View {
    @ObservedObject var scrcpy = ScrcpyManager.shared
    @ObservedObject var bridge = BridgeServer.shared
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Card
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Android Screen Mirror")
                            .font(.title2)
                            .fontWeight(.bold)
                        Spacer()
                        
                        // Status indicator
                        HStack(spacing: 6) {
                            Circle()
                                .fill(scrcpy.isRunning ? Color.green : Color.secondary)
                                .frame(width: 8, height: 8)
                            Text(scrcpy.isRunning ? "Mirroring Active" : "Idle")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color(.controlBackgroundColor)))
                    }
                    
                    Text("Powered by native scrcpy engine with low-latency H.264/Opus streaming over Tailscale or Wi-Fi.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.windowBackgroundColor)))
                
                // Target Connection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Target Device")
                        .font(.headline)
                    
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("IP Address (Wi-Fi or Tailscale 100.x.y.z)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("127.0.0.1", text: $scrcpy.targetIp)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Port")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("5555", text: $scrcpy.targetPort)
                                .frame(width: 80)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        if let tailscaleIp = bridge.device.tailscaleIp, !tailscaleIp.isEmpty {
                            Button("Use Tailscale IP") {
                                scrcpy.targetIp = tailscaleIp
                            }
                            .buttonStyle(.bordered)
                            .padding(.top, 16)
                        }
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.windowBackgroundColor)))
                
                // Performance & Power Options
                VStack(alignment: .leading, spacing: 14) {
                    Text("Display & Power Controls")
                        .font(.headline)
                    
                    Toggle(isOn: $scrcpy.turnScreenOff) {
                        VStack(alignment: .leading) {
                            Text("Turn Off Phone Screen while Mirroring")
                                .font(.body)
                            Text("Saves battery and keeps the physical device cool during long sessions.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Toggle(isOn: $scrcpy.stayAwake) {
                        VStack(alignment: .leading) {
                            Text("Keep Android Device Awake")
                                .font(.body)
                            Text("Prevents phone from locking or going to sleep while connected.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Toggle(isOn: $scrcpy.enableAudio) {
                        VStack(alignment: .leading) {
                            Text("Forward Device Audio (Opus codec)")
                                .font(.body)
                            Text("Streams Android system and media audio directly to your Mac.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("Framerate Limit:")
                        Spacer()
                        Picker("", selection: $scrcpy.maxFps) {
                            Text("30 FPS (Power Saver)").tag(30)
                            Text("60 FPS (Smooth)").tag(60)
                            Text("120 FPS (Pro)").tag(120)
                        }
                        .frame(width: 180)
                    }
                    
                    HStack {
                        Text("Bitrate: \(scrcpy.videoBitrateMbps) Mbps")
                        Slider(value: Binding(
                            get: { Double(scrcpy.videoBitrateMbps) },
                            set: { scrcpy.videoBitrateMbps = Int($0) }
                        ), in: 2...24, step: 2)
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.windowBackgroundColor)))
                
                // Action Buttons
                HStack(spacing: 16) {
                    if scrcpy.isRunning {
                        Button(role: .destructive, action: { scrcpy.stopScrcpy() }) {
                            Label("Stop Screen Mirror", systemImage: "stop.fill")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button(action: { scrcpy.launchScrcpy() }) {
                            Label("Start Screen Mirror", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(.top, 8)
            }
            .padding()
        }
    }
}
