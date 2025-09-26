import SwiftUI
import Charts

private struct StatisticsScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct StatisticsView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @Environment(\.colorScheme) private var colorScheme

    @State private var headerHidden: Bool = false
    @State private var lastScrollOffset: CGFloat = 0
    @State private var didSetInitialOffset: Bool = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                GeometryReader { geo in
                    Color.clear
                        .preference(
                            key: StatisticsScrollOffsetPreferenceKey.self,
                            value: geo.frame(in: .named("statisticsScroll")).minY
                        )
                }
                .frame(height: 0)

                // Neue Übersicht (letztes Workout)
                ProgressOverviewCardView()
                    .environmentObject(workoutStore)

                // Neue Infobox: Veränderungen (Gewicht/Volumen & Wiederholungen)
                ProgressDeltaInfoCardView()
                    .environmentObject(workoutStore)

                // Bestehende Bereiche
                MostUsedExercisesView()
                    .environmentObject(workoutStore)

                RecentActivityView()
                    .environmentObject(workoutStore)
            }
            .padding()
        }
        .toolbar(.hidden, for: .navigationBar)
        .onPreferenceChange(StatisticsScrollOffsetPreferenceKey.self) { newValue in
            if !didSetInitialOffset {
                lastScrollOffset = newValue
                didSetInitialOffset = true
                return
            }
            let delta = newValue - lastScrollOffset
            if delta < -5 {
                if !headerHidden { headerHidden = true }
            } else if delta > 5 {
                if headerHidden { headerHidden = false }
            }
            lastScrollOffset = newValue
        }
        .coordinateSpace(name: "statisticsScroll")
    }
}

// MARK: - Neue Karten

private struct ProgressOverviewCardView: View {
    @EnvironmentObject var workoutStore: WorkoutStore

    private var lastSession: WorkoutSession? {
        workoutStore.sessionHistory.sorted { $0.date > $1.date }.first
    }

    private var lastVolume: Double? {
        guard let session = lastSession else { return nil }
        return session.exercises.reduce(0) { partial, ex in
            partial + ex.sets.reduce(0) { $0 + (Double($1.reps) * $1.weight) }
        }
    }

    private var lastDateText: String {
        guard let session = lastSession else { return "–" }
        return session.date.formatted(.dateTime.day().month().year())
    }

    private var lastExerciseCountText: String {
        guard let session = lastSession else { return "–" }
        return "\(session.exercises.count)"
    }

    private var lastVolumeText: String {
        guard let vol = lastVolume else { return "–" }
        return vol.formatted(.number.precision(.fractionLength(1))) + " kg"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Übersicht")
                .font(.headline)

            HStack(spacing: 12) {
                statBox(title: "Gewicht", value: lastVolumeText, icon: "scalemass.fill", tint: .mossGreen)
                statBox(title: "Datum", value: lastDateText, icon: "calendar", tint: .blue)
                statBox(title: "Übungen", value: lastExerciseCountText, icon: "list.bullet", tint: .orange)
            }
        }
        .padding()
    }

    private func statBox(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .contentTransition(.numericText())
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemBackground))
        )
    }
}

private struct ProgressDeltaInfoCardView: View {
    @EnvironmentObject var workoutStore: WorkoutStore

    private var lastTwoSessions: [WorkoutSession] {
        workoutStore.sessionHistory.sorted { $0.date > $1.date }.prefix(2).map { $0 }
    }

    private var lastSession: WorkoutSession? { lastTwoSessions.first }
    private var prevSession: WorkoutSession? { lastTwoSessions.count > 1 ? lastTwoSessions[1] : nil }

    private func volume(for session: WorkoutSession) -> Double {
        session.exercises.reduce(0) { partial, ex in
            partial + ex.sets.reduce(0) { $0 + (Double($1.reps) * $1.weight) }
        }
    }

    private func reps(for session: WorkoutSession) -> Int {
        session.exercises.reduce(0) { $0 + $1.sets.reduce(0) { $0 + $1.reps } }
    }

    private var deltaVolumeText: String {
        guard let last = lastSession, let prev = prevSession else {
            return "Neu: kein Vergleich"
        }
        let delta = volume(for: last) - volume(for: prev)
        let formatted = delta.magnitude.formatted(.number.precision(.fractionLength(1))) + " kg"
        if delta == 0 {
            return "Gleich wie zuletzt"
        } else if delta > 0 {
            return "+\(formatted) vs. letzte Session"
        } else {
            return "-\(formatted) vs. letzte Session"
        }
    }

    private var deltaRepsText: String {
        guard let last = lastSession, let prev = prevSession else {
            return "Neu: kein Vergleich"
        }
        let delta = reps(for: last) - reps(for: prev)
        if delta == 0 {
            return "Gleich wie zuletzt"
        } else if delta > 0 {
            return "+\(delta) Wdh. vs. letzte Session"
        } else {
            return "\(delta) Wdh. vs. letzte Session"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(Color.mossGreen)
                Text("Veränderungen seit letzter Session")
                    .font(.subheadline.weight(.semibold))
            }

            VStack(spacing: 10) {
                HStack {
                    Text("Gewicht")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(deltaVolumeText)
                        .font(.subheadline.weight(.semibold))
                        .contentTransition(.numericText())
                }
                HStack {
                    Text("Wiederholungen")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(deltaRepsText)
                        .font(.subheadline.weight(.semibold))
                        .contentTransition(.numericText())
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - Bestehende Bereiche (unverändert)

struct MostUsedExercisesView: View {
    @EnvironmentObject var workoutStore: WorkoutStore

    var exerciseUsage: [(Exercise, Int)] {
        var usage: [UUID: Int] = [:]

        for workout in workoutStore.workouts {
            for workoutExercise in workout.exercises {
                usage[workoutExercise.exercise.id, default: 0] += 1
            }
        }

        return workoutStore.exercises
            .map { exercise in
                (exercise, usage[exercise.id] ?? 0)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Beliebteste Übungen")
                .font(.headline)

            if exerciseUsage.isEmpty {
                Text("Noch keine Workouts aufgezeichnet")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(Array(exerciseUsage.enumerated()), id: \.offset) { index, item in
                    let (exercise, count) = item
                    HStack {
                        Text("\(index + 1).")
                            .fontWeight(.semibold)
                            .foregroundColor(.mossGreen)

                        Text(exercise.name)

                        Spacer()

                        Text("\(count)x")
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct RecentActivityView: View {
    @EnvironmentObject var workoutStore: WorkoutStore

    var recentWorkouts: [Workout] {
        workoutStore.workouts
            .sorted { $0.date > $1.date }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Letzte Aktivität")
                .font(.headline)

            if recentWorkouts.isEmpty {
                Text("Noch keine Workouts aufgezeichnet")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(recentWorkouts) { workout in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(workout.name)
                                .fontWeight(.medium)

                            Text(workout.date, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text("\(workout.exercises.count) Übungen")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    StatisticsView()
        .environmentObject(WorkoutStore())
}

