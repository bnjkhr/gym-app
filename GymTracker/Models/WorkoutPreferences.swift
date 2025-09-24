import Foundation

/// Ein Protokoll, um sicherzustellen, dass alle Enum-Typen für den Workout-Assistenten
/// die benötigten Eigenschaften für die Auswahl-UI haben.
protocol WizardSelectableOption: CaseIterable, Identifiable, Equatable where AllCases: RandomAccessCollection {
    var displayName: String { get }
    var description: String { get }
}

enum ExperienceLevel: String, Identifiable, Codable, WizardSelectableOption {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .beginner: return "Anfänger"
        case .intermediate: return "Fortgeschritten"
        case .advanced: return "Experte"
        }
    }

    var description: String {
        switch self {
        case .beginner: return "0-1 Jahr Trainingserfahrung"
        case .intermediate: return "1-3 Jahre Trainingserfahrung"
        case .advanced: return "3+ Jahre Trainingserfahrung"
        }
    }
}

enum FitnessGoal: String, Identifiable, Codable, WizardSelectableOption {
    case muscleBuilding = "muscle_building"
    case strength = "strength"
    case endurance = "endurance"
    case weightLoss = "weight_loss"
    case general = "general"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .muscleBuilding: return "Muskelaufbau"
        case .strength: return "Kraftzuwachs"
        case .endurance: return "Ausdauer"
        case .weightLoss: return "Gewichtsreduktion"
        case .general: return "Allgemeine Fitness"
        }
    }

    var description: String {
        switch self {
        case .muscleBuilding: return "Muskelmasse und Definition aufbauen"
        case .strength: return "Maximalkraft und Kraftausdauer steigern"
        case .endurance: return "Herz-Kreislauf-System und Ausdauer verbessern"
        case .weightLoss: return "Körperfett reduzieren und Körpergewicht senken"
        case .general: return "Gesundheit und allgemeine Fitness verbessern"
        }
    }
}

enum EquipmentPreference: String, Identifiable, Codable, WizardSelectableOption {
    case freeWeights = "free_weights"
    case machines = "machines"
    case mixed = "mixed"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .freeWeights: return "Freie Gewichte"
        case .machines: return "Nur Maschinen"
        case .mixed: return "Gemischt"
        }
    }

    var description: String {
        switch self {
        case .freeWeights: return "Langhanteln, Kurzhanteln, Körpergewicht"
        case .machines: return "Geführte Bewegungen, sicherere Ausführung"
        case .mixed: return "Kombination aus freien Gewichten und Maschinen"
        }
    }
}

enum WorkoutDuration: Int, Identifiable, Codable, WizardSelectableOption {
    case short = 30
    case medium = 45
    case long = 60
    case extended = 90

    var id: Int { rawValue }

    var displayName: String {
        "\(rawValue) Minuten"
    }

    var description: String {
        switch self {
        case .short: return "Kurz und intensiv"
        case .medium: return "Ausgewogene Trainingszeit"
        case .long: return "Vollständiges Training"
        case .extended: return "Umfassendes Training"
        }
    }
}

struct WorkoutPreferences: Codable {
    let experience: ExperienceLevel
    let goal: FitnessGoal
    let frequency: Int // Trainings pro Woche
    let equipment: EquipmentPreference
    let duration: WorkoutDuration

    init(experience: ExperienceLevel, goal: FitnessGoal, frequency: Int, equipment: EquipmentPreference, duration: WorkoutDuration) {
        self.experience = experience
        self.goal = goal
        self.frequency = frequency
        self.equipment = equipment
        self.duration = duration
    }
}