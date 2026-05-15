import SwiftUI

struct MinionIconView: View {
    var size: CGFloat = 14

    var body: some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width
            let lineWidth: CGFloat = s * 0.08

            // Body capsule
            let bodyRect = CGRect(x: s * 0.22, y: s * 0.08, width: s * 0.56, height: s * 0.78)
            let bodyPath = RoundedRectangle(cornerRadius: s * 0.25).path(in: bodyRect)
            context.stroke(bodyPath, with: .color(.white), lineWidth: lineWidth)

            // Goggle strap
            var strapPath = Path()
            strapPath.move(to: CGPoint(x: s * 0.12, y: s * 0.42))
            strapPath.addLine(to: CGPoint(x: s * 0.88, y: s * 0.42))
            context.stroke(strapPath, with: .color(.white), lineWidth: lineWidth)

            // Eye circle
            let eyeRect = CGRect(x: s * 0.32, y: s * 0.3, width: s * 0.36, height: s * 0.36)
            let eyePath = Circle().path(in: eyeRect)
            context.stroke(eyePath, with: .color(.white), lineWidth: lineWidth)

            // Pupil
            let pupilRect = CGRect(x: s * 0.44, y: s * 0.42, width: s * 0.12, height: s * 0.12)
            let pupilPath = Circle().path(in: pupilRect)
            context.fill(pupilPath, with: .color(.white))

            // Smile
            var smilePath = Path()
            smilePath.move(to: CGPoint(x: s * 0.36, y: s * 0.72))
            smilePath.addQuadCurve(
                to: CGPoint(x: s * 0.64, y: s * 0.72),
                control: CGPoint(x: s * 0.5, y: s * 0.82)
            )
            context.stroke(smilePath, with: .color(.white), lineWidth: lineWidth * 0.8)

            // Hair strands
            let hairWidth = lineWidth * 0.7
            var hair1 = Path()
            hair1.move(to: CGPoint(x: s * 0.4, y: s * 0.08))
            hair1.addLine(to: CGPoint(x: s * 0.38, y: 0))
            context.stroke(hair1, with: .color(.white), lineWidth: hairWidth)

            var hair2 = Path()
            hair2.move(to: CGPoint(x: s * 0.5, y: s * 0.06))
            hair2.addLine(to: CGPoint(x: s * 0.5, y: 0))
            context.stroke(hair2, with: .color(.white), lineWidth: hairWidth)

            var hair3 = Path()
            hair3.move(to: CGPoint(x: s * 0.6, y: s * 0.08))
            hair3.addLine(to: CGPoint(x: s * 0.62, y: 0))
            context.stroke(hair3, with: .color(.white), lineWidth: hairWidth)
        }
        .frame(width: size, height: size)
    }
}
