import SwiftUI

/// HomeViewV2 - Modern List-based Home View
///
/// **Design-Prinzipien:**
/// - List statt Grid für native Gestures
/// - Swipe-to-Delete für schnelles Löschen
/// - Drag-and-Drop für Favoriten-Reorder
/// - Haptic Feedback bei allen Interaktionen
/// - 1 Workout pro Zeile (mehr Info sichtbar)
///
/// **Phase 1 Implementation:**
/// - Pure UI Component (keine Business Logic)
/// - Callbacks für alle Aktionen (Dummy in Previews)
/// - @State für lokales UI-Management
///
/// **Usage:**
/// ```swift
/// HomeViewV2(
///     workouts: displayWorkouts,
///     weekStats: WeekStats(workoutCount: 3, totalMinutes: 180),
///     greeting: "Guten Morgen",
///     userName: "Ben",
///     lockerNumber: "123",
///     onStartWorkout: { id in startWorkout(with: id) },
///     onDeleteWorkout: { id in deleteWorkout(id: id) },
///     onReorderWorkouts: { source, dest in reorderWorkouts(from: source, to: dest) }
/// )
/// ```
struct HomeViewV2: View {
    // MARK: - Data

    let workouts: [Workout]
    let workoutDates: [Date]  // Dates with completed workouts
    let greeting: String
    let userName: String
    let lockerNumber: String?

    // MARK: - Callbacks (Dummy in Phase 1)

    var onStartWorkout: ((UUID) -> Void)?
    var onDeleteWorkout: ((UUID) -> Void)?
    var onReorderWorkouts: ((IndexSet, Int) -> Void)?
    var onToggleFavorite: ((UUID) -> Void)?
    var onEditWorkout: ((UUID) -> Void)?
    var onShowSettings: (() -> Void)?
    var onShowLockerInput: (() -> Void)?

    // MARK: - UI State

    @State private var isReorderMode: Bool = false
    @State private var localWorkouts: [Workout]

    // MARK: - Init

    init(
        workouts: [Workout],
        workoutDates: [Date] = [],
        greeting: String = "Hallo",
        userName: String = "",
        lockerNumber: String? = nil,
        onStartWorkout: ((UUID) -> Void)? = nil,
        onDeleteWorkout: ((UUID) -> Void)? = nil,
        onReorderWorkouts: ((IndexSet, Int) -> Void)? = nil,
        onToggleFavorite: ((UUID) -> Void)? = nil,
        onEditWorkout: ((UUID) -> Void)? = nil,
        onShowSettings: (() -> Void)? = nil,
        onShowLockerInput: (() -> Void)? = nil
    ) {
        self.workouts = workouts
        self.workoutDates = workoutDates
        self.greeting = greeting
        self.userName = userName
        self.lockerNumber = lockerNumber
        self.onStartWorkout = onStartWorkout
        self.onDeleteWorkout = onDeleteWorkout
        self.onReorderWorkouts = onReorderWorkouts
        self.onToggleFavorite = onToggleFavorite
        self.onEditWorkout = onEditWorkout
        self.onShowSettings = onShowSettings
        self.onShowLockerInput = onShowLockerInput

        // Initialize local state for reordering
        self._localWorkouts = State(initialValue: workouts)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            HomeV2Theme.pageBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Header Section
                    HomeHeaderSection(
                        greeting: greeting,
                        userName: userName,
                        lockerNumber: lockerNumber,
                        onShowSettings: {
                            HapticManager.shared.light()
                            onShowSettings?()
                        },
                        onShowLockerInput: {
                            HapticManager.shared.light()
                            onShowLockerInput?()
                        }
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                    // Week Calendar Strip
                    HomeWeekCalendar(workoutDates: workoutDates)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)

                    // Workout List
                    if localWorkouts.isEmpty {
                        emptyStateView
                    } else {
                        workoutListView
                    }
                }
            }
        }
        // Sync local state when workouts prop changes
        .onChange(of: workouts.count) { _, _ in
            localWorkouts = workouts
        }
    }

    // MARK: - Workout List

    private var workoutListView: some View {
        VStack(spacing: 0) {
            // Reorder Toggle Button
            HStack {
                Text("Meine Workouts")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(HomeV2Theme.primaryText)

                Spacer()

                Button {
                    HapticManager.shared.selection()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isReorderMode.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isReorderMode ? "checkmark" : "arrow.up.arrow.down")
                            .font(.system(size: 14, weight: .semibold))
                        Text(isReorderMode ? "Fertig" : "Sortieren")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(
                        isReorderMode ? HomeV2Theme.primaryButtonText : HomeV2Theme.primaryText
                    )
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(
                                isReorderMode
                                    ? HomeV2Theme.primaryButtonBackground
                                    : HomeV2Theme.secondaryButtonBackground)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            // List with Swipe & Drag
            List {
                ForEach(localWorkouts) { workout in
                    WorkoutListCard(
                        workout: workout,
                        isReorderMode: isReorderMode,
                        onStart: {
                            HapticManager.shared.light()
                            onStartWorkout?(workout.id)
                        },
                        onEdit: {
                            HapticManager.shared.light()
                            onEditWorkout?(workout.id)
                        },
                        onDelete: {
                            HapticManager.shared.warning()
                            deleteWorkout(workout)
                        },
                        onToggleFavorite: {
                            HapticManager.shared.light()
                            onToggleFavorite?(workout.id)
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            HapticManager.shared.warning()
                            deleteWorkout(workout)
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
                }
                .onMove { source, destination in
                    localWorkouts.move(fromOffsets: source, toOffset: destination)
                    HapticManager.shared.impact()
                    onReorderWorkouts?(source, destination)
                }
            }
            .listStyle(.plain)
            .scrollDisabled(true)
            .frame(height: CGFloat(localWorkouts.count) * 200)  // Approximate card height
            .environment(\.editMode, .constant(isReorderMode ? .active : .inactive))
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "dumbbell")
                .font(.system(size: 60, weight: .light))
                .foregroundStyle(.gray)

            VStack(spacing: 8) {
                Text("Keine Workouts")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(HomeV2Theme.primaryText)

                Text("Erstelle dein erstes Workout im Workouts-Tab")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(HomeV2Theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Helper Methods

    private func deleteWorkout(_ workout: Workout) {
        withAnimation {
            localWorkouts.removeAll { $0.id == workout.id }
        }
        onDeleteWorkout?(workout.id)
    }
}

// MARK: - Preview

#Preview("Standard - 4 Workouts") {
    @Previewable @State var workouts = [
        Workout(
            name: "Push Day",
            exercises: [
                WorkoutExercise(
                    exercise: Exercise(
                        name: "Bench Press",
                        muscleGroups: [.chest, .triceps],
                        equipmentType: .freeWeights
                    ),
                    sets: []
                ),
                WorkoutExercise(
                    exercise: Exercise(
                        name: "Shoulder Press",
                        muscleGroups: [.shoulders, .triceps],
                        equipmentType: .freeWeights
                    ),
                    sets: []
                ),
                WorkoutExercise(
                    exercise: Exercise(
                        name: "Tricep Extension",
                        muscleGroups: [.triceps],
                        equipmentType: .cable
                    ),
                    sets: []
                ),
            ],
            isFavorite: true
        ),
        Workout(
            name: "Pull Day",
            exercises: [
                WorkoutExercise(
                    exercise: Exercise(
                        name: "Lat Pulldown",
                        muscleGroups: [.back],
                        equipmentType: .cable
                    ),
                    sets: []
                ),
                WorkoutExercise(
                    exercise: Exercise(
                        name: "Barbell Row",
                        muscleGroups: [.back, .biceps],
                        equipmentType: .freeWeights
                    ),
                    sets: []
                ),
            ],
            isFavorite: true
        ),
        Workout(
            name: "Leg Day",
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
            ],
            isFavorite: true
        ),
        Workout(
            name: "Arms & Core",
            exercises: [
                WorkoutExercise(
                    exercise: Exercise(
                        name: "Bicep Curl",
                        muscleGroups: [.biceps],
                        equipmentType: .freeWeights
                    ),
                    sets: []
                )
            ],
            isFavorite: false
        ),
    ]

    let today = Date()
    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
    let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: today)!

    return HomeViewV2(
        workouts: workouts,
        workoutDates: [today, yesterday, twoDaysAgo],
        greeting: "Guten Morgen",
        userName: "Ben",
        lockerNumber: "123",
        onStartWorkout: { id in
            print("▶️ Start Workout: \(id)")
        },
        onDeleteWorkout: { id in
            workouts.removeAll { $0.id == id }
            print("🗑️ Deleted Workout: \(id)")
        },
        onReorderWorkouts: { source, dest in
            workouts.move(fromOffsets: source, toOffset: dest)
            print("🔄 Reordered: \(source) → \(dest)")
        },
        onEditWorkout: { id in
            print("✏️ Edit Workout: \(id)")
        },
        onShowSettings: {
            print("⚙️ Show Settings")
        },
        onShowLockerInput: {
            print("🔒 Show Locker Input")
        }
    )
}

#Preview("Empty State") {
    HomeViewV2(
        workouts: [],
        workoutDates: [],
        greeting: "Guten Morgen",
        userName: "Ben"
    )
}

#Preview("Single Workout") {
    HomeViewV2(
        workouts: [
            Workout(
                name: "Full Body",
                exercises: [
                    WorkoutExercise(
                        exercise: Exercise(
                            name: "Deadlift",
                            muscleGroups: [.back, .legs],
                            equipmentType: .freeWeights
                        ),
                        sets: []
                    )
                ],
                isFavorite: true
            )
        ],
        workoutDates: [Date()],
        greeting: "Guten Tag",
        userName: "Ben",
        lockerNumber: "007"
    )
}
