import SwiftUI
import Charts
import UserNotifications
import SwiftData
import HealthKit
#if canImport(ActivityKit)
import ActivityKit
#endif

// Import the keyboard dismissal utilities

struct ContentView: View {
    @StateObject private var workoutStore = WorkoutStore()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: [
        SortDescriptor(\WorkoutEntity.date, order: SortOrder.reverse)
    ])
    private var workoutEntities: [WorkoutEntity]

    var body: some View {
        TabView {
            // Workouts Tab
            NavigationStack {
                WorkoutsHomeView()
                    .environmentObject(workoutStore)
                    .safeAreaInset(edge: .bottom) {
                        if let activeWorkout = workoutStore.activeWorkout {
                            ActiveWorkoutBar(
                                workout: activeWorkout,
                                resumeAction: { 
                                    // Signal the WorkoutsHomeView to navigate to active workout
                                    NotificationCenter.default.post(name: .resumeActiveWorkout, object: nil)
                                },
                                endAction: { endActiveSession() }
                            )
                            .environmentObject(workoutStore)
                            .padding(.horizontal, 16)
                            .padding(Edge.Set.vertical, 12)
                            .padding(.bottom, 6)
                        }
                    }
            }
            .tabItem {
                Image(systemName: "dumbbell")
                Text("Home")
            }

            // Workouts Tab
            NavigationStack {
                WorkoutsTabView()
                    .environmentObject(workoutStore)
            }
            .tabItem {
                Image(systemName: "figure.strengthtraining.functional")
                Text("Workouts")
            }

            // Insights Tab
            NavigationStack {
                StatisticsView()
                    .environmentObject(workoutStore)
            }
            .tabItem {
                Image(systemName: "chart.line.uptrend.xyaxis")
                Text("Insights")
            }
        }
        .tint(colorScheme == .dark ? Color.purple : AppTheme.darkPurple)
        .environment(\.keyboardDismissalEnabled, true)
        .onAppear {
            // Set model context in WorkoutStore immediately when view appears
            workoutStore.modelContext = modelContext
            
            // Initialize AudioManager
            _ = AudioManager.shared
        }
        .task {
            NotificationManager.shared.requestAuthorization()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                workoutStore.refreshRestFromWallClock()
            default:
                break
            }
        }
        .onOpenURL { url in
            // Handle deep link from Live Activity to jump into the active workout
            guard url.scheme?.lowercased() == "workout" else { return }
            if url.host?.lowercased() == "active" {
                if let activeID = workoutStore.activeSessionID {
                    // This will trigger navigation in WorkoutsHomeView when it sees the activeSessionID
                    // Signal the WorkoutsHomeView to navigate to active workout
                    NotificationCenter.default.post(name: .resumeActiveWorkout, object: nil)
                }
            }
        }
    }

    private func resumeActiveWorkout() {
        guard let active = workoutStore.activeWorkout else {
            workoutStore.activeSessionID = nil
            return
        }
        
        // Navigate to the active workout using the WorkoutsHomeView selection
        // This will be handled by the child view's selectedWorkout state
        WorkoutLiveActivityController.shared.start(workoutName: active.name)
    }
    
    private func endActiveSession() {
        workoutStore.stopRest()
        workoutStore.activeSessionID = nil
        WorkoutLiveActivityController.shared.end()
    }
}

private struct WorkoutSelection: Identifiable, Hashable {
    let id: UUID
}

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Workouts Tab

struct WorkoutsHomeView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @Environment(\.colorScheme) private var colorScheme

    @Environment(\.modelContext) private var modelContext
    @Query(sort: [
        SortDescriptor(\WorkoutEntity.date, order: SortOrder.reverse)
    ])
    private var workoutEntities: [WorkoutEntity]
    
    @Query(sort: [
        SortDescriptor(\WorkoutSessionEntity.date, order: SortOrder.reverse)
    ])
    private var sessionEntities: [WorkoutSessionEntity]

    @State private var showingAddWorkout = false
    @State private var showingWorkoutWizard = false
    @State private var showingManualAdd = false
    @State private var showingSettings = false

    @State private var showingProfileAlert = false
    @State private var showingProfileEditor = false
    @State private var showingCalendar = false

    @State private var selectedWorkout: WorkoutSelection?
    @State private var editingWorkoutSelection: WorkoutSelection?
    @State private var viewingSession: WorkoutSession?
    @State private var missingTemplateName: String?
    @State private var showingMissingTemplateAlert = false

    // Neu: Zustand für Löschbestätigung
    @State private var workoutToDelete: Workout?

    @State private var quickGeneratedWorkout: Workout?
    @State private var quickWorkoutName: String = ""

    @State private var headerHidden: Bool = false
    @State private var lastScrollOffset: CGFloat = 0
    @State private var didSetInitialOffset: Bool = false

    // Explicit initializer to avoid private memberwise init caused by private nested types
    init() {}

    private var timeBasedGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Guten Morgen"
        case 12..<18: return "Guten Tag"
        case 18..<22: return "Guten Abend"
        default: return "Gute Nacht"
        }
    }

    private var weekStart: Date {
        let calendar = Calendar.current
        return calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
    }

    private var workoutsThisWeek: Int {
        displaySessions.filter { $0.date >= weekStart }.count
    }

    private var minutesThisWeek: Int {
        displaySessions
            .filter { $0.date >= weekStart }
            .compactMap { $0.duration }
            .map { Int($0 / 60) }
            .reduce(0, +)
    }

    private func mapExerciseEntity(_ entity: ExerciseEntity) -> Exercise? {
        // Use safe mapping with context to avoid touching potentially invalidated snapshots
        return Exercise(entity: entity, in: modelContext)
    }

    private func mapWorkoutEntity(_ entity: WorkoutEntity) -> Workout? {
        // Use safe mapping with context to avoid touching potentially invalidated snapshots
        return Workout(entity: entity, in: modelContext)
    }

    private var displayWorkouts: [Workout] {
        workoutEntities.compactMap { mapWorkoutEntity($0) }
    }
    
    private var displaySessions: [WorkoutSession] {
        sessionEntities.map { WorkoutSession(entity: $0, in: modelContext) }
    }

    private var sortedWorkouts: [Workout] {
        displayWorkouts
    }

    // Precomputed helpers to reduce type-checking complexity
    private var highlightSession: WorkoutSession? {
        displaySessions.first
    }

    private var storedRoutines: [Workout] {
        displayWorkouts
    }

    private var mainScrollView: AnyView {
        AnyView(
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 20) {
                    headerSection
                    highlightSection(highlightSession: highlightSession)
                    savedWorkoutsSection(storedRoutines: storedRoutines)
                }
                .padding(.horizontal, 16)
            }
            .coordinateSpace(name: "workoutsScroll")
            .transaction { tx in
                tx.animation = nil
            }
            .overlay(
                GeometryReader { geo in
                    Color.clear
                        .preference(
                            key: ScrollOffsetPreferenceKey.self,
                            value: geo.frame(in: .named("workoutsScroll")).minY
                        )
                }
            )
        )
    }

    var body: some View {
        rootView
    }

    private func handleScrollOffsetChange(_ newValue: CGFloat) {
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

    private var rootView: AnyView {
        let baseView = createBaseView()
        let viewWithToolbars = addToolbars(to: baseView)
        let viewWithSheets = addSheets(to: viewWithToolbars)
        let viewWithNavigationDestinations = addNavigationDestinations(to: viewWithSheets)
        let viewWithAlerts = addAlerts(to: viewWithNavigationDestinations)
        
        return AnyView(viewWithAlerts)
    }
    
    private func createBaseView() -> some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            mainScrollView
        }
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { newValue in
            handleScrollOffsetChange(newValue)
        }
    }
    
    private func addToolbars(to view: some View) -> some View {
        view
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                // no SwiftData toggle toolbar item anymore
            }
    }
    
    private func addSheets(to view: some View) -> some View {
        view
            .sheet(isPresented: $showingAddWorkout) {
                createAddWorkoutSheet()
            }
            .sheet(isPresented: $showingProfileEditor) {
                ProfileEditView()
                    .environmentObject(workoutStore)
            }
            .sheet(isPresented: $showingWorkoutWizard) {
                WorkoutWizardView(isManualStart: true)
                    .environmentObject(workoutStore)
            }
            .sheet(isPresented: $showingCalendar) {
                CalendarSessionsView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(workoutStore)
            }
            .sheet(isPresented: $showingManualAdd) {
                AddWorkoutView()
                    .environmentObject(workoutStore)
            }
            .sheet(item: $quickGeneratedWorkout) { workout in
                GeneratedWorkoutPreviewView(
                    workout: workout,
                    workoutName: $quickWorkoutName,
                    usedProfileInfo: true,
                    onSave: {
                        if var w = quickGeneratedWorkout {
                            w.name = quickWorkoutName
                            
                            // Ensure WorkoutStore has ModelContext
                            if workoutStore.modelContext == nil {
                                workoutStore.modelContext = modelContext
                            }
                            
                            // Use WorkoutStore's addWorkout method for consistency
                            workoutStore.addWorkout(w)
                        }
                        quickGeneratedWorkout = nil
                    },
                    onDismiss: { quickGeneratedWorkout = nil }
                )
                .environmentObject(workoutStore)
            }
            .sheet(item: $viewingSession) { session in
                SessionDetailView(session: session)
            }
            .sheet(item: $editingWorkoutSelection) { selection in
                if let entity = workoutEntities.first(where: { $0.id == selection.id }) {
                    EditWorkoutView(entity: entity)
                        .environmentObject(workoutStore)
                } else {
                    Text("Workout konnte nicht geladen werden")
                }
            }
    }
    
    private func addNavigationDestinations(to view: some View) -> some View {
        view
            .navigationDestination(item: $selectedWorkout) { selection in
                // Try to find the entity first in Query
                if let entity = workoutEntities.first(where: { $0.id == selection.id }) {
                    WorkoutDetailView(
                        entity: entity,
                        isActiveSession: workoutStore.activeSessionID == selection.id,
                        onActiveSessionEnd: { 
                            endActiveSession() 
                            // Navigation wird automatisch durch dismiss() gehandhabt
                        }
                    )
                    .environmentObject(workoutStore)
                } else {
                    // Fallback: try direct fetch from modelContext
                    let selectionId = selection.id
                    let descriptor = FetchDescriptor<WorkoutEntity>(
                        predicate: #Predicate<WorkoutEntity> { entity in
                            entity.id == selectionId
                        }
                    )
                    if let entity = try? modelContext.fetch(descriptor).first {
                        WorkoutDetailView(
                            entity: entity,
                            isActiveSession: workoutStore.activeSessionID == selection.id,
                            onActiveSessionEnd: { 
                                endActiveSession() 
                                // Navigation wird automatisch durch dismiss() gehandhabt
                            }
                        )
                        .environmentObject(workoutStore)
                    } else {
                        ErrorWorkoutView()
                    }
                }
            }
            .onReceive(workoutStore.$activeSessionID) { activeID in
                guard let activeID else { return }
                let workoutExists = workoutEntities.contains { $0.id == activeID }
                if !workoutExists {
                    // Try direct fetch before giving up
                    let activeSessionId = activeID
                    let descriptor = FetchDescriptor<WorkoutEntity>(
                        predicate: #Predicate<WorkoutEntity> { entity in
                            entity.id == activeSessionId
                        }
                    )
                    if (try? modelContext.fetch(descriptor).first) == nil {
                        workoutStore.activeSessionID = nil
                        WorkoutLiveActivityController.shared.end()
                    }
                } else {
                    // Auto-navigate to active workout if we don't have a selection yet
                    if selectedWorkout == nil {
                        selectedWorkout = WorkoutSelection(id: activeID)
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .resumeActiveWorkout)) { _ in
                if let activeID = workoutStore.activeSessionID {
                    selectedWorkout = WorkoutSelection(id: activeID)
                    if let entity = workoutEntities.first(where: { $0.id == activeID }) {
                        WorkoutLiveActivityController.shared.start(workoutName: entity.name)
                    }
                }
            }
    }
    
    private func addAlerts(to view: some View) -> some View {
        view
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
            .alert("Bitte lege zuerst ein Profil an", isPresented: $showingProfileAlert) {
                Button("Profil anlegen") { showingProfileEditor = true }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Damit wir dein 1‑Klick‑Workout optimal erstellen können.")
            }
    }
    
    private func createAddWorkoutSheet() -> some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Neues Workout erstellen")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top)

                VStack(spacing: 16) {
                    createWorkoutAssistantButton()
                    createManualWorkoutButton()
                    createQuickWorkoutButton()
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
    
    private func createWorkoutAssistantButton() -> some View {
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
    }
    
    private func createManualWorkoutButton() -> some View {
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
    
    private func createQuickWorkoutButton() -> some View {
        Button {
            let profile = workoutStore.userProfile
            let isProfileMissing = profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && profile.weight == nil && profile.birthDate == nil
            if isProfileMissing {
                showingProfileAlert = true
                return
            }
            let goal = profile.goal
            let freq = max(1, min(workoutStore.weeklyGoal, 7))
            let preferences = WorkoutPreferences(
                experience: profile.experience,
                goal: goal,
                frequency: freq,
                equipment: profile.equipment,
                duration: profile.preferredDuration
            )
            quickGeneratedWorkout = workoutStore.generateWorkout(from: preferences)
            quickWorkoutName = "Mein \(goal.displayName) Workout"
            showingAddWorkout = false
        } label: {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("1-Klick-Workout mit Profil erstellen")
                        .font(.headline)
                        .foregroundColor(.primary)
                    if workoutStore.userProfile.name.isEmpty && workoutStore.userProfile.weight == nil && workoutStore.userProfile.birthDate == nil {
                        Text("Hinweis: Lege zuerst dein Profil an, um optimale Ergebnisse zu erhalten.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    } else {
                        Text("Ziel und Trainingsfrequenz werden aus deinem Profil übernommen.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer()
                Image(systemName: "bolt.badge.a.fill")
                    .font(.title2)
                    .foregroundColor(colorScheme == .dark ? Color.green : Color.mossGreen)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill((colorScheme == .dark ? Color.green : Color.mossGreen).opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke((colorScheme == .dark ? Color.green : Color.mossGreen).opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var headerSection: some View {
        Group {
            // Greeting header at top
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(timeBasedGreeting + ",")
                        .font(.largeTitle)
                        .fontWeight(.heavy)
                        .foregroundStyle(.primary)
                    
                    let trimmedName = workoutStore.userProfile.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedName.isEmpty {
                        Text("\(trimmedName)!")
                            .font(.largeTitle)
                            .fontWeight(.heavy)
                            .foregroundStyle(.primary)
                    } else {
                        Button {
                            showingProfileEditor = true
                        } label: {
                            Text("Name!")
                                .font(.largeTitle)
                                .fontWeight(.heavy)
                                .underline()
                                .foregroundStyle(colorScheme == .dark ? Color.purple : AppTheme.darkPurple)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Spacer()

                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(Color(.systemGray))
                                .shadow(color: Color(.systemGray).opacity(0.3), radius: 8, x: 0, y: 4)
                        )
                        .opacity(0.95)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func highlightSection(highlightSession: WorkoutSession?) -> some View {
        Group {
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
        }
    }

    @ViewBuilder
    private func savedWorkoutsSection(storedRoutines: [Workout]) -> some View {
        Group {
            SectionHeader(title: "Gespeicherte Workouts", subtitle: "Tippe zum Starten oder Bearbeiten")

            if storedRoutines.isEmpty {
                Text("Lege ein neues Workout an, um eine Routine zu speichern.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8)
                    ],
                    spacing: 12
                ) {
                    // Add Workout Button Tile
                    Button {
                        showingAddWorkout = true
                    } label: {
                        VStack(spacing: 12) {
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundStyle(colorScheme == .dark ? Color.green : Color.mossGreen)
                            
                            Text("Neues Workout")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 100)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.secondarySystemBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke((colorScheme == .dark ? Color.green : Color.mossGreen).opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
                                )
                        )
                    }
                    .buttonStyle(.plain)

                    ForEach(sortedWorkouts, id: \.id) { workout in
                        WorkoutTileWithMenu(
                            workout: workout,
                            onStart: { startWorkout(with: workout.id) },
                            onEdit: { editWorkout(id: workout.id) },
                            onDelete: { workoutToDelete = workout }
                        )
                    }
                }
            }
            
            // Progress Bar am Ende der Home-View
            WeeklyProgressCard(workoutsThisWeek: workoutsThisWeek, goal: workoutStore.weeklyGoal)
                .padding(.top, 8)
        }
    }



    private func startWorkout(with id: UUID) {
        // First, make sure the modelContext is saved and synced
        do {
            try modelContext.save()
        } catch {
            // Error handled silently
        }
        
        // Use the WorkoutStore's startSession method which handles the reset logic
        if workoutStore.activeSessionID == id {
            // If already active: just navigate to details
            selectedWorkout = WorkoutSelection(id: id)
            if let entity = workoutEntities.first(where: { $0.id == id }) {
                WorkoutLiveActivityController.shared.start(workoutName: entity.name)
            }
            return
        }
        
        // Start new session
        workoutStore.startSession(for: id)
        if workoutStore.activeSessionID == id {
            selectedWorkout = WorkoutSelection(id: id)
            if let entity = workoutEntities.first(where: { $0.id == id }) {
                WorkoutLiveActivityController.shared.start(workoutName: entity.name)
            }
        } else {
            // Error handled silently
        }
    }

    private func showWorkoutDetails(id: UUID) {
        selectedWorkout = WorkoutSelection(id: id)
        // aktive Session bleibt bestehen
    }

    private func editWorkout(id: UUID) {
        editingWorkoutSelection = WorkoutSelection(id: id)
    }

    private func deleteWorkout(id: UUID) {
        if let entity = workoutEntities.first(where: { $0.id == id }) {
            modelContext.delete(entity)
            try? modelContext.save()
        }
        if selectedWorkout?.id == id { selectedWorkout = nil }
        if workoutStore.activeSessionID == id {
            workoutStore.activeSessionID = nil
            WorkoutLiveActivityController.shared.end()
        }
        if editingWorkoutSelection?.id == id {
            editingWorkoutSelection = nil
        }
    }

    private func removeSession(id: UUID) {
        // Delete from SwiftData history
        if let entity = sessionEntities.first(where: { $0.id == id }) {
            modelContext.delete(entity)
            try? modelContext.save()
        }
        // Clear active session if needed
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
        if let templateId = session.templateId,
           workoutEntities.contains(where: { $0.id == templateId }) {
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
        let formatter = DateFormatter()
        // Always use German for this app
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = TimeZone.current
        formatter.setLocalizedDateFormatFromTemplate("EEEEdMMMM")
        return formatter.string(from: workout.date)
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
                    .foregroundStyle(.white)

                Text(workout.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }

            // Dauer-Chip entfernt, nur noch Anzahl Übungen
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                    Text("\(workout.exercises.count) Übungen")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.2), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            (colorScheme == .dark ? Color.green : Color.mossGreen),
                            (colorScheme == .dark ? Color.purple : AppTheme.darkPurple)
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
            Text("Starte deine Trainingsreise")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)

            Text("Lege Trainings an, beobachte deinen Fortschritt und bleib motiviert mit smarten Insights.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)

            Button(action: action) {
                Label("Erstes Training planen", systemImage: "plus.circle.fill")
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
    
    private var localizedDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        // Always use German for this app
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = TimeZone.current
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showHeader {
                Text("Letzte Sessions")
                    .font(.headline)
                    .padding(.horizontal, 8)
            }
            ForEach(workouts, id: \.id) { (session: WorkoutSession) in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.name)
                            .font(.subheadline.weight(.semibold))
                        Text(localizedDateFormatter.string(from: session.date))
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
                .padding(.horizontal, 16)
            }
        }
// Removed .background modifier as per instructions
//        .background(
//            RoundedRectangle(cornerRadius: 16)
//                .fill(Color(.secondarySystemBackground))
//        )
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
                            .lineLimit(1)
                            .monospacedDigit()
                            .fixedSize(horizontal: true, vertical: false)
                            .minimumScaleFactor(0.8)
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
            .tint(colorScheme == .dark ? Color.green : Color.mossGreen)

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

struct WeekCalendarStrip: View {
    let sessions: [WorkoutSession]
    let showCalendar: () -> Void
    @Environment(\.calendar) private var calendar
    @Environment(\.colorScheme) private var colorScheme

    private var startOfWeek: Date {
        let cal = calendar
        let now = Date()
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        return cal.date(from: comps) ?? now
    }

    private var days: [Date] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
    }

    private func hasSession(on day: Date) -> Bool {
        sessions.contains { calendar.isDate($0.date, inSameDayAs: day) }
    }

    private var today: Date { Date() }
    
    // Deutsche Wochentag-Abkürzungen
    private func localizedWeekdayAbbreviation(for date: Date) -> String {
        let formatter = DateFormatter()
        // Always use German for this app
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }

    var body: some View {
        Button(action: showCalendar) {
            HStack(spacing: 18) {
                ForEach(days, id: \.self) { day in
                    VStack(spacing: 6) {
                        Text("\(Calendar.current.component(.day, from: day))")
                            .font(.headline.weight(calendar.isDate(day, inSameDayAs: today) ? .bold : .regular))
                            .foregroundStyle(calendar.isDate(day, inSameDayAs: today) ? Color.primary : Color.primary.opacity(0.7))
                        Text(localizedWeekdayAbbreviation(for: day))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(calendar.isDate(day, inSameDayAs: today) ? Color.primary : Color.primary.opacity(0.6))
                        Circle()
                            .fill(hasSession(on: day) ? (colorScheme == .dark ? Color.green : Color.mossGreen) : Color.secondary.opacity(0.3))
                            .frame(width: 6, height: 6)
                            .opacity(hasSession(on: day) ? 1 : 0.8)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Kalender öffnen")
    }
}

struct WeeklyProgressCard: View {
    let workoutsThisWeek: Int
    let goal: Int
    @Environment(\.colorScheme) private var colorScheme

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(workoutsThisWeek) / Double(goal), 1.0)
    }

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Wochenfortschritt")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("\(workoutsThisWeek) von \(max(goal, 1)) Trainings abgeschlossen")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
            Spacer()
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.25), lineWidth: 6)
                    .frame(width: 44, height: 44)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(colorScheme == .dark ? Color.green : Color.mossGreen, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 44, height: 44)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

struct WeeklySnapshotCard: View {
    let workoutsThisWeek: Int
    let minutesThisWeek: Int
    let goal: Int
    
    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(workoutsThisWeek) / Double(goal), 1.0)
    }
    
    private var progressColor: Color {
        let hue = progress * 0.33 // 0 = rot, 0.33 = grün
        return Color(hue: hue, saturation: 0.8, brightness: 0.8)
    }

    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Diese Woche")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(workoutsThisWeek) Trainings")
                    .font(.headline)
                Text("\(minutesThisWeek) Minuten")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(spacing: 8) {
                ZStack {
                    // Hintergrund-Ring
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 6)
                        .frame(width: 60, height: 60)
                    
                    // Fortschritts-Ring
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            progressColor,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.6), value: progress)
                    
                    // Zentraler Text
                    VStack(spacing: -2) {
                        Text("\(workoutsThisWeek)")
                            .font(.callout)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                        Text("\(goal)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Text("Ziel")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

struct WorkoutTile: View {
    let workout: Workout
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Text("\(workout.exercises.count) Übungen")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            // Menu dots at bottom right
            HStack {
                Spacer()
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
        )
    }
}

struct WorkoutTileWithMenu: View {
    let workout: Workout
    let onStart: () -> Void
    let onEdit: () -> Void  
    let onDelete: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingActionSheet = false
    
    var body: some View {
        Button {
            showingActionSheet = true
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(workout.name)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text("\(workout.exercises.count) Übungen")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Menu dots at bottom right
                HStack {
                    Spacer()
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .confirmationDialog(
            "Workout-Optionen",
            isPresented: $showingActionSheet,
            titleVisibility: .hidden
        ) {
            Button("Workout starten") {
                onStart()
            }
            
            Button("Bearbeiten") {
                onEdit()
            }
            
            Button("Löschen", role: .destructive) {
                onDelete()
            }
            
            Button("Abbrechen", role: .cancel) { }
        }
    }
}

struct WorkoutRow: View {
    let workout: Workout
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.name)
                    .font(.headline)
                Text({
                    let formatter = DateFormatter()
                    formatter.locale = Locale(identifier: "de_DE")
                    formatter.dateStyle = .medium
                    formatter.timeStyle = .none
                    return formatter.string(from: workout.date)
                }())
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
// Removed .background modifier as per instructions
//        .background(
//            RoundedRectangle(cornerRadius: 12)
//                .fill(Color(.systemBackground))
//                .overlay(
//                    RoundedRectangle(cornerRadius: 12)
//                        .stroke(Color(.systemGray4), lineWidth: 1)
//                )
//        )
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
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.15))
            )
            .foregroundStyle(.white)
            .fixedSize(horizontal: true, vertical: false)
    }
}

// Re-add SessionDetailView to fix missing type
struct SessionDetailView: View {
    let session: WorkoutSession
    
    private var localizedDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        // Always use German for this app
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = TimeZone.current
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

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
                            Text(localizedDateFormatter.string(from: session.date))
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
                    .listRowBackground(Color.clear)

                    Section("Übungen") {
                        ForEach(session.exercises, id: \.id) { ex in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(ex.exercise.name)
                                    .font(.subheadline.weight(.semibold))
                                Text("\(ex.sets.count) Sätze")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Session")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Calendar Sessions Sheet
private struct CalendarSessionsView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(sort: [SortDescriptor(\WorkoutSessionEntity.date, order: .reverse)])
    private var sessionEntities: [WorkoutSessionEntity]

    @State private var displayedMonth: Date = Date()
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())

    private var monthTitle: String {
        let formatter = DateFormatter()
        // Always use German for this app
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = TimeZone.current
        formatter.setLocalizedDateFormatFromTemplate("MMMMy")
        return formatter.string(from: displayedMonth)
    }

    private var daysInMonth: [Date] {
        let cal = Calendar.current
        guard let range = cal.range(of: .day, in: .month, for: displayedMonth),
              let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: displayedMonth)) else { return [] }
        return range.compactMap { day -> Date? in
            cal.date(byAdding: .day, value: day - 1, to: monthStart)
        }
    }

    private var gridDays: [Date?] {
        let cal = Calendar.current
        guard let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: displayedMonth)) else { return [] }
        let weekday = cal.component(.weekday, from: monthStart) // 1=Sun...
        let leading = (weekday + 5) % 7 // convert to Monday=0 leading count
        let leadingPlaceholders: [Date?] = Array(repeating: nil, count: leading)
        return leadingPlaceholders + daysInMonth.map { Optional($0) }
    }

    private var sessionDays: Set<Date> {
        let cal = Calendar.current
        return Set(sessionEntities.map { cal.startOfDay(for: $0.date) })
    }

    private func sessions(on date: Date) -> [WorkoutSession] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let sameDay = sessionEntities.filter { cal.isDate($0.date, inSameDayAs: start) }
        return sameDay.map { WorkoutSession(entity: $0) }.sorted { $0.date > $1.date }
    }
    
    private func localizedWeekdaySymbols() -> [String] {
        let formatter = DateFormatter()
        // Always use German for this app
        formatter.locale = Locale(identifier: "de_DE")
        // Get very short weekday symbols (Mo, Di, Mi, etc.)
        return formatter.veryShortWeekdaySymbols
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                // Header with month navigation
                HStack {
                    Button { displayedMonth = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth } label: {
                        Image(systemName: "chevron.left")
                    }
                    Spacer()
                    Text(monthTitle)
                        .font(.headline)
                    Spacer()
                    Button { displayedMonth = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth } label: {
                        Image(systemName: "chevron.right")
                    }
                }
                .padding(.horizontal, 20)

                // Weekday symbols (localized)
                HStack {
                    ForEach(localizedWeekdaySymbols(), id: \.self) { d in
                        Text(d)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 20)

                // Calendar grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                    ForEach(gridDays.indices, id: \.self) { idx in
                        if let day = gridDays[idx] {
                            let cal = Calendar.current
                            let isToday = cal.isDateInToday(day)
                            let isSelected = cal.isDate(cal.startOfDay(for: day), inSameDayAs: selectedDate)
                            let hasSession = sessionDays.contains(cal.startOfDay(for: day))
                            VStack(spacing: 6) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            isSelected ? Color.mossGreen.opacity(0.25) : (isToday ? Color(.systemGray4) : Color(.systemGray6))
                                        )
                                        .frame(width: 36, height: 36)
                                    Text(String(cal.component(.day, from: day)))
                                        .font(.subheadline.weight(.medium))
                                }
                                Circle()
                                    .fill(AppTheme.darkPurple)
                                    .frame(width: 6, height: 6)
                                    .opacity(hasSession ? 1 : 0)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedDate = cal.startOfDay(for: day)
                            }
                        } else {
                            Color.clear.frame(height: 44)
                        }
                    }
                }
                .padding(.horizontal, 20)

                // Sessions list for selected date
                let daySessions = sessions(on: selectedDate)
                if daySessions.isEmpty {
                    VStack(spacing: 8) {
                        Text("Keine Trainings an diesem Tag")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                } else {
                    List {
                        ForEach(daySessions, id: \.id) { session in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.name)
                                    .font(.subheadline.weight(.semibold))
                                HStack(spacing: 8) {
                                    Text({
                                        let formatter = DateFormatter()
                                        formatter.locale = Locale(identifier: "de_DE")
                                        formatter.timeStyle = .short
                                        formatter.dateStyle = .none
                                        return formatter.string(from: session.date)
                                    }())
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("• \(session.exercises.count) Übungen")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                }

                Spacer(minLength: 0)
            }
            .navigationTitle("Kalender")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Date Helpers
private extension Calendar {
    func isDate(_ date1: Date, inSameDayAs startOfDay: Date) -> Bool {
        isDate(date1, equalTo: startOfDay, toGranularity: .day)
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

private extension View {
    func erasedToAnyView() -> AnyView { AnyView(self) }
}

// MARK: - Error View
struct ErrorWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            Text("Workout nicht verfügbar")
                .font(.headline)
            Text("Das Workout konnte nicht geladen werden.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button("Zurück") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}

extension Notification.Name {
    static let resumeActiveWorkout = Notification.Name("resumeActiveWorkout")
}

