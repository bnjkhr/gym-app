import SwiftUI
import Charts

struct ContentView: View {
    @StateObject private var workoutStore = WorkoutStore()
    @State private var navigateToActiveWorkout = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            // Workouts Tab
            NavigationStack {
                WorkoutsHomeView()
                    .environmentObject(workoutStore)
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
                            .environmentObject(workoutStore)
                            .padding(Edge.Set.horizontal, 16)
                            .padding(Edge.Set.vertical, 12)
                            .padding(.bottom, 44)
                        }
                    }
            }
            .tabItem {
                Image(systemName: "dumbbell")
                Text("Workouts")
            }

            // Übungen Tab
            NavigationStack {
                ExercisesView()
                    .environmentObject(workoutStore)
            }
            .tabItem {
                Image(systemName: "list.bullet.rectangle")
                Text("Übungen")
            }

            // Fortschritt Tab
            NavigationStack {
                StatisticsView()
                    .environmentObject(workoutStore)
            }
            .tabItem {
                Image(systemName: "chart.line.uptrend.xyaxis")
                Text("Fortschritt")
            }

            // Einstellungen Tab
            NavigationStack {
                SettingsView()
                    .environmentObject(workoutStore)
            }
            .tabItem {
                Image(systemName: "gearshape")
                Text("Einstellungen")
            }
        }
        .tint(AppTheme.purple)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                workoutStore.flushPersistence()
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
        workoutStore.stopRest()
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
    @Environment(\.colorScheme) private var colorScheme

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
    
    private var sortedWorkouts: [Workout] {
        workoutStore.workouts.stablePartition { $0.isFavorite }
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
                            ForEach(sortedWorkouts) { workout in
                                // Star button outside menu, menu on row only
                                HStack(spacing: 10) {
                                    Button {
                                        workoutStore.toggleFavorite(for: workout.id)
                                    } label: {
                                        Image(systemName: workout.isFavorite ? "star.fill" : "star")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundStyle(workout.isFavorite ? AppTheme.purple : Color.secondary)
                                            .frame(width: 28, height: 28)
                                    }
                                    .buttonStyle(.plain)

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
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top) {
            HStack(alignment: .center) {
                Text("Workouts")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.primary)
                Spacer()
                Button {
                    showingAddWorkout = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle()
                                    .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06), lineWidth: 0.5)
                            )
                            .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.10), radius: 18, x: 0, y: 8)
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color.orange)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)
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
        workoutStore.stopRest()
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
                    .foregroundStyle(AppTheme.purple)

                Text(workout.name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }

            // Dauer-Chip entfernt, nur noch Anzahl Übungen
            HStack(spacing: 10) {
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
                            Color.mossGreen,
                            AppTheme.purple
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
                .foregroundStyle(.white)

            Text("Starte deine Trainingsreise")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)

            Text("Lege Workouts an, beobachte deinen Fortschritt und bleib motiviert mit smarten Insights.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)

            Button(action: action) {
                Label("Erstes Workout planen", systemImage: "plus.circle.fill")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .foregroundStyle(.white)
                    .background(Color.white.opacity(0.18), in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.28), lineWidth: 1))
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(AppTheme.headerGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.04), radius: 18, x: 0, y: 10)
    }
}

// Minimal Wrap placeholder (no true wrapping; lays out vertically)
struct Wrap<Content: View>: View {
    var alignment: HorizontalAlignment = .leading
    var spacing: CGFloat = 8
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: alignment, spacing: spacing) {
            content()
        }
    }
}

struct RecentActivityCard: View {
    let workouts: [WorkoutSession]
    let startAction: (WorkoutSession) -> Void
    let detailAction: (WorkoutSession) -> Void
    let deleteSessionAction: (WorkoutSession) -> Void
    let enableActions: Bool
    let showHeader: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showHeader {
                Text("Letzte Sessions")
                    .font(.headline)
            }
            ForEach(workouts) { session in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.name)
                            .font(.subheadline.weight(.semibold))
                        Text(session.date, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if enableActions {
                        Menu {
                            Button("Starten") { startAction(session) }
                            Button("Details") { detailAction(session) }
                            Button("Löschen", role: .destructive) { deleteSessionAction(session) }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// ActiveWorkoutBar updated to show the rest timer
struct ActiveWorkoutBar: View {
    let workout: Workout
    let resumeAction: () -> Void
    let endAction: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var workoutStore: WorkoutStore

    private var restText: String? {
        guard let state = workoutStore.activeRestState, state.workoutId == workout.id else { return nil }
        let m = state.remainingSeconds / 60
        let s = state.remainingSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Aktives Workout")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Text(workout.name)
                        .font(.headline)
                        .lineLimit(1)
                    if let rest = restText {
                        Label(rest, systemImage: "timer")
                            .font(.caption.weight(.semibold))
                            .contentTransition(.numericText())
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.12), in: Capsule())
                    }
                }
            }
            Spacer()
            Button(action: resumeAction) {
                Label("Fortsetzen", systemImage: "play.fill")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.mossGreen)

            Button(role: .destructive, action: endAction) {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.bordered)
        }
        .padding(12)
        .background(
            // durchscheinender Hintergrund
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.4 : 0.08), radius: 12, x: 0, y: 6)
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }
}

struct WeeklySnapshotCard: View {
    let workoutsThisWeek: Int
    let minutesThisWeek: Int
    let goal: Int

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Diese Woche")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(workoutsThisWeek) Workouts")
                    .font(.headline)
                Text("\(minutesThisWeek) Minuten")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text("Ziel")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(goal) / Woche")
                    .font(.headline)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

struct WorkoutRow: View {
    let workout: Workout
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.name)
                    .font(.headline)
                Text(workout.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(workout.exercises.count) Übungen")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
        )
    }
}

struct MetricChip: View {
    let icon: String
    let text: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.opacity(0.12), in: Capsule())
    }
}

struct CapsuleTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color(.systemGray5))
            )
    }
}

// Re-add SessionDetailView to fix missing type
struct SessionDetailView: View {
    let session: WorkoutSession

    var body: some View {
        NavigationStack {
            List {
                Section("Details") {
                    HStack {
                        Text("Name")
                        Spacer()
                        Text(session.name)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Datum")
                        Spacer()
                        Text(session.date, style: .date)
                            .foregroundStyle(.secondary)
                    }
                    if let duration = session.duration {
                        HStack {
                            Text("Dauer")
                            Spacer()
                            Text("\(Int(duration / 60)) min")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Übungen") {
                    ForEach(session.exercises) { ex in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(ex.exercise.name)
                                .font(.subheadline.weight(.semibold))
                            Text("\(ex.sets.count) Sätze")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Session")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private extension Array {
    func stablePartition(by isInFirstPartition: (Element) -> Bool) -> [Element] {
        var first: [Element] = []
        var second: [Element] = []
        for el in self {
            if isInFirstPartition(el) {
                first.append(el)
            } else {
                second.append(el)
            }
        }
        return first + second
    }
}

#Preview {
    ContentView()
}
