import SwiftUI

enum AppLayout {
    // MARK: - Edge Padding

    /// Unified edge padding used across the app
    static let edge: CGFloat = 16

    // MARK: - Spacing System

    /// Spacing scale following a consistent 4pt grid system
    enum Spacing {
        /// Extra small spacing: 4pt
        static let extraSmall: CGFloat = 4

        /// Small spacing: 6pt (used for tight layouts, icon padding)
        static let small: CGFloat = 6

        /// Small-medium spacing: 8pt
        static let smallMedium: CGFloat = 8

        /// Medium-small spacing: 10pt
        static let mediumSmall: CGFloat = 10

        /// Medium spacing: 12pt (common for form fields, card elements)
        static let medium: CGFloat = 12

        /// Default spacing: 16pt (most common, cards, sections)
        static let standard: CGFloat = 16

        /// Large spacing: 20pt (card padding, prominent sections)
        static let large: CGFloat = 20

        /// Extra large spacing: 24pt (major sections, hero elements)
        static let extraLarge: CGFloat = 24

        /// Double extra large spacing: 28pt
        static let xxLarge: CGFloat = 28

        /// Triple extra large spacing: 32pt (maximum spacing)
        static let xxxLarge: CGFloat = 32
    }

    // MARK: - Corner Radius

    enum CornerRadius {
        /// Small corner radius: 8pt
        static let small: CGFloat = 8

        /// Medium corner radius: 12pt (most cards)
        static let medium: CGFloat = 12

        /// Large corner radius: 16pt
        static let large: CGFloat = 16

        /// Extra large corner radius: 20pt
        static let extraLarge: CGFloat = 20
    }
}

extension View {
    /// Apply the app's standard edge padding (default: horizontal)
    func appEdgePadding(_ edges: Edge.Set = .horizontal) -> some View {
        self.padding(edges, AppLayout.edge)
    }
}
