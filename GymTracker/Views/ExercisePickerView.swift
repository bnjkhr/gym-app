import SwiftUI

struct ExercisePickerView: View {
    @EnvironmentObject var workoutStore: WorkoutStore

    // Indicates whether an exercise is already selected in the parent view
    let isSelected: (Exercise) -> Bool
    // Callback to add an exercise back to the parent
    let onAdd: (Exercise) -> Void

    @State private var searchText: String = ""

    private var filteredExercises: [Exercise] {
        let all = workoutStore.exercises
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

                            if let tooltip = lastSavedDescription(for: exercise) {
                                Text(tooltip)
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

    private func lastSavedDescription(for exercise: Exercise) -> String? {
        guard let metrics = workoutStore.lastMetrics(for: exercise) else { return nil }
        let formattedWeight = metrics.weight.formatted(.number.precision(.fractionLength(1)))
        return "Zuletzt: \(metrics.setCount) Sätze • \(formattedWeight) kg"
    }
}

#Preview {
    NavigationStack {
        ExercisePickerView(
            isSelected: { _ in false },
            onAdd: { _ in }
        )
        .environmentObject(WorkoutStore())
    }
}
