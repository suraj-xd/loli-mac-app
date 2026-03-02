import SwiftUI

struct RobotEyesView: View {
    let mood: Mood
    var phase: DistractionPhase = .none
    @StateObject private var animator = EyeAnimator()

    var body: some View {
        Canvas { context, size in
            let scaleX = size.width / animator.canvasW
            let scaleY = size.height / animator.canvasH

            // Background
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))

            // Boot: braille spinner
            if animator.isBooting {
                let text = Text(animator.brailleChar)
                    .font(.system(size: min(size.width, size.height) * 0.45))
                    .foregroundColor(.white)
                let resolved = context.resolve(text)
                let textSize = resolved.measure(in: size)
                context.draw(resolved, at: CGPoint(
                    x: (size.width - textSize.width) / 2 + textSize.width / 2,
                    y: (size.height - textSize.height) / 2 + textSize.height / 2
                ))
                return
            }

            let eyeW = animator.eyeW * scaleX
            let eyeSpacing = animator.eyeSpacing * scaleX
            let radius = animator.eyeRadius * scaleX

            // Eye positions + flicker offset (in scaled coords)
            let posX = (animator.eyeX + animator.flickerOffsetX) * scaleX
            let posY = (animator.eyeY + animator.flickerOffsetY) * scaleY

            let leftH = animator.leftEyeHeight * scaleY
            let rightH = animator.rightEyeHeight * scaleY

            // Left eye
            let leftRect = CGRect(x: posX, y: posY, width: eyeW, height: leftH)
            context.fill(Path(roundedRect: leftRect, cornerRadius: radius), with: .color(.white))

            // Right eye
            let rightX = posX + eyeW + eyeSpacing
            let rightRect = CGRect(x: rightX, y: posY, width: eyeW, height: rightH)
            context.fill(Path(roundedRect: rightRect, cornerRadius: radius), with: .color(.white))

            // --- Eyelid overlays ---

            // Tired eyelids: triangles drooping outward
            let tiredH = animator.eyelidsTiredHeight * scaleY
            if tiredH > 0.5 {
                var ltPath = Path()
                ltPath.move(to: CGPoint(x: leftRect.minX, y: leftRect.minY - 1))
                ltPath.addLine(to: CGPoint(x: leftRect.maxX, y: leftRect.minY - 1))
                ltPath.addLine(to: CGPoint(x: leftRect.minX, y: leftRect.minY + tiredH - 1))
                ltPath.closeSubpath()
                context.fill(ltPath, with: .color(.black))

                var rtPath = Path()
                rtPath.move(to: CGPoint(x: rightRect.minX, y: rightRect.minY - 1))
                rtPath.addLine(to: CGPoint(x: rightRect.maxX, y: rightRect.minY - 1))
                rtPath.addLine(to: CGPoint(x: rightRect.maxX, y: rightRect.minY + tiredH - 1))
                rtPath.closeSubpath()
                context.fill(rtPath, with: .color(.black))
            }

            // Angry eyelids: triangles angling inward (furrowed brow)
            let angryH = animator.eyelidsAngryHeight * scaleY
            if angryH > 0.5 {
                var laPath = Path()
                laPath.move(to: CGPoint(x: leftRect.minX, y: leftRect.minY - 1))
                laPath.addLine(to: CGPoint(x: leftRect.maxX, y: leftRect.minY - 1))
                laPath.addLine(to: CGPoint(x: leftRect.maxX, y: leftRect.minY + angryH - 1))
                laPath.closeSubpath()
                context.fill(laPath, with: .color(.black))

                var raPath = Path()
                raPath.move(to: CGPoint(x: rightRect.minX, y: rightRect.minY - 1))
                raPath.addLine(to: CGPoint(x: rightRect.maxX, y: rightRect.minY - 1))
                raPath.addLine(to: CGPoint(x: rightRect.minX, y: rightRect.minY + angryH - 1))
                raPath.closeSubpath()
                context.fill(raPath, with: .color(.black))
            }

            // Happy eyelids: rounded rect covering bottom portion
            let happyOff = animator.eyelidsHappyBottomOffset * scaleY
            if happyOff > 0.5 {
                let lhRect = CGRect(
                    x: leftRect.minX - 1,
                    y: leftRect.maxY - happyOff + 1,
                    width: leftRect.width + 2,
                    height: happyOff + 4
                )
                context.fill(Path(roundedRect: lhRect, cornerRadius: radius), with: .color(.black))

                let rhRect = CGRect(
                    x: rightRect.minX - 1,
                    y: rightRect.maxY - happyOff + 1,
                    width: rightRect.width + 2,
                    height: happyOff + 4
                )
                context.fill(Path(roundedRect: rhRect, cornerRadius: radius), with: .color(.black))
            }

            // Scanlines
            var y: CGFloat = 0
            while y < size.height {
                let line = Path(CGRect(x: 0, y: y, width: size.width, height: 1))
                context.fill(line, with: .color(Color.black.opacity(0.12)))
                y += 3
            }
        }
        // Red eyes: only in critical phase
        .colorMultiply(animator.showRedEyes ? Color(red: 1.0, green: 0.3, blue: 0.2) : .white)
        .animation(.easeInOut(duration: 0.5), value: animator.showRedEyes)
        .onChange(of: mood) { _, newMood in
            animator.setMood(newMood)
        }
        .onChange(of: phase) { _, newPhase in
            animator.setRedEyes(newPhase == .critical)
        }
        .onTapGesture {
            animator.tapReaction()
        }
    }
}
