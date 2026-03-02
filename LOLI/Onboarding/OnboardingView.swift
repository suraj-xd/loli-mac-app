import SwiftUI
import AVFoundation

struct OnboardingView: View {
    @State private var step = 0
    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            if step == 0 {
                welcomeStep
            } else {
                readyStep
            }
        }
        .padding(24)
        .frame(width: 280)
        .font(.custom("VT323", size: 18))
    }

    private var welcomeStep: some View {
        VStack(spacing: 16) {
            Text("WELCOME TO LOLI")
                .font(.custom("VT323", size: 24))
                .foregroundColor(.white)

            Text("LOLI watches if you're focused and reacts when you look away.")
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)

            Button {
                AVCaptureDevice.requestAccess(for: .video) { _ in
                    DispatchQueue.main.async {
                        step = 1
                    }
                }
            } label: {
                Text("ALLOW CAMERA")
                    .font(.custom("VT323", size: 18))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white.opacity(0.2))
        }
    }

    private var readyStep: some View {
        VStack(spacing: 16) {
            Text("YOU'RE READY!")
                .font(.custom("VT323", size: 24))
                .foregroundColor(.white)

            Text("Tap the notch to start a focus session.")
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)

            Button {
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                Analytics.track("onboardingCompleted")
                onComplete()
            } label: {
                Text("LET'S GO")
                    .font(.custom("VT323", size: 18))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white.opacity(0.2))
        }
    }
}
