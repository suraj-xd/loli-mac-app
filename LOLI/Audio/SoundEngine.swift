import AVFoundation

class SoundEngine: ObservableObject {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var isSetup = false

    @Published var soundEnabled: Bool {
        didSet { UserDefaults.standard.set(soundEnabled, forKey: "soundEnabled") }
    }

    init() {
        // Default to enabled if never set
        if UserDefaults.standard.object(forKey: "soundEnabled") == nil {
            UserDefaults.standard.set(true, forKey: "soundEnabled")
        }
        self.soundEnabled = UserDefaults.standard.bool(forKey: "soundEnabled")
    }

    func setup() {
        guard !isSetup else { return }
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: nil)
        engine.mainMixerNode.outputVolume = 0.3
        try? engine.start()
        isSetup = true
    }

    func playStartup() {
        playTones([(523, 0.1), (659, 0.1), (784, 0.1), (1047, 0.2)])
    }

    func playFocusGained() {
        playTones([(440, 0.1), (494, 0.15)])
    }

    func playDistracted() {
        playTones([(220, 0.15), (262, 0.15)])
    }

    func playCelebration() {
        playTones([(784, 0.1), (988, 0.1), (1175, 0.1), (1568, 0.3)])
    }

    func playTimerReset() {
        // Descending sad tone — timer was reset due to distraction
        playTones([(440, 0.15), (330, 0.15), (220, 0.3)])
    }

    func playTimerEnd() {
        playTones([(1047, 0.15), (784, 0.15), (1047, 0.15), (1568, 0.3)])
    }

    private func playTones(_ tones: [(frequency: Double, duration: Double)]) {
        guard soundEnabled else { return }
        setup()
        let sampleRate = engine.mainMixerNode.outputFormat(forBus: 0).sampleRate
        guard sampleRate > 0 else { return }

        var allSamples: [Float] = []
        for (freq, dur) in tones {
            let count = Int(sampleRate * dur)
            for i in 0..<count {
                let t = Double(i) / sampleRate
                let sample = sin(2.0 * .pi * freq * t) > 0 ? Float(0.3) : Float(-0.3)
                let envelope = Float(max(0, 1.0 - t / dur * 0.5))
                allSamples.append(sample * envelope)
            }
        }

        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(allSamples.count)) else { return }
        buffer.frameLength = AVAudioFrameCount(allSamples.count)

        if let channelData = buffer.floatChannelData {
            for i in 0..<allSamples.count {
                channelData[0][i] = allSamples[i]
            }
            if format.channelCount > 1 {
                for i in 0..<allSamples.count {
                    channelData[1][i] = allSamples[i]
                }
            }
        }

        playerNode.stop()
        playerNode.scheduleBuffer(buffer, at: nil)
        playerNode.play()
    }
}
