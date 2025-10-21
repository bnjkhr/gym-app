//
//  ActiveExerciseCard.swift
//  GymTracker
//
//  Exercise card for Active Workout View - matches screenshot design
//

import SwiftUI

struct ActiveExerciseCard: View {
    // MARK: - Constants

    private enum Layout {
        static let cardCornerRadius: CGFloat = 39  // Match iPhone screen radius
        static let headerPadding: CGFloat = 20
        static let setPadding: CGFloat = 16
        static let bottomButtonHeight: CGFloat = 56
        static let bottomButtonSpacing: CGFloat = 12
    }

    private enum Typography {
        static let exerciseNameSize: CGFloat = 24
        static let equipmentSize: CGFloat = 14
        static let weightSize: CGFloat = 28
        static let repsSize: CGFloat = 24
        static let unitSize: CGFloat = 14
    }

    // MARK: - Properties

    @Binding var exercise: WorkoutExercise
    let exerciseIndex: Int
    var onToggleCompletion: ((Int) -> Void)?
    var onQuickAdd: ((String) -> Void)?
    var onDeleteSet: ((Int) -> Void)?
    var onMarkAllComplete: (() -> Void)?
    var onAddSet: (() -> Void)?
    var onReorderSets: (() -> Void)?

    @State private var quickAddText: String = ""
    @FocusState private var isQuickAddFocused: Bool
    @State private var isReorderMode: Bool = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            // Sets
            setsView

            // Quick-Add TextField
            quickAddView

            // Bottom Action Buttons
            bottomActionsView
        }
        .background(Color.white)
        .cornerRadius(Layout.cardCornerRadius)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 1)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.exercise.name)
                    .font(.system(size: Typography.exerciseNameSize, weight: .semibold))
                    .foregroundStyle(.black)

                Text(exercise.exercise.equipmentType.rawValue)
                    .font(.system(size: Typography.equipmentSize))
                    .foregroundStyle(.gray)
            }

            Spacer()

            // Menu button (three dots)
            Menu {
                Button("Add Set") {
                    onAddSet?()
                }
                Button("View History") {
                    // TODO
                }
                Button("Delete Exercise", role: .destructive) {
                    // TODO
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, Layout.headerPadding)
        .padding(.top, Layout.headerPadding)
        .padding(.bottom, 12)
    }

    // MARK: - Sets

    private var setsView: some View {
        List {
            ForEach(exercise.sets) { set in
                let index = exercise.sets.firstIndex(where: { $0.id == set.id }) ?? 0

                setRowView(index: index)
                    .contentShape(Rectangle())
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            HapticManager.shared.light()
                            onDeleteSet?(index)
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
            }
            .onMove { source, destination in
                withAnimation {
                    exercise.sets.move(fromOffsets: source, toOffset: destination)
                }
                HapticManager.shared.impact()
            }
        }
        .listStyle(.plain)
        .scrollDisabled(true)
        .frame(height: CGFloat(exercise.sets.count) * 60)  // Approximate height per row
        .environment(\.editMode, .constant(isReorderMode ? .active : .inactive))
    }

    private func setRowView(index: Int) -> some View {
        HStack(spacing: 16) {
            // Weight
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(Int(exercise.sets[index].weight))")
                    .font(.system(size: Typography.weightSize, weight: .bold))
                    .foregroundStyle(.black)

                Text("kg")
                    .font(.system(size: Typography.unitSize))
                    .foregroundStyle(.gray)
            }
            .frame(minWidth: 90, alignment: .leading)

            // Reps
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(exercise.sets[index].reps)")
                    .font(.system(size: Typography.repsSize, weight: .bold))
                    .foregroundStyle(.black)

                Text("reps")
                    .font(.system(size: Typography.unitSize))
                    .foregroundStyle(.gray)
            }
            .frame(minWidth: 80, alignment: .leading)

            Spacer()

            // Checkbox
            Button {
                HapticManager.shared.light()
                onToggleCompletion?(index)
            } label: {
                Image(
                    systemName: exercise.sets[index].completed ? "checkmark.square.fill" : "square"
                )
                .font(.system(size: 28))
                .foregroundStyle(exercise.sets[index].completed ? .black : .gray.opacity(0.3))
            }
        }
        .padding(.horizontal, Layout.headerPadding)
    }

    // MARK: - Quick-Add

    private var quickAddView: some View {
        TextField("Neuer Satz oder Notiz", text: $quickAddText)
            .font(.system(size: 16))
            .foregroundStyle(.gray)
            .padding(.horizontal, Layout.headerPadding)
            .padding(.vertical, 16)
            .focused($isQuickAddFocused)
            .submitLabel(.done)
            .onSubmit {
                handleQuickAdd()
            }
    }

    // MARK: - Bottom Actions

    private var bottomActionsView: some View {
        HStack(spacing: Layout.bottomButtonSpacing) {
            // Mark all complete
            Button {
                HapticManager.shared.success()
                onMarkAllComplete?()
            } label: {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 24))
                    .foregroundStyle(.gray)
                    .frame(maxWidth: .infinity)
                    .frame(height: Layout.bottomButtonHeight)
            }

            // Add set
            Button {
                HapticManager.shared.light()
                onAddSet?()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: Layout.bottomButtonHeight)
            }

            // Reorder
            Button {
                HapticManager.shared.selection()
                withAnimation {
                    isReorderMode.toggle()
                }
            } label: {
                Image(systemName: isReorderMode ? "checkmark" : "arrow.up.arrow.down")
                    .font(.system(size: 24))
                    .foregroundStyle(isReorderMode ? .orange : .gray)
                    .frame(maxWidth: .infinity)
                    .frame(height: Layout.bottomButtonHeight)
            }
        }
        .padding(.horizontal, Layout.headerPadding)
        .padding(.bottom, Layout.headerPadding)
    }

    // MARK: - Quick-Add Logic

    private func handleQuickAdd() {
        guard !quickAddText.isEmpty else { return }
        onQuickAdd?(quickAddText)
        quickAddText = ""
        isQuickAddFocused = false
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var exercise = WorkoutExercise(
        exercise: Exercise(
            name: "Lat Pulldown",
            muscleGroups: [.back],
            equipmentType: .cable
        ),
        sets: [
            ExerciseSet(reps: 8, weight: 100, restTime: 90, completed: true),
            ExerciseSet(reps: 8, weight: 105, restTime: 90, completed: false),
            ExerciseSet(reps: 8, weight: 110, restTime: 90, completed: false),
            ExerciseSet(reps: 6, weight: 115, restTime: 120, completed: false),
            ExerciseSet(reps: 8, weight: 95, restTime: 90, completed: false),
        ]
    )

    ScrollView {
        ActiveExerciseCard(
            exercise: $exercise,
            exerciseIndex: 0,
            onToggleCompletion: { index in
                exercise.sets[index].completed.toggle()
            },
            onQuickAdd: { input in
                print("Quick-Add: \(input)")
            },
            onDeleteSet: { index in
                exercise.sets.remove(at: index)
                print("Deleted set at index \(index)")
            },
            onMarkAllComplete: {
                exercise.sets.indices.forEach { exercise.sets[$0].completed = true }
            },
            onAddSet: {
                exercise.sets.append(
                    ExerciseSet(reps: 8, weight: 100, restTime: 90, completed: false))
            },
            onReorderSets: {
                print("Reorder sets")
            }
        )
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
