import SwiftUI
import UIKit

/// Custom TextField with automatic text selection on focus
///
/// A UIKit-based text field that automatically selects all text when editing begins,
/// making it easy for users to quickly replace values. Supports both numeric and decimal input
/// with proper validation and formatting.
///
/// **Features:**
/// - Auto-selects all text on focus for quick replacement
/// - Decimal pad support with comma/dot handling
/// - Number pad support for integer values
/// - Custom font, text color, and tint color
/// - Zero-value handling (displays empty string)
/// - Prevents multiple decimal separators
///
/// **Usage:**
/// ```swift
/// SelectAllTextField(
///     value: $weight,
///     placeholder: "0",
///     keyboardType: .decimalPad,
///     uiFont: UIFont.systemFont(ofSize: 28, weight: .semibold),
///     textColor: UIColor.label
/// )
/// ```
///
/// **Note:** Primarily used in WorkoutSetCard and ActiveWorkoutSetCard for reps/weight input.
struct SelectAllTextField<Value: Numeric & LosslessStringConvertible>: UIViewRepresentable {
    @Binding var value: Value
    let placeholder: String
    let keyboardType: UIKeyboardType
    var uiFont: UIFont? = nil
    var textColor: UIColor? = nil
    var tintColor: UIColor? = nil

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.keyboardType = keyboardType
        textField.placeholder = placeholder
        textField.textAlignment = .center
        if let uiFont { textField.font = uiFont }
        if let textColor { textField.textColor = textColor }
        if let tintColor { textField.tintColor = tintColor }
        textField.addTarget(
            context.coordinator, action: #selector(Coordinator.textFieldDidChange),
            for: .editingChanged)
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if let uiFont { uiView.font = uiFont }
        if let textColor { uiView.textColor = textColor }
        if let tintColor { uiView.tintColor = tintColor }

        let stringValue: String
        if Value.self == Double.self {
            // For weight fields (Double)
            let doubleValue = value as? Double ?? 0
            if doubleValue > 0 {
                stringValue = String(format: "%.1f", doubleValue).replacingOccurrences(
                    of: ".0", with: "")
            } else {
                stringValue = ""
            }
        } else if Value.self == Int.self {
            // For rep fields (Int)
            let intValue = value as? Int ?? 0
            stringValue = intValue > 0 ? String(intValue) : ""
        } else {
            // Fallback for other types
            stringValue = String(describing: value)
        }

        if uiView.text != stringValue && !uiView.isFirstResponder {
            uiView.text = stringValue
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        let parent: SelectAllTextField

        init(_ parent: SelectAllTextField) {
            self.parent = parent
        }

        @objc func textFieldDidChange(_ textField: UITextField) {
            let text = textField.text ?? ""
            let cleanText = text.replacingOccurrences(of: ",", with: ".")

            if let newValue = Value(cleanText) {
                parent.value = newValue
            } else if text.isEmpty {
                if let zeroValue = Value("0") {
                    parent.value = zeroValue
                }
            }
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            // Select all text when editing begins
            DispatchQueue.main.async {
                textField.selectAll(nil)
            }
        }

        func textField(
            _ textField: UITextField, shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            // Allow only numeric input, comma and dot for decimal fields
            if parent.keyboardType == .decimalPad {
                let allowedCharacters = CharacterSet.decimalDigits.union(
                    CharacterSet(charactersIn: ".,"))
                let characterSet = CharacterSet(charactersIn: string)

                // Prevent multiple decimal separators
                if string == "." || string == "," {
                    let currentText = textField.text ?? ""
                    if currentText.contains(".") || currentText.contains(",") {
                        return false
                    }
                }

                return allowedCharacters.isSuperset(of: characterSet)
            } else {
                // For number pad (reps), only allow digits
                let allowedCharacters = CharacterSet.decimalDigits
                let characterSet = CharacterSet(charactersIn: string)
                return allowedCharacters.isSuperset(of: characterSet)
            }
        }
    }
}
