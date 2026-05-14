import AppKit

extension NSImage {
    static func minionIcon(size: CGFloat = 16) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }

            let scale = size / 16.0
            context.scaleBy(x: scale, y: scale)

            let strokeColor = NSColor.white.cgColor
            context.setStrokeColor(strokeColor)
            context.setLineWidth(1.0)
            context.setLineCap(.round)
            context.setLineJoin(.round)

            // Body (rounded capsule shape)
            let bodyRect = CGRect(x: 4, y: 2, width: 8, height: 12)
            let bodyPath = CGPath(roundedRect: bodyRect, cornerWidth: 4, cornerHeight: 4, transform: nil)
            context.addPath(bodyPath)
            context.strokePath()

            // Goggle strap (horizontal line across head)
            context.move(to: CGPoint(x: 3, y: 10.5))
            context.addLine(to: CGPoint(x: 13, y: 10.5))
            context.strokePath()

            // Single eye (circle in center)
            let eyeRect = CGRect(x: 6.5, y: 9, width: 3, height: 3)
            context.addEllipse(in: eyeRect)
            context.strokePath()

            // Pupil (small dot)
            context.setFillColor(strokeColor)
            let pupilRect = CGRect(x: 7.5, y: 9.8, width: 1.2, height: 1.2)
            context.fillEllipse(in: pupilRect)

            // Mouth (small smile)
            context.move(to: CGPoint(x: 6.5, y: 7))
            context.addQuadCurve(to: CGPoint(x: 9.5, y: 7), control: CGPoint(x: 8, y: 5.8))
            context.strokePath()

            // Hair (2 small lines on top)
            context.move(to: CGPoint(x: 7, y: 14))
            context.addLine(to: CGPoint(x: 7, y: 15.5))
            context.strokePath()

            context.move(to: CGPoint(x: 9, y: 14))
            context.addLine(to: CGPoint(x: 9, y: 15.5))
            context.strokePath()

            return true
        }
        image.isTemplate = true
        return image
    }
}
