import SwiftUI
import Charts
import UserNotifications
import SwiftData
import HealthKit
#if canImport(ActivityKit)
import ActivityKit
#endif

// Import the keyboard dismissal utilities

// MARK: - ShareSheet for Workout Sharing

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ContentView: View {
    @StateObject private var workoutStore = WorkoutStore()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [
        SortDescriptor(\WorkoutEntity.date, order: SortOrder.reverse)
    ])
    private var workoutEntities: [WorkoutEntity]

    @State private var selectedTab = 0
    @State private var isInWorkoutDetail = false

    var body: some View {
        TabView(selection: $selectedTab) {
            // Workouts Tab
            NavigationStack {
                WorkoutsHomeView(isInWorkoutDetail: $isInWorkoutDetail)
                    .environmentObject(workoutStore)
            }
            .tabItem {
                Image(systemName: "house")
                Text("Home")
            }
            .tag(0)

            // Workouts Tab
            NavigationStack {
                WorkoutsTabView()
                    .environmentObject(workoutStore)
            }
            .tabItem {
                Image(systemName: "dumbbell")
                Text("Workouts")
            }
            .tag(1)

            // Insights Tab
            NavigationStack {
                StatisticsView()
                    .environmentObject(workoutStore)
            }
            .tabItem {
                Image(systemName: "chart.line.uptrend.xyaxis")
                Text("Insights")
            }
            .tag(2)
        }
        .overlay(alignment: .bottom) {
            // ActiveWorkoutBar wird nicht in WorkoutDetailView angezeigt
            if let activeWorkout = workoutStore.activeWorkout, !isInWorkoutDetail {
                VStack(spacing: 0) {
                    Spacer()

                    ActiveWorkoutBar(
                        workout: activeWorkout,
                        resumeAction: {
                            // Switch to Home tab and signal to navigate to active workout
                            selectedTab = 0
                            NotificationCenter.default.post(name: .resumeActiveWorkout, object: nil)
                        },
                        endAction: { endActiveSession() }
                    )
                    .environmentObject(workoutStore)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 90) // Platz für die Tab-Bar
                }
                .ignoresSafeArea(.keyboard)
            }
        }
        .tint(AppTheme.powerOrange)
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
            // Handle .gymtracker file import
            if url.pathExtension.lowercased() == "gymtracker" {
                importWorkout(from: url)
                return
            }

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
        .onReceive(NotificationCenter.default.publisher(for: .navigateToWorkoutsTab)) { _ in
            selectedTab = 1
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

    private func importWorkout(from url: URL) {
        do {
            // JSON-Datei laden
            let shareable = try ShareableWorkout.importFrom(url: url)

            // Übungen aus DB laden
            let descriptor = FetchDescriptor<ExerciseEntity>()
            let exercises = try modelContext.fetch(descriptor)

            // WorkoutEntity erstellen
            let _ = try shareable.toWorkoutEntity(in: modelContext, exerciseEntities: exercises)

            print("✅ Workout '\(shareable.workout.name)' erfolgreich importiert")
        } catch {
            print("❌ Fehler beim Importieren des Workouts: \(error)")
        }
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
    @Binding var isInWorkoutDetail: Bool

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

    @State private var showingSettings = false
    @State private var showingProfileEditor = false
    @State private var showingCalendar = false

    @State private var selectedWorkout: WorkoutSelection?
    @State private var editingWorkoutSelection: WorkoutSelection?
    @State private var viewingSession: WorkoutSession?
    @State private var missingTemplateName: String?
    @State private var showingMissingTemplateAlert = false

    // Neu: Zustand für Löschbestätigung
    @State private var workoutToDelete: Workout?
    @State private var shareItem: ShareItem?
    @State private var showingHomeLimitAlert = false

    @State private var headerHidden: Bool = false
    @State private var lastScrollOffset: CGFloat = 0
    @State private var didSetInitialOffset: Bool = false

    // Explicit initializer to avoid private memberwise init caused by private nested types
    init(isInWorkoutDetail: Binding<Bool>) {
        self._isInWorkoutDetail = isInWorkoutDetail
    }
    
    private func workoutCategory(for workout: Workout) -> String {
        let exerciseNames = workout.exercises.map { $0.exercise.name.lowercased() }
        
        let machineKeywords = ["maschine", "machine", "lat", "press", "curl", "extension", "row"]
        let freeWeightKeywords = ["hantel", "kurzhantel", "langhantel", "dumbbell", "barbell", "squat", "deadlift", "bench"]
        
        let hasMachine = exerciseNames.contains { name in
            machineKeywords.contains { keyword in name.contains(keyword) }
        }
        
        let hasFreeWeight = exerciseNames.contains { name in
            freeWeightKeywords.contains { keyword in name.contains(keyword) }
        }
        
        if hasMachine && hasFreeWeight {
            return "Mixed"
        } else if hasMachine {
            return "Maschinen"
        } else if hasFreeWeight {
            return "Freie Gewichte"
        } else {
            return "Training"
        }
    }

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
    
    private var favoritedWorkouts: [Workout] {
        displayWorkouts.filter { $0.isFavorite }
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
                LazyVStack(spacing: 0) {
                    headerSection
                        .padding(.bottom, 24)

                    highlightSection(highlightSession: highlightSession)

                    if highlightSession != nil {
                        WeeklyProgressCard(workoutsThisWeek: workoutsThisWeek, goal: workoutStore.weeklyGoal)
                            .padding(.top, 24)
                    }

                    favoriteWorkoutsSection(favoritedWorkouts: favoritedWorkouts)
                        .padding(.top, 24)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
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
            Color(.systemBackground)
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
            .sheet(isPresented: $showingProfileEditor) {
                ProfileEditView()
                    .environmentObject(workoutStore)
            }
            .sheet(isPresented: $showingCalendar) {
                CalendarSessionsView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
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
            .sheet(item: $shareItem) { item in
                ShareSheet(activityItems: [item.url])
            }
            .confirmationDialog(
                "Workout löschen?",
                isPresented: Binding(
                    get: { workoutToDelete != nil },
                    set: { if !$0 { workoutToDelete = nil } }
                ),
                presenting: workoutToDelete
            ) { workout in
                Button("Löschen", role: .destructive) {
                    deleteWorkout(id: workout.id)
                    workoutToDelete = nil
                }
                Button("Abbrechen", role: .cancel) {
                    workoutToDelete = nil
                }
            } message: { workout in
                Text("'\(workout.name)' wird unwiderruflich gelöscht.")
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
                    .onAppear { isInWorkoutDetail = true }
                    .onDisappear { isInWorkoutDetail = false }
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
                        .onAppear { isInWorkoutDetail = true }
                        .onDisappear { isInWorkoutDetail = false }
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
            .alert("Home-Favoriten voll", isPresented: $showingHomeLimitAlert) {
                Button("Verstanden") { }
            } message: {
                Text("Du kannst maximal 4 Workouts als Home-Favoriten speichern.\n\nEntferne zuerst ein anderes Workout aus dem Home-Tab, um Platz zu schaffen.")
            }
    }
    
    @ViewBuilder
    private var headerSection: some View {
        Group {
            // Greeting header at top
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    let trimmedName = workoutStore.userProfile.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedName.isEmpty {
                        Text("\(timeBasedGreeting),")
                            .font(.system(size: 32, weight: .semibold, design: .default))
                            .foregroundStyle(.primary)
                        Text("\(trimmedName)!")
                            .font(.system(size: 32, weight: .semibold, design: .default))
                            .foregroundStyle(.primary)
                    } else {
                        Text("\(timeBasedGreeting),")
                            .font(.system(size: 32, weight: .semibold, design: .default))
                            .foregroundStyle(.primary)
                        Button {
                            showingProfileEditor = true
                        } label: {
                            Text("Name!")
                                .font(.system(size: 32, weight: .semibold, design: .default))
                                .underline()
                                .foregroundStyle(AppTheme.powerOrange)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Spacer()

                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(Color(.systemGray5))
                        )
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
        }
    }

    @ViewBuilder
    private func highlightSection(highlightSession: WorkoutSession?) -> some View {
        Group {
            if let session = highlightSession {
                Button {
                    startSession(session)
                } label: {
                    WorkoutHighlightCard(workout: Workout(session: session))
                }
                .buttonStyle(.plain)
            } else {
                OnboardingCard(
                    onNavigateToWorkouts: {
                        // Navigation zum Workouts-Tab wird über ContentView gesteuert
                        NotificationCenter.default.post(name: .navigateToWorkoutsTab, object: nil)
                    },
                    onShowProfile: {
                        showingProfileEditor = true
                    }
                )
            }
        }
    }

    @ViewBuilder
    private func favoriteWorkoutsSection(favoritedWorkouts: [Workout]) -> some View {
        Group {
            if favoritedWorkouts.isEmpty {
                EmptyView()
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    spacing: 12
                ) {
                    ForEach(favoritedWorkouts, id: \.id) { workout in
                        WorkoutTileCard(
                            workout: workout,
                            isHomeFavorite: workout.isFavorite,
                            onTap: { startWorkout(with: workout.id) },
                            onEdit: { editWorkout(id: workout.id) },
                            onStart: { startWorkout(with: workout.id) },
                            onDelete: { workoutToDelete = workout },
                            onToggleHome: { toggleHomeFavorite(workoutID: workout.id) },
                            onDuplicate: { duplicateWorkout(id: workout.id) },
                            onShare: { shareWorkout(id: workout.id) }
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func savedWorkoutsSection(storedRoutines: [Workout]) -> some View {
        Group {
            if storedRoutines.isEmpty {
                VStack(spacing: 12) {
                    Text("Keine Workouts")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)
                    
                    Text("Erstelle dein erstes Workout im Workouts-Tab")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    spacing: 12
                ) {
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

    private func duplicateWorkout(id: UUID) {
        guard let originalEntity = workoutEntities.first(where: { $0.id == id }) else { return }

        // Erstelle neue WorkoutEntity als Kopie
        let duplicatedEntity = WorkoutEntity(
            name: "\(originalEntity.name) (Kopie)",
            date: Date(),
            exercises: [],
            defaultRestTime: originalEntity.defaultRestTime,
            duration: nil,
            notes: originalEntity.notes,
            isFavorite: false, // Nicht als Favorit markieren
            isSampleWorkout: false // Benutzer-Workout
        )

        // Kopiere alle Übungen mit Sets
        for originalWorkoutExercise in originalEntity.exercises {
            let copiedWorkoutExercise = WorkoutExerciseEntity(
                exercise: originalWorkoutExercise.exercise
            )

            // Kopiere alle Sets
            for originalSet in originalWorkoutExercise.sets {
                let copiedSet = ExerciseSetEntity(
                    reps: originalSet.reps,
                    weight: originalSet.weight,
                    restTime: originalSet.restTime,
                    completed: false
                )
                copiedWorkoutExercise.sets.append(copiedSet)
                modelContext.insert(copiedSet)
            }

            duplicatedEntity.exercises.append(copiedWorkoutExercise)
            modelContext.insert(copiedWorkoutExercise)
        }

        // Speichere in SwiftData
        modelContext.insert(duplicatedEntity)
        try? modelContext.save()

        print("✅ Workout '\(originalEntity.name)' erfolgreich dupliziert")
    }

    private func shareWorkout(id: UUID) {
        guard let entity = workoutEntities.first(where: { $0.id == id }) else { return }

        do {
            // Workout in ShareableWorkout konvertieren
            let shareable = ShareableWorkout.from(entity: entity)

            // Als JSON-Datei exportieren
            let fileURL = try shareable.exportToFile()

            // Share-Sheet öffnen
            shareItem = ShareItem(url: fileURL)

            print("✅ Workout '\(entity.name)' bereit zum Teilen")
        } catch {
            print("❌ Fehler beim Exportieren des Workouts: \(error)")
        }
    }

    private func importWorkout(from url: URL) {
        do {
            // JSON-Datei laden
            let shareable = try ShareableWorkout.importFrom(url: url)

            // Übungen aus DB laden
            let descriptor = FetchDescriptor<ExerciseEntity>()
            let exercises = try modelContext.fetch(descriptor)

            // WorkoutEntity erstellen
            let _ = try shareable.toWorkoutEntity(in: modelContext, exerciseEntities: exercises)

            print("✅ Workout '\(shareable.workout.name)' erfolgreich importiert")
        } catch {
            print("❌ Fehler beim Importieren des Workouts: \(error)")
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
    
    private func toggleHomeFavorite(workoutID: UUID) {
        let success = workoutStore.toggleHomeFavorite(workoutID: workoutID)
        if !success {
            showingHomeLimitAlert = true
        } else {
            // Force a UI refresh by saving the context
            // SwiftData @Query should automatically update the UI
            try? modelContext.save()
        }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(dateText.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .tracking(0.5)

                Text(workout.name)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }

            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("\(workout.exercises.count) Übungen")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                        )
                )
                
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 140)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.deepBlue)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
        .accessibilityElement(children: .combine)
    }
}

struct OnboardingCard: View {
    let onNavigateToWorkouts: () -> Void
    let onShowProfile: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text("Willkommen bei GymBo!")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Starte jetzt deine Trainingsreise und erreiche deine Fitnessziele.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                // Button 1: Beispielworkouts
                Button {
                    onNavigateToWorkouts()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "list.bullet.clipboard.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Entdecke Beispielworkouts")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Finde vorgefertigte Trainings im Workouts-Tab")
                                .font(.system(size: 12, weight: .medium))
                                .opacity(0.85)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .opacity(0.7)
                    }
                    .foregroundStyle(.white)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.15))
                    )
                }
                .buttonStyle(.plain)

                // Button 2: Neues Workout erstellen
                Button {
                    onNavigateToWorkouts()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Erstelle dein erstes Workout")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Tippe auf '+' im Workouts-Tab")
                                .font(.system(size: 12, weight: .medium))
                                .opacity(0.85)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .opacity(0.7)
                    }
                    .foregroundStyle(.white)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.15))
                    )
                }
                .buttonStyle(.plain)

                // Button 3: Profil einrichten
                Button {
                    onShowProfile()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Richte dein Profil ein")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Personalisiere deine Trainingserfahrung")
                                .font(.system(size: 12, weight: .medium))
                                .opacity(0.85)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .opacity(0.7)
                    }
                    .foregroundStyle(.white)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.15))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppTheme.mossGreen, AppTheme.turquoiseBoost],
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
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Aktives Workout")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .textCase(.uppercase)
                    .tracking(0.5)
                HStack(spacing: 10) {
                    Text(workout.name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if let rest = restText {
                        Label(rest, systemImage: "timer")
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                            .monospacedDigit()
                            .fixedSize(horizontal: true, vertical: false)
                            .minimumScaleFactor(0.8)
                            .contentTransition(.numericText())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.2))
                            )
                    }
                }
            }
            Spacer()
            Button(action: resumeAction) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(AppTheme.mossGreen)
                    )
            }
            .buttonStyle(.plain)

            Button(action: endAction) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.15))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppTheme.deepBlue, AppTheme.darkPurple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)
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
                            .fill(hasSession(on: day) ? AppTheme.mossGreen : Color.secondary.opacity(0.3))
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
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Wochenfortschritt")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                
                Text("\(workoutsThisWeek) von \(max(goal, 1)) Trainings")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
                
                Text("abgeschlossen")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
            }
            
            Spacer()
            
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 4)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        Color.white,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 50, height: 50)
                    .animation(.easeInOut(duration: 1.0), value: progress)
                
                Text("\(workoutsThisWeek)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
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
    
    private func workoutCategory(for workout: Workout) -> String {
        let exerciseNames = workout.exercises.map { $0.exercise.name.lowercased() }
        
        let machineKeywords = ["maschine", "machine", "lat", "press", "curl", "extension", "row"]
        let freeWeightKeywords = ["hantel", "kurzhantel", "langhantel", "dumbbell", "barbell", "squat", "deadlift", "bench"]
        
        let hasMachine = exerciseNames.contains { name in
            machineKeywords.contains { keyword in name.contains(keyword) }
        }
        
        let hasFreeWeight = exerciseNames.contains { name in
            freeWeightKeywords.contains { keyword in name.contains(keyword) }
        }
        
        if hasMachine && hasFreeWeight {
            return "Mixed"
        } else if hasMachine {
            return "Maschinen"
        } else if hasFreeWeight {
            return "Freie Gewichte"
        } else {
            return "Training"
        }
    }
    
    var body: some View {
        Button {
            onStart()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(workoutCategory(for: workout))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                HStack {
                    Text("\(workout.exercises.count) Übungen")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Button {
                        showingActionSheet = true
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.tertiary)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
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
        .buttonStyle(.plain)
        .confirmationDialog(
            "Workout-Optionen",
            isPresented: $showingActionSheet,
            titleVisibility: .hidden
        ) {
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
                                            isSelected ? AppTheme.mossGreen.opacity(0.25) : (isToday ? Color(.systemGray4) : Color(.systemGray6))
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
    static let navigateToWorkoutsTab = Notification.Name("navigateToWorkoutsTab")
}

