import SwiftUI

/// Übungs-Karte für Active Workout View (v2)
///
/// Eine Karte, die eine komplette Übung mit allen Sets anzeigt.
/// Kombiniert Header, CompactSetRows, Quick-Add Field und Menu.
///
/// **Features:**
/// - Exercise Header (Name + Equipment + Indicator)
/// - Alle Sets als CompactSetRows
/// - Quick-Add Field ("Type anything...")
/// - Menu (Drei-Punkte) für Optionen
/// - Swipe-to-delete für Sets (optional)
///
/// **Layout:**
/// ```
/// ┌─────────────────────────────┐
/// │ 🔴 Squat            [...]   │ ← Header
/// │    Barbell                  │
/// │                             │
/// │ 1  135 Kg  6 reps  ☐        │ ← Set 1
/// │ 2  135 Kg  6 reps  ☐        │ ← Set 2
/// │ 3  135 Kg  7 reps  ☐        │ ← Set 3
/// │                             │
/// │ Type anything...            │ ← Quick-Add
/// └─────────────────────────────┘
/// ```
///
/// **Usage:**
/// ```swift
/// ExerciseCard(
///     exercise: $workout.exercises[0],
///     exerciseIndex: 0,
///     onToggleCompletion: { setIndex in
///         // Handle set completion
///     },
///     onQuickAdd: { input in
///         // Handle quick-add
///     }
/// )
/// ```
struct ExerciseCard: View {
    @Binding var exercise: WorkoutExercise
    let exerciseIndex: Int
    var onToggleCompletion: ((Int) -> Void)?
    var onQuickAdd: ((String) -> Void)?
    var onDeleteSet: ((Int) -> Void)?
    var onMenuAction: (() -> Void)?

    @State private var quickAddText: String = ""
    @FocusState private var isQuickAddFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            header
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider()
                .padding(.horizontal, 16)

            // Sets
            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, _ in
                CompactSetRow(
                    set: $exercise.sets[index],
                    setIndex: index,
                    onToggleCompletion: {
                        onToggleCompletion?(index)
                    }
                )
                .padding(.horizontal, 16)
                .contextMenu {
                    if onDeleteSet != nil {
                        Button(role: .destructive) {
                            onDeleteSet?(index)
                        } label: {
                            Label("Satz löschen", systemImage: "trash")
                        }
                    }
                }

                // Divider between sets (not after last)
                if index < exercise.sets.count - 1 {
                    Divider()
                        .padding(.leading, 56)  // Align with set content
                }
            }

            // Quick-Add Field
            if onQuickAdd != nil {
                Divider()
                    .padding(.horizontal, 16)

                quickAddField
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }

            // Notes Display (if exists)
            if let notes = exercise.notes, !notes.isEmpty {
                Divider()
                    .padding(.horizontal, 16)

                HStack(spacing: 8) {
                    Image(systemName: "note.text")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            // Indicator (red dot)
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .padding(.top, 6)

            // Exercise Info
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.exercise.name)
                    .font(.headline)
                    .fontWeight(.semibold)

                if let equipment = exercise.exercise.equipmentType {
                    Text(equipment.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Menu Button
            Menu {
                Button {
                    // Add set
                } label: {
                    Label("Satz hinzufügen", systemImage: "plus")
                }

                Button {
                    // View history
                } label: {
                    Label("Verlauf anzeigen", systemImage: "clock")
                }

                Divider()

                Button(role: .destructive) {
                    onMenuAction?()
                } label: {
                    Label("Übung entfernen", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
            }
        }
    }

    // MARK: - Quick-Add Field

    private var quickAddField: some View {
        HStack(spacing: 8) {
            Image(systemName: "text.cursor")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Type anything...", text: $quickAddText)
                .font(.subheadline)
                .focused($isQuickAddFocused)
                .submitLabel(.done)
                .onSubmit {
                    handleQuickAdd()
                }

            if !quickAddText.isEmpty {
                Button {
                    quickAddText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Quick-Add Logic

    private func handleQuickAdd() {
        guard !quickAddText.isEmpty else { return }

        // Parse input: "100 x 8" or "100x8" → Weight: 100, Reps: 8
        let trimmed = quickAddText.trimmingCharacters(in: .whitespaces)

        // Try to parse as "weight x reps"
        if let parsed = parseSetInput(trimmed) {
            // Valid set format - add new set
            onQuickAdd?(quickAddText)
            quickAddText = ""
            isQuickAddFocused = false
        } else {
            // Not a set format - save as note
            onQuickAdd?(quickAddText)
            quickAddText = ""
            isQuickAddFocused = false
        }
    }

    /// Parses input like "100 x 8" or "100x8" into (weight, reps)
    private func parseSetInput(_ input: String) -> (weight: Double, reps: Int)? {
        // Pattern: number [spaces] x [spaces] number
        let pattern = #"^\s*(\d+(?:\.\d+)?)\s*[xX×]\s*(\d+)\s*$"#

        guard let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input))
        else {
            return nil
        }

        // Extract weight
        guard let weightRange = Range(match.range(at: 1), in: input),
            let weight = Double(input[weightRange])
        else {
            return nil
        }

        // Extract reps
        guard let repsRange = Range(match.range(at: 2), in: input),
            let reps = Int(input[repsRange])
        else {
            return nil
        }

        return (weight, reps)
    }
}

// MARK: - Previews

#Preview("Single Exercise") {
    @Previewable @State var exercise = WorkoutExercise(
        exercise: Exercise(
            name: "Squat",
            muscleGroups: [.legs],
            equipmentType: .freeWeights
        ),
        sets: [
            ExerciseSet(reps: 6, weight: 135, restTime: 90, completed: true),
            ExerciseSet(reps: 6, weight: 135, restTime: 90, completed: true),
            ExerciseSet(reps: 7, weight: 135, restTime: 90, completed: false),
        ]
    )

    ScrollView {
        ExerciseCard(
            exercise: $exercise,
            exerciseIndex: 0,
            onToggleCompletion: { setIndex in
                exercise.sets[setIndex].completed.toggle()
            },
            onQuickAdd: { input in
                print("Quick-Add: \(input)")
            },
            onDeleteSet: { setIndex in
                exercise.sets.remove(at: setIndex)
            }
        )
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("With Notes") {
    @Previewable @State var exercise = WorkoutExercise(
        exercise: Exercise(
            name: "Bench Press",
            muscleGroups: [.chest],
            equipmentType: .freeWeights
        ),
        sets: [
            ExerciseSet(reps: 8, weight: 100, restTime: 90, completed: false),
            ExerciseSet(reps: 8, weight: 100, restTime: 90, completed: false),
        ],
        notes: "Felt heavy today, might reduce weight next time"
    )

    ScrollView {
        ExerciseCard(
            exercise: $exercise,
            exerciseIndex: 0,
            onToggleCompletion: { setIndex in
                exercise.sets[setIndex].completed.toggle()
            },
            onQuickAdd: { input in
                print("Quick-Add: \(input)")
            }
        )
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("Multiple Exercises") {
    @Previewable @State var exercises = [
        WorkoutExercise(
            exercise: Exercise(
                name: "Squat",
                muscleGroups: [.legs],
                equipmentType: .freeWeights
            ),
            sets: [
                ExerciseSet(reps: 6, weight: 135, restTime: 90, completed: true),
                ExerciseSet(reps: 6, weight: 135, restTime: 90, completed: true),
                ExerciseSet(reps: 7, weight: 135, restTime: 90, completed: false),
            ]
        ),
        WorkoutExercise(
            exercise: Exercise(
                name: "Hack Squat",
                muscleGroups: [.legs],
                equipmentType: .machine
            ),
            sets: [
                ExerciseSet(reps: 9, weight: 80, restTime: 90, completed: false),
                ExerciseSet(reps: 8, weight: 80, restTime: 90, completed: false),
                ExerciseSet(reps: 8, weight: 80, restTime: 90, completed: false),
            ],
            restTimeToNext: 180  // 3 minutes to next exercise
        ),
    ]

    ScrollView {
        VStack(spacing: 0) {
            ForEach(Array(exercises.enumerated()), id: \.element.id) { index, _ in
                ExerciseCard(
                    exercise: $exercises[index],
                    exerciseIndex: index,
                    onToggleCompletion: { setIndex in
                        exercises[index].sets[setIndex].completed.toggle()
                    },
                    onQuickAdd: { input in
                        print("Quick-Add for exercise \(index): \(input)")
                    }
                )
                .padding(.horizontal)

                // Separator between exercises
                if index < exercises.count - 1 {
                    ExerciseSeparator(
                        restTime: exercises[index].restTimeToNext,
                        onAddExercise: {
                            print("Add exercise after \(index)")
                        }
                    )
                    .padding(.vertical, 8)
                }
            }
        }
        .padding(.vertical)
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("Empty Sets") {
    @Previewable @State var exercise = WorkoutExercise(
        exercise: Exercise(
            name: "New Exercise",
            muscleGroups: [.chest],
            equipmentType: .bodyweight
        ),
        sets: []
    )

    ScrollView {
        ExerciseCard(
            exercise: $exercise,
            exerciseIndex: 0,
            onToggleCompletion: nil,
            onQuickAdd: { input in
                print("Quick-Add: \(input)")
            }
        )
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
