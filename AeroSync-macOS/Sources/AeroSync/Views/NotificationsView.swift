import SwiftUI
import AppKit

public struct NotificationsView: View {
    @ObservedObject var bridge = BridgeServer.shared
    @State private var replyTexts: [String: String] = [:]
    @State private var copiedOtpId: String? = nil
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mirrored Notifications")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Real-time notifications from your Android device with instant OTP copy and inline replies.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                if !bridge.notifications.isEmpty {
                    Button("Clear All") {
                        bridge.notifications.removeAll()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding([.horizontal, .top])
            
            if bridge.notifications.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "bell.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No Notifications Yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Notifications received on your Android phone will appear here in real-time.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    ForEach(bridge.notifications) { item in
                        NotificationCard(
                            item: item,
                            replyText: Binding(
                                get: { replyTexts[item.id] ?? "" },
                                set: { replyTexts[item.id] = $0 }
                            ),
                            isCopied: copiedOtpId == item.id,
                            onCopyOtp: { otp in
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(otp, forType: .string)
                                withAnimation {
                                    copiedOtpId = item.id
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    if copiedOtpId == item.id {
                                        copiedOtpId = nil
                                    }
                                }
                            },
                            onSendReply: { text in
                                bridge.replyToNotification(id: item.id, text: text)
                                replyTexts[item.id] = ""
                            }
                        )
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}

struct NotificationCard: View {
    let item: MirroredNotification
    @Binding var replyText: String
    let isCopied: Bool
    let onCopyOtp: (String) -> Void
    let onSendReply: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: appIcon(for: item.appName))
                    .foregroundColor(.accentColor)
                    .font(.title3)
                
                Text(item.appName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(DateFormatter.localizedString(from: item.timestamp, dateStyle: .none, timeStyle: .short))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text(item.title)
                .font(.headline)
            
            Text(item.message)
                .font(.body)
                .foregroundColor(.primary)
            
            // OTP Highlight Card
            if let otp = item.otpCode {
                HStack(spacing: 12) {
                    Image(systemName: "key.fill")
                        .foregroundColor(.yellow)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Detected Verification Code")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(otp)
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                    }
                    
                    Spacer()
                    
                    Button(action: { onCopyOtp(otp) }) {
                        Label(isCopied ? "Copied!" : "Copy OTP", systemImage: isCopied ? "checkmark" : "doc.on.doc")
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(isCopied ? Color.green : Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
            }
            
            // Inline Quick Reply
            if item.canReply {
                HStack {
                    TextField("Reply to \(item.title)...", text: $replyText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            if !replyText.isEmpty {
                                onSendReply(replyText)
                            }
                        }
                    
                    Button("Send") {
                        if !replyText.isEmpty {
                            onSendReply(replyText)
                        }
                    }
                    .disabled(replyText.isEmpty)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.windowBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.08), lineWidth: 1))
    }
    
    private func appIcon(for app: String) -> String {
        switch app.lowercased() {
        case let a where a.contains("whatsapp"): return "message.fill"
        case let a where a.contains("telegram"): return "paperplane.fill"
        case let a where a.contains("message"): return "bubble.left.and.bubble.right.fill"
        case let a where a.contains("mail") || a.contains("gmail"): return "envelope.fill"
        default: return "app.badge.fill"
        }
    }
}
