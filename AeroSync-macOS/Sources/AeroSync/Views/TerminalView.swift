import SwiftUI

public struct TerminalView: View {
    @ObservedObject var bridge = BridgeServer.shared
    @State private var localCommand: String = ""
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Remote Terminal & Gateway")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Your Android phone can run authenticated shell and agy commands remotely over Tailscale.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding([.horizontal, .top])
            
            // Preset Quick Triggers
            HStack(spacing: 8) {
                Text("Quick Scripts:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button("Sleep Display") {
                    runCommand("pmset displaysleepnow")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("Mac Uptime") {
                    runCommand("uptime")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("Check Agy CLI") {
                    runCommand("~/.local/bin/agy --version")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal)
            
            // Terminal Output Console Box
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(bridge.terminalLogs.enumerated()), id: \.offset) { index, log in
                            Text(log)
                                .font(.system(size: 12, weight: .regular, design: .monospaced))
                                .foregroundColor(logColor(for: log))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(index)
                        }
                    }
                    .padding(12)
                }
                .background(Color.black.opacity(0.85))
                .cornerRadius(10)
                .padding(.horizontal)
                .onChange(of: bridge.terminalLogs.count) { _, _ in
                    if let last = bridge.terminalLogs.indices.last {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
            
            // Manual Test Input Box
            HStack {
                Text("❯")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.green)
                
                TextField("Run shell or agy command...", text: $localCommand)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit {
                        executeCurrentCommand()
                    }
                
                Button("Execute") {
                    executeCurrentCommand()
                }
                .disabled(localCommand.isEmpty)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(.controlBackgroundColor)))
            .padding([.horizontal, .bottom])
        }
    }
    
    private func executeCurrentCommand() {
        guard !localCommand.isEmpty else { return }
        let cmd = localCommand
        localCommand = ""
        runCommand(cmd)
    }
    
    private func runCommand(_ cmd: String) {
        bridge.appendLog("❯ \(cmd)")
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", cmd]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                Task { @MainActor in
                    bridge.appendLog(output)
                }
            } catch {
                Task { @MainActor in
                    bridge.appendLog("❌ Error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func logColor(for log: String) -> Color {
        if log.contains("❌") || log.contains("Error") { return .red }
        if log.contains("✅") || log.contains("🚀") { return .green }
        if log.contains("📞") || log.contains("📱") { return .cyan }
        if log.contains("🔔") { return .yellow }
        return .white.opacity(0.9)
    }
}
