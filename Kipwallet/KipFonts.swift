import SwiftUI

/// Manrope: fuente oficial de la familia Kip (decision de Jesus, 2026-11-08).
/// Los .ttf reales de la app Android van en la carpeta Fonts del proyecto
/// y se registran en el Info.plist (UIAppFonts). Los nombres PostScript
/// internos de esos archivos son Manrope-Regular/-SemiBold/-Bold/-ExtraBold;
/// SwiftUI resuelve la familia y el peso contra ellos.
enum KipFont {
    static let family = "Manrope"
}

extension Font {
    static func manrope(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(KipFont.family, size: size).weight(weight)
    }
}
