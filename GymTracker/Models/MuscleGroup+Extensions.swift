import Foundation

/// Display name extension for MuscleGroup enum
///
/// Provides German localized display names for all muscle groups used in the UI.
///
/// **Usage:**
/// ```swift
/// let group = MuscleGroup.chest
/// Text(group.displayName) // "Brust"
/// ```
extension MuscleGroup {
    var displayName: String {
        switch self {
        case .chest: return "Brust"
        case .back: return "Rücken"
        case .shoulders: return "Schultern"
        case .biceps: return "Bizeps"
        case .triceps: return "Trizeps"
        case .legs: return "Beine"
        case .glutes: return "Gesäß"
        case .abs: return "Bauch"
        case .cardio: return "Cardio"
        case .forearms: return "Unterarme"
        case .calves: return "Waden"
        case .trapezius: return "Trapezmuskel"
        case .lowerBack: return "Unterer Rücken"
        case .upperBack: return "Oberer Rücken"
        case .fullBody: return "Ganzkörper"
        case .hips: return "Hüfte"
        case .core: return "Rumpf"
        case .hamstrings: return "Beinbeuger"
        case .lats: return "Latissimus"
        case .grip: return "Griffkraft"
        case .arms: return "Arme"
        case .adductors: return "Adduktoren"
        case .obliques: return "Schräge Bauchmuskeln"
        case .hipFlexors: return "Hüftbeuger"
        case .traps: return "Trapez"
        case .coordination: return "Koordination"
        }
    }
}
