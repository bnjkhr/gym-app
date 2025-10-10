import SwiftUI

// MARK: - App Theme

enum AppTheme {
    // MARK: - Primary Colors

    /// PowerOrange - Hauptakzentfarbe
    static let powerOrange = Color(
        light: Color(red: 255/255, green: 107/255, blue: 26/255),
        dark: Color(red: 255/255, green: 122/255, blue: 42/255)
    )

    /// DeepBlue - Sekundärfarbe für Navigation und Flächen
    static let deepBlue = Color(
        light: Color(red: 30/255, green: 58/255, blue: 138/255),
        dark: Color(red: 11/255, green: 21/255, blue: 51/255)
    )

    /// TurquoiseBoost - Akzentfarbe für Highlights
    static let turquoiseBoost = Color(
        light: Color(red: 82/255, green: 167/255, blue: 204/255),
        dark: Color(red: 82/255, green: 167/255, blue: 204/255)
    )

    /// MossGreen - Erfolgs- und Bestätigungsfarbe
    static let mossGreen = Color(
        light: Color(red: 75/255, green: 127/255, blue: 82/255),
        dark: Color(red: 92/255, green: 154/255, blue: 100/255)
    )

    /// BrightYellow - Warnfarbe und Highlights
    static let brightYellow = Color(
        light: Color(red: 255/255, green: 214/255, blue: 10/255),
        dark: Color(red: 245/255, green: 196/255, blue: 0/255)
    )

    // MARK: - Background & Surfaces

    /// NeutralGrey - Haupthintergrund
    static let background = Color(
        light: Color(red: 243/255, green: 244/255, blue: 246/255),
        dark: Color(red: 15/255, green: 17/255, blue: 21/255)
    )

    /// Card/Surface Background
    static let cardBackground = Color(
        light: Color.white,
        dark: Color(red: 25/255, green: 27/255, blue: 31/255)
    )

    // MARK: - Text Colors

    /// Primary Text
    static let textPrimary = Color(
        light: Color(red: 11/255, green: 11/255, blue: 12/255),
        dark: Color.white
    )

    /// Secondary Text
    static let textSecondary = Color(
        light: Color(red: 91/255, green: 98/255, blue: 106/255),
        dark: Color(red: 151/255, green: 161/255, blue: 172/255)
    )

    // MARK: - Gradients

    /// Hintergrundverlauf für Header-Karten
    static var headerGradient: LinearGradient {
        LinearGradient(
            colors: [powerOrange, deepBlue],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Verlauf für Karten
    static var cardGradient: LinearGradient {
        LinearGradient(
            colors: [cardBackground.opacity(0.8), cardBackground],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Legacy Support
    @available(*, deprecated, message: "Use powerOrange instead")
    static let purple = powerOrange

    @available(*, deprecated, message: "Use deepBlue instead")
    static let indigo = deepBlue

    @available(*, deprecated, message: "Use deepBlue instead")
    static let darkPurple = deepBlue

    @available(*, deprecated, message: "Use background instead")
    static let darkBackground = background
}

// MARK: - Color Extension for Light/Dark Mode

extension Color {
    init(light: Color, dark: Color) {
        self.init(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(dark)
            default:
                return UIColor(light)
            }
        })
    }
}



// MARK: - Reusable Styles

struct GradientCardBackground: View {
    var cornerRadius: CGFloat = 32
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(AppTheme.headerGradient)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.25), radius: 24, x: 0, y: 16)
    }
}

extension View {
    func bigAppleTitleStyle() -> some View {
        self
            .font(.title.weight(.bold))
            .foregroundStyle(.white)
    }

    func pillSearchFieldStyle() -> some View {
        self
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.18))
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
                    )
            )
    }
}

#Preview("Theme Card") {
    ZStack { Color.black.ignoresSafeArea() }
        .overlay(
            VStack(spacing: 8) {
                Text("Starte deine\nTrainingsreise").bigAppleTitleStyle()
                
                GradientCardBackground()
                    .frame(height: 120)
                    .padding(.horizontal, 16)
            }
        )
}



