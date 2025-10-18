//
//  ValidatedTextField.swift
//  GymTracker
//
//  Validated text field components for common input types
//

import SwiftUI

// MARK: - Weight Input Field

/// TextField for weight input with automatic validation
struct WeightTextField: View {
    @Binding var weight: Double
    var placeholder: String = "kg"
    var label: String? = nil

    @State private var textValue: String
    @FocusState private var isFocused: Bool

    init(weight: Binding<Double>, placeholder: String = "kg", label: String? = nil) {
        self._weight = weight
        self.placeholder = placeholder
        self.label = label
        self._textValue = State(initialValue: weight.wrappedValue > 0 ? InputValidation.formatWeight(weight.wrappedValue) : "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let label = label {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            TextField(placeholder, text: $textValue)
                .keyboardType(.decimalPad)
                .focused($isFocused)
                .onChange(of: textValue) { _, newValue in
                    validateAndUpdate(newValue)
                }
                .onChange(of: isFocused) { _, focused in
                    if !focused {
                        // Format on blur
                        if weight > 0 {
                            textValue = InputValidation.formatWeight(weight)
                        }
                    }
                }

            if !textValue.isEmpty, let parsed = InputValidation.parseDouble(textValue), !InputValidation.WeightRange.isValid(parsed) {
                Text(parsed < InputValidation.WeightRange.min ? InputValidation.ErrorMessage.weightTooLow : InputValidation.ErrorMessage.weightTooHigh)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }

    private func validateAndUpdate(_ text: String) {
        guard let parsed = InputValidation.parseDouble(text) else {
            if text.isEmpty {
                weight = 0
            }
            return
        }

        // Clamp to valid range
        weight = InputValidation.WeightRange.clamped(parsed)
    }
}

// MARK: - Reps Input Field

/// TextField for repetitions input with automatic validation
struct RepsTextField: View {
    @Binding var reps: Int
    var placeholder: String = "Wdh."
    var label: String? = nil

    @State private var textValue: String
    @FocusState private var isFocused: Bool

    init(reps: Binding<Int>, placeholder: String = "Wdh.", label: String? = nil) {
        self._reps = reps
        self.placeholder = placeholder
        self.label = label
        self._textValue = State(initialValue: reps.wrappedValue > 0 ? "\(reps.wrappedValue)" : "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let label = label {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            TextField(placeholder, text: $textValue)
                .keyboardType(.numberPad)
                .focused($isFocused)
                .onChange(of: textValue) { _, newValue in
                    validateAndUpdate(newValue)
                }
                .onChange(of: isFocused) { _, focused in
                    if !focused {
                        // Format on blur
                        if reps > 0 {
                            textValue = "\(reps)"
                        }
                    }
                }

            if !textValue.isEmpty, let parsed = InputValidation.parseInt(textValue), !InputValidation.RepsRange.isValid(parsed) {
                Text(parsed < InputValidation.RepsRange.min ? InputValidation.ErrorMessage.repsTooLow : InputValidation.ErrorMessage.repsTooHigh)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }

    private func validateAndUpdate(_ text: String) {
        guard let parsed = InputValidation.parseInt(text) else {
            if text.isEmpty {
                reps = 0
            }
            return
        }

        // Clamp to valid range
        reps = InputValidation.RepsRange.clamped(parsed)
    }
}

// MARK: - Body Weight Input Field

/// TextField for body weight input with automatic validation
struct BodyWeightTextField: View {
    @Binding var weight: Double
    var placeholder: String = "kg"
    var label: String? = "Körpergewicht"

    @State private var textValue: String
    @FocusState private var isFocused: Bool

    init(weight: Binding<Double>, placeholder: String = "kg", label: String? = "Körpergewicht") {
        self._weight = weight
        self.placeholder = placeholder
        self.label = label
        self._textValue = State(initialValue: weight.wrappedValue > 0 ? InputValidation.formatWeight(weight.wrappedValue) : "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let label = label {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            TextField(placeholder, text: $textValue)
                .keyboardType(.decimalPad)
                .focused($isFocused)
                .onChange(of: textValue) { _, newValue in
                    validateAndUpdate(newValue)
                }
                .onChange(of: isFocused) { _, focused in
                    if !focused {
                        // Format on blur
                        if weight > 0 {
                            textValue = InputValidation.formatWeight(weight)
                        }
                    }
                }

            if !textValue.isEmpty, let parsed = InputValidation.parseDouble(textValue), !InputValidation.BodyWeightRange.isValid(parsed) {
                Text(parsed < InputValidation.BodyWeightRange.min ? InputValidation.ErrorMessage.bodyWeightTooLow : InputValidation.ErrorMessage.bodyWeightTooHigh)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }

    private func validateAndUpdate(_ text: String) {
        guard let parsed = InputValidation.parseDouble(text) else {
            if text.isEmpty {
                weight = 0
            }
            return
        }

        // Clamp to valid range
        weight = InputValidation.BodyWeightRange.clamped(parsed)
    }
}

// MARK: - Preview

#Preview("Validated TextFields") {
    Form {
        Section("Exercise Weight") {
            WeightTextField(weight: .constant(75.5), label: "Gewicht")
        }

        Section("Repetitions") {
            RepsTextField(reps: .constant(12), label: "Wiederholungen")
        }

        Section("Body Weight") {
            BodyWeightTextField(weight: .constant(80.0))
        }
    }
}
