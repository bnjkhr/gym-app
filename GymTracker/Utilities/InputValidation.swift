//
//  InputValidation.swift
//  GymTracker
//
//  Input validation utilities for form fields
//

import Foundation

/// Input validation rules and utilities
enum InputValidation {

    // MARK: - Weight Validation

    /// Valid weight range in kilograms
    enum WeightRange {
        /// Minimum valid weight: 0.5 kg
        static let min: Double = 0.5

        /// Maximum valid weight: 500 kg
        static let max: Double = 500.0

        /// Check if weight is within valid range
        static func isValid(_ weight: Double) -> Bool {
            return weight >= min && weight <= max
        }

        /// Clamp weight to valid range
        static func clamped(_ weight: Double) -> Double {
            return Swift.min(Swift.max(weight, min), max)
        }
    }

    // MARK: - Repetition Validation

    /// Valid repetition range
    enum RepsRange {
        /// Minimum valid repetitions: 1
        static let min: Int = 1

        /// Maximum valid repetitions: 999
        static let max: Int = 999

        /// Check if reps are within valid range
        static func isValid(_ reps: Int) -> Bool {
            return reps >= min && reps <= max
        }

        /// Clamp reps to valid range
        static func clamped(_ reps: Int) -> Int {
            return Swift.min(Swift.max(reps, min), max)
        }
    }

    // MARK: - Body Weight Validation

    /// Valid body weight range in kilograms
    enum BodyWeightRange {
        /// Minimum valid body weight: 20 kg
        static let min: Double = 20.0

        /// Maximum valid body weight: 300 kg
        static let max: Double = 300.0

        /// Check if body weight is within valid range
        static func isValid(_ weight: Double) -> Bool {
            return weight >= min && weight <= max
        }

        /// Clamp body weight to valid range
        static func clamped(_ weight: Double) -> Double {
            return Swift.min(Swift.max(weight, min), max)
        }
    }

    // MARK: - Height Validation

    /// Valid height range in centimeters
    enum HeightRange {
        /// Minimum valid height: 50 cm
        static let min: Double = 50.0

        /// Maximum valid height: 250 cm
        static let max: Double = 250.0

        /// Check if height is within valid range
        static func isValid(_ height: Double) -> Bool {
            return height >= min && height <= max
        }

        /// Clamp height to valid range
        static func clamped(_ height: Double) -> Double {
            return Swift.min(Swift.max(height, min), max)
        }
    }

    // MARK: - Duration Validation

    /// Valid duration range in seconds
    enum DurationRange {
        /// Minimum valid duration: 1 second
        static let min: TimeInterval = 1.0

        /// Maximum valid duration: 24 hours
        static let max: TimeInterval = 24 * 60 * 60.0

        /// Check if duration is within valid range
        static func isValid(_ duration: TimeInterval) -> Bool {
            return duration >= min && duration <= max
        }

        /// Clamp duration to valid range
        static func clamped(_ duration: TimeInterval) -> TimeInterval {
            return Swift.min(Swift.max(duration, min), max)
        }
    }

    // MARK: - String Parsing Helpers

    /// Safely parse double from string
    /// - Parameter string: Input string
    /// - Returns: Parsed double or nil if invalid
    static func parseDouble(_ string: String) -> Double? {
        // Handle both comma and dot as decimal separator
        let normalized = string.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    /// Safely parse int from string
    /// - Parameter string: Input string
    /// - Returns: Parsed int or nil if invalid
    static func parseInt(_ string: String) -> Int? {
        return Int(string)
    }

    /// Format weight for display
    /// - Parameter weight: Weight in kg
    /// - Returns: Formatted string (e.g., "75.5")
    static func formatWeight(_ weight: Double) -> String {
        // Remove trailing zeros
        let formatted = String(format: "%.1f", weight)
        if formatted.hasSuffix(".0") {
            return String(formatted.dropLast(2))
        }
        return formatted
    }

    /// Format reps for display
    /// - Parameter reps: Number of repetitions
    /// - Returns: Formatted string
    static func formatReps(_ reps: Int) -> String {
        return "\(reps)"
    }
}

// MARK: - Validation Error Messages

extension InputValidation {
    /// User-friendly error messages
    enum ErrorMessage {
        static let weightTooLow = "Gewicht muss mindestens \(InputValidation.WeightRange.min) kg sein"
        static let weightTooHigh = "Gewicht darf maximal \(InputValidation.WeightRange.max) kg sein"
        static let repsTooLow = "Wiederholungen müssen mindestens \(InputValidation.RepsRange.min) sein"
        static let repsTooHigh = "Wiederholungen dürfen maximal \(InputValidation.RepsRange.max) sein"
        static let bodyWeightTooLow = "Körpergewicht muss mindestens \(InputValidation.BodyWeightRange.min) kg sein"
        static let bodyWeightTooHigh = "Körpergewicht darf maximal \(InputValidation.BodyWeightRange.max) kg sein"
        static let heightTooLow = "Größe muss mindestens \(InputValidation.HeightRange.min) cm sein"
        static let heightTooHigh = "Größe darf maximal \(InputValidation.HeightRange.max) cm sein"
        static let invalidNumber = "Bitte gültige Zahl eingeben"
    }
}
