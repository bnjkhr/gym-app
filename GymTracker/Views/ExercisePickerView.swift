import SwiftUI
import SwiftData

struct ExercisePickerView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\ExerciseEntity.name)]) private var exerciseEntities: [ExerciseEntity]

    // Indicates whether an exercise is already selected in the parent view
    let isSelected: (Exercise) -> Bool
    // Callback to add an exercise back to the parent
    let onAdd: (Exercise) -> Void

    @State private var searchText: String = ""

    private var allExercises: [Exercise] {
        exerciseEntities.compactMap { Exercise(entity: $0, in: modelContext) }
    }

    private var filteredExercises: [Exercise] {
        let all = allExercises
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        List {
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
                            onAdd(exercise)
                        } label: {
                            Image(systemName: isSelected(exercise) ? "checkmark.circle.fill" : "plus.circle")
                                .imageScale(.large)
                                .foregroundColor(isSelected(exercise) ? .secondary : .accentColor)
                        }
                        .buttonStyle(.plain)
                        .disabled(isSelected(exercise))
                        .accessibilityLabel(isSelected(exercise) ? "Bereits hinzugefügt" : "Übung hinzufügen")
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Übungen")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Suchen")
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: ExerciseEntity.self, configurations: config)

    return NavigationStack {
        ExercisePickerView(
            isSelected: { _ in false },
            onAdd: { _ in }
        )
        .modelContainer(container)
    }
}
