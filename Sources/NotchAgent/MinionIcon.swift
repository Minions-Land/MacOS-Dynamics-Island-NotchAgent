import AppKit

extension NSImage {
    static func minionIcon(size: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }

            let scale = size / 18.0
            context.scaleBy(x: scale, y: scale)

            let strokeColor = NSColor.white.cgColor
            context.setStrokeColor(strokeColor)
            context.setLineWidth(1.2)
            context.setLineCap(.round)
            context.setLineJoin(.round)

            // Body (tall rounded capsule)
            let bodyPath = CGMutablePath()
            bodyPath.addRoundedRect(in: CGRect(x: 4.5, y: 1.5, width: 9, height: 14), cornerWidth: 4.5, cornerHeight: 4.5)
            context.addPath(bodyPath)
            context.strokePath()

            // Goggle strap
            context.move(to: CGPoint(x: 3, y: 11.5))
            context.addLine(to: CGPoint(x: 15, y: 11.5))
            context.strokePath()

            // Eye (goggle circle)
            context.addEllipse(in: CGRect(x: 6.5, y: 9.5, width: 5, height: 5))
            context.strokePath()

            // Pupil
            context.setFillColor(strokeColor)
            context.fillEllipse(in: CGRect(x: 8.2, y: 11, width: 1.6, height: 1.6))

            // Smile
            context.move(to: CGPoint(x: 7, y: 6))
            context.addQuadCurve(to: CGPoint(x: 11, y: 6), control: CGPoint(x: 9, y: 4.2))
            context.strokePath()

            // Hair (3 strands)
            context.setLineWidth(1.0)
            context.move(to: CGPoint(x: 7.5, y: 15.5))
            context.addLine(to: CGPoint(x: 7, y: 17))
            context.strokePath()

            context.move(to: CGPoint(x: 9, y: 15.5))
            context.addLine(to: CGPoint(x: 9, y: 17.5))
            context.strokePath()

            context.move(to: CGPoint(x: 10.5, y: 15.5))
            context.addLine(to: CGPoint(x: 11, y: 17))
            context.strokePath()

            return true
        }
        image.isTemplate = true
        return image
    }
}
