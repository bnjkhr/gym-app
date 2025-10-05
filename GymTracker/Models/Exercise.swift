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
        case .back: return .blue
        case .shoulders: return .orange
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
        case .hamstrings: return .orange.opacity(0.7)
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
        case .fortgeschritten: return .orange
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
