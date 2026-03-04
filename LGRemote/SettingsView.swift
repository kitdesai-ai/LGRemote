import SwiftUI

struct SettingsView: View {
    @ObservedObject var tv: LGTVService
    @Environment(\.dismiss) private var dismiss
    
    @State private var ipAddress: String = ""
    @State private var macAddress: String = ""
    @State private var isScanning: Bool = false
    @State private var discoveredTVs: [(ip: String, name: String)] = []
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 28) {
                        // Manual config
                        configSection
                        
                        // How to find info
                        helpSection
                        
                        // Danger zone
                        resetSection
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        save()
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
            }
            .onAppear {
                ipAddress = tv.tvIP
                macAddress = tv.tvMAC
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Config Section
    
    private var configSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("TV Connection")
            
            VStack(spacing: 12) {
                fieldRow(
                    icon: "wifi",
                    label: "IP Address",
                    placeholder: "192.168.1.100",
                    text: $ipAddress,
                    keyboardType: .decimalPad
                )
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                fieldRow(
                    icon: "antenna.radiowaves.left.and.right",
                    label: "MAC Address",
                    placeholder: "A1:B2:C3:D4:E5:F6",
                    text: $macAddress,
                    keyboardType: .asciiCapable
                )
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            
            Text("MAC address is required for Wake-on-LAN (turning the TV on remotely).")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.35))
                .padding(.horizontal, 4)
        }
    }
    
    private func fieldRow(
        icon: String,
        label: String,
        placeholder: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.4))
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                    .textCase(.uppercase)
                    .tracking(1)
                
                TextField(placeholder, text: text)
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white)
                    .keyboardType(keyboardType)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
        }
    }
    
    // MARK: - Help Section
    
    private var helpSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Finding Your TV Info")
            
            VStack(alignment: .leading, spacing: 12) {
                helpItem(
                    step: "1",
                    text: "On your LG TV, go to **Settings → Network → Wi-Fi** and note the IP address."
                )
                helpItem(
                    step: "2",
                    text: "For the MAC address, go to **Settings → Network → Wi-Fi → Advanced Wi-Fi Settings**."
                )
                helpItem(
                    step: "3",
                    text: "Make sure your phone and TV are on the **same Wi-Fi network**."
                )
                helpItem(
                    step: "4",
                    text: "For Wake-on-LAN, enable **Turn on via Wi-Fi** in your TV's network settings."
                )
            }
            .padding(16)
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
    }
    
    private func helpItem(step: String, text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(step)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.3))
                .frame(width: 22, height: 22)
                .background(Color.white.opacity(0.08))
                .clipShape(Circle())
            
            Text(text)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    // MARK: - Reset Section
    
    private var resetSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Advanced")
            
            Button {
                HapticManager.buttonTap()
                UserDefaults.standard.removeObject(forKey: "lgTV_clientKey")
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 15))
                    Text("Reset Pairing Key")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                    Spacer()
                }
                .foregroundStyle(.orange)
                .padding(16)
                .background(Color.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            
            Text("If you're having trouble connecting, try resetting the pairing key. You'll need to re-accept the pairing on your TV.")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.35))
                .padding(.horizontal, 4)
        }
    }
    
    // MARK: - Helpers
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.5))
            .textCase(.uppercase)
            .tracking(1.5)
    }
    
    private func save() {
        tv.tvIP = ipAddress.trimmingCharacters(in: .whitespaces)
        tv.tvMAC = macAddress.trimmingCharacters(in: .whitespaces)
    }
}
