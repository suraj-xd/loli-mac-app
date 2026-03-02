import SwiftUI

enum DistractionPhase: Equatable {
    case none
    case searching      // 0-3s: curious, timer frozen
    case angry          // 3-6s: angry, NO red eyes, shows "DISTRACTED"
    case critical       // 6-9s: angry + red eyes, red shaking "DISTRACTED"
    case reset          // 9s+: timer reset, tired then curious
}

@MainActor
class FocusMoodController: ObservableObject {
    @Published var mood: Mood = .normal
    @Published var phase: DistractionPhase = .none

    private var distractedSince: Date?
    private var focusedSince: Date?
    private var tiredUntil: Date?

    var onTimerReset: (() -> Void)?
    var onUserReturned: (() -> Void)?
    var isTimerActive: Bool = false

    private var didResetThisPeriod = false
    private var wasDistracted = false

    // Thresholds (seconds)
    private let searchDuration: TimeInterval = 3
    private let angryDuration: TimeInterval = 6
    private let criticalDuration: TimeInterval = 9
    private let tiredDuration: TimeInterval = 3
    private let refocusThreshold: TimeInterval = 2

    func update(isFocused: Bool) {
        let now = Date()

        if isFocused {
            distractedSince = nil

            if focusedSince == nil { focusedSince = now }

            // Post-reset tired period
            if let tiredEnd = tiredUntil, now < tiredEnd {
                mood = .tired
                phase = .reset
                return
            }
            if tiredUntil != nil {
                tiredUntil = nil
            }

            // User just came back after being distracted
            if wasDistracted {
                wasDistracted = false
                didResetThisPeriod = false
                phase = .none
                mood = .happy
                onUserReturned?()
                return
            }

            phase = .none
            mood = .happy
            if let since = focusedSince, now.timeIntervalSince(since) > refocusThreshold {
                mood = .normal
            }
        } else {
            focusedSince = nil
            wasDistracted = true
            if distractedSince == nil { distractedSince = now }

            // Post-reset tired period
            if let tiredEnd = tiredUntil, now < tiredEnd {
                mood = .tired
                phase = .reset
                return
            }
            if tiredUntil != nil {
                tiredUntil = nil
                mood = .curious
                phase = .none
                return
            }

            guard let since = distractedSince else { return }
            let duration = now.timeIntervalSince(since)

            if !isTimerActive {
                mood = .curious
                phase = .none
                return
            }

            // Escalation ladder
            switch duration {
            case 0..<searchDuration:
                mood = .curious
                phase = .searching

            case searchDuration..<angryDuration:
                mood = .angry
                phase = .angry

            case angryDuration..<criticalDuration:
                mood = .angry
                phase = .critical

            default:
                if !didResetThisPeriod {
                    didResetThisPeriod = true
                    tiredUntil = now.addingTimeInterval(tiredDuration)
                    mood = .tired
                    phase = .reset
                    onTimerReset?()
                } else {
                    mood = .curious
                    phase = .none
                }
            }
        }
    }
}
