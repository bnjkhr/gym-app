import Foundation
import SwiftUI

struct Exercise: Identifiable, Codable {
    let id: UUID
    var name: String
    var muscleGroups: [MuscleGroup]
    var description: String
    var instructions: [String]
    var createdAt: Date

    init(id: UUID = UUID(), name: String, muscleGroups: [MuscleGroup], description: String = "", instructions: [String] = [], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.muscleGroups = muscleGroups
        self.description = description
        self.instructions = instructions
        self.createdAt = createdAt
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
