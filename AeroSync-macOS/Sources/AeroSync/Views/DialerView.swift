import SwiftUI

public struct DialerView: View {
    @ObservedObject var bridge = BridgeServer.shared
    @State private var inputNumber: String = ""
    
    let keypad: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["*", "0", "#"]
    ]
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 20) {
            // Incoming / Active Call HUD Banner
            if let call = bridge.currentCall {
                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        Image(systemName: call.status == .ringing ? "phone.down.waves.left.and.right" : "phone.fill")
                            .font(.system(size: 32))
                            .foregroundColor(call.status == .ringing ? .orange : .green)
                            .symbolEffect(.pulse, isActive: call.status == .ringing)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(call.contactName ?? call.phoneNumber)
                                .font(.headline)
                            Text(call.status == .ringing ? "Incoming Call on Android..." : "Call in Progress (Controlled via AeroSync)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if call.status == .ringing {
                            Button(action: { bridge.answerCall() }) {
                                Label("Answer", systemImage: "phone.fill")
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Button(action: { bridge.rejectCall() }) {
                            Label(call.status == .ringing ? "Decline" : "Hang Up", systemImage: "phone.down.fill")
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color(.windowBackgroundColor).opacity(0.8)))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                }
                .padding(.horizontal)
            }
            
            // Audio Routing Status Bar
            HStack(spacing: 8) {
                Image(systemName: "headphones")
                    .foregroundColor(.blue)
                Text("Audio Routing:")
                    .font(.caption)
                    .fontWeight(.medium)
                Text("Use Multipoint Bluetooth headset or phone speakerphone")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            
            // Number Display Box
            HStack {
                TextField("Enter phone number...", text: $inputNumber)
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                
                if !inputNumber.isEmpty {
                    Button(action: { inputNumber = String(inputNumber.dropLast()) }) {
                        Image(systemName: "delete.left.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.controlBackgroundColor)))
            .padding(.horizontal, 40)
            
            // Keypad Grid
            VStack(spacing: 12) {
                ForEach(keypad, id: \.self) { row in
                    HStack(spacing: 24) {
                        ForEach(row, id: \.self) { digit in
                            Button(action: { inputNumber.append(digit) }) {
                                Text(digit)
                                    .font(.title2)
                                    .fontWeight(.medium)
                                    .frame(width: 60, height: 60)
                                    .background(Circle().fill(Color(.controlColor)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            
            // Call Action Button
            Button(action: {
                guard !inputNumber.isEmpty else { return }
                bridge.dialPhoneNumber(inputNumber)
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "phone.fill")
                    Text("Call via Phone")
                        .fontWeight(.semibold)
                }
                .frame(width: 200, height: 48)
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(24)
            }
            .buttonStyle(.plain)
            .disabled(inputNumber.isEmpty)
            .opacity(inputNumber.isEmpty ? 0.5 : 1.0)
            
            Spacer()
        }
        .padding(.top)
    }
}
