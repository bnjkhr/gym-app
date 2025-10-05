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
