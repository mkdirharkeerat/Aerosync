import Foundation
import Network
import Combine
import UserNotifications
import AppKit

@MainActor
public class BridgeServer: ObservableObject {
    public static let shared = BridgeServer()
    
    @Published public var device: DeviceState = DeviceState()
    @Published public var currentCall: CallEvent? = nil
    @Published public var notifications: [MirroredNotification] = []
    @Published public var terminalLogs: [String] = []
    @Published public var serverPort: UInt16 = 8920
    @Published public var isServerRunning: Bool = false
    @Published public var clientConnected: Bool = false
    
    private var listener: NWListener?
    private var activeConnection: NWConnection?
    private let queue = DispatchQueue(label: "com.aerosync.server", qos: .userInitiated)
    
    public init() {
        setupLocalNotificationPermissions()
    }
    
    public func startServer(port: UInt16 = 8920) {
        self.serverPort = port
        do {
            let parameters = NWParameters.tcp
            let wsOptions = NWProtocolWebSocket.Options()
            wsOptions.autoReplyPing = true
            parameters.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)
            
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
            listener?.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    switch state {
                    case .ready:
                        self?.isServerRunning = true
                        self?.appendLog("🚀 AeroSync Bridge Server active on port \(port)")
                    case .failed(let error):
                        self?.isServerRunning = false
                        self?.appendLog("❌ Bridge Server failed: \(error.localizedDescription)")
                    case .cancelled:
                        self?.isServerRunning = false
                        self?.appendLog("⏹ Bridge Server stopped")
                    default:
                        break
                    }
                }
            }
            
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleIncomingConnection(connection)
            }
            
            listener?.start(queue: queue)
        } catch {
            appendLog("❌ Failed to bind server: \(error.localizedDescription)")
        }
    }
    
    public func stopServer() {
        listener?.cancel()
        activeConnection?.cancel()
        isServerRunning = false
        clientConnected = false
    }
    
    nonisolated private func handleIncomingConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                switch state {
                case .ready:
                    self?.activeConnection = connection
                    self?.clientConnected = true
                    self?.device.status = .connected
                    self?.appendLog("📱 Android Companion Connected from \(connection.endpoint)")
                    self?.receiveNextPacket(on: connection)
                case .failed(let err):
                    self?.clientConnected = false
                    self?.device.status = .disconnected
                    self?.appendLog("⚠️ Connection error: \(err.localizedDescription)")
                case .cancelled:
                    self?.clientConnected = false
                    self?.device.status = .disconnected
                    self?.appendLog("📱 Client Disconnected")
                default:
                    break
                }
            }
        }
        connection.start(queue: queue)
    }
    
    nonisolated private func receiveNextPacket(on connection: NWConnection) {
        connection.receiveMessage { [weak self] (content, context, isComplete, error) in
            if let data = content, let text = String(data: data, encoding: .utf8) {
                Task { @MainActor [weak self] in
                    self?.processIncomingMessage(text)
                }
            }
            
            if error == nil {
                self?.receiveNextPacket(on: connection)
            }
        }
    }
    
    private func processIncomingMessage(_ rawJson: String) {
        guard let data = rawJson.data(using: .utf8),
              let packet = try? JSONDecoder().decode(AeroPacket.self, from: data) else {
            return
        }
        
        switch packet.type {
        case "HANDSHAKE":
            handleHandshake(packet.payload)
        case "CALL_STATE":
            handleCallState(packet.payload)
        case "NOTIFICATION":
            handleIncomingNotification(packet.payload)
        case "TERMINAL_EXEC":
            handleRemoteTerminalCommand(packet.payload)
        case "PING":
            sendPacket(AeroPacket(type: "PONG", payload: "OK"))
        default:
            appendLog("Unknown packet type: \(packet.type)")
        }
    }
    
    private func handleHandshake(_ payload: String) {
        struct HandshakePayload: Codable {
            let deviceName: String
            let batteryLevel: Int
            let isCharging: Bool
            let tailscaleIp: String?
        }
        if let data = payload.data(using: .utf8),
           let info = try? JSONDecoder().decode(HandshakePayload.self, from: data) {
            device.name = info.deviceName
            device.batteryLevel = info.batteryLevel
            device.isCharging = info.isCharging
            device.tailscaleIp = info.tailscaleIp
            device.status = .connected
            appendLog("✅ Handshake successful: \(info.deviceName) (Battery: \(info.batteryLevel)%)")
        }
    }
    
    private func handleCallState(_ payload: String) {
        struct CallPayload: Codable {
            let status: String
            let number: String
            let name: String?
        }
        guard let data = payload.data(using: .utf8),
              let info = try? JSONDecoder().decode(CallPayload.self, from: data) else { return }
        
        switch info.status {
        case "RINGING":
            currentCall = CallEvent(
                contactName: info.name,
                phoneNumber: info.number,
                status: .ringing
            )
            triggerCallHUD(caller: info.name ?? info.number)
            appendLog("📞 Incoming call from: \(info.name ?? info.number)")
        case "ACTIVE":
            if var call = currentCall {
                call.status = .active
                currentCall = call
            }
            appendLog("🟢 Call connected with \(info.name ?? info.number)")
        case "IDLE":
            currentCall = nil
            appendLog("⚪ Call ended")
        default:
            break
        }
    }
    
    private func handleIncomingNotification(_ payload: String) {
        guard let data = payload.data(using: .utf8),
              let notif = try? JSONDecoder().decode(MirroredNotification.self, from: data) else { return }
        
        var updated = notif
        if let otp = extractOTP(from: notif.message) {
            updated.otpCode = otp
        }
        
        notifications.insert(updated, at: 0)
        showLocalNotification(notification: updated)
        appendLog("🔔 [\(updated.appName)] \(updated.title): \(updated.message.prefix(40))...")
    }
    
    private func handleRemoteTerminalCommand(_ command: String) {
        appendLog("📟 [Remote Phone Exec] \(command)")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", command]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                
                Task { @MainActor [weak self] in
                    self?.appendLog("➜ Output:\n\(output)")
                    self?.sendPacket(AeroPacket(type: "TERMINAL_RESPONSE", payload: output))
                }
            } catch {
                Task { @MainActor [weak self] in
                    self?.appendLog("❌ Exec error: \(error.localizedDescription)")
                    self?.sendPacket(AeroPacket(type: "TERMINAL_RESPONSE", payload: "Error: \(error.localizedDescription)"))
                }
            }
        }
    }
    
    // MARK: - Outgoing Actions to Android Phone
    public func dialPhoneNumber(_ number: String) {
        sendPacket(AeroPacket(type: "CALL_DIAL", payload: number))
        appendLog("📲 Dialing \(number) on phone...")
    }
    
    public func answerCall() {
        sendPacket(AeroPacket(type: "CALL_ACTION", payload: "ANSWER"))
        if var call = currentCall {
            call.status = .active
            currentCall = call
        }
        appendLog("📞 Answered call on Mac")
    }
    
    public func rejectCall() {
        sendPacket(AeroPacket(type: "CALL_ACTION", payload: "REJECT"))
        currentCall = nil
        appendLog("🛑 Rejected call on Mac")
    }
    
    public func replyToNotification(id: String, text: String) {
        struct ReplyPayload: Codable {
            let id: String
            let text: String
        }
        if let json = try? JSONEncoder().encode(ReplyPayload(id: id, text: text)),
           let jsonStr = String(data: json, encoding: .utf8) {
            sendPacket(AeroPacket(type: "NOTIFICATION_REPLY", payload: jsonStr))
            appendLog("💬 Sent reply for notification \(id)")
        }
    }
    
    private func sendPacket(_ packet: AeroPacket) {
        guard let data = try? JSONEncoder().encode(packet),
              let connection = activeConnection else { return }
        
        let message = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(identifier: "wsMessage", metadata: [message])
        
        connection.send(content: data, contentContext: context, isComplete: true, completion: .idempotent)
    }
    
    public func appendLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        terminalLogs.append("[\(timestamp)] \(message)")
        if terminalLogs.count > 500 {
            terminalLogs.removeFirst()
        }
    }
    
    private func extractOTP(from text: String) -> String? {
        let pattern = #"(?i)(?:code|otp|pin|is|verification)\s*(?:is|:)?\s*([0-9]{4,8})\b"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let nsString = text as NSString
            let results = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
            if let match = results.first, match.numberOfRanges > 1 {
                return nsString.substring(with: match.range(at: 1))
            }
        }
        return nil
    }
    
    private func setupLocalNotificationPermissions() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }
    
    private func showLocalNotification(notification: MirroredNotification) {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let content = UNMutableNotificationContent()
        content.title = "\(notification.appName) — \(notification.title)"
        content.body = notification.message
        content.sound = .default
        
        if let otp = notification.otpCode {
            content.subtitle = "🔑 Verification Code: \(otp)"
        }
        
        let request = UNNotificationRequest(identifier: notification.id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    private func triggerCallHUD(caller: String) {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let content = UNMutableNotificationContent()
        content.title = "📞 Incoming Phone Call"
        content.body = "\(caller) is calling your Android phone"
        content.sound = .defaultCritical
        let request = UNNotificationRequest(identifier: "incoming_call", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
