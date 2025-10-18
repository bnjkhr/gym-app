import SwiftUI

/// Sheet for reordering exercises in a workout
///
/// Allows users to drag and drop exercises to change their order in the workout.
/// Displays exercise name and set count for each exercise.
///
/// **Features:**
/// - Drag & drop reordering
/// - Always in edit mode
/// - Cancel and save actions
/// - Adaptive presentation (.medium, .large)
///
/// **Usage:**
/// ```swift
/// .sheet(isPresented: $showingReorderSheet) {
///     ReorderExercisesSheet(
///         exercises: workout.exercises,
///         onCancel: { showingReorderSheet = false },
///         onSave: { reorderedExercises in
///             workout.exercises = reorderedExercises
///             reorderEntityExercises(to: reorderedExercises)
///             showingReorderSheet = false
///         }
///     )
/// }
/// ```
struct ReorderExercisesSheet: View {
    let exercises: [WorkoutExercise]
    let onCancel: () -> Void
    let onSave: ([WorkoutExercise]) -> Void

    @State private var reorderedExercises: [WorkoutExercise]

    init(
        exercises: [WorkoutExercise], onCancel: @escaping () -> Void,
        onSave: @escaping ([WorkoutExercise]) -> Void
    ) {
        self.exercises = exercises
        self.onCancel = onCancel
        self.onSave = onSave
        self._reorderedExercises = State(initialValue: exercises)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(reorderedExercises) { exercise in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(exercise.exercise.name)
                                .font(.headline)
                            Text("\(exercise.sets.count) Sätze")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .onMove { indices, newOffset in
                    reorderedExercises.move(fromOffsets: indices, toOffset: newOffset)
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Reihenfolge ändern")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        onSave(reorderedExercises)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
