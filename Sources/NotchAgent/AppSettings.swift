import Foundation
import SwiftUI

@MainActor
@Observable
class AppSettings {
    static let shared = AppSettings()

    var fontScale: Double {
        didSet {
            UserDefaults.standard.set(fontScale, forKey: "fontScale")
        }
    }

    private init() {
        let saved = UserDefaults.standard.double(forKey: "fontScale")
        self.fontScale = saved > 0 ? saved : 1.0
    }

    func scaled(_ base: CGFloat) -> CGFloat {
        base * fontScale
    }

    static let scaleOptions: [(label: String, value: Double)] = [
        ("Small", 0.9),
        ("Default", 1.0),
        ("Large", 1.2),
        ("Extra Large", 1.4)
    ]
}
