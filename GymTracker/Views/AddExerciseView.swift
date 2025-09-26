import SwiftUI

struct AddExerciseView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var selectedMuscleGroups: Set<MuscleGroup> = []
    @State private var instructions: [String] = [""]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Grundinformationen Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Grundinformationen")
                            .font(.headline)
                        
                        TextField("Name der Übung", text: $name)
                            .textFieldStyle(.plain)
                        
                        TextField("Beschreibung (optional)", text: $description, axis: .vertical)
                            .textFieldStyle(.plain)
                            .lineLimit(3...6)
                    }
                    
                    // Muskelgruppen Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Muskelgruppen")
                            .font(.headline)
                        
                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 100))
                        ], spacing: 8) {
                            ForEach(MuscleGroup.allCases, id: \.self) { muscleGroup in
                                MuscleGroupButton(
                                    muscleGroup: muscleGroup,
                                    isSelected: selectedMuscleGroups.contains(muscleGroup)
                                ) {
                                    if selectedMuscleGroups.contains(muscleGroup) {
                                        selectedMuscleGroups.remove(muscleGroup)
                                    } else {
                                        selectedMuscleGroups.insert(muscleGroup)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Anweisungen Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Anweisungen (optional)")
                            .font(.headline)
                        
                        ForEach(instructions.indices, id: \.self) { index in
                            HStack {
                                TextField("Schritt \(index + 1)", text: $instructions[index])
                                    .textFieldStyle(.plain)
                                
                                if instructions.count > 1 {
                                    Button {
                                        instructions.remove(at: index)
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                        }
                        
                        Button {
                            instructions.append("")
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Schritt hinzufügen")
                            }
                            .foregroundColor(.mossGreen)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Neue Übung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Speichern") {
                        saveExercise()
                    }
                    .disabled(name.isEmpty || selectedMuscleGroups.isEmpty)
                }
            }
        }
    }

    private func saveExercise() {
        let filteredInstructions = instructions.filter { !$0.isEmpty }
        let exercise = Exercise(
            name: name,
            muscleGroups: Array(selectedMuscleGroups),
            description: description,
            instructions: filteredInstructions
        )

        workoutStore.addExercise(exercise)
        dismiss()
    }
}

struct MuscleGroupButton: View {
    let muscleGroup: MuscleGroup
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(muscleGroup.rawValue)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    isSelected
                        ? muscleGroup.color
                        : muscleGroup.color.opacity(0.1)
                )
                .foregroundColor(
                    isSelected
                        ? .white
                        : muscleGroup.color
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AddExerciseView()
        .environmentObject(WorkoutStore())
}
