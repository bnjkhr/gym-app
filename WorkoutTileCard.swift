import SwiftUI

struct WorkoutTileCard: View {
    let workout: Workout
    let isHomeFavorite: Bool
    let onTap: () -> Void
    let onShowMenu: () -> Void
    let onToggleHome: () -> Void
    
    private func workoutCategory(for workout: Workout) -> String {
        let exerciseNames = workout.exercises.map { $0.exercise.name.lowercased() }
        
        let machineKeywords = ["maschine", "machine", "lat", "press", "curl", "extension", "row"]
        let freeWeightKeywords = ["hantel", "kurzhantel", "langhantel", "dumbbell", "barbell", "squat", "deadlift", "bench"]
        
        let hasMachine = exerciseNames.contains { name in
            machineKeywords.contains { keyword in name.contains(keyword) }
        }
        
        let hasFreeWeight = exerciseNames.contains { name in
            freeWeightKeywords.contains { keyword in name.contains(keyword) }
        }
        
        if hasMachine && hasFreeWeight {
            return "Mixed"
        } else if hasMachine {
            return "Maschinen"
        } else if hasFreeWeight {
            return "Freie Gewichte"
        } else {
            return "Training"
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Header area - three dots button
                HStack {
                    Spacer()
                    Button(action: onShowMenu) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.tertiary)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                }
                
                // Content area - workout name and category
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(workoutCategory(for: workout))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                // Push content to top with spacer
                Spacer()
                
                // Footer area - exercises count and home button
                HStack {
                    Text("\(workout.exercises.count) Übungen")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Button(action: onToggleHome) {
                        Image(systemName: isHomeFavorite ? "house.fill" : "house")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(isHomeFavorite ? .blue : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.systemGray6))
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let sampleExercise = Exercise(
        id: UUID(),
        name: "Bankdrücken",
        muscleGroups: [.chest, .shoulders],
        equipmentType: .freeWeights,
        description: "Klassische Brustübung",
        instructions: ["Lege dich auf die Bank"],
        createdAt: Date()
    )
    
    let sampleWorkout = Workout(
        id: UUID(),
        name: "Ganzkörper",
        date: Date(),
        exercises: [
            WorkoutExercise(exercise: sampleExercise, sets: [
                ExerciseSet(reps: 10, weight: 80.0, restTime: 90, completed: false),
                ExerciseSet(reps: 8, weight: 85.0, restTime: 90, completed: false),
                ExerciseSet(reps: 6, weight: 90.0, restTime: 90, completed: false)
            ])
        ],
        defaultRestTime: 90,
        duration: nil,
        notes: "",
        isFavorite: false
    )
    
    return WorkoutTileCard(
        workout: sampleWorkout,
        isHomeFavorite: true,
        onTap: { print("Workout tapped - starting...") },
        onShowMenu: { print("Menu tapped") },
        onToggleHome: { print("Home toggled") }
    )
    .padding()
}