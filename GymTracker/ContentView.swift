import SwiftUI
import Charts

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

            SettingsView()
                .environmentObject(workoutStore)
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("Einstellungen")
                }
        }
        .tint(Color.mossGreen)
    }
}

private struct WorkoutSelection: Identifiable, Hashable {
    let id: UUID
}

// MARK: - Workouts Tab

struct WorkoutsHomeView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @State private var showingAddWorkout = false
    @State private var selectedWorkout: WorkoutSelection?
    @State private var pendingActionWorkoutID: UUID?
    @State private var activeSessionID: UUID?
    @State private var editingWorkoutSelection: WorkoutSelection?

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

    private var sortedWorkoutIndices: [Int] {
        workoutStore.workouts.indices.sorted {
            workoutStore.workouts[$0].date > workoutStore.workouts[$1].date
        }
    }

    private var storedWorkoutIndices: ArraySlice<Int> {
        let indices = sortedWorkoutIndices
        guard indices.count > 1 else { return [] }
        return indices.dropFirst()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        if let workout = highlightWorkout {
                            Button {
                                presentActions(for: workout)
                            } label: {
                                WorkoutHighlightCard(workout: workout)
                            }
                            .buttonStyle(.plain)
                        } else {
                            EmptyStateCard(action: { showingAddWorkout = true })
                        }

                        WeeklySnapshotCard(
                            workoutsThisWeek: workoutsThisWeek,
                            minutesThisWeek: minutesThisWeek,
                            goal: workoutStore.weeklyGoal
                        )

                        if !storedWorkoutIndices.isEmpty {
                            SectionHeader(title: "Gespeicherte Workouts", subtitle: "Tippe zum Starten oder Bearbeiten")

                            VStack(spacing: 14) {
                                ForEach(storedWorkoutIndices, id: \.self) { index in
                                    let workout = workoutStore.workouts[index]
                                    Button {
                                        presentActions(for: workout)
                                    } label: {
                                        WorkoutCard(workout: workout)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        SectionHeader(title: "Letzte Sessions", subtitle: "Halte deine Routine frisch")

                        RecentActivityCard(workouts: workoutStore.workouts.sorted { $0.date > $1.date }.prefix(5).map { $0 })
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
                    .tint(Color("AccentColor"))
                }
            }
            .sheet(isPresented: $showingAddWorkout) {
                AddWorkoutView()
                    .environmentObject(workoutStore)
            }
            .navigationDestination(item: $selectedWorkout) { selection in
                if let binding = binding(for: selection.id) {
                    WorkoutDetailView(
                        workout: binding,
                        isActiveSession: activeSessionID == selection.id,
                        onActiveSessionEnd: { endActiveSession() }
                    )
                    .environmentObject(workoutStore)
                } else {
                    Text("Workout konnte nicht geladen werden")
                }
            }
            .confirmationDialog("Aktion wählen", isPresented: Binding(
                get: { pendingActionWorkoutID != nil },
                set: { newValue in
                    if !newValue { pendingActionWorkoutID = nil }
                }
            ), actions: {
                if let workoutID = pendingActionWorkoutID {
                    Button("Workout starten") {
                        startWorkout(with: workoutID)
                    }
                    Button("Details ansehen") {
                        showWorkoutDetails(id: workoutID)
                    }
                    Button("Bearbeiten") {
                        editWorkout(id: workoutID)
                    }
                }
                Button("Abbrechen", role: .cancel) {}
            })
            .sheet(item: $editingWorkoutSelection) { selection in
                if let binding = binding(for: selection.id) {
                    EditWorkoutView(workout: binding)
                        .environmentObject(workoutStore)
                } else {
                    Text("Workout konnte nicht geladen werden")
                }
            }
            .safeAreaInset(edge: .bottom) {
                if shouldShowActiveSessionBar, let activeWorkout = currentActiveWorkout {
                    ActiveWorkoutBar(
                        workout: activeWorkout,
                        resumeAction: { resumeActiveWorkout() },
                        endAction: { endActiveSession() }
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .onReceive(workoutStore.$workouts) { workouts in
                guard let activeID = activeSessionID else { return }
                if !workouts.contains(where: { $0.id == activeID }) {
                    activeSessionID = nil
                }
            }
        }
    }

    private func binding(for id: UUID) -> Binding<Workout>? {
        guard let index = workoutStore.workouts.firstIndex(where: { $0.id == id }) else {
            return nil
        }
        return binding(index: index)
    }

    private func binding(index: Int) -> Binding<Workout> {
        Binding(
            get: { workoutStore.workouts[index] },
            set: { workoutStore.workouts[index] = $0 }
        )
    }

    private func presentActions(for workout: Workout) {
        pendingActionWorkoutID = workout.id
    }

    private func startWorkout(with id: UUID) {
        guard let binding = binding(for: id) else { return }
        var workout = binding.wrappedValue
        workout.date = Date()
        workout.duration = nil
        for exerciseIndex in workout.exercises.indices {
            for setIndex in workout.exercises[exerciseIndex].sets.indices {
                workout.exercises[exerciseIndex].sets[setIndex].completed = false
            }
        }
        binding.wrappedValue = workout

        selectedWorkout = WorkoutSelection(id: id)
        pendingActionWorkoutID = nil
        activeSessionID = id
    }

    private func showWorkoutDetails(id: UUID) {
        selectedWorkout = WorkoutSelection(id: id)
        pendingActionWorkoutID = nil
        activeSessionID = nil
    }

    private func editWorkout(id: UUID) {
        pendingActionWorkoutID = nil
        editingWorkoutSelection = WorkoutSelection(id: id)
    }

    private var currentActiveWorkout: Workout? {
        guard let activeID = activeSessionID,
              let index = workoutStore.workouts.firstIndex(where: { $0.id == activeID }) else {
            return nil
        }
        return workoutStore.workouts[index]
    }

    private var shouldShowActiveSessionBar: Bool {
        activeSessionID != nil && selectedWorkout == nil && currentActiveWorkout != nil
    }

    private func resumeActiveWorkout() {
        guard let activeID = activeSessionID, binding(for: activeID) != nil else {
            activeSessionID = nil
            return
        }
        selectedWorkout = WorkoutSelection(id: activeID)
    }

    private func endActiveSession() {
        activeSessionID = nil
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
                    .foregroundStyle(Color("AccentColor").opacity(0.6))

                Text(workout.name)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }

            HStack(spacing: 12) {
                MetricChip(icon: "clock", text: durationText, tint: .mossGreen)
                MetricChip(icon: "flame.fill", text: "\(workout.exercises.count) Übungen", tint: .mossGreen)
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
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white, Color.mossGreen.opacity(0.14)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.mossGreen.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: Color.mossGreen.opacity(0.18), radius: 20, x: 0, y: 12)
        .accessibilityElement(children: .combine)
    }
}

struct EmptyStateCard: View {
    let action: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(Color.mossGreen)

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
                    .background(Color("AccentColor").opacity(0.15), in: Capsule())
                    .foregroundColor(Color.mossGreen)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 18, x: 0, y: 10)
    }
}

struct WeeklySnapshotCard: View {
    let workoutsThisWeek: Int
    let minutesThisWeek: Int
    let goal: Int

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

            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 10)
                    .frame(width: 64, height: 64)

                Circle()
                    .trim(from: 0, to: CGFloat(min(max(progress, 0), 1)))
                    .stroke(
                        Color.mossGreen,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 64, height: 64)
                    .animation(.easeInOut(duration: 0.6), value: progress)

                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.mossGreen)
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.white)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 16, x: 0, y: 8)
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
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 6)
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
    var tint: Color = Color.mossGreen

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
        .background(tint.opacity(0.12), in: Capsule())
        .foregroundStyle(tint)
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
            AnyShapeStyle(Color.mossGreen.opacity(0.16))
        case .secondary:
            AnyShapeStyle(Color.primary.opacity(0.05))
        }
    }

    private var foreground: Color {
        switch style {
        case .primary:
            return Color.mossGreen
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

private struct ActiveWorkoutBar: View {
    let workout: Workout
    let resumeAction: () -> Void
    let endAction: () -> Void

    private var completedSets: Int {
        workout.exercises.flatMap { $0.sets }.filter { $0.completed }.count
    }

    private var totalSets: Int {
        workout.exercises.reduce(0) { $0 + $1.sets.count }
    }

    private var statusText: String {
        guard totalSets > 0 else { return "Noch keine Sätze" }
        return "\(completedSets)/\(totalSets) Sätze abgeschlossen"
    }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Aktives Workout")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(workout.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(statusText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: resumeAction) {
                Image(systemName: "play.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(Color.mossGreen))
            }
            .accessibilityLabel("Aktives Workout fortsetzen")

            Button(action: endAction) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .background(
                        Circle()
                            .fill(.regularMaterial)
                    )
            }
            .accessibilityLabel("Aktives Workout beenden")
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.mossGreen.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 14, x: 0, y: 6)
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
                        .fill(Color("AccentColor").opacity(0.12))
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
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 6)
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
        [GridItem(.adaptive(minimum: 140), spacing: 14)]
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(filteredExercises) { exercise in
                        ExerciseTile(exercise: exercise)
                    }
                }
                .padding(16)
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
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(primaryColor.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 5)
    }
}

// MARK: - Progress Tab

struct ProgressDashboardView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @State private var selectedExerciseID: UUID?
    @State private var selectedRange: ExerciseRange = .threeMonths
    @State private var calendarMonth: Date = Date()

    private let calendar = Calendar.current

    private var weekStart: Date {
        calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
    }

    private var weeklyWorkouts: [Workout] {
        workoutStore.workouts.filter { $0.date >= weekStart }
    }

    private var progressValue: Double {
        let goal = workoutStore.weeklyGoal
        guard goal > 0 else { return 0 }
        return min(Double(weeklyWorkouts.count) / Double(goal), 1)
    }

    private var minutesThisWeek: Int {
        weeklyWorkouts.compactMap { $0.duration }.map { Int($0 / 60) }.reduce(0, +)
    }

    private var activeExercise: Exercise? {
        if let id = selectedExerciseID {
            return workoutStore.exercises.first { $0.id == id }
        }
        return workoutStore.exercises.first
    }

    private var exerciseStats: WorkoutStore.ExerciseStats? {
        guard let exercise = activeExercise else { return nil }
        return workoutStore.exerciseStats(for: exercise)
    }

    private var filteredHistory: [WorkoutStore.ExerciseStats.HistoryPoint] {
        guard let stats = exerciseStats else { return [] }
        guard let range = selectedRange.dateRange else { return stats.history }
        return stats.history.filter { range.contains($0.date) }
    }

    private var statCards: [StatMetric] {
        [
            StatMetric(title: "Workouts", value: "\(workoutStore.totalWorkoutCount)", icon: "dumbbell.fill"),
            StatMetric(title: "Ø pro Woche", value: String(format: "%.1f", workoutStore.averageWorkoutsPerWeek), icon: "calendar"),
            StatMetric(title: "Wochen-Serie", value: "\(workoutStore.currentWeekStreak)", icon: "flame.fill"),
            StatMetric(title: "Ø Dauer", value: "\(workoutStore.averageDurationMinutes) Min", icon: "clock")
        ]
    }

    private var currentMonthRange: ClosedRange<Date>? {
        guard let interval = calendar.dateInterval(of: .month, for: calendarMonth) else { return nil }
        let start = interval.start
        let end = calendar.date(byAdding: .second, value: -1, to: interval.end) ?? interval.end
        return start...end
    }

    private var calendarData: [Date: [Workout]] {
        guard let range = currentMonthRange else { return [:] }
        return workoutStore.workoutsByDay(in: range)
    }

    private var muscleVolumeData: [(MuscleGroup, Double)] {
        workoutStore.muscleVolume(byGroupInLastWeeks: 4)
    }

    private var maxMuscleVolume: Double {
        muscleVolumeData.map { $0.1 }.max() ?? 0
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    WeeklyGoalCard(
                        progress: progressValue,
                        workoutsCount: weeklyWorkouts.count,
                        goal: workoutStore.weeklyGoal,
                        minutes: minutesThisWeek
                    )

                    StatMetricsGrid(metrics: statCards)

                    ExerciseAnalyticsSection(
                        exercise: activeExercise,
                        stats: exerciseStats,
                        history: filteredHistory,
                        selectedRange: $selectedRange
                    ) {
                        Menu {
                            ForEach(workoutStore.exercises) { exercise in
                                Button {
                                    selectedExerciseID = exercise.id
                                } label: {
                                    HStack {
                                        Text(exercise.name)
                                        if selectedExerciseID == exercise.id || (selectedExerciseID == nil && exercise.id == activeExercise?.id) {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(activeExercise?.name ?? "Übung wählen")
                                    .font(.headline)
                                Image(systemName: "chevron.down")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    WorkoutCalendarSection(
                        month: calendarMonth,
                        calendar: calendar,
                        workoutsByDay: calendarData,
                        onPrevious: { adjustMonth(by: -1) },
                        onNext: { adjustMonth(by: 1) }
                    )

                    MuscleVolumeSection(data: muscleVolumeData, maxValue: maxMuscleVolume)

                    RecentActivityCard(workouts: workoutStore.workouts.sorted { $0.date > $1.date }.prefix(5).map { $0 })
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 28)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Fortschritt")
            .onAppear {
                if selectedExerciseID == nil {
                    selectedExerciseID = workoutStore.exercises.first?.id
                }
                calendarMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
            }
        }
    }

    private func adjustMonth(by value: Int) {
        calendarMonth = calendar.date(byAdding: .month, value: value, to: calendarMonth) ?? calendarMonth
    }

    struct StatMetric: Identifiable {
        let id = UUID()
        let title: String
        let value: String
        let icon: String
    }

    enum ExerciseRange: String, CaseIterable, Identifiable {
        case oneMonth = "1M"
        case threeMonths = "3M"
        case sixMonths = "6M"
        case oneYear = "1Y"
        case all = "All"

        var id: String { rawValue }

        var dateRange: ClosedRange<Date>? {
            guard self != .all else { return nil }
            let calendar = Calendar.current
            let end = Date()
            let component: Calendar.Component
            let value: Int

            switch self {
            case .oneMonth:
                component = .month
                value = -1
            case .threeMonths:
                component = .month
                value = -3
            case .sixMonths:
                component = .month
                value = -6
            case .oneYear:
                component = .year
                value = -1
            case .all:
                return nil
            }

            guard let start = calendar.date(byAdding: component, value: value, to: end) else { return nil }
            return start...end
        }
    }
}

struct WeeklyGoalCard: View {
    let progress: Double
    let workoutsCount: Int
    let goal: Int
    let minutes: Int

    private var formattedProgress: String {
        guard goal > 0 else { return "0%" }
        return String(format: "%.0f%%", progress * 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Wöchentlicher Fortschritt")
                        .font(.headline)
                    Text("\(workoutsCount) von \(goal) Workouts")
                        .font(.title3.weight(.semibold))
                    Text("Noch \(max(goal - workoutsCount, 0)) Sessions geplant")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(Color.primary.opacity(0.08), lineWidth: 10)
                        .frame(width: 84, height: 84)

                    Circle()
                        .trim(from: 0, to: CGFloat(min(max(progress, 0), 1)))
                        .stroke(
                            Color.mossGreen,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 84, height: 84)
                        .animation(.easeInOut(duration: 0.6), value: progress)

                    VStack(spacing: 2) {
                        Text(formattedProgress)
                            .font(.headline)
                        Text("Ziel")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack {
                Label("\(minutes) Min aktiv", systemImage: "timer")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(Color.mossGreen)
                    .frame(width: 160)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 18, x: 0, y: 10)
    }
}

struct StatMetricsGrid: View {
    let metrics: [ProgressDashboardView.StatMetric]

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(metrics) { metric in
                StatMetricCard(metric: metric)
            }
        }
    }
}

struct StatMetricCard: View {
    let metric: ProgressDashboardView.StatMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.mossGreen.opacity(0.14))
                    .frame(width: 44, height: 44)
                Image(systemName: metric.icon)
                    .foregroundStyle(Color.mossGreen)
            }

            Text(metric.value)
                .font(.title3.weight(.semibold))

            Text(metric.title)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 6)
    }
}

struct ExerciseAnalyticsSection<SelectionControl: View>: View {
    let exercise: Exercise?
    let stats: WorkoutStore.ExerciseStats?
    let history: [WorkoutStore.ExerciseStats.HistoryPoint]
    @Binding var selectedRange: ProgressDashboardView.ExerciseRange
    @ViewBuilder var selectionControl: SelectionControl

    private var formatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Übungsanalyse")
                        .font(.headline)
                    Text(exercise?.name ?? "Wähle eine Übung, um Details zu sehen")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                selectionControl
            }

            Picker("Zeitraum", selection: $selectedRange) {
                ForEach(ProgressDashboardView.ExerciseRange.allCases) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .tint(Color.mossGreen)

            if let stats, !history.isEmpty {
                Chart(history) { point in
                    LineMark(
                        x: .value("Datum", point.date),
                        y: .value("1RM", point.estimatedOneRepMax)
                    )
                    .interpolationMethod(.monotone)
                    AreaMark(
                        x: .value("Datum", point.date),
                        y: .value("1RM", point.estimatedOneRepMax)
                    )
                    .foregroundStyle(Color.mossGreen.opacity(0.20))
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(date, format: .dateTime.month(.abbreviated).day())
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let number = value.as(Double.self) {
                                Text(number.formatted(.number.precision(.fractionLength(0))))
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                }

                AnalyticsMetricsRow(stats: stats)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("Noch keine Daten verfügbar")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.white)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 8)
    }
}

private struct AnalyticsMetricsRow: View {
    let stats: WorkoutStore.ExerciseStats

    private var metrics: [(title: String, value: String)] {
        [
            ("1RM", stats.estimatedOneRepMax.formatted(.number.precision(.fractionLength(1))) + " kg"),
            ("Max Gewicht", stats.maxWeight.formatted(.number.precision(.fractionLength(1))) + " kg"),
            ("Volumen", stats.totalVolume.formatted(.number.precision(.fractionLength(1))) + " kg"),
            ("Wdh.", "\(stats.totalReps)")
        ]
    }

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            ForEach(metrics, id: \.title) { metric in
                VStack(alignment: .leading, spacing: 6) {
                    Text(metric.title)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(metric.value)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct WorkoutCalendarSection: View {
    let month: Date
    let calendar: Calendar
    let workoutsByDay: [Date: [Workout]]
    let onPrevious: () -> Void
    let onNext: () -> Void

    private var monthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }

    private var daysInMonth: [Date] {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return [] }
        var dates: [Date] = []
        var day = interval.start

        while day < interval.end {
            dates.append(day)
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? day
        }
        return dates
    }

    private var leadingPaddingDays: Int {
        guard let firstDay = daysInMonth.first else { return 0 }
        let weekday = calendar.component(.weekday, from: firstDay)
        let adjusted = weekday - calendar.firstWeekday
        return adjusted >= 0 ? adjusted : adjusted + 7
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let startIndex = max(calendar.firstWeekday - 1, 0)
        let suffix = Array(symbols[startIndex...])
        let prefix = Array(symbols[..<startIndex])
        return suffix + prefix
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Trainingskalender")
                    .font(.headline)
                Spacer()
                Button(action: onPrevious) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)

                Text(monthFormatter.string(from: month))
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Button(action: onNext) {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.borderless)
            }

            HStack {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol.uppercased())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 12) {
                ForEach(0..<leadingPaddingDays, id: \.self) { _ in
                    Spacer()
                }

                ForEach(daysInMonth, id: \.self) { day in
                    let startOfDay = calendar.startOfDay(for: day)
                    let workouts = workoutsByDay[startOfDay] ?? []
                    VStack(spacing: 6) {
                        Text("\(calendar.component(.day, from: day))")
                            .font(.caption)
                            .foregroundStyle(.primary)
                        Circle()
                            .fill(workouts.isEmpty ? Color.primary.opacity(0.08) : Color("AccentColor"))
                            .frame(width: 8, height: 8)
                            .opacity(workouts.isEmpty ? 0.25 : 1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.white)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 8)
    }
}

struct MuscleVolumeSection: View {
    let data: [(MuscleGroup, Double)]
    let maxValue: Double

    private var formatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Muskelvolumen (letzte 4 Wochen)")
                .font(.headline)

            if data.isEmpty {
                Text("Noch keine Trainingsdaten vorhanden.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 14) {
                    ForEach(data.prefix(5), id: \.0) { entry in
                        let progress = maxValue == 0 ? 0 : entry.1 / maxValue
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(entry.0.rawValue)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text((formatter.string(from: NSNumber(value: entry.1)) ?? "0") + " kg")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            ProgressView(value: progress)
                                .progressViewStyle(.linear)
                                .tint(entry.0.color)
                                .background(entry.0.color.opacity(0.15), in: Capsule())
                                .frame(height: 8)
                        }
                    }
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.white)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 8)
    }
}

struct RecentActivityCard: View {
    let workouts: [Workout]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Letzte Sessions")
                    .font(.headline)
                Spacer()
                Text("\(workouts.count)")
                    .font(.caption)
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
                                Text(workout.date.formatted(.dateTime.day().month().weekday()))
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
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.white)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 8)
    }
}

private extension View {
    @ViewBuilder
    func onChangeCompat<Value: Equatable>(of value: Value, perform action: @escaping (Value) -> Void) -> some View {
        if #available(iOS 17, *) {
            self.onChange(of: value, initial: false) { _, newValue in
                action(newValue)
            }
        } else {
            self.onChange(of: value, perform: action)
        }
    }
}

#Preview {
    ContentView()
}
