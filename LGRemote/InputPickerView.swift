import SwiftUI

struct InputPickerView: View {
    @ObservedObject var tv: LGTVService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if tv.availableInputs.isEmpty {
                    emptyState
                } else {
                    inputList
                }
            }
            .navigationTitle("Switch Input")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Input List
    
    private var inputList: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(tv.availableInputs) { input in
                    inputRow(input)
                }
            }
            .padding(20)
        }
    }
    
    private func inputRow(_ input: TVInput) -> some View {
        Button {
            HapticManager.selection()
            tv.switchInput(to: input)
            
            // Brief delay then dismiss
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                HapticManager.success()
                dismiss()
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: iconForInput(input))
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isSelected(input) ? .white : .white.opacity(0.5))
                    .frame(width: 36, height: 36)
                    .background(
                        isSelected(input)
                            ? Color.blue.opacity(0.25)
                            : Color.white.opacity(0.06)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(input.label)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(input.connected ? Color.green : Color.gray.opacity(0.4))
                            .frame(width: 6, height: 6)
                        
                        Text(input.connected ? "Connected" : "Not connected")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                }
                
                Spacer()
                
                if isSelected(input) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.blue)
                }
            }
            .padding(14)
            .background(
                isSelected(input)
                    ? Color.blue.opacity(0.08)
                    : Color.white.opacity(0.04)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isSelected(input)
                            ? Color.blue.opacity(0.3)
                            : Color.white.opacity(0.06),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.on.rectangle.slash")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.2))
            
            Text("No inputs available")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
            
            Text("Connect to your TV first, then inputs will appear here.")
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.25))
                .multilineTextAlignment(.center)
            
            if tv.connectionState == .connected {
                Button {
                    HapticManager.buttonTap()
                    tv.fetchInputList()
                } label: {
                    Text("Refresh")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(40)
    }
    
    // MARK: - Helpers
    
    private func isSelected(_ input: TVInput) -> Bool {
        tv.currentInput == input.id
    }
    
    private func iconForInput(_ input: TVInput) -> String {
        let id = input.id.lowercased()
        let label = input.label.lowercased()
        
        if id == "livetv" || label == "tv" {
            return "antenna.radiowaves.left.and.right"
        } else if id.contains("hdmi") || label.contains("hdmi") {
            return "cable.connector.horizontal"
        } else if id.contains("usb") || label.contains("usb") {
            return "externaldrive.fill"
        } else if id.contains("av") || label.contains("composite") {
            return "video.fill"
        } else if id.contains("component") {
            return "circle.grid.3x3.fill"
        } else if label.contains("airplay") || label.contains("screen share") {
            return "airplayaudio"
        } else if label.contains("bluetooth") {
            return "wave.3.right"
        } else {
            return "rectangle.connected.to.line.below"
        }
    }
}
