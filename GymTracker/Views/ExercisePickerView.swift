import SwiftUI
import SwiftData

struct ExercisePickerView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\ExerciseEntity.name)]) private var exerciseEntities: [ExerciseEntity]

    // Indicates whether an exercise is already selected in the parent view
    let isSelected: (Exercise) -> Bool
    // Callback to add an exercise back to the parent
    let onAdd: (Exercise) -> Void
    // Callback to remove an exercise from the parent
    let onRemove: (Exercise) -> Void

    @State private var searchText: String = ""
    @State private var selectedMuscleGroup: MuscleGroup?
    @State private var showingAddExercise = false

    private var allExercises: [Exercise] {
        exerciseEntities.compactMap { Exercise(entity: $0, in: modelContext) }
    }

    private var filteredExercises: [Exercise] {
        var result = allExercises

        // Filter by muscle group
        if let muscleGroup = selectedMuscleGroup {
            result = result.filter { $0.muscleGroups.contains(muscleGroup) }
        }

        // Filter by search text
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
        }

        return result
    }

    var body: some View {
        List {
            // Muscle group filter section
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // "Alle" button to clear filter
                        Button {
                            selectedMuscleGroup = nil
                        } label: {
                            Text("Alle")
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedMuscleGroup == nil ? Color.accentColor : Color.secondary.opacity(0.2))
                                .foregroundColor(selectedMuscleGroup == nil ? .white : .primary)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)

                        // Muscle group buttons
                        ForEach(MuscleGroup.allCases, id: \.self) { muscleGroup in
                            Button {
                                selectedMuscleGroup = muscleGroup
                            } label: {
                                Text(muscleGroup.rawValue)
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedMuscleGroup == muscleGroup ? muscleGroup.color : Color.secondary.opacity(0.2))
                                    .foregroundColor(selectedMuscleGroup == muscleGroup ? .white : .primary)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            if filteredExercises.isEmpty {
                Section {
                    VStack(alignment: .center, spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("Keine Übungen gefunden")
                            .font(.headline)
                        Text("Passe deine Suche an.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            } else {
                ForEach(filteredExercises) { exercise in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(exercise.name)
                                .font(.body)

                            // Show muscle groups as subtitle
                            if !exercise.muscleGroups.isEmpty {
                                Text(exercise.muscleGroups.map { $0.rawValue }.joined(separator: " • "))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        Button {
                            if isSelected(exercise) {
                                onRemove(exercise)
                            } else {
                                onAdd(exercise)
                            }
                        } label: {
                            Image(systemName: isSelected(exercise) ? "checkmark.circle.fill" : "plus.circle")
                                .imageScale(.large)
                                .foregroundColor(isSelected(exercise) ? .green : .accentColor)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isSelected(exercise) ? "Übung entfernen" : "Übung hinzufügen")
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Übungen")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Suchen")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddExercise = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                }
            }
        }
        .sheet(isPresented: $showingAddExercise) {
            AddExerciseView()
                .environment(\.modelContext, modelContext)
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: ExerciseEntity.self, configurations: config)

    return NavigationStack {
        ExercisePickerView(
            isSelected: { _ in false },
            onAdd: { _ in },
            onRemove: { _ in }
        )
        .modelContainer(container)
    }
}
