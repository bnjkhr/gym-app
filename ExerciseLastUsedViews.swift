import SwiftUI

/// Beispiel-View, die zeigt, wie die Last-Used Daten in der UI verwendet werden können
struct ExerciseLastUsedDisplayView: View {
    let exercise: Exercise
    @ObservedObject var store: WorkoutStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(exercise.name)
                .font(.headline)
            
            if let lastMetrics = store.completeLastMetrics(for: exercise) {
                if lastMetrics.hasData {
                    Text(lastMetrics.displayText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let date = lastMetrics.lastUsedDate {
                        Text("Zuletzt am \(date.formatted(.dateTime.day().month().year()))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                } else {
                    Text("Noch nicht verwendet")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            } else {
                Text("Keine Daten verfügbar")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

/// Erweiterte View mit allen Last-Used Details
struct DetailedExerciseLastUsedView: View {
    let exercise: Exercise
    @ObservedObject var store: WorkoutStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Letzte Verwendung")
                .font(.headline)
            
            if let metrics = store.completeLastMetrics(for: exercise) {
                if metrics.hasData {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        
                        if let weight = metrics.weight {
                            MetricCard(
                                title: "Gewicht",
                                value: "\(weight.formatted()) kg",
                                icon: "scalemass"
                            )
                        }
                        
                        if let reps = metrics.reps {
                            MetricCard(
                                title: "Wiederholungen",
                                value: "\(reps)",
                                icon: "repeat"
                            )
                        }
                        
                        if let setCount = metrics.setCount {
                            MetricCard(
                                title: "Sätze",
                                value: "\(setCount)",
                                icon: "list.number"
                            )
                        }
                        
                        if let restTime = metrics.restTime {
                            MetricCard(
                                title: "Pause",
                                value: "\(Int(restTime))s",
                                icon: "clock"
                            )
                        }
                    }
                    
                    if let date = metrics.lastUsedDate {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.secondary)
                            Text("Zuletzt am \(date.formatted(.dateTime.day().month().year()))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 4)
                    }
                    
                } else {
                    ContentUnavailableView(
                        "Noch nicht verwendet",
                        systemImage: "dumbbell",
                        description: Text("Diese Übung wurde noch nie in einem Workout durchgeführt.")
                    )
                }
            } else {
                ContentUnavailableView(
                    "Daten nicht verfügbar",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Die Last-Used Daten konnten nicht geladen werden.")
                )
            }
        }
    }
}

/// Hilfsstruct für Metrik-Karten
struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

/// Beispiel für Quick-Fill Buttons in einem Workout
struct QuickFillFromLastUsedView: View {
    let exercise: Exercise
    @ObservedObject var store: WorkoutStore
    @Binding var targetWeight: Double
    @Binding var targetReps: Int
    
    var body: some View {
        if let metrics = store.completeLastMetrics(for: exercise),
           let weight = metrics.weight,
           let reps = metrics.reps {
            
            HStack {
                Button(action: {
                    targetWeight = weight
                    targetReps = reps
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Wie letztes Mal")
                        Text("(\(weight.formatted())kg × \(reps))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.bordered)
                
                Spacer()
            }
        }
    }
}

// MARK: - Preview
#Preview {
    let store = WorkoutStore()
    let exercise = Exercise(
        name: "Bankdrücken",
        muscleGroups: [.chest],
        equipmentType: .freeWeights,
        description: "Klassische Brustübung"
    )
    
    VStack(spacing: 20) {
        ExerciseLastUsedDisplayView(exercise: exercise, store: store)
        
        DetailedExerciseLastUsedView(exercise: exercise, store: store)
        
        QuickFillFromLastUsedView(
            exercise: exercise,
            store: store,
            targetWeight: .constant(80),
            targetReps: .constant(10)
        )
    }
    .padding()
}