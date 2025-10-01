import SwiftUI

// MARK: - App Theme

enum AppTheme {
    // Primäre Markenfarbe (Purple wie im Screenshot)
    static let purple = Color(red: 0.36, green: 0.20, blue: 0.60)   // dunkleres Purple
    static let indigo = Color(red: 0.48, green: 0.56, blue: 0.86)   // kühles Indigo/Lavender

    static let darkPurple = Color.darkPurple
    
    // Moos-Grün (eine erdige, natürliche Grünvariante)
    static let mossGreen = Color(red: 0.4, green: 0.6, blue: 0.3)

    // Hintergrundverlauf für Header-Karten
    static var headerGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.70, green: 0.74, blue: 0.92), // helles Lavender oben links
                indigo,                                    // kühles Indigo in der Mitte
                darkPurple,                                // kräftiges Purple
                Color(red: 0.26, green: 0.15, blue: 0.46)  // tiefes Purple unten rechts
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // Verlauf wie die Boxen im Screenshot (leicht glasig)
    static var cardGradient: LinearGradient {
        LinearGradient(
            colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // Dunkler Hintergrundbereich
    static let darkBackground = Color.black
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
            .font(.system(size: 48, weight: .heavy, design: .rounded))
            .tracking(-0.5)
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
            VStack(spacing: 20) {
                Text("Starte deine\nTrainingsreise").bigAppleTitleStyle()
                GradientCardBackground()
                    .frame(height: 220)
                    .padding()
            }
        )
}

