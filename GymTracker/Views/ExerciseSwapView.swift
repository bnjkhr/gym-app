import SwiftUI

struct ExerciseSwapView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @Environment(\.dismiss) private var dismiss

    let currentExercise: Exercise
    let userLevel: ExperienceLevel
    let onSwap: (Exercise) -> Void

    @State private var similarExercises: [Exercise] = []
    @State private var filterOption: FilterOption = .all
    @State private var isLoading = true

    enum FilterOption: String, CaseIterable {
        case all = "Alle"
        case myLevel = "Mein Level"
        case sameEquipment = "Gleiches Equipment"

        var icon: String {
            switch self {
            case .all: return "list.bullet"
            case .myLevel: return "star.fill"
            case .sameEquipment: return "dumbbell.fill"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Current Exercise Header
                currentExerciseHeader

                Divider()

                // Filter Options
                filterBar

                // Similar Exercises List
                if isLoading {
                    VStack(spacing: 16) {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Suche ähnliche Übungen...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else if filteredExercises.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("Keine ähnlichen Übungen gefunden")
                            .font(.headline)
                        Text("Versuche einen anderen Filter")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredExercises) { exercise in
                                ExerciseSimilarityCard(
                                    exercise: exercise,
                                    currentExercise: currentExercise,
                                    userLevel: userLevel,
                                    onSwap: {
                                        onSwap(exercise)
                                        dismiss()
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Übung austauschen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadSimilarExercises()
            }
        }
    }

    private var currentExerciseHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.triangle.swap")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("Aktuelle Übung")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(currentExercise.name)
                    .font(.title3)
                    .fontWeight(.semibold)

                HStack(spacing: 12) {
                    // Muscle Groups
                    if !currentExercise.muscleGroups.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.caption)
                            Text(currentExercise.muscleGroups.map { $0.rawValue }.joined(separator: ", "))
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }

                    // Difficulty Badge
                    DifficultyBadge(level: currentExercise.difficultyLevel, compact: true)

                    // Equipment
                    HStack(spacing: 4) {
                        Image(systemName: currentExercise.equipmentType.icon)
                            .font(.caption)
                        Text(currentExercise.equipmentType.rawValue)
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(FilterOption.allCases, id: \.self) { option in
                    Button(action: {
                        withAnimation {
                            filterOption = option
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: option.icon)
                                .font(.caption)
                            Text(option.rawValue)
                                .font(.subheadline)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(filterOption == option ? Color.blue : Color(.tertiarySystemBackground))
                        .foregroundColor(filterOption == option ? .white : .primary)
                        .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }

    private var filteredExercises: [Exercise] {
        switch filterOption {
        case .all:
            return similarExercises
        case .myLevel:
            return similarExercises.filter { exercise in
                matchesDifficultyLevel(exercise, for: userLevel)
            }
        case .sameEquipment:
            return similarExercises.filter { exercise in
                exercise.equipmentType == currentExercise.equipmentType ||
                exercise.equipmentType == .mixed ||
                currentExercise.equipmentType == .mixed
            }
        }
    }

    private func loadSimilarExercises() async {
        // Kleine Verzögerung um sicherzustellen dass WorkoutStore bereit ist
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 sekunden

        await MainActor.run {
            print("🔍 Loading similar exercises for: \(currentExercise.name)")
            similarExercises = workoutStore.getSimilarExercises(
                to: currentExercise,
                count: 20,
                userLevel: userLevel
            )
            print("✅ Found \(similarExercises.count) similar exercises")
            isLoading = false
        }
    }

    private func matchesDifficultyLevel(_ exercise: Exercise, for level: ExperienceLevel) -> Bool {
        switch level {
        case .beginner:
            return exercise.difficultyLevel == .anfänger || exercise.difficultyLevel == .fortgeschritten
        case .intermediate:
            return true
        case .advanced:
            return exercise.difficultyLevel == .fortgeschritten || exercise.difficultyLevel == .profi
        }
    }
}

struct ExerciseSimilarityCard: View {
    let exercise: Exercise
    let currentExercise: Exercise
    let userLevel: ExperienceLevel
    let onSwap: () -> Void

    var similarityScore: Int {
        currentExercise.similarityScore(to: exercise)
    }

    var matchesUserLevel: Bool {
        switch userLevel {
        case .beginner:
            return exercise.difficultyLevel == .anfänger || exercise.difficultyLevel == .fortgeschritten
        case .intermediate:
            return true
        case .advanced:
            return exercise.difficultyLevel == .fortgeschritten || exercise.difficultyLevel == .profi
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                // Left side - Exercise Info
                VStack(alignment: .leading, spacing: 8) {
                    Text(exercise.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    // Muscle Groups
                    if !exercise.muscleGroups.isEmpty {
                        Text(exercise.muscleGroups.map { $0.rawValue }.joined(separator: ", "))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }

                    HStack(spacing: 8) {
                        // Difficulty Badge
                        DifficultyBadge(level: exercise.difficultyLevel, compact: true)

                        // Equipment Icon
                        HStack(spacing: 4) {
                            Image(systemName: exercise.equipmentType.icon)
                                .font(.caption2)
                            Text(exercise.equipmentType.rawValue)
                                .font(.caption2)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(4)
                    }
                }

                Spacer()

                // Right side - Score & Action
                VStack(spacing: 8) {
                    // Similarity Score
                    VStack(spacing: 2) {
                        Text("\(similarityScore)%")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(scoreColor)
                        Text("Match")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    // Swap Button
                    Button(action: onSwap) {
                        Text("Tauschen")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                }
            }
            .padding()

            // Level Match Indicator
            if matchesUserLevel {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                    Text("Passt zu deinem Level")
                        .font(.caption)
                        .foregroundColor(.green)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 12)
            }
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var scoreColor: Color {
        if similarityScore >= 70 {
            return .green
        } else if similarityScore >= 40 {
            return .orange
        } else {
            return .red
        }
    }
}

struct DifficultyBadge: View {
    let level: DifficultyLevel
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: level.icon)
                .font(compact ? .caption2 : .caption)
            Text(level.displayName)
                .font(compact ? .caption2 : .caption)
        }
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, compact ? 3 : 4)
        .background(level.color.opacity(0.15))
        .foregroundColor(level.color)
        .cornerRadius(6)
    }
}

#Preview {
    let sampleExercise = Exercise(
        name: "Bankdrücken",
        muscleGroups: [.chest, .triceps],
        equipmentType: .freeWeights,
        difficultyLevel: .fortgeschritten,
        description: "Klassisches Bankdrücken für Brust"
    )

    ExerciseSwapView(
        currentExercise: sampleExercise,
        userLevel: .intermediate,
        onSwap: { _ in }
    )
    .environmentObject(WorkoutStore())
}
