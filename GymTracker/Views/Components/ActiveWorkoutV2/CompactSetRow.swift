import SwiftUI

/// Kompakte Set-Reihe für Active Workout View (v2)
///
/// Zeigt eine einzelne Set-Reihe in kompakter Form an: `135 Kg | 6 reps | ☐`
/// Im Gegensatz zur alten `ActiveWorkoutSetCard` ist diese Komponente deutlich platzsparender
/// und zeigt mehrere Sets gleichzeitig an.
///
/// **Features:**
/// - Inline TextField für Weight (immer editierbar)
/// - Inline TextField für Reps (immer editierbar)
/// - Completion Checkbox (rechts)
/// - Minimales Design (keine großen Cards)
///
/// **Layout:**
/// ```
/// [60kg TextField] Kg  [8 TextField] reps  ☐
/// ```
///
/// **Usage:**
/// ```swift
/// CompactSetRow(
///     set: $workout.exercises[0].sets[0],
///     setIndex: 0,
///     onToggleCompletion: {
///         // Handle completion
///     }
/// )
/// ```
struct CompactSetRow: View {
    @Binding var set: ExerciseSet
    let setIndex: Int
    var onToggleCompletion: () -> Void

    @FocusState private var focusedField: Field?

    enum Field {
        case weight, reps
    }

    var body: some View {
        HStack(spacing: 12) {
            // Set Number (optional, can be shown or hidden)
            Text("\(setIndex + 1)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            // Weight Input
            HStack(spacing: 4) {
                TextField("0", value: $set.weight, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
                    .focused($focusedField, equals: .weight)

                Text("Kg")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Reps Input
            HStack(spacing: 4) {
                TextField("0", value: $set.reps, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 50)
                    .focused($focusedField, equals: .reps)

                Text("reps")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Completion Checkbox
            Button {
                onToggleCompletion()
            } label: {
                Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(set.completed ? AppTheme.mossGreen : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())  // Make entire row tappable
        .onTapGesture {
            // Dismiss keyboard when tapping outside input fields
            focusedField = nil
        }
    }
}

// MARK: - Preview

#Preview("Single Set") {
    @Previewable @State var set = ExerciseSet(
        reps: 8,
        weight: 100,
        restTime: 90,
        completed: false
    )

    VStack(spacing: 0) {
        CompactSetRow(
            set: $set,
            setIndex: 0,
            onToggleCompletion: {
                set.completed.toggle()
            }
        )
        .padding(.horizontal)

        Divider()
    }
}

#Preview("Multiple Sets") {
    @Previewable @State var sets = [
        ExerciseSet(reps: 8, weight: 100, restTime: 90, completed: true),
        ExerciseSet(reps: 8, weight: 100, restTime: 90, completed: true),
        ExerciseSet(reps: 6, weight: 105, restTime: 90, completed: false),
    ]

    VStack(spacing: 0) {
        ForEach(Array(sets.enumerated()), id: \.element.id) { index, _ in
            CompactSetRow(
                set: $sets[index],
                setIndex: index,
                onToggleCompletion: {
                    sets[index].completed.toggle()
                }
            )
            .padding(.horizontal)

            if index < sets.count - 1 {
                Divider()
                    .padding(.leading, 40)
            }
        }
    }
    .background(Color(.systemBackground))
    .cornerRadius(12)
    .padding()
}

#Preview("With Previous Values") {
    @Previewable @State var set = ExerciseSet(
        reps: 0,
        weight: 0,
        restTime: 90,
        completed: false
    )

    VStack(alignment: .leading, spacing: 8) {
        Text("Set 1")
            .font(.caption)
            .foregroundStyle(.secondary)

        CompactSetRow(
            set: $set,
            setIndex: 0,
            onToggleCompletion: {
                set.completed.toggle()
            }
        )

        // Previous values hint
        HStack {
            Spacer()
            Text("Last time: 100 kg × 8 reps")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
    .padding()
    .background(Color(.systemBackground))
    .cornerRadius(12)
    .padding()
}
