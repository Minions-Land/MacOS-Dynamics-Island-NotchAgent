import SwiftUI

struct MinionShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Body capsule
        let bodyRect = CGRect(x: w * 0.25, y: h * 0.1, width: w * 0.5, height: h * 0.75)
        path.addRoundedRect(in: bodyRect, cornerSize: CGSize(width: w * 0.25, height: w * 0.25))

        // Goggle strap
        path.move(to: CGPoint(x: w * 0.15, y: h * 0.58))
        path.addLine(to: CGPoint(x: w * 0.85, y: h * 0.58))

        // Eye circle
        path.addEllipse(in: CGRect(x: w * 0.35, y: h * 0.48, width: w * 0.3, height: w * 0.3))

        // Hair strands
        path.move(to: CGPoint(x: w * 0.4, y: h * 0.85))
        path.addLine(to: CGPoint(x: w * 0.38, y: h * 0.95))

        path.move(to: CGPoint(x: w * 0.6, y: h * 0.85))
        path.addLine(to: CGPoint(x: w * 0.62, y: h * 0.95))

        return path
    }
}

struct MinionIconView: View {
    var size: CGFloat = 14

    var body: some View {
        ZStack {
            MinionShape()
                .stroke(Color.white, lineWidth: 1.2)
                .frame(width: size, height: size)

            // Pupil dot
            Circle()
                .fill(Color.white)
                .frame(width: size * 0.1, height: size * 0.1)
                .offset(y: -size * 0.05)

            // Smile
            SmilePath()
                .stroke(Color.white, lineWidth: 1.0)
                .frame(width: size * 0.3, height: size * 0.1)
                .offset(y: size * 0.15)
        }
        .frame(width: size, height: size)
    }
}

struct SmilePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.midX, y: rect.maxY)
        )
        return path
    }
}
