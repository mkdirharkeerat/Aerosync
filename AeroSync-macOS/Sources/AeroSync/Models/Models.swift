import Foundation

// MARK: - Connection & Device Models
public enum ConnectionStatus: String, Codable, Sendable {
    case disconnected = "Disconnected"
    case connecting = "Connecting..."
    case connected = "Connected"
    case error = "Connection Error"
}

public enum ConnectionMode: String, Codable, Sendable {
    case tailscale = "Tailscale Mesh"
    case localWifi = "Local Wi-Fi"
    case usb = "Direct USB"
}

public struct DeviceState: Codable, Sendable {
    public var name: String
    public var ipAddress: String
    public var tailscaleIp: String?
    public var batteryLevel: Int
    public var isCharging: Bool
    public var connectionMode: ConnectionMode
    public var status: ConnectionStatus
    public var isBluetoothAudioPaired: Bool
    
    public init(
        name: String = "Android Device",
        ipAddress: String = "127.0.0.1",
        tailscaleIp: String? = nil,
        batteryLevel: Int = 100,
        isCharging: Bool = false,
        connectionMode: ConnectionMode = .localWifi,
        status: ConnectionStatus = .disconnected,
        isBluetoothAudioPaired: Bool = false
    ) {
        self.name = name
        self.ipAddress = ipAddress
        self.tailscaleIp = tailscaleIp
        self.batteryLevel = batteryLevel
        self.isCharging = isCharging
        self.connectionMode = connectionMode
        self.status = status
        self.isBluetoothAudioPaired = isBluetoothAudioPaired
    }
}

// MARK: - Telephony & Call Models
public enum CallStatus: String, Codable, Sendable {
    case idle = "IDLE"
    case ringing = "RINGING"
    case active = "ACTIVE"
    case ended = "ENDED"
}

public struct CallEvent: Identifiable, Codable, Sendable {
    public var id: String
    public var contactName: String?
    public var phoneNumber: String
    public var status: CallStatus
    public var timestamp: Date
    public var durationSeconds: Int
    
    public init(
        id: String = UUID().uuidString,
        contactName: String? = nil,
        phoneNumber: String,
        status: CallStatus = .ringing,
        timestamp: Date = Date(),
        durationSeconds: Int = 0
    ) {
        self.id = id
        self.contactName = contactName
        self.phoneNumber = phoneNumber
        self.status = status
        self.timestamp = timestamp
        self.durationSeconds = durationSeconds
    }
}

// MARK: - Notification Models
public struct MirroredNotification: Identifiable, Codable, Sendable {
    public var id: String
    public var appName: String
    public var packageName: String
    public var title: String
    public var message: String
    public var timestamp: Date
    public var otpCode: String?
    public var canReply: Bool
    
    public init(
        id: String = UUID().uuidString,
        appName: String,
        packageName: String,
        title: String,
        message: String,
        timestamp: Date = Date(),
        otpCode: String? = nil,
        canReply: Bool = false
    ) {
        self.id = id
        self.appName = appName
        self.packageName = packageName
        self.title = title
        self.message = message
        self.timestamp = timestamp
        self.otpCode = otpCode
        self.canReply = canReply
    }
}

// MARK: - IPC Wire Protocol Message
public struct AeroPacket: Codable, Sendable {
    public var type: String
    public var payload: String
    public var timestamp: TimeInterval
    
    public init(type: String, payload: String) {
        self.type = type
        self.payload = payload
        self.timestamp = Date().timeIntervalSince1970
    }
}
