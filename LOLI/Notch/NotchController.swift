import SwiftUI
import Combine
import DynamicNotchKit

@MainActor
class NotchController: ObservableObject {
    private var notch: DynamicNotch<LOLIExpandedView, LOLICompactLeadingView, LOLICompactTrailingView>?
    @Published var isExpanded = true
    @Published var showOnboarding = !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

    let timerState = TimerState()
    let cameraManager = CameraManager()
    let focusDetector = FocusDetector()
    let focusMoodController = FocusMoodController()
    let soundEngine = SoundEngine()

    private var focusUpdateTimer: Timer?
    private var cameraRecheckTimer: Timer?
    private var sleepObserver: Any?
    private var wakeObserver: Any?
    private var activateObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    private var lastPhase: DistractionPhase = .none

    func show() {
        notch = DynamicNotch(
            hoverBehavior: [.keepVisible],
            style: .auto
        ) {
            LOLIExpandedView(timerState: self.timerState, soundEngine: self.soundEngine, notchController: self, onToggle: { self.toggleMode() })
        } compactLeading: {
            LOLICompactLeadingView(timerState: self.timerState, onToggle: { self.toggleMode() })
        } compactTrailing: {
            LOLICompactTrailingView(timerState: self.timerState, onToggle: { self.toggleMode() })
        }

        Task {
            await notch?.expand()
        }

        setupCamera()
        setupFocusLoop()
        setupCameraRecheck()
        setupSleepWake()
        NotificationManager.requestPermission()
        soundEngine.setup()

        // Wire distraction timer reset
        focusMoodController.onTimerReset = { [weak self] in
            guard let self else { return }
            self.soundEngine.playTimerReset()
            self.timerState.resetTimer()
        }

        // Wire user returned after distraction — auto-restart + chime + happy
        focusMoodController.onUserReturned = { [weak self] in
            guard let self else { return }
            self.timerState.frozen = false
            self.timerState.distractionPhase = .none
            self.soundEngine.playFocusGained()
        }

        // Wire timer completion
        timerState.onComplete = { [weak self] in
            self?.soundEngine.playCelebration()
            self?.soundEngine.playTimerEnd()
            let minutes = (self?.timerState.totalSeconds ?? 0) / 60
            NotificationManager.sendTimerComplete(minutes: minutes)
        }

        // Wire camera authorization
        cameraManager.$isAuthorized
            .receive(on: RunLoop.main)
            .sink { [weak self] authorized in
                self?.timerState.cameraAuthorized = authorized
            }
            .store(in: &cancellables)
    }

    func toggleMode() {
        Task {
            if isExpanded {
                await notch?.compact()
            } else {
                await notch?.expand()
            }
            isExpanded.toggle()
        }
    }

    private func setupCamera() {
        cameraManager.onFrame = { [weak self] buffer in
            self?.focusDetector.processFrame(buffer)
        }
        cameraManager.requestAccess()
    }

    private func setupFocusLoop() {
        focusUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }

                self.focusMoodController.isTimerActive = self.timerState.isRunning
                self.focusMoodController.update(isFocused: self.focusDetector.isFocused)

                // Update mood for pet preview even when idle
                self.timerState.mood = self.focusMoodController.mood
                self.timerState.isFocused = self.focusDetector.isFocused

                guard self.timerState.isRunning else { return }

                let newPhase = self.focusMoodController.phase

                // Freeze timer when distracted (any phase beyond none)
                self.timerState.frozen = newPhase != .none

                // Update distraction phase for UI
                self.timerState.distractionPhase = newPhase

                self.lastPhase = newPhase
            }
        }
    }

    private func setupCameraRecheck() {
        // Re-check camera permission every 2s (catches Settings toggle without restart)
        cameraRecheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.cameraManager.recheckAuthorization()
            }
        }

        // Also recheck when app becomes active (user returning from Settings)
        activateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.cameraManager.recheckAuthorization()
        }
    }

    private func setupSleepWake() {
        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.cameraManager.stop()
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.cameraManager.requestAccess()
        }
    }

    func cleanup() {
        cameraManager.stop()
        focusUpdateTimer?.invalidate()
        cameraRecheckTimer?.invalidate()
        if let activateObserver { NotificationCenter.default.removeObserver(activateObserver) }
        if let sleepObserver { NSWorkspace.shared.notificationCenter.removeObserver(sleepObserver) }
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
        Task {
            await notch?.hide()
        }
    }
}
