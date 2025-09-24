import SwiftUI
import Charts

struct ContentView: View {
    @StateObject private var workoutStore = WorkoutStore()
    @State private var navigateToActiveWorkout = false

    var body: some View {
        NavigationStack {
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
            .navigationDestination(isPresented: $navigateToActiveWorkout) {
                if let activeWorkout = workoutStore.activeWorkout,
                   let binding = workoutBinding(for: activeWorkout.id) {
                    WorkoutDetailView(
                        workout: binding,
                        isActiveSession: true,
                        onActiveSessionEnd: {
                            workoutStore.activeSessionID = nil
                            WorkoutLiveActivityController.shared.end()
                        }
                    )
                    .environmentObject(workoutStore)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let activeWorkout = workoutStore.activeWorkout {
                    ActiveWorkoutBar(
                        workout: activeWorkout,
                        resumeAction: { resumeActiveWorkout() },
                        endAction: { endActiveSession() }
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
    }

    private func workoutBinding(for id: UUID) -> Binding<Workout>? {
        guard let index = workoutStore.workouts.firstIndex(where: { $0.id == id }) else {
            return nil
        }
        return Binding(
            get: { workoutStore.workouts[index] },
            set: { workoutStore.workouts[index] = $0 }
        )
    }

    private func resumeActiveWorkout() {
        guard let active = workoutStore.activeWorkout else {
            workoutStore.activeSessionID = nil
            return
        }
        // Navigiere über die globale NavigationDestination
        navigateToActiveWorkout = true
        WorkoutLiveActivityController.shared.start(workoutName: active.name)
    }

    private func endActiveSession() {
        workoutStore.activeSessionID = nil
        WorkoutLiveActivityController.shared.end()
        navigateToActiveWorkout = false
    }
}

private struct WorkoutSelection: Identifiable, Hashable {
    let id: UUID
}

// MARK: - Workouts Tab

struct WorkoutsHomeView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @State private var showingAddWorkout = false
    @State private var showingWorkoutWizard = false
    @State private var showingManualAdd = false
    @State private var selectedWorkout: WorkoutSelection?
    @State private var editingWorkoutSelection: WorkoutSelection?
    @State private var viewingSession: WorkoutSession?
    @State private var missingTemplateName: String?
    @State private var showingMissingTemplateAlert = false

    // Neu: Zustand für Löschbestätigung
    @State private var workoutToDelete: Workout?

    private var weekStart: Date {
        let calendar = Calendar.current
        return calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
    }

    private var workoutsThisWeek: Int {
        workoutStore.sessionHistory.filter { $0.date >= weekStart }.count
    }

    private var minutesThisWeek: Int {
        workoutStore.sessionHistory
            .filter { $0.date >= weekStart }
            .compactMap { $0.duration }
            .map { Int($0 / 60) }
            .reduce(0, +)
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                let sortedSessions = workoutStore.sessionHistory
                    .sorted { $0.date > $1.date }
                let highlightSession = sortedSessions.first
                let storedRoutines = workoutStore.workouts

                LazyVStack(spacing: 20, pinnedViews: []) {
                    if let session = highlightSession {
                        SessionActionButton(
                            session: session,
                            startAction: { startSession($0) },
                            detailAction: { viewSession($0) },
                            deleteAction: { removeSession(id: $0.id) }
                        ) {
                            WorkoutHighlightCard(workout: Workout(session: session))
                        }
                    } else {
                        EmptyStateCard(action: { showingAddWorkout = true })
                    }

                    SectionHeader(title: "Gespeicherte Workouts", subtitle: "Tippe zum Starten oder Bearbeiten")

                    if storedRoutines.isEmpty {
                        Text("Lege ein neues Workout an, um eine Routine zu speichern.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        LazyVStack(spacing: 6) {
                            ForEach(storedRoutines) { workout in
                                // Tippen zeigt Menü (Starten, Bearbeiten, Löschen mit Bestätigung)
                                Menu {
                                    Button("Workout starten") {
                                        startWorkout(with: workout.id)
                                    }
                                    Button("Bearbeiten") {
                                        editWorkout(id: workout.id)
                                    }
                                    Button("Löschen", role: .destructive) {
                                        workoutToDelete = workout
                                    }
                                } label: {
                                    WorkoutRow(workout: workout)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    WeeklySnapshotCard(
                        workoutsThisWeek: workoutsThisWeek,
                        minutesThisWeek: minutesThisWeek,
                        goal: workoutStore.weeklyGoal
                    )

                    RecentActivityCard(
                        workouts: Array(sortedSessions.prefix(5)),
                        startAction: { startSession($0) },
                        detailAction: { viewSession($0) },
                        deleteSessionAction: { removeSession(id: $0.id) },
                        enableActions: true,
                        showHeader: false
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
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
            NavigationStack {
                VStack(spacing: 20) {
                    Text("Neues Workout erstellen")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.top)

                    VStack(spacing: 16) {
                        Button {
                            showingAddWorkout = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showingWorkoutWizard = true
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Workout-Assistent")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text("Personalisiertes Workout basierend auf deinen Zielen")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer()
                                Image(systemName: "wand.and.stars")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.blue.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            showingAddWorkout = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showingManualAdd = true
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Manuell erstellen")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text("Selbst zusammengestelltes Workout")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer()
                                Image(systemName: "plus.circle")
                                    .font(.title2)
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray6))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()

                    Spacer()
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Abbrechen") {
                            showingAddWorkout = false
                        }
                    }
                }
            }
        }
        .navigationDestination(item: $selectedWorkout) { selection in
            if let binding = binding(for: selection.id) {
                WorkoutDetailView(
                    workout: binding,
                    isActiveSession: workoutStore.activeSessionID == selection.id,
                    onActiveSessionEnd: { endActiveSession() }
                )
                .environmentObject(workoutStore)
            } else {
                Text("Workout konnte nicht geladen werden")
            }
        }
        .sheet(item: $editingWorkoutSelection) { selection in
            if let binding = binding(for: selection.id) {
                EditWorkoutView(workout: binding)
                    .environmentObject(workoutStore)
            } else {
                Text("Workout konnte nicht geladen werden")
            }
        }
        .onReceive(workoutStore.$workouts) { workouts in
            guard let activeID = workoutStore.activeSessionID else { return }
            if !workouts.contains(where: { $0.id == activeID }) {
                workoutStore.activeSessionID = nil
                WorkoutLiveActivityController.shared.end()
            }
        }
        .sheet(item: $viewingSession) { session in
            SessionDetailView(session: session)
        }
        .alert("Wirklich löschen?", isPresented: Binding(
            get: { workoutToDelete != nil },
            set: { if !$0 { workoutToDelete = nil } }
        )) {
            Button("Löschen", role: .destructive) {
                if let id = workoutToDelete?.id {
                    deleteWorkout(id: id)
                }
                workoutToDelete = nil
            }
            Button("Abbrechen", role: .cancel) {
                workoutToDelete = nil
            }
        } message: {
            Text("\(workoutToDelete?.name ?? "Workout") wird dauerhaft entfernt.")
        }
        .alert("Vorlage nicht gefunden", isPresented: $showingMissingTemplateAlert, presenting: missingTemplateName) { _ in
            Button("OK", role: .cancel) { missingTemplateName = nil }
        } message: { name in
            Text("Für die Session \(name) existiert keine gespeicherte Vorlage mehr.")
        }
        .sheet(isPresented: $showingWorkoutWizard) {
            WorkoutWizardView()
                .environmentObject(workoutStore)
        }
        .sheet(isPresented: $showingManualAdd) {
            AddWorkoutView()
                .environmentObject(workoutStore)
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

    private func startWorkout(with id: UUID) {
        guard let binding = binding(for: id) else { return }
        var workout = binding.wrappedValue

        // Wenn bereits aktiv: nicht zurücksetzen, nur in Details navigieren
        if workoutStore.activeSessionID == id {
            selectedWorkout = WorkoutSelection(id: id)
            WorkoutLiveActivityController.shared.start(workoutName: workout.name)
            return
        }

        // Neu starten: Zeitstempel setzen und Sätze zurücksetzen
        workout.date = Date()
        workout.duration = nil
        for exerciseIndex in workout.exercises.indices {
            for setIndex in workout.exercises[exerciseIndex].sets.indices {
                workout.exercises[exerciseIndex].sets[setIndex].completed = false
            }
        }
        binding.wrappedValue = workout

        selectedWorkout = WorkoutSelection(id: id)
        workoutStore.activeSessionID = id
        WorkoutLiveActivityController.shared.start(workoutName: workout.name)
    }

    private func showWorkoutDetails(id: UUID) {
        selectedWorkout = WorkoutSelection(id: id)
        // aktive Session bleibt bestehen
    }

    private func editWorkout(id: UUID) {
        editingWorkoutSelection = WorkoutSelection(id: id)
    }

    private func deleteWorkout(id: UUID) {
        if let index = workoutStore.workouts.firstIndex(where: { $0.id == id }) {
            workoutStore.deleteWorkout(at: IndexSet(integer: index))
            if selectedWorkout?.id == id {
                selectedWorkout = nil
            }
            if workoutStore.activeSessionID == id {
                workoutStore.activeSessionID = nil
                WorkoutLiveActivityController.shared.end()
            }
            if editingWorkoutSelection?.id == id {
                editingWorkoutSelection = nil
            }
        }
    }

    private func removeSession(id: UUID) {
        workoutStore.removeSession(with: id)
        if workoutStore.activeSessionID == id {
            workoutStore.activeSessionID = nil
            WorkoutLiveActivityController.shared.end()
        }
        if let session = viewingSession, session.id == id {
            viewingSession = nil
        }
    }

    private func startSession(_ session: WorkoutSession) {
        viewingSession = nil
        if let templateId = session.templateId, binding(for: templateId) != nil {
            missingTemplateName = nil
            startWorkout(with: templateId)
        } else {
            missingTemplateName = session.name
            showingMissingTemplateAlert = true
        }
    }

    private func viewSession(_ session: WorkoutSession) {
        viewingSession = session
    }

    private func endActiveSession() {
        workoutStore.activeSessionID = nil
        WorkoutLiveActivityController.shared.end()
    }
}

struct WorkoutHighlightCard: View {
    let workout: Workout
    @Environment(\.colorScheme) private var colorScheme

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
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(dateText.uppercased())
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.mossGreen)

                Text(workout.name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }

            HStack(spacing: 10) {
                MetricChip(icon: "clock", text: durationText, tint: .mossGreen)
                MetricChip(icon: "flame.fill", text: "\(workout.exercises.count) Übungen", tint: .mossGreen)
            }

            Wrap(alignment: .leading, spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    CapsuleTag(text: tag)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(.secondarySystemBackground),
                            Color.mossGreen.opacity(colorScheme == .dark ? 0.06 : 0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 4)
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
                .fill(Color(.secondarySystemBackground))
        )
        .shadow(color: Color.black.opacity(0.04), radius: 18, x: 0, y: 10)
    }
}

struct WeeklySnapshotCard: View {
    let workoutsThisWeek: Int
    let minutesThisWeek: Int
    let goal: Int

    private var progressRatio: Double {
        guard goal > 0 else { return 0 }
        return Double(workoutsThisWeek) / Double(goal)
    }

    private var clampedProgress: Double {
        min(max(progressRatio, 0), 1)
    }

    private var progressPercentageText: String {
        let percent = Int(round(progressRatio * 100))
        return "\(percent)%"
    }

    private var goalSummaryText: String {
        guard goal > 0 else { return "\(workoutsThisWeek) Workouts" }
        return "\(workoutsThisWeek)/\(goal) Workouts"
    }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Diese Woche")
                    .font(.headline)
                    .fontWeight(.semibold)
                Text(goalSummaryText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(progressPercentageText) erfüllt • \(minutesThisWeek) Min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 8)
                    .frame(width: 56, height: 56)

                Circle()
                    .trim(from: 0, to: CGFloat(clampedProgress))
                    .stroke(
                        Color.mossGreen,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 56, height: 56)
                    .animation(.easeInOut(duration: 0.6), value: clampedProgress)

                Text(progressPercentageText)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.mossGreen)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .shadow(color: .black.opacity(0.02), radius: 6, x: 0, y: 3)
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

// Neue, schlichte Zeile ohne Play-Button
struct WorkoutRow: View {
    let workout: Workout
    var onPlay: (() -> Void)? = nil

    private var formattedDate: String {
        workout.date.formatted(.dateTime.day().month().hour().minute())
    }

    private var durationText: String? {
        guard let duration = workout.duration else { return nil }
        return "\(Int(duration / 60)) Min"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(workout.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    Text(formattedDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
                // Play-Button wird nicht mehr verwendet
            }

            Wrap(alignment: .leading, spacing: 6) {
                InfoChip(icon: "list.bullet", label: "\(workout.exercises.count) Übungen")
                if let durationText {
                    InfoChip(icon: "clock", label: durationText)
                }
                if !workout.notes.isEmpty {
                    InfoChip(icon: "note.text", label: "Notizen")
                }
            }

            Divider()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                    Text(formattedDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tertiary)
            }

            Wrap(alignment: .leading, spacing: 8) {
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
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .shadow(color: .black.opacity(0.02), radius: 4, x: 0, y: 2)
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
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.tertiarySystemFill), in: Capsule())
    }
}

struct MetricChip: View {
    let icon: String
    let text: String
    var tint: Color = Color.mossGreen

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .imageScale(.small)
            Text(text)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
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
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(background, in: Capsule())
            .foregroundStyle(foreground)
    }

    private var background: Color {
        switch style {
        case .primary:
            return Color.mossGreen.opacity(0.12)
        case .secondary:
            return Color(.tertiarySystemFill)
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
        let containerWidth = (proposal.width ?? 300) - spacing
        var size = CGSize(width: containerWidth, height: 0)
        var currentRowWidth: CGFloat = 0
        var currentRowHeight: CGFloat = 0

        for subview in subviews {
            let subviewSize = subview.sizeThatFits(.init(width: min(containerWidth, 100), height: 40))

            if currentRowWidth + subviewSize.width + spacing > containerWidth && currentRowWidth > 0 {
                size.height += currentRowHeight + spacing
                currentRowWidth = subviewSize.width + spacing
                currentRowHeight = subviewSize.height
            } else {
                currentRowWidth += subviewSize.width + spacing
                currentRowHeight = max(currentRowHeight, subviewSize.height)
            }
        }

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

    @State private var currentTime = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var completedSets: Int {
        workout.exercises.flatMap { $0.sets }.filter { $0.completed }.count
    }

    private var totalSets: Int {
        workout.exercises.reduce(0) { $0 + $1.sets.count }
    }

    private var statusText: String {
        guard totalSets > 0 else { return "Noch keine Sätze" }
        return "\(completedSets)/\(totalSets) Sätze"
    }

    private var elapsedTime: TimeInterval {
        currentTime.timeIntervalSince(workout.date)
    }

    private var formattedElapsedTime: String {
        let totalSeconds = Int(elapsedTime)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
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

            VStack(alignment: .trailing, spacing: 2) {
                Text(formattedElapsedTime)
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.mossGreen)
                Text("Dauer")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

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
        .onAppear {
            currentTime = Date()
        }
        .onReceive(timer) { _ in
            currentTime = Date()
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
                    .fill(Color(.secondarySystemBackground))
            )
            .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 6)
        }
    }
}

// MARK: - Exercises Tab (Liste + Filter-Chips + Bottom-Search)

struct ExercisesCatalogView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @State private var showingAddExercise = false
    @State private var searchText = ""
    @State private var selectedMuscle: MuscleGroup? = nil

    // verfügbare Muskelgruppen aus dem Store
    private var availableMuscles: [MuscleGroup] {
        let all = workoutStore.exercises.flatMap { $0.muscleGroups }
        return Array(Set(all)).sorted { $0.rawValue < $1.rawValue }
    }

    private var filteredExercises: [Exercise] {
        workoutStore.exercises.filter { exercise in
            // Filter Muskelgruppe
            let matchesMuscle = selectedMuscle == nil || exercise.muscleGroups.contains(selectedMuscle!)
            // Filter Suche
            if searchText.isEmpty {
                return matchesMuscle
            }
            let matchesSearch =
                exercise.name.localizedCaseInsensitiveContains(searchText) ||
                exercise.muscleGroups.contains { $0.rawValue.localizedCaseInsensitiveContains(searchText) }
            return matchesMuscle && matchesSearch
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            List {
                if !availableMuscles.isEmpty {
                    // Filter-Chips unter der Suchleiste
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(
                                title: "Alle",
                                isSelected: selectedMuscle == nil,
                                color: Color.mossGreen
                            ) {
                                selectedMuscle = nil
                            }
                            ForEach(availableMuscles, id: \.self) { muscle in
                                FilterChip(
                                    title: muscle.rawValue,
                                    isSelected: selectedMuscle == muscle,
                                    color: muscle.color
                                ) {
                                    selectedMuscle = (selectedMuscle == muscle) ? nil : muscle
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                }

                ForEach(filteredExercises) { exercise in
                    NavigationLink {
                        EditExerciseView(exercise: exercise) { updated in
                            workoutStore.updateExercise(updated)
                        } deleteAction: {
                            if let index = workoutStore.exercises.firstIndex(where: { $0.id == exercise.id }) {
                                workoutStore.deleteExercise(at: IndexSet(integer: index))
                            }
                        }
                    } label: {
                        ExerciseCompactRow(exercise: exercise)
                    }
                }
            }
            .listStyle(.insetGrouped)
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
            .safeAreaInset(edge: .bottom) {
                BottomSearchBar(text: $searchText)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
        }
    }
}

private struct ExerciseCompactRow: View {
    let exercise: Exercise

    var body: some View {
        HStack(spacing: 12) {
            // Icon mit Farbe der ersten Muskelgruppe
            let color = exercise.muscleGroups.first?.color ?? Color("AccentColor")
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 34, height: 34)
                Image(systemName: "figure.strengthtraining.functional")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                if !exercise.description.isEmpty {
                    Text(exercise.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if !exercise.muscleGroups.isEmpty {
                    Wrap(alignment: .leading, spacing: 4) {
                        ForEach(exercise.muscleGroups, id: \.self) { muscle in
                            Text(muscle.rawValue)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(muscle.color.opacity(0.15), in: Capsule())
                                .foregroundStyle(muscle.color)
                        }
                    }
                }
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.medium))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? color.opacity(0.18) : Color(.tertiarySystemFill))
                )
                .foregroundStyle(isSelected ? color : .primary)
                .overlay(
                    Capsule().stroke(color.opacity(isSelected ? 0.35 : 0), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct BottomSearchBar: View {
    @Binding var text: String
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Übungen durchsuchen …", text: $text)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .focused($focused)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Suche löschen")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule().stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 3)
        .onAppear {
            // Optional: Fokus nicht automatisch setzen
            focused = false
        }
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

    private var weeklyWorkouts: [WorkoutSession] {
        workoutStore.sessionHistory.filter { $0.date >= weekStart }
    }

    private var progressValue: Double {
        let goal = workoutStore.weeklyGoal
        guard goal > 0 else { return 0 }
        return Double(weeklyWorkouts.count) / Double(goal)
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

    private var calendarData: [Date: [WorkoutSession]] {
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
                VStack(spacing: 18) {
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

                    RecentActivityCard(
                        workouts: workoutStore.sessionHistory.sorted { $0.date > $1.date }.prefix(5).map { $0 },
                        enableActions: false
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
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
        return String(format: "%.0f%%", max(progress, 0) * 100)
    }

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    private var remainingText: String {
        guard goal > 0 else { return "Kein Ziel festgelegt" }
        if workoutsCount >= goal {
            return "Ziel übertroffen!"
        }
        return "Noch \(goal - workoutsCount) Sessions geplant"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Wöchentlicher Fortschritt")
                        .font(.headline)
                    Text("\(workoutsCount) von \(goal) Workouts")
                        .font(.title3.weight(.semibold))
                    Text(remainingText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(Color.primary.opacity(0.08), lineWidth: 10)
                        .frame(width: 84, height: 84)

                    Circle()
                        .trim(from: 0, to: CGFloat(clampedProgress))
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
                .fill(Color(.secondarySystemBackground))
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
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.mossGreen.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: metric.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.mossGreen)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(metric.value)
                    .font(.title3.weight(.bold))

                Text(metric.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .shadow(color: .black.opacity(0.02), radius: 4, x: 0, y: 2)
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
                .fill(Color(.secondarySystemBackground))
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
    let workoutsByDay: [Date: [WorkoutSession]]
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
                .fill(Color(.secondarySystemBackground))
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
                .fill(Color(.secondarySystemBackground))
        )
        .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 8)
    }
}

struct RecentActivityCard: View {
    let workouts: [WorkoutSession]
    var startAction: (WorkoutSession) -> Void = { _ in }
    var detailAction: (WorkoutSession) -> Void = { _ in }
    var deleteSessionAction: (WorkoutSession) -> Void = { _ in }
    var enableActions: Bool = true
    var showHeader: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if showHeader {
                HStack {
                    Text("Letzte Sessions")
                        .font(.headline)
                    Spacer()
                    Text("\(workouts.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if workouts.isEmpty {
                Text("Starte dein erstes Workout, um hier Insights zu sehen.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 14) {
                    ForEach(workouts) { session in
                        if enableActions {
                            SessionActionButton(
                                session: session,
                                startAction: startAction,
                                detailAction: detailAction,
                                deleteAction: deleteSessionAction
                            ) {
                                sessionRow(for: session)
                            }
                        } else {
                            sessionRow(for: session)
                        }
                    }
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 8)
    }

    @ViewBuilder
    private func sessionRow(for session: WorkoutSession) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.name)
                    .fontWeight(.medium)
                Text(session.date.formatted(.dateTime.day().month().weekday()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let duration = session.duration {
                Text("\(Int(duration / 60)) Min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()
                .frame(height: 18)

            Text("\(session.exercises.count) Übungen")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}



struct SessionDetailView: View {
    let session: WorkoutSession

    var body: some View {
        NavigationStack {
            List {
                Section("Überblick") {
                    LabeledContent("Datum", value: session.date.formatted(.dateTime.day().month().year().hour().minute()))
                    if let duration = session.duration {
                        LabeledContent("Dauer", value: "\(Int(duration / 60)) Min")
                    }
                    if !session.notes.isEmpty {
                        Text(session.notes)
                            .foregroundStyle(.secondary)
                    }
                }

                ForEach(Array(session.exercises.enumerated()), id: \.offset) { index, exercise in
                    Section("Übung \(index + 1): \(exercise.exercise.name)") {
                        ForEach(Array(exercise.sets.enumerated()), id: \.offset) { setIndex, set in
                            HStack {
                                Text("Satz \(setIndex + 1)")
                                Spacer()
                                Text("\(set.reps) Wdh")
                                Text(String(format: "%.1f kg", set.weight))
                                    .foregroundStyle(.secondary)
                            }
                            .font(.footnote)
                        }
                    }
                }
            }
            .navigationTitle(session.name)
            .navigationBarTitleDisplayMode(.inline)
        }
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
