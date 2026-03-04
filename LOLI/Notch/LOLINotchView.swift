import SwiftUI

private let pixelFont = "VT323-Regular"

struct LOLIExpandedView: View {
    @ObservedObject var timerState: TimerState
    @ObservedObject var soundEngine: SoundEngine
    @ObservedObject var notchController: NotchController
    var onToggle: () -> Void
    @State private var isHovering = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 4) {
                if notchController.showOnboarding {
                    OnboardingView {
                        notchController.showOnboarding = false
                    }
                } else if timerState.showPopover {
                    TimerPopoverView(timerState: timerState, soundEngine: soundEngine)
                } else {
                    RobotEyesView(mood: timerState.mood, phase: timerState.distractionPhase)
                        .frame(width: 170, height: 70)

                    if timerState.isRunning {
                        timerDisplay
                            .onTapGesture { onToggle() }
                    }

                    if !timerState.cameraAuthorized {
                        cameraPermissionView
                    }
                }
            }

            if timerState.isRunning {
                Button {
                    timerState.stop()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(width: 16, height: 16)
                        .background(.white.opacity(0.1), in: Circle())
                }
                .buttonStyle(.plain)
                .opacity(isHovering ? 1 : 0)
                .animation(.easeInOut(duration: 0.15), value: isHovering)
            }
        }
        .onHover { hovering in
            isHovering = hovering
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var timerDisplay: some View {
        let showTime = timerState.isRunning

        if showTime {
            Text(timerState.displayText)
                .font(.custom(pixelFont, size: 29))
                .foregroundColor(timerState.displayColor)
                .shadow(color: timerState.distractionPhase == .critical
                    ? Color.red.opacity(0.6) : .clear,
                    radius: timerState.distractionPhase == .critical ? 8 : 0)
                .modifier(ShakeEffect(
                    shaking: timerState.distractionPhase == .critical
                ))
                .opacity(timerState.distractionPhase == .angry ? 0.85 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: timerState.distractionPhase)
        }
    }

    private var cameraPermissionView: some View {
        VStack(spacing: 4) {
            Text("CAMERA NEEDED")
                .font(.custom(pixelFont, size: 14))
                .foregroundColor(.red)
            Button("Open Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                    NSWorkspace.shared.open(url)
                }
            }
            .font(.custom(pixelFont, size: 14))
            .foregroundColor(.green)
        }
    }
}

// Horizontal shake like a hazard warning
struct ShakeEffect: ViewModifier {
    var shaking: Bool
    @State private var shakeTimer: Timer?
    @State private var offset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .onChange(of: shaking) { _, on in
                if on {
                    startShake()
                } else {
                    stopShake()
                }
            }
            .onAppear {
                if shaking { startShake() }
            }
            .onDisappear { stopShake() }
    }

    private func startShake() {
        stopShake()
        shakeTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { _ in
            DispatchQueue.main.async {
                withAnimation(.linear(duration: 0.06)) {
                    offset = CGFloat.random(in: -2.5...2.5)
                }
            }
        }
    }

    private func stopShake() {
        shakeTimer?.invalidate()
        shakeTimer = nil
        withAnimation(.easeOut(duration: 0.15)) { offset = 0 }
    }
}

struct LOLICompactLeadingView: View {
    @ObservedObject var timerState: TimerState
    var onToggle: () -> Void

    var body: some View {
        RobotEyesView(mood: timerState.mood, phase: timerState.distractionPhase)
            .frame(width: 40, height: 20)
            .onTapGesture { onToggle() }
    }
}

struct LOLICompactTrailingView: View {
    @ObservedObject var timerState: TimerState
    var onToggle: () -> Void

    var body: some View {
        if timerState.isRunning {
            Text(timerState.displayText)
                .font(.custom(pixelFont, size: 20))
                .foregroundColor(timerState.displayColor)
                .onTapGesture { onToggle() }
        }
    }
}
