import Vision
import AVFoundation
import Combine

class FocusDetector: ObservableObject {
    @Published var isFocused = false

    private var lastDetectionTime: Date = .distantPast
    private let detectionInterval: TimeInterval = 0.1
    private let sequenceHandler = VNSequenceRequestHandler()
    private let processQueue = DispatchQueue(label: "focus.detector")

    func processFrame(_ sampleBuffer: CMSampleBuffer) {
        processQueue.async { [weak self] in
            self?.doProcessFrame(sampleBuffer)
        }
    }

    private func doProcessFrame(_ sampleBuffer: CMSampleBuffer) {
        let now = Date()
        guard now.timeIntervalSince(lastDetectionTime) >= detectionInterval else { return }
        lastDetectionTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectFaceLandmarksRequest { [weak self] request, _ in
            guard let results = request.results as? [VNFaceObservation],
                  let face = results.first else {
                DispatchQueue.main.async { self?.isFocused = false }
                return
            }

            let focused = self?.evaluateFocus(face: face) ?? false
            DispatchQueue.main.async { self?.isFocused = focused }
        }

        try? sequenceHandler.perform([request], on: pixelBuffer, orientation: .leftMirrored)
    }

    private func evaluateFocus(face: VNFaceObservation) -> Bool {
        guard face.boundingBox.width > 0.08 else { return false }

        guard let landmarks = face.landmarks,
              let leftEye = landmarks.leftEye,
              let rightEye = landmarks.rightEye else { return false }

        let leftOpen = eyeOpenness(leftEye)
        let rightOpen = eyeOpenness(rightEye)

        guard leftOpen > 0.15, rightOpen > 0.15 else { return false }

        let avg = (leftOpen + rightOpen) / 2
        guard avg > 0 else { return false }
        let asymmetry = abs(leftOpen - rightOpen) / avg
        guard asymmetry < 0.5 else { return false }

        return true
    }

    private func eyeOpenness(_ eye: VNFaceLandmarkRegion2D) -> CGFloat {
        let points = eye.normalizedPoints
        guard points.count >= 4 else { return 0 }

        let ys = points.map(\.y)
        let xs = points.map(\.x)
        let height = (ys.max() ?? 0) - (ys.min() ?? 0)
        let width = (xs.max() ?? 0) - (xs.min() ?? 0)
        guard width > 0 else { return 0 }
        return height / width
    }
}
