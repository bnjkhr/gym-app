import SwiftData
import SwiftUI

// MARK: - Supporting Types

/// UIKit Share Sheet Wrapper für Workout-Export
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// Wrapper für Share Sheet mit Workout-Export
struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

/// PreferenceKey für Scroll-Offset Tracking (Header auto-hide)
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - WorkoutsHomeView

/// Die Hauptansicht des Home-Tabs mit Workout-Dashboard und Management.
///
/// Diese View ist Teil der ContentView-Modularisierung (Phase 3).
/// Sie stellt das komplette Dashboard mit aktiven Workouts, Kalender,
/// Statistiken und Workout-Grid dar.
///
/// **Verantwortlichkeiten:**
/// - Workout-Liste mit Favoriten und Kategorien
/// - Aktives Workout Display (Active Workout Bar)
/// - Wochenkalender-Streifen
/// - Wochenstatistiken (Workouts, Minuten)
/// - Workout-Management (Start, Edit, Delete, Duplicate, Share)
/// - Navigation zu Settings, Profile, Calendar
/// - Onboarding für neue User
///
/// **Struktur:**
/// - Header mit Greeting + Actions
/// - Active Workout Bar (falls aktiv)
/// - Week Calendar Strip
/// - Weekly Stats Cards
/// - Workout Grid (Favoriten + Alle)
/// - Onboarding Card (bei Bedarf)
///
/// **Performance:**
/// - @Query für Workouts und Sessions
/// - Cached mapped entities
/// - Header auto-hide beim Scrollen
/// - LazyVGrid für Workout-Tiles
///
/// **Navigation:**
/// - Settings Sheet
/// - Profile Editor Sheet
/// - Calendar Sheet
/// - Workout Detail (via selectedWorkout)
/// - Session Detail (via viewingSession)
///
/// **Verwendung:**
/// ```swift
/// WorkoutsHomeView()
///     .environmentObject(workoutStore)
///     .environment(\.modelContext, modelContext)
/// ```
///
/// - Version: 1.0
/// - SeeAlso: `ContentView`, `WorkoutHighlightCard`, `WeekCalendarStrip`

struct WorkoutsHomeView: View {
    @EnvironmentObject var workoutStore: WorkoutStoreCoordinator
    @Environment(\.colorScheme) private var colorScheme

    @Environment(\.modelContext) private var modelContext
    @Query(sort: [
        SortDescriptor(\WorkoutEntity.date, order: SortOrder.reverse)
    ])
    private var workoutEntities: [WorkoutEntity]

    @Query(sort: [
        SortDescriptor(\WorkoutSessionEntity.date, order: SortOrder.reverse)
    ])
    private var sessionEntities: [WorkoutSessionEntityV1]

    @State private var showingSettings = false
    @State private var showingProfileEditor = false
    @State private var showingCalendar = false
    @State private var showingLockerNumberInput = false

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

    // Performance: Cache mapped entities to avoid re-mapping on every render
    @State private var cachedWorkouts: [Workout] = []
    @State private var cachedSessions: [WorkoutSession] = []

    private var workoutActionService: WorkoutActionService {
        WorkoutActionService(modelContext: modelContext, workoutStore: workoutStore)
    }

    private func workoutCategory(for workout: Workout) -> String {
        let exerciseNames = workout.exercises.map { $0.exercise.name.lowercased() }

        let machineKeywords = ["maschine", "machine", "lat", "press", "curl", "extension", "row"]
        let freeWeightKeywords = [
            "hantel", "kurzhantel", "langhantel", "dumbbell", "barbell", "squat", "deadlift",
            "bench",
        ]

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
        return calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))
            ?? Date()
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

    // Performance: Use cached values instead of recomputing on every access
    private var displayWorkouts: [Workout] {
        cachedWorkouts
    }

    private var displaySessions: [WorkoutSession] {
        cachedSessions
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
            .fullScreenCover(isPresented: $showingLockerNumberInput) {
                LockerNumberInputView()
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
                    .environment(\.isInWorkoutDetail, true)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            workoutStore.isShowingWorkoutDetail = true
                        }
                    }
                    .onDisappear {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            workoutStore.isShowingWorkoutDetail = false
                        }
                    }
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
                        .environment(\.isInWorkoutDetail, true)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                workoutStore.isShowingWorkoutDetail = true
                            }
                        }
                        .onDisappear {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                workoutStore.isShowingWorkoutDetail = false
                            }
                        }
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
                }
                // Removed auto-navigation - user must explicitly tap ActiveWorkoutBar to resume
            }
            .onReceive(NotificationCenter.default.publisher(for: .resumeActiveWorkout)) { _ in
                if let activeID = workoutStore.activeSessionID {
                    selectedWorkout = WorkoutSelection(id: activeID)
                    if let entity = workoutEntities.first(where: { $0.id == activeID }) {
                        WorkoutLiveActivityController.shared.start(
                            workoutId: entity.id, workoutName: entity.name)
                    }
                }
            }
    }

    private func addAlerts(to view: some View) -> some View {
        view
            .alert(
                "Wirklich löschen?",
                isPresented: Binding(
                    get: { workoutToDelete != nil },
                    set: { if !$0 { workoutToDelete = nil } }
                )
            ) {
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
            .alert(
                "Vorlage nicht gefunden", isPresented: $showingMissingTemplateAlert,
                presenting: missingTemplateName
            ) { _ in
                Button("OK", role: .cancel) { missingTemplateName = nil }
            } message: { name in
                Text("Für die Session \(name) existiert keine gespeicherte Vorlage mehr.")
            }
            .alert("Home-Favoriten voll", isPresented: $showingHomeLimitAlert) {
                Button("Verstanden") {}
            } message: {
                Text(
                    "Du kannst maximal 4 Workouts als Home-Favoriten speichern.\n\nEntferne zuerst ein anderes Workout aus dem Home-Tab, um Platz zu schaffen."
                )
            }
            // Performance: Update cache only when entities change
            .onChange(of: workoutEntities) { _, newEntities in
                updateWorkoutCache(newEntities)
            }
            .onChange(of: sessionEntities) { _, newEntities in
                updateSessionCache(newEntities)
            }
            .onAppear {
                // Initial cache population
                updateWorkoutCache(workoutEntities)
                updateSessionCache(sessionEntities)
            }
    }

    @ViewBuilder
    private var headerSection: some View {
        Group {
            // Greeting header at top
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    let trimmedName = workoutStore.userProfile.name.trimmingCharacters(
                        in: .whitespacesAndNewlines)
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

                // Locker Number Badge
                Button {
                    showingLockerNumberInput = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14, weight: .semibold))
                        if let lockerNumber = workoutStore.userProfile.lockerNumber,
                            !lockerNumber.isEmpty
                        {
                            Text(lockerNumber)
                                .font(.system(size: 14, weight: .bold))
                                .monospacedDigit()
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.customBlue)
                    )
                }
                .buttonStyle(.plain)

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
                    viewSession(session)
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
                // Performance: Explicit ID for better grid item recycling
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
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
                        .id(workout.id)  // Performance: Explicit ID for optimal recycling
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
                        GridItem(.flexible(), spacing: 12),
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
                WorkoutLiveActivityController.shared.start(
                    workoutId: entity.id, workoutName: entity.name)
            }
            return
        }

        // Start new session
        workoutStore.startSession(for: id)
        if workoutStore.activeSessionID == id {
            selectedWorkout = WorkoutSelection(id: id)
            if let entity = workoutEntities.first(where: { $0.id == id }) {
                WorkoutLiveActivityController.shared.start(
                    workoutId: entity.id, workoutName: entity.name)
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
        do {
            _ = try workoutActionService.deleteWorkout(id: id, in: Array(workoutEntities))
        } catch {
            print("❌ Fehler beim Löschen des Workouts: \(error)")
        }
        if selectedWorkout?.id == id { selectedWorkout = nil }
        if editingWorkoutSelection?.id == id {
            editingWorkoutSelection = nil
        }
    }

    private func duplicateWorkout(id: UUID) {
        do {
            try workoutActionService.duplicateWorkout(id: id, in: Array(workoutEntities))
            print("✅ Workout erfolgreich dupliziert")
        } catch {
            print("❌ Fehler beim Duplizieren des Workouts: \(error)")
        }
    }

    private func shareWorkout(id: UUID) {
        do {
            let fileURL = try workoutActionService.shareWorkout(id: id, in: Array(workoutEntities))
            shareItem = ShareItem(url: fileURL)
            print("✅ Workout bereit zum Teilen")
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
            workoutEntities.contains(where: { $0.id == templateId })
        {
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
        workoutActionService.endActiveSession()
    }

    private func toggleHomeFavorite(workoutID: UUID) {
        let success = workoutStore.toggleHomeFavorite(workoutID: workoutID)
        if !success {
            showingHomeLimitAlert = true
        } else {
            // Force a UI refresh by processing changes and refreshing the cache
            modelContext.processPendingChanges()
            try? modelContext.save()
            // Update cache immediately to trigger UI refresh
            updateWorkoutCache(workoutEntities)
        }
    }

    // MARK: - Performance Optimization: Cache Management

    /// Updates the workout cache by mapping entities to domain models
    /// Only called when workoutEntities actually change, not on every render
    private func updateWorkoutCache(_ entities: [WorkoutEntity]) {
        cachedWorkouts = entities.compactMap { mapWorkoutEntity($0) }
    }

    /// Updates the session cache by mapping entities to domain models
    /// Only called when sessionEntities actually change, not on every render
    private func updateSessionCache(_ entities: [WorkoutSessionEntityV1]) {
        cachedSessions = entities.map { WorkoutSession(entity: $0, in: modelContext) }
    }
}
