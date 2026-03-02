import SwiftUI
import Combine

@MainActor
class EyeAnimator: ObservableObject {
    // Eye position (in canvas coordinates 0..constraintMax)
    @Published var eyeX: CGFloat = 0
    @Published var eyeY: CGFloat = 0
    @Published var leftEyeHeight: CGFloat = 36
    @Published var rightEyeHeight: CGFloat = 36
    @Published var mood: Mood = .normal

    // Red eyes filter (like web CSS filter)
    @Published var showRedEyes = false

    // Eyelid heights in canvas pixels (not normalized!)
    // These get set to eyeHeight/2 when active, 0 when inactive
    @Published var eyelidsTiredHeight: CGFloat = 0
    @Published var eyelidsAngryHeight: CGFloat = 0
    @Published var eyelidsHappyBottomOffset: CGFloat = 0

    // Flicker (scary = vertical, frozen = horizontal)
    @Published var flickerOffsetX: CGFloat = 0
    @Published var flickerOffsetY: CGFloat = 0

    // Boot animation
    @Published var isBooting = true
    @Published var bootFrame: Int = 0
    private var bootTimer: Timer?
    private let brailleFrames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]

    // Internal targets (tweened via averaging like web)
    private var targetX: CGFloat = 0
    private var targetY: CGFloat = 0
    private var targetLeftH: CGFloat = 36
    private var targetRightH: CGFloat = 36
    private var eyelidsTiredHeightNext: CGFloat = 0
    private var eyelidsAngryHeightNext: CGFloat = 0
    private var eyelidsHappyBottomOffsetNext: CGFloat = 0

    // Flicker state
    private var hFlicker = false
    private var hFlickerAmplitude: CGFloat = 2
    private var hFlickerAlternate = false
    private var vFlicker = false
    private var vFlickerAmplitude: CGFloat = 2
    private var vFlickerAlternate = false

    // Angry pulsing flicker (250ms on, ~600ms off like reference)
    private var angryFlickerActive = false
    private var nextAngryBurst: Date = .distantFuture
    private var angryBurstUntil: Date = .distantPast

    // Mood booleans (matching web exactly)
    private var tired = false
    private var angry = false
    private var happy = false
    private var curious = false

    // Idle random look
    private var idleTimer: Timer?
    private let idleBaseInterval: TimeInterval = 1.0
    private let idleVariation: TimeInterval = 2.0

    // Mouse tracking
    private var mouseMonitor: Any?
    @Published var isTrackingMouse = false
    private var lastMouseMoveTime: Date = .distantPast

    // Canvas native resolution (matches web: 128x64)
    let canvasW: CGFloat = 128
    let canvasH: CGFloat = 64
    let eyeW: CGFloat = 38
    let defaultEyeH: CGFloat = 34
    let eyeSpacing: CGFloat = 10
    let eyeRadius: CGFloat = 8
    private let curiousHeightBoost: CGFloat = 8

    var constraintX: CGFloat { canvasW - eyeW * 2 - eyeSpacing }
    var constraintY: CGFloat { canvasH - defaultEyeH }

    private var blinkTimer: Timer?
    private var displayLink: Timer?
    private var isBlinking = false

    init() {
        targetX = constraintX / 2
        targetY = constraintY / 2
        eyeX = targetX
        eyeY = targetY

        startBootAnimation()
        startDisplayLink()
    }

    private func startBootAnimation() {
        isBooting = true
        bootFrame = 0
        // Spin through ~12 frames at 80ms each (~1s total)
        bootTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self else { timer.invalidate(); return }
                self.bootFrame += 1
                if self.bootFrame >= 12 {
                    timer.invalidate()
                    self.bootTimer = nil
                    self.isBooting = false
                    self.startAutoBlink()
                    self.startIdleLook()
                    self.startMouseTracking()
                }
            }
        }
    }

    var brailleChar: String {
        brailleFrames[bootFrame % brailleFrames.count]
    }

    private func startDisplayLink() {
        // 15 FPS like web
        displayLink = Timer.scheduledTimer(withTimeInterval: 1.0 / 15.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateFrame()
            }
        }
    }

    /// Main frame update — matches web's draw() loop
    private func updateFrame() {
        // Tween positions (averaging like web)
        eyeX = floor((eyeX + targetX) / 2)
        eyeY = floor((eyeY + targetY) / 2)
        leftEyeHeight = floor((leftEyeHeight + targetLeftH) / 2)
        rightEyeHeight = floor((rightEyeHeight + targetRightH) / 2)

        // Curious: outer eye grows when looking sideways (like reference)
        if curious {
            if targetX <= 10 {
                targetLeftH = defaultEyeH + curiousHeightBoost
                targetRightH = defaultEyeH
            } else if targetX >= constraintX - 10 {
                targetRightH = defaultEyeH + curiousHeightBoost
                targetLeftH = defaultEyeH
            } else {
                targetLeftH = defaultEyeH
                targetRightH = defaultEyeH
            }
        }

        // Calculate eyelid targets based on mood booleans (exactly like web lines 766-784)
        if tired {
            eyelidsTiredHeightNext = floor(leftEyeHeight / 2)
            eyelidsAngryHeightNext = 0
        } else {
            eyelidsTiredHeightNext = 0
        }

        if angry {
            eyelidsAngryHeightNext = floor(leftEyeHeight / 2)
            eyelidsTiredHeightNext = 0
        } else {
            eyelidsAngryHeightNext = 0
        }

        if happy {
            eyelidsHappyBottomOffsetNext = floor(leftEyeHeight / 2)
        } else {
            eyelidsHappyBottomOffsetNext = 0
        }

        // Smooth eyelid transitions (averaging like web lines 787-795)
        eyelidsTiredHeight = floor((eyelidsTiredHeight + eyelidsTiredHeightNext) / 2)
        eyelidsAngryHeight = floor((eyelidsAngryHeight + eyelidsAngryHeightNext) / 2)
        eyelidsHappyBottomOffset = floor((eyelidsHappyBottomOffset + eyelidsHappyBottomOffsetNext) / 2)

        // Angry pulsing flicker: bursts of horizontal shake
        if angryFlickerActive {
            let now = Date()
            if now >= nextAngryBurst {
                angryBurstUntil = now.addingTimeInterval(0.25)
                nextAngryBurst = now.addingTimeInterval(0.6 + Double.random(in: 0...0.3))
            }
            hFlicker = now < angryBurstUntil
        }

        // Flicker (web lines 711-731)
        if hFlicker {
            flickerOffsetX = hFlickerAlternate ? hFlickerAmplitude : -hFlickerAmplitude
            hFlickerAlternate.toggle()
        } else {
            flickerOffsetX = 0
        }

        if vFlicker {
            flickerOffsetY = vFlickerAlternate ? vFlickerAmplitude : -vFlickerAmplitude
            vFlickerAlternate.toggle()
        } else {
            flickerOffsetY = 0
        }
    }

    // MARK: - Mouse tracking

    private func startMouseTracking() {
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            Task { @MainActor in
                self?.handleMouseMove(event)
            }
        }
    }

    private func handleMouseMove(_ event: NSEvent) {
        lastMouseMoveTime = Date()

        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        let mouseX = NSEvent.mouseLocation.x
        let mouseY = NSEvent.mouseLocation.y

        let normalizedX = (mouseX - screenFrame.minX) / screenFrame.width
        let normalizedY = (mouseY - screenFrame.minY) / screenFrame.height

        targetX = normalizedX * constraintX
        targetY = (1 - normalizedY) * constraintY
        isTrackingMouse = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self else { return }
            if Date().timeIntervalSince(self.lastMouseMoveTime) >= 2.9 {
                self.isTrackingMouse = false
            }
        }
    }

    // MARK: - Idle random look

    private func startIdleLook() {
        scheduleNextLook()
    }

    private func scheduleNextLook() {
        let interval = idleBaseInterval + Double.random(in: 0...idleVariation)
        idleTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.randomLook()
                self?.scheduleNextLook()
            }
        }
    }

    private func randomLook() {
        guard !isBlinking, !isTrackingMouse else { return }
        targetX = CGFloat(Int.random(in: 0...Int(constraintX)))
        targetY = CGFloat(Int.random(in: 0...Int(constraintY)))
    }

    // MARK: - Blink

    func blink() {
        guard !isBlinking else { return }
        isBlinking = true
        targetLeftH = 1
        targetRightH = 1

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.targetLeftH = self?.defaultEyeH ?? 36
            self?.targetRightH = self?.defaultEyeH ?? 36
            self?.isBlinking = false
        }
    }

    func wink() {
        guard !isBlinking else { return }
        isBlinking = true
        targetLeftH = 1

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.targetLeftH = self?.defaultEyeH ?? 36
            self?.isBlinking = false
        }
    }

    // MARK: - Tap reaction

    func tapReaction() {
        let roll = Double.random(in: 0...1)
        if roll < 0.4 {
            blink()
        } else if roll < 0.7 {
            wink()
        } else {
            setMood(.happy)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                if self?.mood == .happy { self?.setMood(.normal) }
            }
        }
    }

    // MARK: - Mood (matches web RoboEyes.ts set mood exactly)

    func setMood(_ newMood: Mood) {
        // If leaving scary/frozen/angry, stop flicker
        if (mood == .scary || mood == .frozen || mood == .angry) && (newMood != .scary && newMood != .frozen && newMood != .angry) {
            hFlicker = false
            vFlicker = false
            angryFlickerActive = false
        }

        if curious && newMood != .curious {
            curious = false
            targetLeftH = defaultEyeH
            targetRightH = defaultEyeH
        }

        switch newMood {
        case .tired:
            tired = true
            angry = false
            happy = false
            showRedEyes = false
        case .angry:
            tired = false
            angry = true
            happy = false
            angryFlickerActive = true
            hFlickerAmplitude = 2
            vFlicker = false
            // Red eyes controlled externally via setRedEyes() based on distraction phase
        case .happy:
            tired = false
            angry = false
            happy = true
            showRedEyes = false
        case .frozen:
            tired = false
            angry = false
            happy = false
            hFlicker = true
            hFlickerAmplitude = 2
            vFlicker = false
            showRedEyes = false
        case .scary:
            // Web: tired=true + vertical flicker + red eyes
            tired = true
            angry = false
            happy = false
            hFlicker = false
            vFlicker = true
            vFlickerAmplitude = 2
            showRedEyes = true
        case .curious:
            tired = false
            angry = false
            happy = false
            curious = true
            showRedEyes = false
        default: // .normal
            tired = false
            angry = false
            happy = false
            showRedEyes = false
        }

        if !curious {
            targetLeftH = defaultEyeH
            targetRightH = defaultEyeH
        }

        mood = newMood
    }

    func setRedEyes(_ on: Bool) {
        showRedEyes = on
    }

    // MARK: - Celebration

    func playCelebration() {
        setMood(.happy)
        targetLeftH = defaultEyeH + 12
        targetRightH = defaultEyeH + 12

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self else { return }
            self.targetLeftH = self.defaultEyeH - 8
            self.targetRightH = self.defaultEyeH - 8
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            self.targetLeftH = self.defaultEyeH + 8
            self.targetRightH = self.defaultEyeH + 8
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self else { return }
            self.targetLeftH = self.defaultEyeH
            self.targetRightH = self.defaultEyeH
        }
    }

    // MARK: - Auto-blink

    private func startAutoBlink() {
        scheduleNextBlink()
    }

    private func scheduleNextBlink() {
        let interval = Double.random(in: 3...10)
        blinkTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.blink()
                self?.scheduleNextBlink()
            }
        }
    }

    deinit {
        blinkTimer?.invalidate()
        idleTimer?.invalidate()
        displayLink?.invalidate()
        bootTimer?.invalidate()
        if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
    }
}
