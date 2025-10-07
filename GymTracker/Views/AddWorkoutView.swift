import SwiftUI
import SwiftData

struct AddWorkoutView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var workoutName = ""
    @State private var creationDate = Date()
    @State private var notes = ""
    @State private var restTimeSeconds: Double = 90
    @State private var selectedExercises: [ExerciseSelection] = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Workout Details") {
                    TextField("Workout Name", text: $workoutName)
                        .textFieldStyle(.plain)

                    HStack {
                        Label("Angelegt", systemImage: "calendar")
                        Spacer()
                        Text(creationDate, format: .dateTime.day().month().year())
                            .foregroundStyle(.secondary)
                    }

                    TextField("Notizen (optional)", text: $notes, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(3...6)
                }

                Section("Übungen") {
                    if selectedExercises.isEmpty {
                        Text("Füge Übungen hinzu, um Sätze und Gewichte vorzubereiten.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach($selectedExercises) { $selection in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(selection.exercise.name)
                                            .font(.headline)

                                        if let tooltip = lastSavedDescription(for: selection.exercise) {
                                            Text(tooltip)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }

                                    Spacer()

                                    Button {
                                        removeExercise(selection)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }

                                Stepper(value: $selection.setCount, in: 1...10) {
                                    Label("Sätze: \(selection.setCount)", systemImage: "square.stack.3d.up.fill")
                                        .labelStyle(.titleAndIcon)
                                }

                                HStack {
                                    Label("Gewicht", systemImage: "scalemass.fill")
                                        .labelStyle(.titleAndIcon)
                                    Spacer()
                                    TextField("0.0", text: .init(
                                        get: { selection.weight > 0 ? String(format: "%.1f", selection.weight) : "" },
                                        set: { newValue in
                                            if let weight = Double(newValue.replacingOccurrences(of: ",", with: ".")) {
                                                selection.weight = max(0, min(weight, 999.9))
                                            } else if newValue.isEmpty {
                                                selection.weight = 0
                                            }
                                        }
                                    ))
                                        .textFieldStyle(.plain)
                                        .multilineTextAlignment(.trailing)
                                        .keyboardType(.decimalPad)
                                        .frame(maxWidth: 120)
                                    Text("kg")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    NavigationLink {
                        ExercisePickerView(
                            isSelected: { exercise in
                                isExerciseSelected(exercise)
                            },
                            onAdd: { exercise in
                                addExercise(exercise)
                            },
                            onRemove: { exercise in
                                removeExerciseById(exercise.id)
                            }
                        )
                    } label: {
                        Label("Übung hinzufügen", systemImage: "plus.circle")
                    }
                }

                Section("Pause zwischen Sätzen") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Pause")
                            Spacer()
                            Text(restTimeFormatted)
                                .font(.body.monospacedDigit())
                        }
                        Slider(value: $restTimeSeconds, in: 30...240, step: 5)
                    }
                    .padding(.vertical, 4)
                }

            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .navigationTitle("Neues Workout")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                // Ensure WorkoutStore has access to ModelContext BEFORE rendering
                workoutStore.modelContext = modelContext
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Erstellen") {
                        saveWorkout()
                    }
                    .disabled(workoutName.isEmpty || selectedExercises.isEmpty)
                }
            }
        }
    }

    private func saveWorkout() {
        // Ensure we have or create ExerciseEntity for each selected exercise
        // Fetch existing exercises by id
        let fetch = FetchDescriptor<ExerciseEntity>()
        let allExercises = (try? modelContext.fetch(fetch)) ?? []
        var byId: [UUID: ExerciseEntity] = Dictionary(uniqueKeysWithValues: allExercises.map { ($0.id, $0) })

        var workoutExerciseEntities: [WorkoutExerciseEntity] = []
        for (index, selection) in selectedExercises.enumerated() {
            // Resolve or create ExerciseEntity
            let exId = selection.exercise.id
            let exerciseEntity: ExerciseEntity = byId[exId] ?? {
                let e = ExerciseEntity(
                    id: exId,
                    name: selection.exercise.name,
                    muscleGroupsRaw: selection.exercise.muscleGroups.map { $0.rawValue },
                    descriptionText: selection.exercise.description,
                    instructions: selection.exercise.instructions,
                    createdAt: selection.exercise.createdAt
                )
                byId[exId] = e
                modelContext.insert(e)
                return e
            }()

            let we = WorkoutExerciseEntity(exercise: exerciseEntity, order: index)
            for _ in 0..<selection.setCount {
                let set = ExerciseSetEntity(
                    id: UUID(),
                    reps: 0,
                    weight: selection.weight,
                    restTime: restTimeSeconds,
                    completed: false
                )
                we.sets.append(set)
            }
            workoutExerciseEntities.append(we)
        }

        let workoutEntity = WorkoutEntity(
            id: UUID(),
            name: workoutName,
            date: creationDate,
            exercises: workoutExerciseEntities,
            defaultRestTime: restTimeSeconds,
            duration: nil,
            notes: notes,
            isFavorite: false
        )
        modelContext.insert(workoutEntity)

        do {
            try modelContext.save()
            print("✅ Neues Workout erfolgreich gespeichert: \(workoutName)")

            // Mark onboarding step as completed: first workout created
            if !workoutStore.userProfile.hasCreatedFirstWorkout {
                workoutStore.markOnboardingStep(hasCreatedFirstWorkout: true)
            }
        } catch {
            print("❌ Fehler beim Speichern des neuen Workouts: \(error)")
        }

        dismiss()
    }

    private var restTimeFormatted: String {
        let totalSeconds = Int(restTimeSeconds)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        if minutes > 0 {
            return String(format: "%d:%02d Min", minutes, seconds)
        } else {
            return "\(seconds) Sek"
        }
    }

    private func addExercise(_ exercise: Exercise) {
        guard !isExerciseSelected(exercise) else { return }

        let metrics = workoutStore.lastMetrics(for: exercise)
        let selection = ExerciseSelection(
            exercise: exercise,
            weight: metrics?.weight ?? 20,
            setCount: metrics?.setCount ?? 3
        )

        selectedExercises.append(selection)
    }

    private func removeExercise(_ selection: ExerciseSelection) {
        selectedExercises.removeAll { $0.id == selection.id }
    }

    private func removeExerciseById(_ exerciseId: UUID) {
        selectedExercises.removeAll { $0.exercise.id == exerciseId }
    }

    private func isExerciseSelected(_ exercise: Exercise) -> Bool {
        selectedExercises.contains { $0.exercise.id == exercise.id }
    }

    private func lastSavedDescription(for exercise: Exercise) -> String? {
        guard let metrics = workoutStore.lastMetrics(for: exercise) else { return nil }
        let formattedWeight = metrics.weight.formatted(.number.precision(.fractionLength(1)))
        return "Zuletzt: \(metrics.setCount) Sätze • \(formattedWeight) kg"
    }

    private struct ExerciseSelection: Identifiable {
        let id = UUID()
        let exercise: Exercise
        var weight: Double
        var setCount: Int
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: WorkoutEntity.self, WorkoutExerciseEntity.self, ExerciseSetEntity.self, ExerciseEntity.self, configurations: config)
    return AddWorkoutView()
        .environmentObject(WorkoutStore())
        .modelContainer(container)
}
