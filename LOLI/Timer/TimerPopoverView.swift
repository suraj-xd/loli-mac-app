import SwiftUI

private let pixelFont = "VT323-Regular"

struct TimerPopoverView: View {
    @ObservedObject var timerState: TimerState
    @ObservedObject var soundEngine: SoundEngine
    @State private var customMinutes: Int = 25
    @State private var showCustom = false

    var body: some View {
        VStack(spacing: 12) {
            Text("FOCUS TIMER")
                .font(.custom(pixelFont, size: 18))
                .foregroundColor(.white)

            if showCustom {
                customTimerPicker
            } else {
                presetButtons
            }

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)

            // Sound toggle
            Button {
                soundEngine.soundEnabled.toggle()
            } label: {
                HStack(spacing: 6) {
                    Text(soundEngine.soundEnabled ? "♪" : "♪")
                        .font(.custom(pixelFont, size: 16))
                    Text(soundEngine.soundEnabled ? "SOUND ON" : "SOUND OFF")
                        .font(.custom(pixelFont, size: 14))
                }
                .foregroundColor(soundEngine.soundEnabled ? .white.opacity(0.8) : .white.opacity(0.3))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(width: 250)
    }

    private var presetButtons: some View {
        VStack(spacing: 5) {
            timerOption("NO TIMER") {
                timerState.startNoTimer()
            }
            timerOption("10 MIN") {
                timerState.start(minutes: 10)
            }
            timerOption("30 MIN") {
                timerState.start(minutes: 30)
            }
            timerOption("60 MIN") {
                timerState.start(minutes: 60)
            }

            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(height: 1)
                .padding(.vertical, 2)

            timerOption("CUSTOM") {
                withAnimation(.easeInOut(duration: 0.15)) { showCustom = true }
            }
        }
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
                timerOption("BACK") {
                    withAnimation(.easeInOut(duration: 0.15)) { showCustom = false }
                }
                timerOption("START") {
                    timerState.start(minutes: customMinutes)
                }
            }
        }
    }

    private func timerOption(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.custom(pixelFont, size: 16))
                .foregroundColor(.white.opacity(0.8))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
