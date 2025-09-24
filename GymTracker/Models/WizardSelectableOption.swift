import Foundation

/// Ein Protokoll, um sicherzustellen, dass alle Enum-Typen für den Workout-Assistenten
/// die benötigten Eigenschaften für die Auswahl-UI haben.
protocol WizardSelectableOption: CaseIterable, Identifiable, Equatable where AllCases: RandomAccessCollection {
    var displayName: String { get }
    var description: String { get }
}