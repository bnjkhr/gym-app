//
//  AppButtonStyles.swift
//  GymTracker
//
//  Reusable button styles and components
//

import SwiftUI

// MARK: - Button Styles
// Note: ScaleButtonStyle already exists in ContentView.swift

/// Primary button style with prominent background
struct PrimaryButtonStyle: ButtonStyle {
    var isDestructive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppLayout.Spacing.medium)
            .background(isDestructive ? Color.red : Color.accentColor)
            .cornerRadius(AppLayout.CornerRadius.medium)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Secondary button style with outline
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.accentColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppLayout.Spacing.medium)
            .background(
                RoundedRectangle(cornerRadius: AppLayout.CornerRadius.medium)
                    .stroke(Color.accentColor, lineWidth: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Reusable Button Components

/// Standard delete button with trash icon
struct DeleteButton: View {
    let action: () -> Void
    let title: String

    init(_ title: String = "Löschen", action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(role: .destructive, action: action) {
            Label(title, systemImage: "trash")
        }
    }
}

/// Standard save/confirm button
struct SaveButton: View {
    let action: () -> Void
    let title: String
    let isDisabled: Bool

    init(
        _ title: String = "Speichern",
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
        }
        .disabled(isDisabled)
    }
}

/// Standard cancel button
struct CancelButton: View {
    let action: () -> Void
    let title: String

    init(_ title: String = "Abbrechen", action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
        }
    }
}

/// Icon button with scale animation
struct IconButton: View {
    let systemName: String
    let action: () -> Void
    let tint: Color?

    init(
        systemName: String,
        tint: Color? = nil,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.tint = tint
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title3)
        }
        .buttonStyle(ScaleButtonStyle())
        .if(tint != nil) { view in
            view.tint(tint!)
        }
    }
}

// MARK: - View Extension Helper

extension View {
    /// Conditionally applies a transformation
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Preview

#Preview("Button Styles") {
    VStack(spacing: AppLayout.Spacing.large) {
        Button("Primary Button") {}
            .buttonStyle(PrimaryButtonStyle())

        Button("Destructive Button") {}
            .buttonStyle(PrimaryButtonStyle(isDestructive: true))

        Button("Secondary Button") {}
            .buttonStyle(SecondaryButtonStyle())

        Divider()

        HStack {
            DeleteButton {}
            SaveButton {}
            CancelButton {}
        }

        HStack {
            IconButton(systemName: "plus") {}
            IconButton(systemName: "trash", tint: .red) {}
            IconButton(systemName: "pencil", tint: .blue) {}
        }
    }
    .padding()
}
