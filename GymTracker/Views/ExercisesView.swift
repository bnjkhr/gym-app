import SwiftUI

struct ExercisesView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @State private var showingAddExercise = false
    @State private var searchText = ""
    @State private var editingExercise: Exercise?
    @State private var pendingDeletion: [Exercise] = []
    @State private var showingDeleteAlert = false

    var filteredExercises: [Exercise] {
        if searchText.isEmpty {
            return workoutStore.exercises
        } else {
            return workoutStore.exercises.filter { exercise in
                exercise.name.localizedCaseInsensitiveContains(searchText) ||
                exercise.muscleGroups.contains { $0.rawValue.localizedCaseInsensitiveContains(searchText) }
            }
        }
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(filteredExercises) { exercise in
                    Button {
                        editingExercise = exercise
                    } label: {
                        ExerciseRowView(exercise: exercise)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: requestDeletionForList)
            }
            .searchable(text: $searchText, prompt: "Übungen suchen...")
            .navigationTitle("Übungen")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddExercise = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddExercise) {
                AddExerciseView()
                    .environmentObject(workoutStore)
            }
            .sheet(item: $editingExercise) { exercise in
                NavigationStack {
                    EditExerciseView(exercise: exercise) { updatedExercise in
                        workoutStore.updateExercise(updatedExercise)
                    } deleteAction: {
                        requestDeletion(for: [exercise])
                    }
                }
            }
            .alert("Übung löschen?", isPresented: $showingDeleteAlert) {
                Button("Löschen", role: .destructive) {
                    performDeletion()
                }
                Button("Abbrechen", role: .cancel) {
                    pendingDeletion = []
                }
            } message: {
                if pendingDeletion.count == 1 {
                    Text("\(pendingDeletion.first?.name ?? "") wird entfernt.")
                } else {
                    Text("\(pendingDeletion.count) Übungen werden entfernt.")
                }
            }
        }
    }

    private func requestDeletionForList(at indexSet: IndexSet) {
        let exercises = indexSet.compactMap { filteredExercises[safe: $0] }
        requestDeletion(for: exercises)
    }

    private func requestDeletion(for exercises: [Exercise]) {
        guard !exercises.isEmpty else { return }
        pendingDeletion = exercises
        showingDeleteAlert = true
    }

    private func performDeletion() {
        defer {
            showingDeleteAlert = false
        }
        for exercise in pendingDeletion {
            if let index = workoutStore.exercises.firstIndex(where: { $0.id == exercise.id }) {
                workoutStore.deleteExercise(at: IndexSet(integer: index))
            }
            if editingExercise?.id == exercise.id {
                editingExercise = nil
            }
        }
        pendingDeletion = []
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct ExerciseRowView: View {
    let exercise: Exercise

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(exercise.name)
                .font(.headline)

            if !exercise.description.isEmpty {
                Text(exercise.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                ForEach(exercise.muscleGroups, id: \.self) { muscleGroup in
                    Text(muscleGroup.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(muscleGroup.color.opacity(0.2))
                        .foregroundColor(muscleGroup.color)
                        .clipShape(Capsule())
                }
                Spacer()
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    ExercisesView()
        .environmentObject(WorkoutStore())
}
