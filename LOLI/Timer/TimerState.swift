import SwiftUI
import Combine

@MainActor
class TimerState: ObservableObject {
    enum Mode {
        case idle
        case running
        case paused
        case completed
    }

    @Published var mode: Mode = .idle
    @Published var totalSeconds: Int = 0
    @Published var remainingSeconds: Int = 0
    @Published var mood: Mood = .normal
    @Published var isFocused: Bool = false
    @Published var showPopover: Bool = true
    @Published var cameraAuthorized: Bool = true

    // Distraction display state
    @Published var distractionPhase: DistractionPhase = .none
    @Published var frozen: Bool = false

    private var timer: Timer?
    var onComplete: (() -> Void)?

    var isRunning: Bool { mode == .running }

    var formattedTime: String {
        let secs = totalSeconds > 0 ? remainingSeconds : remainingSeconds
        let mins = secs / 60
        let s = secs % 60
        return String(format: "%02d:%02d", mins, s)
    }

    /// What to display in the timer area
    var displayText: String {
        switch distractionPhase {
        case .angry, .critical:
            return "DISTRACTED"
        default:
            return formattedTime
        }
    }

    /// Color for timer/distraction text
    var displayColor: Color {
        switch distractionPhase {
        case .critical:
            return Color(red: 1.0, green: 0.2, blue: 0.2)
        case .angry:
            return .white
        default:
            return .white
        }
    }

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(totalSeconds - remainingSeconds) / Double(totalSeconds)
    }

    func start(minutes: Int) {
        totalSeconds = minutes * 60
        remainingSeconds = totalSeconds
        mode = .running
        showPopover = false
        frozen = false
        distractionPhase = .none
        startTicking()
        Analytics.track("timerStarted", parameters: ["hasCountdown": "true"])
    }

    func startNoTimer() {
        mode = .running
        totalSeconds = 0
        remainingSeconds = 0
        showPopover = false
        frozen = false
        distractionPhase = .none
        startTicking()
        Analytics.track("timerStarted", parameters: ["hasCountdown": "false"])
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        mode = .idle
        remainingSeconds = 0
        totalSeconds = 0
        frozen = false
        distractionPhase = .none
        showPopover = true
    }

    func resetTimer() {
        if totalSeconds > 0 {
            remainingSeconds = totalSeconds
        } else {
            remainingSeconds = 0
        }
        frozen = false
        distractionPhase = .none
        Analytics.track("timerReset")
    }

    func complete() {
        timer?.invalidate()
        timer = nil
        mode = .completed
        mood = .happy
        frozen = false
        distractionPhase = .none
        Analytics.track("timerCompleted")
        onComplete?()

        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.mood = .normal
            self?.mode = .idle
            self?.showPopover = true
        }
    }

    private func startTicking() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func tick() {
        guard !frozen else { return }

        if totalSeconds > 0 {
            if remainingSeconds > 0 {
                remainingSeconds -= 1
            }
            if remainingSeconds == 0 {
                complete()
            }
        } else {
            remainingSeconds += 1
        }
    }
}
