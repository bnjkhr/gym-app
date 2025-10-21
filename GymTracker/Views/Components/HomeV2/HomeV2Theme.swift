import SwiftUI

/// HomeV2 Theme - Zentrale Farbdefinitionen für Light/Dark Mode
///
/// **Usage:**
/// ```swift
/// Text("Hello")
///     .foregroundStyle(HomeV2Theme.primaryText)
///
/// VStack { }
///     .background(HomeV2Theme.cardBackground)
/// ```
struct HomeV2Theme {
    // MARK: - Backgrounds

    /// Card Background (white in light, dark gray in dark)
    static let cardBackground = Color(
        uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(white: 0.15, alpha: 1.0)  // Dark gray
                : UIColor.white  // White
        })

    /// Page Background (light gray in light, black in dark)
    static let pageBackground = Color(
        uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor.black  // Black
                : UIColor.systemGroupedBackground  // Light gray
        })

    /// Card Border (subtle gray in both modes)
    static let cardBorder = Color(
        uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(white: 0.3, alpha: 1.0)  // Lighter gray for visibility
                : UIColor.systemGray5  // Light mode gray
        })

    // MARK: - Text Colors

    /// Primary Text (black in light, white in dark)
    static let primaryText = Color(
        uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor.white  // White
                : UIColor.black  // Black
        })

    /// Secondary Text (gray in both modes)
    static let secondaryText = Color(
        uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor.systemGray  // Light gray
                : UIColor.gray  // Medium gray
        })

    // MARK: - Buttons

    /// Primary Button Background (black in light, white in dark)
    static let primaryButtonBackground = Color(
        uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor.white  // White
                : UIColor.black  // Black
        })

    /// Primary Button Text (white in light, black in dark) - inverse of background
    static let primaryButtonText = Color(
        uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor.black  // Black text on white button
                : UIColor.white  // White text on black button
        })

    /// Secondary Button Background (light gray in light, dark gray in dark)
    static let secondaryButtonBackground = Color(
        uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(white: 0.3, alpha: 1.0)  // Dark gray
                : UIColor.systemGray6  // Light gray
        })

    /// Secondary Button Text (follows primaryText)
    static let secondaryButtonText = primaryText

    // MARK: - Icons

    /// Icon Color (follows primaryText)
    static let iconColor = primaryText

    /// Icon Color Secondary (follows secondaryText)
    static let iconColorSecondary = secondaryText
}
