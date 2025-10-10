import Foundation
import SwiftUI

struct Exercise: Identifiable, Codable {
    let id: UUID
    var name: String
    var muscleGroups: [MuscleGroup]
    var equipmentType: EquipmentType
    var difficultyLevel: DifficultyLevel
    var description: String
    var instructions: [String]
    var createdAt: Date

    init(id: UUID = UUID(), name: String, muscleGroups: [MuscleGroup], equipmentType: EquipmentType = .mixed, difficultyLevel: DifficultyLevel = .anfänger, description: String = "", instructions: [String] = [], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.muscleGroups = muscleGroups
        self.equipmentType = equipmentType
        self.difficultyLevel = difficultyLevel
        self.description = description
        self.instructions = instructions
        self.createdAt = createdAt
    }
}

enum EquipmentType: String, CaseIterable, Codable {
    case freeWeights = "Freie Gewichte"
    case machine = "Maschine"
    case bodyweight = "Körpergewicht"
    case cable = "Kabelzug"
    case mixed = "Gemischt"
    
    var icon: String {
        switch self {
        case .freeWeights: return "dumbbell"
        case .machine: return "gear"
        case .bodyweight: return "figure.strengthtraining.traditional"
        case .cable: return "cable.connector"
        case .mixed: return "infinity"
        }
    }
}

enum MuscleGroup: String, CaseIterable, Codable {
    case chest = "Brust"
    case back = "Rücken"
    case shoulders = "Schultern"
    case biceps = "Bizeps"
    case triceps = "Trizeps"
    case legs = "Beine"
    case glutes = "Gesäß"
    case abs = "Bauch"
    case cardio = "Cardio"

    // 🆕 NEUE MUSKELGRUPPEN aus MD-Datei
    case forearms = "Unterarme"
    case calves = "Waden"
    case trapezius = "Trapezmuskel"
    case lowerBack = "Unterer Rücken"
    case upperBack = "Oberer Rücken"
    case fullBody = "Ganzkörper"
    case hips = "Hüfte"
    case core = "Rumpf"

    // 🆕 NEUE MUSKELGRUPPEN aus CSV
    case hamstrings = "Beinbeuger"
    case lats = "Latissimus"
    case grip = "Griffkraft"
    case arms = "Arme"
    case adductors = "Adduktoren"
    case obliques = "Schräge Bauchmuskeln"
    case hipFlexors = "Hüftbeuger"
    case traps = "Trapez"
    case coordination = "Koordination"

    var color: Color {
        switch self {
        case .chest: return .red
        case .back: return .customBlue
        case .shoulders: return .customOrange
        case .biceps: return .green
        case .triceps: return .purple
        case .legs: return .yellow
        case .glutes: return .pink
        case .abs: return .mint
        case .cardio: return .cyan
        // Neue Farben für neue Muskelgruppen
        case .forearms: return .brown
        case .calves: return .indigo
        case .trapezius: return .teal
        case .lowerBack: return .gray
        case .upperBack: return .secondary
        case .fullBody: return .primary
        case .hips: return .purple.opacity(0.7)
        case .core: return .mint.opacity(0.8)
        // Farben für CSV-Muskelgruppen
        case .hamstrings: return .customOrange.opacity(0.7)
        case .lats: return .cyan.opacity(0.8)
        case .grip: return .brown.opacity(0.8)
        case .arms: return .green.opacity(0.6)
        case .adductors: return .yellow.opacity(0.7)
        case .obliques: return .mint.opacity(0.6)
        case .hipFlexors: return .pink.opacity(0.6)
        case .traps: return .teal.opacity(0.8)
        case .coordination: return .indigo.opacity(0.6)
        }
    }
}

enum DifficultyLevel: String, CaseIterable, Codable {
    case anfänger = "Anfänger"
    case fortgeschritten = "Fortgeschritten"
    case profi = "Profi"

    var displayName: String {
        return rawValue
    }

    var sortOrder: Int {
        switch self {
        case .anfänger: return 1
        case .fortgeschritten: return 2
        case .profi: return 3
        }
    }

    var color: Color {
        switch self {
        case .anfänger: return .green
        case .fortgeschritten: return .customOrange
        case .profi: return .red
        }
    }

    var icon: String {
        switch self {
        case .anfänger: return "star.fill"
        case .fortgeschritten: return "star.fill"
        case .profi: return "star.fill"
        }
    }
}

// MARK: - Exercise Type Extension
extension Exercise {
    /// Prüft ob die Übung eine Cardio-Übung ist (Zeit-basiert statt Gewicht)
    var isCardio: Bool {
        return muscleGroups.contains(.cardio)
    }

    /// Gibt die bevorzugte Einheit für Sets dieser Übung zurück
    var preferredUnit: SetUnit {
        return isCardio ? .time : .weight
    }
}

// MARK: - Exercise Similarity Extension
extension Exercise {
    /// Berechnet einen Ähnlichkeitsscore (0-100) zu einer anderen Übung
    /// Basierend auf Muskelgruppen (60%), Equipment (25%) und Schwierigkeit (15%)
    func similarityScore(to other: Exercise) -> Int {
        guard self.id != other.id else { return 0 }

        let muscleScore = muscleGroupSimilarity(to: other)
        let equipmentScore = equipmentSimilarity(to: other)
        let difficultyScore = difficultySimilarity(to: other)

        let totalScore = (muscleScore * 0.6) + (equipmentScore * 0.25) + (difficultyScore * 0.15)
        return Int(totalScore * 100)
    }

    /// Prüft ob die Übung ähnliche Muskelgruppen trainiert
    func hasSimilarMuscleGroups(to other: Exercise) -> Bool {
        let commonMuscles = Set(self.muscleGroups).intersection(Set(other.muscleGroups))
        return !commonMuscles.isEmpty
    }

    /// Prüft ob die Übung die primäre Muskelgruppe teilt
    func sharesPrimaryMuscleGroup(with other: Exercise) -> Bool {
        guard let primarySelf = muscleGroups.first,
              let primaryOther = other.muscleGroups.first else {
            return false
        }
        return primarySelf == primaryOther
    }

    // MARK: - Private Similarity Calculations

    private func muscleGroupSimilarity(to other: Exercise) -> Double {
        let selfMuscles = Set(self.muscleGroups)
        let otherMuscles = Set(other.muscleGroups)

        guard !selfMuscles.isEmpty && !otherMuscles.isEmpty else { return 0.0 }

        let intersection = selfMuscles.intersection(otherMuscles)
        let union = selfMuscles.union(otherMuscles)

        // Jaccard-Index: Anzahl gemeinsamer / Anzahl aller Muskelgruppen
        return Double(intersection.count) / Double(union.count)
    }

    private func equipmentSimilarity(to other: Exercise) -> Double {
        if self.equipmentType == other.equipmentType {
            return 1.0
        }

        // Mixed Equipment ist kompatibel mit allem (halber Score)
        if self.equipmentType == .mixed || other.equipmentType == .mixed {
            return 0.5
        }

        return 0.0
    }

    private func difficultySimilarity(to other: Exercise) -> Double {
        let selfOrder = self.difficultyLevel.sortOrder
        let otherOrder = other.difficultyLevel.sortOrder
        let difference = abs(selfOrder - otherOrder)

        switch difference {
        case 0: return 1.0  // Gleiches Level
        case 1: return 0.5  // Ein Level Unterschied
        default: return 0.0 // Zwei Levels Unterschied
        }
    }
}
