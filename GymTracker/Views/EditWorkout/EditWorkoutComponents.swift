import SwiftUI

// MARK: - Collapsed Exercise Row

struct CollapsedExerciseRow: View {
    let exerciseName: String
    let setCount: Int
    let avgReps: Int
    let avgWeight: Double
    let isReorderMode: Bool
    let onTap: () -> Void
    let onToggleExpand: () -> Void
    let onLongPress: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Drag Handle (always visible for familiarity)
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
                .frame(width: 30)
                .onLongPressGesture(minimumDuration: 0.5) {
                    onLongPress()
                }

            // Exercise Info - Tappable for quick edit
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exerciseName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)

                    Text("\(setCount) Sätze • \(avgReps) WDH • \(avgWeight, specifier: "%.1f")kg")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            // Expand/Collapse Toggle
            if !isReorderMode {
                Button(action: onToggleExpand) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(0)) // Will animate
                }
            }
        }
        .padding(AppLayout.Spacing.standard)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.cardBackground)
        )
    }
}

// MARK: - Quick Edit View

struct QuickEditView: View {
    @Binding var sets: Int
    @Binding var reps: Int
    @Binding var weight: Double
    let onApply: () -> Void
    let onExpand: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Für alle Sätze")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                // Sätze
                VStack(spacing: 6) {
                    Text("Sätze")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    TextField("3", value: $sets, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(AppLayout.Spacing.medium)
                        .frame(width: 80)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.1))
                        )
                        .onChange(of: sets) { _, _ in onApply() }
                }

                // WDH
                VStack(spacing: 6) {
                    Text("WDH")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    TextField("10", value: $reps, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(AppLayout.Spacing.medium)
                        .frame(width: 80)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.1))
                        )
                        .onChange(of: reps) { _, _ in onApply() }
                }

                // Gewicht
                VStack(spacing: 6) {
                    Text("Gewicht")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    HStack(spacing: 4) {
                        TextField("80", value: $weight, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(AppLayout.Spacing.medium)
                            .frame(width: 80)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.1))
                            )
                            .onChange(of: weight) { _, _ in onApply() }
                        Text("kg")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }

            // Link to individual edit
            Button(action: onExpand) {
                HStack(spacing: 6) {
                    Image(systemName: "list.bullet")
                        .font(.caption)
                    Text("Sätze einzeln bearbeiten")
                        .font(.caption)
                }
                .foregroundStyle(AppTheme.turquoiseBoost)
            }
        }
        .padding(AppLayout.Spacing.standard)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: - Expanded Set List View

struct ExpandedSetListView: View {
    @Binding var sets: [EditableSet]
    let defaultRestTime: Double
    let onCollapse: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Header with collapse button
            HStack {
                Text("Einzelne Sätze")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))

                Spacer()

                Button(action: onCollapse) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.up")
                            .font(.caption2)
                        Text("Einklappen")
                            .font(.caption)
                    }
                    .foregroundStyle(AppTheme.turquoiseBoost)
                }
            }

            // Individual sets
            ForEach(Array(sets.enumerated()), id: \.offset) { index, _ in
                HStack(spacing: 12) {
                    Text("Satz \(index + 1)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: 60, alignment: .leading)

                    // WDH
                    HStack(spacing: 4) {
                        Text("WDH")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                        TextField("10", value: $sets[index].reps, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(AppLayout.Spacing.smallMedium)
                            .frame(width: 60)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.1))
                            )
                    }

                    // Gewicht
                    HStack(spacing: 4) {
                        Text("Gewicht")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                        TextField("80", value: $sets[index].weight, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(AppLayout.Spacing.smallMedium)
                            .frame(width: 70)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.1))
                            )
                        Text("kg")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }

            // Add set button
            Button(action: {
                let lastSet = sets.last ?? EditableSet(reps: 10, weight: 80, restTime: defaultRestTime)
                sets.append(EditableSet(reps: lastSet.reps, weight: lastSet.weight, restTime: defaultRestTime))
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("Satz hinzufügen")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.mossGreen)
                .padding(.vertical, 8)
            }
        }
        .padding(AppLayout.Spacing.standard)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: - Reorder Mode Overlay

struct ReorderModeOverlay: View {
    @Binding var exercises: [EditableExercise]
    let exerciseNames: [UUID: String]
    let onExit: () -> Void

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { onExit() }

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Übungen neu anordnen")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)

                    Spacer()

                    Button(action: onExit) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(AppTheme.mossGreen)
                    }
                }
                .padding()
                .background(AppTheme.cardBackground)

                // Draggable List
                List {
                    ForEach(exercises, id: \.id) { exercise in
                        HStack(spacing: 12) {
                            Image(systemName: "line.3.horizontal")
                                .foregroundStyle(.secondary)

                            Text(exerciseNames[exercise.exerciseId] ?? "Unknown")
                                .font(.system(size: 16, weight: .medium))

                            Spacer()

                            Text("\(exercise.sets.count) Sätze")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(AppTheme.cardBackground)
                    }
                    .onMove { from, to in
                        exercises.move(fromOffsets: from, toOffset: to)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .environment(\.editMode, .constant(.active))
            }
            .background(AppTheme.background)
            .cornerRadius(AppLayout.CornerRadius.extraLarge)
            .padding(.horizontal, 20)
            .padding(.vertical, 60)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
}
