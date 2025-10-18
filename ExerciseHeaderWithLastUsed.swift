import SwiftUI

/// Übungs-Header mit Last-Used Informationen für die Workout-Detail-View
struct ExerciseHeaderWithLastUsed: View {
    let exercise: Exercise
    let workoutStore: WorkoutStoreCoordinator
    let isActiveSession: Bool
    let onQuickFill: ((Double, Int) -> Void)?
    let onLongPress: (() -> Void)?

    @State private var showingLastUsedDetails = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Übungsname mit Long Press für Reorder
            HStack {
                Text(exercise.name)
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                if isActiveSession && lastUsedMetrics.hasData {
                    Button(action: {
                        showingLastUsedDetails.toggle()
                    }) {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(.accentColor)
                            .font(.caption)
                    }
                }
            }
            .contentShape(Rectangle())
            .onLongPressGesture {
                onLongPress?()
            }

            // Last-Used Informationen
            if lastUsedMetrics.hasData {
                lastUsedSection
            } else {
                Text("Noch nie verwendet")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $showingLastUsedDetails) {
            LastUsedDetailsSheet(
                exercise: exercise,
                workoutStore: workoutStore,
                onQuickFill: onQuickFill
            )
        }
    }

    private var lastUsedMetrics: ExerciseLastUsedMetrics {
        workoutStore.completeLastMetrics(for: exercise)
            ?? ExerciseLastUsedMetrics(
                weight: nil, reps: nil, setCount: nil, lastUsedDate: nil, restTime: nil
            )
    }

    private var lastUsedSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Kompakte Anzeige der wichtigsten Daten
            HStack(spacing: 12) {
                if let weight = lastUsedMetrics.weight, let reps = lastUsedMetrics.reps {
                    Label("\(weight.formatted())kg", systemImage: "scalemass")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Label("\(reps) Wdh.", systemImage: "repeat")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let setCount = lastUsedMetrics.setCount {
                    Label("\(setCount) Sätze", systemImage: "list.number")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Quick Fill Button für aktive Sessions
                if isActiveSession, let weight = lastUsedMetrics.weight,
                    let reps = lastUsedMetrics.reps
                {
                    Button(action: {
                        onQuickFill?(weight, reps)

                        // Haptic Feedback
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption2)
                            Text("Übernehmen")
                                .font(.caption2)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Datum der letzten Verwendung
            if let date = lastUsedMetrics.lastUsedDate {
                Text("Zuletzt am \(date.formatted(.dateTime.day().month().year()))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

/// Detail-Sheet für ausführliche Last-Used Informationen
struct LastUsedDetailsSheet: View {
    let exercise: Exercise
    let workoutStore: WorkoutStoreCoordinator
    let onQuickFill: ((Double, Int) -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(exercise.name)
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Letzte Verwendung")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }

                    // Detaillierte Last-Used Metriken
                    if let metrics = workoutStore.completeLastMetrics(for: exercise) {
                        DetailedExerciseLastUsedView(exercise: exercise, store: workoutStore)
                    }

                    // Quick Actions
                    if let metrics = workoutStore.completeLastMetrics(for: exercise),
                        let weight = metrics.weight,
                        let reps = metrics.reps
                    {

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Schnellaktionen")
                                .font(.headline)

                            VStack(spacing: 8) {
                                // Exakt wie letztes Mal
                                Button(action: {
                                    onQuickFill?(weight, reps)
                                    dismiss()
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.clockwise")
                                        Text("Exakt wie letztes Mal")
                                        Spacer()
                                        Text("\(weight.formatted())kg × \(reps)")
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(AppLayout.CornerRadius.small)
                                }
                                .buttonStyle(.plain)

                                // Progressive Overload Suggestions
                                progressiveOverloadButtons(baseWeight: weight, baseReps: reps)
                            }
                        }
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Übungsdetails")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Schließen") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func progressiveOverloadButtons(baseWeight: Double, baseReps: Int) -> some View {
        VStack(spacing: 8) {
            // Gewicht steigern
            Button(action: {
                let newWeight = baseWeight + (baseWeight < 20 ? 1.25 : 2.5)  // Kleinere Sprünge für leichte Gewichte
                onQuickFill?(newWeight, baseReps)
                dismiss()
            }) {
                HStack {
                    Image(systemName: "arrow.up")
                    Text("Gewicht steigern")
                    Spacer()
                    let newWeight = baseWeight + (baseWeight < 20 ? 1.25 : 2.5)
                    Text("\(newWeight.formatted())kg × \(baseReps)")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(AppLayout.CornerRadius.small)
            }
            .buttonStyle(.plain)

            // Wiederholungen steigern
            if baseReps < 15 {  // Nur bis zu einem sinnvollen Maximum
                Button(action: {
                    onQuickFill?(baseWeight, baseReps + 1)
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("Wiederholungen steigern")
                        Spacer()
                        Text("\(baseWeight.formatted())kg × \(baseReps + 1)")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(AppLayout.CornerRadius.small)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    let store = WorkoutStoreCoordinator()
    let exercise = Exercise(
        name: "Bankdrücken",
        muscleGroups: [.chest],
        equipmentType: .freeWeights,
        description: "Klassische Brustübung"
    )

    VStack {
        ExerciseHeaderWithLastUsed(
            exercise: exercise,
            workoutStore: store,
            isActiveSession: true,
            onQuickFill: { weight, reps in
                print("Quick fill: \(weight)kg × \(reps)")
            },
            onLongPress: {
                print("Long press detected")
            }
        )
        .padding()

        Spacer()
    }
}
