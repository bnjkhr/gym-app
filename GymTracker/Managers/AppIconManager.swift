import SwiftUI
import UIKit

// MARK: - App Icon Style

enum AppIconStyle: String, CaseIterable, Identifiable {
    case standard = "Standard"
    case tinted = "Tinted"
    case clear = "Clear"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .standard:
            return "Klassisches Design"
        case .tinted:
            return "Mit Farbakzent"
        case .clear:
            return "Liquid Glass Effekt"
        }
    }

    /// Returns the icon name for the current style and appearance
    func iconName(for appearance: UIUserInterfaceStyle) -> String? {
        switch (self, appearance) {
        case (.standard, .dark):
            return "AppIcon-Dark"
        case (.standard, _):
            return nil // nil = primary icon (AppIcon)
        case (.tinted, .dark):
            return "AppIcon-TintedDark"
        case (.tinted, _):
            return "AppIcon-TintedLight"
        case (.clear, .dark):
            return "AppIcon-ClearDark"
        case (.clear, _):
            return "AppIcon-ClearLight"
        }
    }
}

// MARK: - App Icon Manager

@MainActor
class AppIconManager: ObservableObject {
    static let shared = AppIconManager()

    @Published var currentStyle: AppIconStyle {
        didSet {
            UserDefaults.standard.set(currentStyle.rawValue, forKey: "appIconStyle")
            updateAppIcon()
        }
    }

    private init() {
        let savedStyle = UserDefaults.standard.string(forKey: "appIconStyle")
        self.currentStyle = AppIconStyle(rawValue: savedStyle ?? "") ?? .standard

        // Listen to trait collection changes for automatic icon switching
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateAppIcon()
        }
    }

    /// Updates the app icon based on current style and system appearance
    func updateAppIcon() {
        guard UIApplication.shared.supportsAlternateIcons else {
            print("⚠️ Alternate icons are not supported on this device")
            return
        }

        // Get the current appearance from the key window's trait collection
        let currentAppearance: UIUserInterfaceStyle
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            currentAppearance = window.traitCollection.userInterfaceStyle
            print("📱 Current appearance from window: \(currentAppearance == .dark ? "dark" : "light")")
        } else {
            currentAppearance = UITraitCollection.current.userInterfaceStyle
            print("📱 Current appearance from UITraitCollection.current: \(currentAppearance == .dark ? "dark" : "light")")
        }

        let targetIconName = currentStyle.iconName(for: currentAppearance)
        print("🎯 Target icon: \(targetIconName ?? "Primary (AppIcon)"), Current style: \(currentStyle.rawValue)")
        print("📋 Current alternate icon: \(UIApplication.shared.alternateIconName ?? "Primary")")

        // Check if we need to change the icon
        if UIApplication.shared.alternateIconName != targetIconName {
            print("🔄 Changing icon from '\(UIApplication.shared.alternateIconName ?? "Primary")' to '\(targetIconName ?? "Primary")'")
            UIApplication.shared.setAlternateIconName(targetIconName) { error in
                if let error = error {
                    print("❌ Failed to change app icon: \(error.localizedDescription)")
                } else {
                    print("✅ App icon changed to: \(targetIconName ?? "Primary")")
                }
            }
        } else {
            print("ℹ️ Icon already set to correct value, no change needed")
        }
    }

    /// Call this when the app's trait collection changes (e.g., dark mode toggle)
    func handleTraitCollectionChange() {
        updateAppIcon()
    }
}

// MARK: - UserDefaults Extension

extension UserDefaults {
    var appIconStyle: AppIconStyle {
        get {
            guard let rawValue = string(forKey: "appIconStyle"),
                  let style = AppIconStyle(rawValue: rawValue) else {
                return .standard
            }
            return style
        }
        set {
            set(newValue.rawValue, forKey: "appIconStyle")
        }
    }
}
