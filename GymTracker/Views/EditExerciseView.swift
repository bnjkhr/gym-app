import SwiftUI

struct EditExerciseView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var description: String
    @State private var selectedMuscleGroups: Set<MuscleGroup>

    let originalExercise: Exercise
    let saveAction: (Exercise) -> Void
    let deleteAction: () -> Void

    init(exercise: Exercise, saveAction: @escaping (Exercise) -> Void, deleteAction: @escaping () -> Void) {
        self.originalExercise = exercise
        self.saveAction = saveAction
        self.deleteAction = deleteAction
        _name = State(initialValue: exercise.name)
        _description = State(initialValue: exercise.description)
        _selectedMuscleGroups = State(initialValue: Set(exercise.muscleGroups))
    }

    var body: some View {
        Form {
            Section("Details") {
                TextField("Name", text: $name)
                TextField("Beschreibung", text: $description, axis: .vertical)
                    .lineLimit(2...5)
            }

            Section("Muskelgruppen") {
                muscleGroupChips
            }

            Section {
                Button(role: .destructive) {
                    deleteAction()
                    dismiss()
                } label: {
                    Label("Übung löschen", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Übung bearbeiten")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Speichern") {
                    let updated = Exercise(
                        id: originalExercise.id,
                        name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                        muscleGroups: Array(selectedMuscleGroups),
                        description: description.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                    saveAction(updated)
                    dismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            ToolbarItem(placement: .navigationBarLeading) {
                Button("Abbrechen") {
                    dismiss()
                }
            }
        }
    }

    private var muscleGroupChips: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
            ForEach(MuscleGroup.allCases, id: \.self) { group in
                Button {
                    toggleSelection(for: group)
                } label: {
                    HStack {
                        Image(systemName: selectedMuscleGroups.contains(group) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(group.color)
                        Text(group.rawValue)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(group.color.opacity(selectedMuscleGroups.contains(group) ? 0.2 : 0.08))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private func toggleSelection(for group: MuscleGroup) {
        if selectedMuscleGroups.contains(group) {
            selectedMuscleGroups.remove(group)
        } else {
            selectedMuscleGroups.insert(group)
        }
    }
}

#Preview {
    NavigationStack {
        EditExerciseView(exercise: Exercise(name: "Bankdrücken", muscleGroups: [.chest, .triceps], description: "Training für Brust und Trizeps")) { _ in
        } deleteAction: {}
    }
}
