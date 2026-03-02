import SwiftUI

private let pixelFont = "VT323-Regular"

struct TimerPopoverView: View {
    @ObservedObject var timerState: TimerState
    @ObservedObject var soundEngine: SoundEngine
    @State private var selectedMinutes: Int? = 25
    @State private var showCustom = false
    @State private var customMinutes: Int = 25

    var body: some View {
        VStack(spacing: 14) {
            if showCustom {
                customTimerPicker
            } else {
                durationPicker
            }

            // Sound toggle
            Button {
                soundEngine.soundEnabled.toggle()
            } label: {
                HStack(spacing: 4) {
                    Text(soundEngine.soundEnabled ? "♪" : "♪")
                        .font(.custom(pixelFont, size: 14))
                    Text(soundEngine.soundEnabled ? "ON" : "OFF")
                        .font(.custom(pixelFont, size: 13))
                }
                .foregroundColor(soundEngine.soundEnabled ? .white.opacity(0.5) : .white.opacity(0.2))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var durationPicker: some View {
        VStack(spacing: 12) {
            // Duration squares
            HStack(spacing: 6) {
                ForEach([15, 25, 45, 60], id: \.self) { mins in
                    durationButton(mins)
                }
                // Auto (no timer)
                Button {
                    selectedMinutes = nil
                } label: {
                    Text("∞")
                        .font(.custom(pixelFont, size: 20))
                        .foregroundColor(selectedMinutes == nil ? .white : .white.opacity(0.5))
                        .frame(width: 42, height: 42)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selectedMinutes == nil ? Color.white.opacity(0.12) : Color.white.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(selectedMinutes == nil ? Color.white.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }

            // Start button
            Button {
                if let mins = selectedMinutes {
                    timerState.start(minutes: mins)
                } else {
                    timerState.startNoTimer()
                }
            } label: {
                Text("START")
                    .font(.custom(pixelFont, size: 18))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            // Custom option
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { showCustom = true }
            } label: {
                Text("CUSTOM")
                    .font(.custom(pixelFont, size: 13))
                    .foregroundColor(.white.opacity(0.3))
            }
            .buttonStyle(.plain)
        }
    }

    private func durationButton(_ mins: Int) -> some View {
        Button {
            selectedMinutes = mins
        } label: {
            Text("\(mins)")
                .font(.custom(pixelFont, size: 20))
                .foregroundColor(selectedMinutes == mins ? .white : .white.opacity(0.5))
                .frame(width: 42, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(selectedMinutes == mins ? Color.white.opacity(0.12) : Color.white.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(selectedMinutes == mins ? Color.white.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var customTimerPicker: some View {
        VStack(spacing: 10) {
            Text("\(customMinutes)")
                .font(.custom(pixelFont, size: 42))
                .foregroundColor(.white)

            Text("MINUTES")
                .font(.custom(pixelFont, size: 14))
                .foregroundColor(.white.opacity(0.4))

            Slider(value: Binding(
                get: { Double(customMinutes) },
                set: { customMinutes = Int($0) }
            ), in: 1...120, step: 1)
            .tint(.white)

            HStack(spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { showCustom = false }
                } label: {
                    Text("BACK")
                        .font(.custom(pixelFont, size: 16))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.04)))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.1), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button {
                    timerState.start(minutes: customMinutes)
                } label: {
                    Text("START")
                        .font(.custom(pixelFont, size: 16))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.1)))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.15), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
