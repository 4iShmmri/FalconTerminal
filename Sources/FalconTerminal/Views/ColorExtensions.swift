import SwiftUI

extension Color {
    init(_ rgb: RGBColor) {
        self.init(nsColor: rgb.nsColor)
    }

    /// Parse a `#RRGGBB` hex string, falling back to `fallback`.
    init(hex: String, fallback: Color = .gray) {
        guard hex.hasPrefix("#"), hex.count == 7 else { self = fallback; return }
        self.init(RGBColor(hex: hex))
    }
}
