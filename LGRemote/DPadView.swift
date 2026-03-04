import SwiftUI

struct DPadView: View {
    @ObservedObject var tv: LGTVService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 32) {
                    Spacer()

                    // Navigation wheel
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.04))
                            .frame(width: 220, height: 220)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )

                        // UP
                        dirButton(icon: "chevron.up", x: 0, y: -76) {
                            tv.sendButton("UP")
                        }

                        // DOWN
                        dirButton(icon: "chevron.down", x: 0, y: 76) {
                            tv.sendButton("DOWN")
                        }

                        // LEFT
                        dirButton(icon: "chevron.left", x: -76, y: 0) {
                            tv.sendButton("LEFT")
                        }

                        // RIGHT
                        dirButton(icon: "chevron.right", x: 76, y: 0) {
                            tv.sendButton("RIGHT")
                        }

                        // CENTER (OK/Enter)
                        Button {
                            HapticManager.buttonTap()
                            tv.sendButton("ENTER")
                        } label: {
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 72, height: 72)
                                .overlay(
                                    Text("OK")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.7))
                                )
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }

                    // Back & Home
                    HStack(spacing: 16) {
                        pillButton(icon: "arrow.uturn.backward", label: "Back") {
                            tv.sendButton("BACK")
                        }
                        pillButton(icon: "gearshape.fill", label: "Settings") {
                            tv.sendButton("MENU")
                        }
                        pillButton(icon: "house.fill", label: "Home") {
                            tv.sendButton("HOME")
                        }
                    }

                    Spacer()
                }
            }
            .navigationTitle("Navigate")
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

    // MARK: - Helpers

    private func dirButton(icon: String, x: CGFloat, y: CGFloat, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.softTap()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 52, height: 52)
        }
        .buttonStyle(ScaleButtonStyle())
        .offset(x: x, y: y)
    }

    private func pillButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.softTap()
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(label)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.white.opacity(0.5))
            .padding(.horizontal, 20)
            .frame(height: 40)
            .background(Color.white.opacity(0.05))
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
