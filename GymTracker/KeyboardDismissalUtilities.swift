import SwiftUI
import UIKit

// MARK: - Keyboard Dismissal Utilities

/// A view modifier that dismisses the keyboard when tapping outside text fields
struct DismissKeyboardOnTap: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onTapGesture {
                hideKeyboard()
            }
    }
}

/// A view modifier that dismisses the keyboard when dragging starts
struct DismissKeyboardOnDrag: ViewModifier {
    func body(content: Content) -> some View {
        content
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        hideKeyboard()
                    }
            )
    }
}

/// A comprehensive keyboard dismissal modifier that combines tap and drag gestures
struct DismissKeyboard: ViewModifier {
    let includeDrag: Bool
    
    init(includeDrag: Bool = true) {
        self.includeDrag = includeDrag
    }
    
    func body(content: Content) -> some View {
        content
            .onTapGesture {
                hideKeyboard()
            }
            .conditionalModifier(includeDrag) { view in
                view.gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            hideKeyboard()
                        }
                )
            }
    }
}

// MARK: - Helper Extensions

extension View {
    /// Dismisses the keyboard when tapping outside text fields
    func dismissKeyboardOnTap() -> some View {
        modifier(DismissKeyboardOnTap())
    }
    
    /// Dismisses the keyboard when dragging starts
    func dismissKeyboardOnDrag() -> some View {
        modifier(DismissKeyboardOnDrag())
    }
    
    /// Comprehensive keyboard dismissal with both tap and optional drag
    func dismissKeyboard(includeDrag: Bool = true) -> some View {
        modifier(DismissKeyboard(includeDrag: includeDrag))
    }
    
    /// Conditionally applies a modifier
    @ViewBuilder
    func conditionalModifier<T: ViewModifier>(_ condition: Bool, _ modifier: T) -> some View {
        if condition {
            self.modifier(modifier)
        } else {
            self
        }
    }
    
    /// Conditionally applies a view transformation
    @ViewBuilder
    func conditionalModifier<T>(_ condition: Bool, _ transform: (Self) -> T) -> some View where T: View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Global Keyboard Dismissal Function

/// Globally dismisses the keyboard
func hideKeyboard() {
    DispatchQueue.main.async {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), 
                                       to: nil, 
                                       from: nil, 
                                       for: nil)
    }
}

// MARK: - SwiftUI Environment Extension

/// Environment key for keyboard dismissal preferences
struct KeyboardDismissalKey: EnvironmentKey {
    static let defaultValue: Bool = true
}

extension EnvironmentValues {
    /// Whether keyboard dismissal should be enabled globally
    var keyboardDismissalEnabled: Bool {
        get { self[KeyboardDismissalKey.self] }
        set { self[KeyboardDismissalKey.self] = newValue }
    }
}

// MARK: - Smart Keyboard Dismissal Modifier

/// A smart keyboard dismissal modifier that respects environment settings
struct SmartKeyboardDismissal: ViewModifier {
    @Environment(\.keyboardDismissalEnabled) private var isEnabled
    let includeDrag: Bool
    
    init(includeDrag: Bool = true) {
        self.includeDrag = includeDrag
    }
    
    func body(content: Content) -> some View {
        content
            .conditionalModifier(isEnabled) { view in
                view.dismissKeyboard(includeDrag: includeDrag)
            }
    }
}

extension View {
    /// Smart keyboard dismissal that respects environment settings
    func smartKeyboardDismissal(includeDrag: Bool = true) -> some View {
        modifier(SmartKeyboardDismissal(includeDrag: includeDrag))
    }
}

// MARK: - Keyboard Dismissal for Specific Views

/// A view modifier specifically designed for ScrollView content
struct ScrollViewKeyboardDismissal: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        hideKeyboard()
                    }
            )
    }
}

extension View {
    /// Dismisses keyboard when tapping empty areas in ScrollView
    func scrollViewKeyboardDismissal() -> some View {
        modifier(ScrollViewKeyboardDismissal())
    }
}

// MARK: - UIKit Integration Helper

#if canImport(UIKit)
/// A UIKit-based solution for more precise keyboard dismissal
struct UIKitKeyboardDismissal: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = UIColor.clear
        
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject {
        @objc func dismissKeyboard() {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), 
                                          to: nil, 
                                          from: nil, 
                                          for: nil)
        }
    }
}

extension View {
    /// Uses UIKit-based keyboard dismissal for more precise control
    func uiKitKeyboardDismissal() -> some View {
        background(UIKitKeyboardDismissal())
    }
}
#endif

// MARK: - Keyboard State Monitoring

/// Observable class to monitor keyboard state
@MainActor
class KeyboardMonitor: ObservableObject {
    @Published var isKeyboardVisible = false
    @Published var keyboardHeight: CGFloat = 0
    
    init() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.keyboardWillShow(notification)
        }
        
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.keyboardWillHide(notification)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func keyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        isKeyboardVisible = true
        keyboardHeight = keyboardFrame.height
    }
    
    private func keyboardWillHide(_ notification: Notification) {
        isKeyboardVisible = false
        keyboardHeight = 0
    }
}

// MARK: - Example Usage Comments

/*
 
 USAGE EXAMPLES:
 
 1. Basic tap-to-dismiss for any view:
    YourView()
        .dismissKeyboardOnTap()
 
 2. Tap and drag to dismiss:
    YourView()
        .dismissKeyboard()
 
 3. Only tap to dismiss (no drag):
    YourView()
        .dismissKeyboard(includeDrag: false)
 
 4. Smart dismissal that respects environment:
    YourView()
        .smartKeyboardDismissal()
        .environment(\.keyboardDismissalEnabled, true)
 
 5. For ScrollView content:
    ScrollView {
        YourContent()
    }
    .scrollViewKeyboardDismissal()
 
 6. UIKit-based solution for precise control:
    YourView()
        .uiKitKeyboardDismissal()
 
 7. Monitor keyboard state:
    struct MyView: View {
        @StateObject private var keyboardMonitor = KeyboardMonitor()
        
        var body: some View {
            YourContent()
                .padding(.bottom, keyboardMonitor.keyboardHeight)
        }
    }
 
 8. Apply globally in your main ContentView:
    ContentView()
        .dismissKeyboard()
        .environment(\.keyboardDismissalEnabled, true)
 
 */