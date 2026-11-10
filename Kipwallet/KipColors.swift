import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// Paleta oficial de la familia Kip (la misma de las apps Android, verificada en su codigo).
enum KipColor {
    static let accent = Color(hex: 0x5EC96E)
    static let gradientStart = Color(hex: 0xB3F76E)
    static let gradientEnd = Color(hex: 0x2FA36B)
    static let onAccent = Color(hex: 0x0C2313)
    static let darkBg = Color(hex: 0x12181F)
    static let darkCard = Color(hex: 0x1D2833)
    static let darkElevated = Color(hex: 0x2C3B49)
    static let darkBorder = Color(hex: 0x35485A)
    static let darkText = Color(hex: 0xEDF2F4)
    static let darkTextSecondary = Color(hex: 0x9FB0BF)
    static let lightBg = Color(hex: 0xF4F5F3)
    static let lightCard = Color(hex: 0xFAFBF9)
    static let lightElevated = Color(hex: 0xEDF1ED)
    static let lightBorder = Color(hex: 0xDFE5DE)
    static let lightText = Color(hex: 0x1C2420)
    static let lightTextSecondary = Color(hex: 0x61746A)

    static func bg(_ scheme: ColorScheme) -> Color { scheme == .dark ? darkBg : lightBg }
    static func card(_ scheme: ColorScheme) -> Color { scheme == .dark ? darkCard : lightCard }
    static func elevated(_ scheme: ColorScheme) -> Color { scheme == .dark ? darkElevated : lightElevated }
    static func border(_ scheme: ColorScheme) -> Color { scheme == .dark ? darkBorder : lightBorder }
    static func text(_ scheme: ColorScheme) -> Color { scheme == .dark ? darkText : lightText }
    static func textSecondary(_ scheme: ColorScheme) -> Color { scheme == .dark ? darkTextSecondary : lightTextSecondary }
}
