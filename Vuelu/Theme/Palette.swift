import SwiftUI
import UIKit

/// Colours sampled from the logo: a muted violet bookmark on a lavender background.
nonisolated extension Color {
    /// The bookmark violet itself (logo: #8C7DA7).
    static let brand = Color(light: 0x8C7DA7, dark: 0xA898D0)
    /// Deeper violet for text and controls that need contrast.
    static let brandDeep = Color(light: 0x6B5B8E, dark: 0xB8AADE)
    /// Filled buttons with white labels: stays dark enough for contrast in both modes.
    static let brandFill = Color(light: 0x6B5B8E, dark: 0x7A68AC)
    /// App background, the logo's lavender (logo: #EFEAF8).
    static let canvas = Color(light: 0xEFEAF8, dark: 0x15121D)
    /// Cards sitting on the canvas.
    static let surface = Color(light: 0xFAF8FE, dark: 0x221D2D)
    static let inkSecondary = Color(light: 0x6E6680, dark: 0xA79FB8)

    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

nonisolated extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
