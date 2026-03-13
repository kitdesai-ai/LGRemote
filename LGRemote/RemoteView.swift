import SwiftUI

struct RemoteView: View {
    @StateObject private var tv = LGTVService()
    @State private var showingSettings = false
    @State private var showingInputPicker = false
    @State private var showingDPad = false
    @State private var powerPressScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()
            
            if tv.tvIP.isEmpty {
                onboardingView
            } else {
                VStack(spacing: 0) {
                    // Top bar
                    topBar

                    Spacer()

                    // Power button
                    powerButton
                        .padding(.bottom, 36)

                    // Volume & Channel controls
                    controlsRow
                        .padding(.bottom, 32)

                    // Input selector
                    inputButton
                        .padding(.bottom, 16)

                    // Mute button
                    muteButton

                    Spacer()

                    // Connection status
                    connectionFooter
                        .padding(.bottom, 8)
                }
                .padding(.horizontal, 24)
            }

            // Floating action buttons (hidden during onboarding)
            if !tv.tvIP.isEmpty {
                VStack {
                    Spacer()
                    HStack {
                        // D-Pad FAB — bottom left
                        Button {
                            HapticManager.softTap()
                            showingDPad = true
                        } label: {
                            Image(systemName: "dpad.fill")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(.white.opacity(0.8))
                                .frame(width: 52, height: 52)
                                .glassButton()
                        }
                        .buttonStyle(ScaleButtonStyle())

                        Spacer()

                        // Settings FAB — bottom right
                        Button {
                            HapticManager.softTap()
                            showingSettings = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(.white.opacity(0.8))
                                .frame(width: 52, height: 52)
                                .glassButton()
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingSettings) {
            SettingsView(tv: tv)
        }
        .sheet(isPresented: $showingInputPicker) {
            InputPickerView(tv: tv)
        }
        .sheet(isPresented: $showingDPad) {
            DPadView(tv: tv)
        }
        .onAppear {
            if !tv.tvIP.isEmpty {
                tv.connect()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            tv.disconnect()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            if !tv.tvIP.isEmpty {
                tv.connect()
            }
        }
    }
    
    // MARK: - Onboarding

    private var onboardingView: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "tv.fill")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(.white.opacity(0.15))

                VStack(spacing: 8) {
                    Text("No TV Connected")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Set up your LG TV to get started.\nMake sure it's on and connected to the same network.")
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
            }

            Spacer()

            Button {
                HapticManager.buttonTap()
                showingSettings = true
            } label: {
                Text("Get Started")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("LG webOS Remote")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                Text(connectionLabel)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(connectionColor)
            }
            
            Spacer()
        }
        .padding(.top, 16)
    }
    
    private var connectionLabel: String {
        switch tv.connectionState {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting…"
        case .awaitingPairing: return "Accept on TV"
        case .connected: return "Connected"
        case .error(let msg): return msg
        }
    }
    
    private var connectionColor: Color {
        switch tv.connectionState {
        case .connected: return .green
        case .connecting, .awaitingPairing: return .orange
        case .error: return .red
        case .disconnected: return .gray
        }
    }
    
    // MARK: - Power Button
    
    private var powerButton: some View {
        Button {
            HapticManager.heavyTap()
            if tv.connectionState == .connected {
                tv.powerOff()
                tv.disconnect()
            } else {
                tv.powerOn()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(
                        tv.connectionState == .connected
                            ? Color.red.opacity(0.15)
                            : Color.green.opacity(0.12)
                    )
                    .frame(width: 88, height: 88)
                
                Circle()
                    .stroke(
                        tv.connectionState == .connected
                            ? Color.red.opacity(0.6)
                            : Color.green.opacity(0.5),
                        lineWidth: 2
                    )
                    .frame(width: 88, height: 88)
                
                Image(systemName: "power")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(
                        tv.connectionState == .connected
                            ? Color.red
                            : Color.green
                    )
            }
            .scaleEffect(powerPressScale)
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    // MARK: - Volume & Channel Controls
    
    private var controlsRow: some View {
        HStack(spacing: 32) {
            // Volume
            controlPill(
                topIcon: "speaker.plus.fill",
                bottomIcon: "speaker.minus.fill",
                label: "VOL",
                value: "\(tv.volume)",
                topAction: { tv.volumeUp() },
                bottomAction: { tv.volumeDown() }
            )
            
            // Channel
            controlPill(
                topIcon: "chevron.up",
                bottomIcon: "chevron.down",
                label: "CH",
                value: nil,
                topAction: { tv.channelUp() },
                bottomAction: { tv.channelDown() }
            )
        }
    }
    
    private func controlPill(
        topIcon: String,
        bottomIcon: String,
        label: String,
        value: String?,
        topAction: @escaping () -> Void,
        bottomAction: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 0) {
            // Top button
            Button {
                HapticManager.softTap()
                topAction()
            } label: {
                Image(systemName: topIcon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 72)
            }
            .buttonStyle(ScaleButtonStyle())
            
            // Center label
            VStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.35))
                    .tracking(2)
                
                if let value = value {
                    Text(value)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                        .monospacedDigit()
                }
            }
            .frame(height: 44)
            
            // Bottom button
            Button {
                HapticManager.softTap()
                bottomAction()
            } label: {
                Image(systemName: bottomIcon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 72)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .frame(width: 120)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    // MARK: - Input Button
    
    private var inputButton: some View {
        Button {
            HapticManager.buttonTap()
            showingInputPicker = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "rectangle.on.rectangle.angled")
                    .font(.system(size: 18, weight: .semibold))
                
                Text("Input")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                
                Spacer()
                
                if let inputLabel = tv.availableInputs.first(where: { $0.id == tv.currentInput })?.label {
                    Text(inputLabel)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .frame(height: 56)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    // MARK: - Mute Button
    
    private var muteButton: some View {
        Button {
            HapticManager.buttonTap()
            tv.toggleMute()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: tv.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 16, weight: .semibold))
                
                Text(tv.isMuted ? "Unmute" : "Mute")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(tv.isMuted ? .orange : .white.opacity(0.6))
            .padding(.horizontal, 24)
            .frame(height: 48)
            .background(
                tv.isMuted
                    ? Color.orange.opacity(0.12)
                    : Color.white.opacity(0.05)
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(
                        tv.isMuted ? Color.orange.opacity(0.3) : Color.white.opacity(0.08),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private var showReconnect: Bool {
        switch tv.connectionState {
        case .disconnected, .error: return true
        default: return false
        }
    }

    // MARK: - Connection Footer
    
    private var connectionFooter: some View {
        Group {
            if showReconnect {
                Button {
                    HapticManager.buttonTap()
                    if tv.tvIP.isEmpty {
                        showingSettings = true
                    } else {
                        tv.connect()
                    }
                } label: {
                    Text(tv.tvIP.isEmpty ? "Set Up TV" : "Reconnect")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                }
            }
        }
    }
}

// MARK: - Glass Button Modifier

extension View {
    func glassButton() -> some View {
        self
            .background(.ultraThinMaterial, in: Circle())
            .overlay(
                Circle()
                    .stroke(.white.opacity(0.15), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
    }
}

// MARK: - Scale Button Style (press-in effect)

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    RemoteView()
}
