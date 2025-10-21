import SwiftUI

/// WorkoutListCard - Individual Workout Card for HomeViewV2
///
/// **Design:**
/// - Großes Format (1 pro Zeile)
/// - Workout Icon (Emoji basierend auf Muskelgruppen)
/// - Exercise Count + Estimated Duration
/// - Muscle Groups Preview (max 3)
/// - Start Button + Menu Button
///
/// **Features:**
/// - Swipe-to-Delete (handled by parent List)
/// - Drag Handle (conditional, nur in Reorder Mode)
/// - Haptic Feedback bei allen Aktionen
///
/// **Usage:**
/// ```swift
/// WorkoutListCard(
///     workout: workout,
///     isReorderMode: false,
///     onStart: { startWorkout() },
///     onEdit: { editWorkout() }
/// )
/// ```
struct WorkoutListCard: View {
    // MARK: - Properties

    let workout: Workout
    let isReorderMode: Bool

    var onStart: (() -> Void)?
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?
    var onToggleFavorite: (() -> Void)?

    // MARK: - Computed Properties

    /// Workout Icon basierend auf primärer Muskelgruppe
    private var workoutIcon: String {
        // Sammle alle Muskelgruppen
        let allMuscleGroups = workout.exercises.flatMap { $0.exercise.muscleGroups }

        // Priorität: Chest > Back > Legs > Shoulders > Arms
        if allMuscleGroups.contains(.chest) {
            return "💪"
        } else if allMuscleGroups.contains(.back) {
            return "🏋️"
        } else if allMuscleGroups.contains(.legs) || allMuscleGroups.contains(.glutes) {
            return "🦵"
        } else if allMuscleGroups.contains(.shoulders) {
            return "🤸"
        } else if allMuscleGroups.contains(.biceps) || allMuscleGroups.contains(.triceps) {
            return "💪"
        } else if allMuscleGroups.contains(.abs) {
            return "🔥"
        } else if allMuscleGroups.contains(.cardio) {
            return "🏃"
        }
        return "🔥"  // Fallback
    }

    /// Geschätzte Dauer in Minuten (3 Min pro Set)
    private var estimatedDuration: Int {
        let totalSets = workout.exercises.reduce(0) { total, exercise in
            total + exercise.sets.count
        }
        // Fallback: Wenn keine Sets, schätze 5 Sets pro Übung
        let estimatedSets = totalSets > 0 ? totalSets : workout.exercises.count * 5
        return estimatedSets * 3  // 3 Minuten pro Set (inkl. Rest)
    }

    /// Unique Muscle Groups (max 3 für Display)
    private var uniqueMuscleGroups: [MuscleGroup] {
        let allGroups = workout.exercises.flatMap { $0.exercise.muscleGroups }
        let uniqueSet = Set(allGroups)
        return Array(uniqueSet)
            .sorted { $0.rawValue < $1.rawValue }
            .prefix(3)
            .map { $0 }
    }

    /// Muscle Groups Display String
    private var muscleGroupsText: String {
        if uniqueMuscleGroups.isEmpty {
            return "Training"
        }
        let displayGroups = uniqueMuscleGroups.map { $0.rawValue }
        return displayGroups.joined(separator: ", ")
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 12) {
            // Header Row (Title + Favorite)
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(HomeV2Theme.primaryText)
                        .lineLimit(1)

                    Text("\(workout.exercises.count) Übungen · \(estimatedDuration) Min")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(HomeV2Theme.secondaryText)
                }

                Spacer()

                // Favorite Star
                Button {
                    HapticManager.shared.light()
                    onToggleFavorite?()
                } label: {
                    Image(systemName: workout.isFavorite ? "star.fill" : "star")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(
                            workout.isFavorite ? HomeV2Theme.primaryText : HomeV2Theme.secondaryText
                        )
                }
                .buttonStyle(.plain)
            }

            // Muscle Groups Tags
            if !uniqueMuscleGroups.isEmpty {
                HStack(spacing: 6) {
                    ForEach(uniqueMuscleGroups, id: \.self) { group in
                        Text(group.rawValue)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(HomeV2Theme.secondaryText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(HomeV2Theme.secondaryButtonBackground)
                            )
                    }
                    Spacer()
                }
            }

            // Actions Row
            HStack(spacing: 12) {
                // Start Button
                Button {
                    HapticManager.shared.light()
                    onStart?()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Start Workout")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(HomeV2Theme.primaryButtonText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(HomeV2Theme.primaryButtonBackground)
                    )
                }
                .buttonStyle(.plain)

                // Menu Button
                Button {
                    HapticManager.shared.light()
                    onEdit?()
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(HomeV2Theme.primaryText)
                        .frame(width: 48, height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(HomeV2Theme.secondaryButtonBackground)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(HomeV2Theme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(HomeV2Theme.cardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview("Push Day") {
    @Previewable @State var workout = Workout(
        name: "Push Day",
        exercises: [
            WorkoutExercise(
                exercise: Exercise(
                    name: "Bench Press",
                    muscleGroups: [.chest, .triceps],
                    equipmentType: .freeWeights
                ),
                sets: [
                    ExerciseSet(reps: 8, weight: 100, restTime: 90, completed: false),
                    ExerciseSet(reps: 8, weight: 105, restTime: 90, completed: false),
                    ExerciseSet(reps: 8, weight: 110, restTime: 90, completed: false),
                ]
            ),
            WorkoutExercise(
                exercise: Exercise(
                    name: "Shoulder Press",
                    muscleGroups: [.shoulders, .triceps],
                    equipmentType: .freeWeights
                ),
                sets: [
                    ExerciseSet(reps: 10, weight: 60, restTime: 90, completed: false),
                    ExerciseSet(reps: 10, weight: 65, restTime: 90, completed: false),
                ]
            ),
            WorkoutExercise(
                exercise: Exercise(
                    name: "Tricep Extension",
                    muscleGroups: [.triceps],
                    equipmentType: .cable
                ),
                sets: [
                    ExerciseSet(reps: 12, weight: 50, restTime: 60, completed: false),
                    ExerciseSet(reps: 12, weight: 55, restTime: 60, completed: false),
                ]
            ),
        ],
        isFavorite: true
    )

    ScrollView {
        VStack(spacing: 12) {
            WorkoutListCard(
                workout: workout,
                isReorderMode: false,
                onStart: { print("▶️ Start") },
                onEdit: { print("✏️ Edit") },
                onToggleFavorite: {
                    workout.isFavorite.toggle()
                    print("⭐ Favorite toggled")
                }
            )

            WorkoutListCard(
                workout: workout,
                isReorderMode: true,
                onStart: { print("▶️ Start") },
                onEdit: { print("✏️ Edit") }
            )
        }
        .padding()
    }
    .background(HomeV2Theme.pageBackground)
}

#Preview("Leg Day") {
    @Previewable @State var workout = Workout(
        name: "Leg Day Intense",
        exercises: [
            WorkoutExercise(
                exercise: Exercise(
                    name: "Squat",
                    muscleGroups: [.legs, .glutes],
                    equipmentType: .freeWeights
                ),
                sets: []
            ),
            WorkoutExercise(
                exercise: Exercise(
                    name: "Leg Press",
                    muscleGroups: [.legs],
                    equipmentType: .machine
                ),
                sets: []
            ),
            WorkoutExercise(
                exercise: Exercise(
                    name: "Leg Curl",
                    muscleGroups: [.legs],
                    equipmentType: .machine
                ),
                sets: []
            ),
            WorkoutExercise(
                exercise: Exercise(
                    name: "Calf Raise",
                    muscleGroups: [.calves],
                    equipmentType: .machine
                ),
                sets: []
            ),
        ],
        isFavorite: false
    )

    ScrollView {
        WorkoutListCard(
            workout: workout,
            isReorderMode: false,
            onStart: { print("▶️ Start") },
            onEdit: { print("✏️ Edit") },
            onToggleFavorite: {
                workout.isFavorite.toggle()
                print("⭐ Favorite: \(workout.isFavorite)")
            }
        )
        .padding()
    }
    .background(HomeV2Theme.pageBackground)
}

#Preview("Empty Workout") {
    let workout = Workout(
        name: "New Workout",
        exercises: [],
        isFavorite: false
    )

    ScrollView {
        WorkoutListCard(
            workout: workout,
            isReorderMode: false,
            onStart: { print("▶️ Start") },
            onEdit: { print("✏️ Edit") }
        )
        .padding()
    }
    .background(HomeV2Theme.pageBackground)
}
