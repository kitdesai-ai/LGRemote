import SwiftUI

struct SettingsView: View {
    @ObservedObject var tv: LGTVService
    @Environment(\.dismiss) private var dismiss

    @State private var ipAddress: String = ""
    @State private var macAddress: String = ""
    @State private var showManualSetup = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        // Discovery or current config
                        if tv.tvIP.isEmpty || tv.isScanning || !tv.discoveredTVs.isEmpty {
                            discoverySection
                        }

                        // Manual setup (shown if toggled or if a TV is already configured)
                        if showManualSetup || !tv.tvIP.isEmpty {
                            configSection
                        }

                        // Show manual setup toggle if no TV configured and not already showing
                        if tv.tvIP.isEmpty && !showManualSetup {
                            Button {
                                HapticManager.buttonTap()
                                showManualSetup = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "pencil.line")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("Set Up Manually")
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                }
                                .foregroundStyle(.white.opacity(0.5))
                                .padding(.horizontal, 24)
                                .frame(height: 48)
                                .background(Color.white.opacity(0.05))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                            }
                        }

                        // Help & Advanced
                        helpSection
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
                if tv.tvIP.isEmpty {
                    tv.startDiscovery()
                }
            }
            .onDisappear {
                tv.stopDiscovery()
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Discovery Section

    private var discoverySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                sectionHeader("Discovered TVs")
                Spacer()
                if tv.isScanning {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Button {
                        HapticManager.softTap()
                        tv.startDiscovery()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.blue)
                    }
                }
            }

            if tv.discoveredTVs.isEmpty && tv.isScanning {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Searching for LG TVs on your network...")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(Color.white.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else if tv.discoveredTVs.isEmpty && !tv.isScanning {
                VStack(spacing: 8) {
                    Image(systemName: "tv.slash")
                        .font(.system(size: 24))
                        .foregroundStyle(.white.opacity(0.2))
                    Text("No TVs found")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                    Text("Make sure your TV is on and connected to the same network.")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.25))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(Color.white.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                VStack(spacing: 8) {
                    ForEach(tv.discoveredTVs) { discovered in
                        Button {
                            HapticManager.buttonTap()
                            selectTV(discovered)
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "tv.fill")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(tv.tvIP == discovered.host ? .blue : .white.opacity(0.5))
                                    .frame(width: 36, height: 36)
                                    .background(
                                        tv.tvIP == discovered.host
                                            ? Color.blue.opacity(0.2)
                                            : Color.white.opacity(0.06)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(discovered.name)
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white)
                                    Text(discovered.host)
                                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.35))
                                }

                                Spacer()

                                if tv.tvIP == discovered.host {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(.blue)
                                }
                            }
                            .padding(14)
                            .background(
                                tv.tvIP == discovered.host
                                    ? Color.blue.opacity(0.08)
                                    : Color.white.opacity(0.04)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(
                                        tv.tvIP == discovered.host
                                            ? Color.blue.opacity(0.3)
                                            : Color.white.opacity(0.06),
                                        lineWidth: 1
                                    )
                            )
                        }
                    }
                }
            }
        }
    }

    private func selectTV(_ discovered: DiscoveredTV) {
        tv.stopDiscovery()
        ipAddress = discovered.host
        tv.tvIP = discovered.host
        // Give scan connections time to fully close before connecting
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            tv.connect()
        }
        showManualSetup = false
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

            Text("MAC address is only needed for Wake-on-LAN (turning the TV on remotely). You can find it in your TV's network settings.")
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
            sectionHeader("Tips")

            VStack(alignment: .leading, spacing: 12) {
                helpItem(
                    step: "1",
                    text: "Make sure your phone and TV are on the **same network**."
                )
                helpItem(
                    step: "2",
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
