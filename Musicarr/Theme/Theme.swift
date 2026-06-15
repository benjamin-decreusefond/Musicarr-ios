import SwiftUI

/// Musicarr's visual language, ported from the web app's CSS variables so the
/// iOS / tvOS client looks and feels like the server's web UI.
enum Theme {
    // Core palette (matches web `:root` custom properties).
    static let bg          = Color(hex: 0x0B0C10)
    static let bgElev      = Color(hex: 0x141620)
    static let bgElev2     = Color(hex: 0x1C1F2E)
    static let surfaceHover = Color(hex: 0x232739)
    static let text        = Color(hex: 0xF4F5FB)
    static let textDim     = Color(hex: 0x9AA0B4)
    static let textFaint   = Color(hex: 0x5D6275)
    static let accent      = Color(hex: 0xC9F24D)   // acid lime — the signature
    static let accentInk   = Color(hex: 0x11140A)
    static let line        = Color(hex: 0x242838)
    static let danger      = Color(hex: 0xFF5D6C)

    static let radius: CGFloat = 10
    static let radiusLg: CGFloat = 16

    // Display font (Space Grotesk on web; we fall back to rounded system here).
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

/// A page background gradient like the web `.main` area.
struct PageBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Theme.bgElev, Theme.bg],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

extension View {
    /// Apply the app's dark scheme consistently.
    func musicarrScreen() -> some View {
        self
            .background(Theme.bg.ignoresSafeArea())
            .preferredColorScheme(.dark)
            .tint(Theme.accent)
    }
}
