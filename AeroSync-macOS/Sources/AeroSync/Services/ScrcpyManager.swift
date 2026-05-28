import Foundation
import Combine

@MainActor
public class ScrcpyManager: ObservableObject {
    public static let shared = ScrcpyManager()
    
    @Published public var isRunning: Bool = false
    @Published public var targetIp: String = "127.0.0.1"
    @Published public var targetPort: String = "5555"
    @Published public var turnScreenOff: Bool = true
    @Published public var stayAwake: Bool = true
    @Published public var enableAudio: Bool = true
    @Published public var maxFps: Int = 60
    @Published public var videoBitrateMbps: Int = 8
    @Published public var lastLog: String = ""
    
    private var process: Process?
    private let scrcpyPath = "/opt/homebrew/bin/scrcpy"
    private let adbPath = "/opt/homebrew/bin/adb"
    
    public init() {}
    
    public func launchScrcpy(ip: String? = nil, port: String? = nil) {
        if isRunning {
            stopScrcpy()
        }
        
        let connectIp = ip ?? targetIp
        let connectPort = port ?? targetPort
        let fps = maxFps
        let bitrate = videoBitrateMbps
        let screenOff = turnScreenOff
        let awake = stayAwake
        let audio = enableAudio
        let scrcpyBin = scrcpyPath
        let adbBin = adbPath
        
        BridgeServer.shared.appendLog("🖥️ Launching scrcpy connection to \(connectIp):\(connectPort)...")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // Step 1: Ensure ADB is connected to this target
            let adbProcess = Process()
            adbProcess.executableURL = URL(fileURLWithPath: adbBin)
            adbProcess.arguments = ["connect", "\(connectIp):\(connectPort)"]
            try? adbProcess.run()
            adbProcess.waitUntilExit()
            
            // Step 2: Spawn scrcpy
            let scrcpy = Process()
            scrcpy.executableURL = URL(fileURLWithPath: scrcpyBin)
            
            var args: [String] = [
                "--tcpip=\(connectIp):\(connectPort)",
                "--window-title=AeroSync — Android Mirror",
                "--max-fps=\(fps)",
                "--video-bit-rate=\(bitrate)M"
            ]
            
            if screenOff {
                args.append("--turn-screen-off")
            }
            if awake {
                args.append("--stay-awake")
            }
            if audio {
                args.append("--audio-codec=opus")
            } else {
                args.append("--no-audio")
            }
            
            scrcpy.arguments = args
            
            let pipe = Pipe()
            scrcpy.standardOutput = pipe
            scrcpy.standardError = pipe
            
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if let str = String(data: data, encoding: .utf8), !str.isEmpty {
                    Task { @MainActor in
                        self?.lastLog = str.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }
            
            scrcpy.terminationHandler = { _ in
                Task { @MainActor in
                    self?.isRunning = false
                    BridgeServer.shared.appendLog("🖥️ scrcpy session closed")
                }
            }
            
            do {
                try scrcpy.run()
                Task { @MainActor in
                    self?.process = scrcpy
                    self?.isRunning = true
                    BridgeServer.shared.appendLog("✅ scrcpy mirror window active")
                }
            } catch {
                Task { @MainActor in
                    self?.isRunning = false
                    BridgeServer.shared.appendLog("❌ Failed to start scrcpy: \(error.localizedDescription)")
                }
            }
        }
    }
    
    public func stopScrcpy() {
        process?.terminate()
        process = nil
        isRunning = false
    }
}
