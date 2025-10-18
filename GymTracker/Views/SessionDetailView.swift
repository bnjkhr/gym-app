import SwiftUI
import SwiftData

struct SessionDetailView: View {
    let session: WorkoutSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var workoutStore: WorkoutStoreCoordinator

    @State private var showingRestartConfirmation = false
    @State private var previousSessions: [WorkoutSessionEntity] = []

    // Performance: Use cached DateFormatter
    private var localizedDateFormatter: DateFormatter {
        DateFormatters.germanMedium
    }

    // MARK: - Computed Statistics

    private var totalVolume: Double {
        session.exercises.reduce(0.0) { sessionTotal, exercise in
            let exerciseVolume = exercise.sets
                .filter { $0.completed }
                .reduce(0.0) { $0 + ($1.weight * Double($1.reps)) }
            return sessionTotal + exerciseVolume
        }
    }

    private var completionRate: Double {
        let allSets = session.exercises.flatMap { $0.sets }
        guard !allSets.isEmpty else { return 0 }
        let completedCount = allSets.filter { $0.completed }.count
        return Double(completedCount) / Double(allSets.count) * 100
    }

    private var totalSetsCompleted: Int {
        session.exercises.flatMap { $0.sets }.filter { $0.completed }.count
    }

    private var totalSets: Int {
        session.exercises.flatMap { $0.sets }.count
    }

    private var totalReps: Int {
        session.exercises.flatMap { $0.sets }
            .filter { $0.completed }
            .reduce(0) { $0 + $1.reps }
    }

    private var averageRestTime: TimeInterval {
        let allSets = session.exercises.flatMap { $0.sets }
        guard !allSets.isEmpty else { return 0 }
        let totalRest = allSets.reduce(0.0) { $0 + $1.restTime }
        return totalRest / Double(allSets.count)
    }

    private var topSet: (exercise: String, set: ExerciseSet)? {
        var maxVolume = 0.0
        var topSet: (String, ExerciseSet)? = nil

        for exercise in session.exercises {
            for set in exercise.sets where set.completed {
                let volume = set.weight * Double(set.reps)
                if volume > maxVolume {
                    maxVolume = volume
                    topSet = (exercise.exercise.name, set)
                }
            }
        }
        return topSet
    }

    private var exerciseStatistics: [ExerciseStatistic] {
        session.exercises.map { workoutExercise in
            let completedSets = workoutExercise.sets.filter { $0.completed }
            let maxWeight = completedSets.map { $0.weight }.max() ?? 0
            let totalVolume = completedSets.reduce(0.0) { $0 + ($1.weight * Double($1.reps)) }
            let avgReps = completedSets.isEmpty ? 0 : Double(completedSets.reduce(0) { $0 + $1.reps }) / Double(completedSets.count)

            // Calculate progression
            let progression = calculateProgression(for: workoutExercise.exercise.id, currentVolume: totalVolume)

            return ExerciseStatistic(
                id: workoutExercise.id,
                exerciseName: workoutExercise.exercise.name,
                maxWeight: maxWeight,
                totalVolume: totalVolume,
                averageReps: avgReps,
                completedSets: completedSets.count,
                totalSets: workoutExercise.sets.count,
                progressionPercentage: progression
            )
        }
    }

    private func calculateProgression(for exerciseId: UUID, currentVolume: Double) -> Double? {
        // Find previous session with same exercise
        let previousSessionsWithExercise = previousSessions.filter { sessionEntity in
            sessionEntity.exercises.contains(where: { $0.exercise?.id == exerciseId })
        }

        guard let lastSession = previousSessionsWithExercise.first,
              let lastExercise = lastSession.exercises.first(where: { $0.exercise?.id == exerciseId }) else {
            return nil
        }

        // Calculate previous volume
        let previousVolume = lastExercise.sets
            .filter { $0.completed }
            .reduce(0.0) { $0 + ($1.weight * Double($1.reps)) }

        guard previousVolume > 0 else { return nil }

        // Calculate percentage change
        let change = ((currentVolume - previousVolume) / previousVolume) * 100
        return change
    }

    private var volumeDataPoints: [VolumeDataPoint] {
        exerciseStatistics.map { stat in
            VolumeDataPoint(exerciseName: stat.exerciseName, volume: stat.totalVolume)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Main Content
                ScrollView(showsIndicators: true) {
                    VStack(spacing: 20) {
                        // Hero Section
                        heroSection
                            .padding(.horizontal, 20)
                            .padding(.top, 8)

                        // Summary Grid
                        summaryGrid
                            .padding(.horizontal, 20)

                        // Chart Section
                        if !volumeDataPoints.isEmpty {
                            VolumeChart(dataPoints: volumeDataPoints)
                                .padding(.horizontal, 20)
                        }

                        // Exercises List
                        exercisesList
                            .padding(.horizontal, 20)

                        // Notes Section
                        if !session.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            notesSection
                                .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 100) // Space for toolbar
                }
                .background(Color(.systemGroupedBackground))

                // Bottom Toolbar
                actionToolbar
            }
            .navigationTitle("Session Details")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(
                "Workout erneut starten?",
                isPresented: $showingRestartConfirmation,
                titleVisibility: .visible
            ) {
                Button("Starten") {
                    restartWorkout()
                }
                Button("Abbrechen", role: .cancel) { }
            } message: {
                Text("Das Workout '\(session.name)' wird als neue Session gestartet.")
            }
            .onAppear {
                loadPreviousSessions()
            }
        }
    }

    // MARK: - Data Loading

    private func loadPreviousSessions() {
        let descriptor = FetchDescriptor<WorkoutSessionEntity>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        if let allSessions = try? modelContext.fetch(descriptor) {
            // Filter sessions that are older than current session
            previousSessions = allSessions.filter { $0.date < session.date }
        }
    }

    // MARK: - View Builders

    @ViewBuilder
    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Date Label
            Text(DateFormatters.germanWeekdayDayMonth.string(from: session.date).uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
                .tracking(0.5)

            // Workout Name
            Text(session.name)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)

            HStack(spacing: 12) {
                // Duration Badge
                if let duration = session.duration {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("\(Int(duration / 60)) min")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.2))
                    )
                }

                // Completion Badge
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("\(Int(completionRate))%")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.2))
                )

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppLayout.Spacing.extraLarge)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppTheme.deepBlue, AppTheme.darkPurple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Workout \(session.name), am \(DateFormatters.germanWeekdayDayMonth.string(from: session.date)), Abschlussrate \(Int(completionRate)) Prozent")
    }

    @ViewBuilder
    private var summaryGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ],
            spacing: 12
        ) {
            SessionStatCard(
                icon: "scalemass.fill",
                value: "\(Int(totalVolume)) kg",
                label: "Gesamtvolumen",
                color: AppTheme.powerOrange
            )

            SessionStatCard(
                icon: "square.stack.3d.up.fill",
                value: "\(totalSetsCompleted)/\(totalSets)",
                label: "Sätze",
                color: AppTheme.mossGreen
            )

            SessionStatCard(
                icon: "repeat",
                value: "\(totalReps)",
                label: "Wiederholungen",
                color: AppTheme.turquoiseBoost
            )

            SessionStatCard(
                icon: "timer",
                value: "\(Int(averageRestTime))s",
                label: "Ø Pause",
                color: AppTheme.deepBlue
            )

            // Herzfrequenzdaten, wenn vorhanden
            if let minHR = session.minHeartRate {
                SessionStatCard(
                    icon: "heart.fill",
                    value: "\(minHR) bpm",
                    label: "Min. HF",
                    color: .customBlue
                )
            }

            if let maxHR = session.maxHeartRate {
                SessionStatCard(
                    icon: "heart.fill",
                    value: "\(maxHR) bpm",
                    label: "Max. HF",
                    color: .red
                )
            }

            if let avgHR = session.avgHeartRate {
                SessionStatCard(
                    icon: "heart.fill",
                    value: "\(avgHR) bpm",
                    label: "Ø HF",
                    color: .customOrange
                )
            }
        }
    }

    @ViewBuilder
    private var exercisesList: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Übungen")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 4)

            ForEach(session.exercises, id: \.id) { exercise in
                if let stat = exerciseStatistics.first(where: { $0.id == exercise.id }) {
                    ExerciseDetailCard(
                        statistic: stat,
                        sets: exercise.sets
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notizen")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)

            Text(session.notes)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(AppLayout.Spacing.standard)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.systemBackground))
                )
        }
        .padding(AppLayout.Spacing.standard)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(.systemGray5), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    @ViewBuilder
    private var actionToolbar: some View {
        HStack(spacing: 12) {
            Button {
                showingRestartConfirmation = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Erneut starten")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.mossGreen, AppTheme.turquoiseBoost],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .shadow(color: AppTheme.mossGreen.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel("Workout erneut starten")
            .accessibilityHint("Startet das Workout \(session.name) als neue Session")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            Rectangle()
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -2)
        )
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Actions

    private func restartWorkout() {
        // Find template if exists
        if let templateId = session.templateId {
            // Try to start the template directly
            workoutStore.startSession(for: templateId)
            if workoutStore.activeSessionID == templateId {
                dismiss()
            }
        } else {
            // Create new template from session and start it
            createTemplateAndStart()
        }
    }

    private func createTemplateAndStart() {
        // Create a new WorkoutEntity from the session
        let newWorkout = WorkoutEntity(
            name: session.name,
            date: Date(),
            exercises: [],
            defaultRestTime: session.defaultRestTime,
            duration: nil,
            notes: session.notes,
            isFavorite: false,
            isSampleWorkout: false
        )

        // Fetch existing exercises from DB to match
        let descriptor = FetchDescriptor<ExerciseEntity>()
        guard let allExercises = try? modelContext.fetch(descriptor) else { return }

        // Copy exercises and sets
        for (index, exercise) in session.exercises.enumerated() {
            // Find matching ExerciseEntity by ID
            guard let exerciseEntity = allExercises.first(where: { $0.id == exercise.exercise.id }) else {
                continue
            }

            let workoutExercise = WorkoutExerciseEntity(
                exercise: exerciseEntity,
                order: index
            )

            for set in exercise.sets {
                let newSet = ExerciseSetEntity(
                    reps: set.reps,
                    weight: set.weight,
                    restTime: set.restTime,
                    completed: false // Reset completion status
                )
                workoutExercise.sets.append(newSet)
                modelContext.insert(newSet)
            }

            newWorkout.exercises.append(workoutExercise)
            modelContext.insert(workoutExercise)
        }

        modelContext.insert(newWorkout)
        try? modelContext.save()

        // Start the new workout
        workoutStore.startSession(for: newWorkout.id)
        if workoutStore.activeSessionID == newWorkout.id {
            dismiss()
        }
    }
}
