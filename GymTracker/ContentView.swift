import SwiftUI

struct ContentView: View {
    @StateObject private var workoutStore = WorkoutStore()

    var body: some View {
        TabView {
            WorkoutsHomeView()
                .environmentObject(workoutStore)
                .tabItem {
                    Image(systemName: "dumbbell")
                    Text("Workouts")
                }

            ExercisesCatalogView()
                .environmentObject(workoutStore)
                .tabItem {
                    Image(systemName: "list.bullet.rectangle")
                    Text("Übungen")
                }

            ProgressDashboardView()
                .environmentObject(workoutStore)
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Fortschritt")
                }
        }
        .tint(Color("AccentColor"))
    }
}

// MARK: - Workouts Tab

struct WorkoutsHomeView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @State private var showingAddWorkout = false

    private var weekStart: Date {
        let calendar = Calendar.current
        return calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
    }

    private var highlightWorkout: Workout? {
        workoutStore.workouts.sorted { $0.date > $1.date }.first
    }

    private var workoutsThisWeek: Int {
        workoutStore.workouts.filter { $0.date >= weekStart }.count
    }

    private var minutesThisWeek: Int {
        workoutStore.workouts
            .filter { $0.date >= weekStart }
            .compactMap { $0.duration }
            .map { Int($0 / 60) }
            .reduce(0, +)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color("AccentColor").opacity(0.25),
                        Color(.systemBackground)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        if let workout = highlightWorkout {
                            WorkoutHighlightCard(workout: workout)
                        } else {
                            EmptyStateCard(action: { showingAddWorkout = true })
                        }

                        WeeklySnapshotCard(workoutsThisWeek: workoutsThisWeek, minutesThisWeek: minutesThisWeek)

                        SectionHeader(title: "Letzte Sessions", subtitle: "Halte deine Routine frisch")

                        VStack(spacing: 18) {
                            ForEach(workoutStore.workouts.sorted { $0.date > $1.date }) { workout in
                                WorkoutCard(workout: workout)
                            }
                        }

                        AddActionButton(
                            title: "Workout planen",
                            subtitle: "Erstelle neue Sessions oder tracke spontane Workouts",
                            action: { showingAddWorkout = true }
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 28)
                }
            }
            .navigationTitle("Workouts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddWorkout = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .accessibilityLabel("Workout hinzufügen")
                }
            }
            .sheet(isPresented: $showingAddWorkout) {
                AddWorkoutView()
                    .environmentObject(workoutStore)
            }
        }
    }
}

struct WorkoutHighlightCard: View {
    let workout: Workout

    private var dateText: String {
        workout.date.formatted(.dateTime.weekday(.wide).day().month())
    }

    private var durationText: String {
        if let duration = workout.duration {
            return "\(Int(duration / 60)) Min"
        }
        return "Flexibel"
    }

    private var tags: [String] {
        let names = workout.exercises.map { $0.exercise.name }
        if names.count > 3 {
            return Array(names.prefix(3)) + ["+\(names.count - 3)"]
        }
        return names
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(dateText.uppercased())
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.75))

                Text(workout.name)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }

            HStack(spacing: 12) {
                MetricChip(icon: "clock", text: durationText)
                MetricChip(icon: "flame.fill", text: "\(workout.exercises.count) Übungen")
            }

            Wrap(alignment: .leading, spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    CapsuleTag(text: tag)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(26)
        .background(
            LinearGradient(
                colors: [Color("AccentColor"), Color("AccentColor").opacity(0.65), .purple.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(0.95)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color("AccentColor").opacity(0.45), radius: 24, x: 0, y: 18)
        .accessibilityElement(children: .combine)
    }
}

struct EmptyStateCard: View {
    let action: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(Color("AccentColor"))

            Text("Starte deine Trainingsreise")
                .font(.title2)
                .fontWeight(.bold)

            Text("Lege Workouts an, beobachte deinen Fortschritt und bleib motiviert mit smarten Insights.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(action: action) {
                Label("Erstes Workout planen", systemImage: "plus.circle.fill")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Color("AccentColor").opacity(0.12), in: Capsule())
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color("AccentColor").opacity(0.15), lineWidth: 1)
        )
    }
}

struct WeeklySnapshotCard: View {
    let workoutsThisWeek: Int
    let minutesThisWeek: Int

    private var goal: Int { 5 }

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(workoutsThisWeek) / Double(goal), 1)
    }

    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Diese Woche")
                    .font(.headline)
                Text("\(workoutsThisWeek) von \(goal) Sessions")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(minutesThisWeek) Minuten aktiv")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            ProgressView(value: progress)
                .progressViewStyle(.circular)
                .tint(Color("AccentColor"))
                .frame(width: 56, height: 56)
                .overlay {
                    Text("\(Int(progress * 100))%")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color("AccentColor"))
                }
        }
        .padding(22)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
}

struct SectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct WorkoutCard: View {
    let workout: Workout

    private var formattedDate: String {
        workout.date.formatted(.dateTime.day().month().hour().minute())
    }

    private var durationText: String? {
        guard let duration = workout.duration else { return nil }
        return "\(Int(duration / 60)) Min"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(workout.name)
                        .font(.headline)
                    Text(formattedDate)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(.tertiaryLabel))
            }

            Wrap(alignment: .leading, spacing: 8) {
                ForEach(workout.exercises.prefix(3)) { workoutExercise in
                    CapsuleTag(text: workoutExercise.exercise.name, style: .secondary)
                }
                if workout.exercises.count > 3 {
                    CapsuleTag(text: "+\(workout.exercises.count - 3)", style: .secondary)
                }
            }

            HStack(spacing: 16) {
                InfoChip(icon: "list.bullet", label: "\(workout.exercises.count) Übungen")
                if let durationText {
                    InfoChip(icon: "clock", label: durationText)
                }
                if !workout.notes.isEmpty {
                    InfoChip(icon: "note.text", label: "Notizen")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

struct InfoChip: View {
    let icon: String
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .imageScale(.small)
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.05), in: Capsule())
    }
}

struct MetricChip: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .imageScale(.small)
            Text(text)
                .font(.footnote)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.18), in: Capsule())
        .foregroundStyle(.white)
    }
}

struct CapsuleTag: View {
    enum Style {
        case primary
        case secondary
    }

    let text: String
    var style: Style = .primary

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(background)
            .foregroundStyle(foreground)
            .clipShape(Capsule())
    }

    private var background: AnyShapeStyle {
        switch style {
        case .primary:
            AnyShapeStyle(
                LinearGradient(
                    colors: [Color.white.opacity(0.22), Color.white.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .secondary:
            AnyShapeStyle(Color.primary.opacity(0.05))
        }
    }

    private var foreground: Color {
        switch style {
        case .primary:
            return .white
        case .secondary:
            return .primary
        }
    }
}

struct Wrap<Content: View>: View {
    var alignment: HorizontalAlignment = .leading
    var spacing: CGFloat = 8
    @ViewBuilder var content: Content

    init(alignment: HorizontalAlignment = .leading, spacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        WrapLayout(alignment: alignment, spacing: spacing) {
            content
        }
    }
}

struct WrapLayout: Layout {
    let alignment: HorizontalAlignment
    let spacing: CGFloat

    init(alignment: HorizontalAlignment = .leading, spacing: CGFloat = 8) {
        self.alignment = alignment
        self.spacing = spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let containerWidth = (proposal.width ?? 320) - spacing
        var size = CGSize(width: 0, height: 0)
        var currentRowWidth: CGFloat = 0
        var currentRowHeight: CGFloat = 0

        for subview in subviews {
            let subviewSize = subview.sizeThatFits(ProposedViewSize(width: containerWidth, height: proposal.height))

            if currentRowWidth + subviewSize.width + spacing > containerWidth {
                size.width = max(size.width, currentRowWidth)
                size.height += currentRowHeight + spacing
                currentRowWidth = subviewSize.width + spacing
                currentRowHeight = subviewSize.height
            } else {
                currentRowWidth += subviewSize.width + spacing
                currentRowHeight = max(currentRowHeight, subviewSize.height)
            }
        }

        size.width = max(size.width, currentRowWidth)
        size.height += currentRowHeight
        return size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var origin = CGPoint(x: bounds.minX, y: bounds.minY)
        var rowHeight: CGFloat = 0

        for subview in subviews {
            var subviewSize = subview.sizeThatFits(proposal)
            if subviewSize.width > bounds.width {
                subviewSize.width = bounds.width
            }

            if origin.x + subviewSize.width > bounds.maxX {
                origin.x = bounds.minX
                origin.y += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(at: origin, proposal: ProposedViewSize(width: subviewSize.width, height: subviewSize.height))
            origin.x += subviewSize.width + spacing
            rowHeight = max(rowHeight, subviewSize.height)
        }
    }
}

struct AddActionButton: View {
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color("AccentColor").opacity(0.18))
                        .frame(width: 46, height: 46)
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color("AccentColor"))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
    }
}

// MARK: - Exercises Tab

struct ExercisesCatalogView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @State private var showingAddExercise = false
    @State private var searchText = ""

    private var filteredExercises: [Exercise] {
        if searchText.isEmpty {
            return workoutStore.exercises
        }

        return workoutStore.exercises.filter { exercise in
            exercise.name.localizedCaseInsensitiveContains(searchText) ||
            exercise.muscleGroups.contains { $0.rawValue.localizedCaseInsensitiveContains(searchText) }
        }
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 160), spacing: 16)]
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(filteredExercises) { exercise in
                        ExerciseTile(exercise: exercise)
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Übungen")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Übung oder Muskelgruppe")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddExercise = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .accessibilityLabel("Übung hinzufügen")
                }
            }
            .sheet(isPresented: $showingAddExercise) {
                AddExerciseView()
                    .environmentObject(workoutStore)
            }
        }
    }
}

struct ExerciseTile: View {
    let exercise: Exercise

    private var primaryColor: Color {
        exercise.muscleGroups.first?.color ?? Color("AccentColor")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                Circle()
                    .fill(primaryColor.opacity(0.15))
                    .frame(width: 46, height: 46)
                Image(systemName: "figure.strengthtraining.functional")
                    .foregroundStyle(primaryColor)
            }

            Text(exercise.name)
                .font(.headline)

            if !exercise.description.isEmpty {
                Text(exercise.description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Wrap(alignment: .leading, spacing: 6) {
                ForEach(exercise.muscleGroups, id: \.self) { muscle in
                    Text(muscle.rawValue)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(muscle.color.opacity(0.16), in: Capsule())
                        .foregroundStyle(muscle.color)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(primaryColor.opacity(0.18), lineWidth: 1)
        )
    }
}

// MARK: - Progress Tab

struct ProgressDashboardView: View {
    @EnvironmentObject var workoutStore: WorkoutStore

    private let weeklyGoal = 5

    private var weekStart: Date {
        let calendar = Calendar.current
        return calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
    }

    private var weeklyWorkouts: [Workout] {
        workoutStore.workouts.filter { $0.date >= weekStart }
    }

    private var progressValue: Double {
        guard weeklyGoal > 0 else { return 0 }
        return min(Double(weeklyWorkouts.count) / Double(weeklyGoal), 1)
    }

    private var uniqueExercisesCount: Int {
        Set(workoutStore.workouts.flatMap { $0.exercises.map { $0.exercise.id } }).count
    }

    private var totalSets: Int {
        workoutStore.workouts.reduce(0) { partialResult, workout in
            partialResult + workout.exercises.reduce(0) { $0 + $1.sets.count }
        }
    }

    private var recentWorkouts: [Workout] {
        workoutStore.workouts.sorted { $0.date > $1.date }.prefix(5).map { $0 }
    }

    private var minutesThisWeek: Int {
        weeklyWorkouts.compactMap { $0.duration }.map { Int($0 / 60) }.reduce(0, +)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    WeeklyGoalCard(
                        progress: progressValue,
                        workoutsCount: weeklyWorkouts.count,
                        goal: weeklyGoal,
                        minutes: minutesThisWeek
                    )

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        StatMetricCard(title: "Gesamte Workouts", value: "\(workoutStore.workouts.count)", icon: "dumbbell.fill", tint: .orange)
                        StatMetricCard(title: "Übungen", value: "\(uniqueExercisesCount)", icon: "list.number", tint: .blue)
                        StatMetricCard(title: "Sätze absolviert", value: "\(totalSets)", icon: "checkmark.circle", tint: .green)
                        StatMetricCard(title: "Ø Dauer", value: averageDurationText, icon: "clock", tint: .purple)
                    }

                    RecentActivityCard(workouts: recentWorkouts)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 28)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Fortschritt")
        }
    }

    private var averageDurationText: String {
        let durations = workoutStore.workouts.compactMap { $0.duration }
        guard !durations.isEmpty else { return "–" }
        let average = durations.reduce(0, +) / Double(durations.count)
        return "\(Int(average / 60)) Min"
    }
}

struct WeeklyGoalCard: View {
    let progress: Double
    let workoutsCount: Int
    let goal: Int
    let minutes: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Wöchentliches Ziel")
                        .font(.headline)
                    Text("\(workoutsCount) von \(goal) Workouts abgeschlossen")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(Int(progress * 100))%")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.2), in: Capsule())
            }

            ProgressView(value: progress)
                .tint(.white)
                .progressViewStyle(.linear)
                .frame(height: 6)
                .background(Color.white.opacity(0.25), in: RoundedRectangle(cornerRadius: 3))

            HStack(spacing: 14) {
                Label("\(minutes) Minuten aktiv", systemImage: "timer")
                    .foregroundStyle(.white)
                Spacer()
                Label("Noch \(max(goal - workoutsCount, 0)) Sessions", systemImage: "target")
                    .foregroundStyle(.white.opacity(0.9))
            }
            .font(.footnote)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color("AccentColor"), Color("AccentColor").opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: Color("AccentColor").opacity(0.35), radius: 18, x: 0, y: 14)
    }
}

struct StatMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .foregroundStyle(tint)
            }

            Text(value)
                .font(.title3)
                .fontWeight(.bold)

            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(tint.opacity(0.14), lineWidth: 1)
        )
    }
}

struct RecentActivityCard: View {
    let workouts: [Workout]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Letzte Aktivität")
                    .font(.headline)
                Spacer()
                Text("\(workouts.count) Einträge")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if workouts.isEmpty {
                Text("Starte dein erstes Workout, um hier Insights zu sehen.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 14) {
                    ForEach(workouts) { workout in
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(workout.name)
                                    .fontWeight(.medium)
                                Text(workout.date, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if let duration = workout.duration {
                                Text("\(Int(duration / 60)) Min")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Divider()
                                .frame(height: 18)

                            Text("\(workout.exercises.count) Übungen")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.04), lineWidth: 1)
        )
    }
}

#Preview {
    ContentView()
}
