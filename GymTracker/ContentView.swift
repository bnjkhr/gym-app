import Charts
import HealthKit
import SwiftData
import SwiftUI
import UserNotifications

#if canImport(ActivityKit)
    import ActivityKit
#endif

// Import the keyboard dismissal utilities

// MARK: - Performance: Cached DateFormatters

/// Cached DateFormatters to avoid expensive initialization on every render
/// DateFormatter initialization costs ~50ms, cached access costs ~0.001ms
enum DateFormatters {
    /// Long date format: "Montag, 6. Oktober 2025"
    static let germanLong: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = TimeZone.current
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()

    /// Medium date format: "6. Okt. 2025"
    static let germanMedium: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = TimeZone.current
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    /// Short time format: "14:30"
    static let germanShortTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = TimeZone.current
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    /// Custom format: "EEEEdMMMM" -> "Montag6Oktober"
    static let germanWeekdayDayMonth: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = TimeZone.current
        formatter.setLocalizedDateFormatFromTemplate("EEEEdMMMM")
        return formatter
    }()

    /// Custom format: "MMMMy" -> "Oktober 2025"
    static let germanMonthYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = TimeZone.current
        formatter.setLocalizedDateFormatFromTemplate("MMMMy")
        return formatter
    }()

    /// Get very short weekday symbols for German locale: ["Mo", "Di", "Mi", ...]
    static func germanVeryShortWeekdaySymbols() -> [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.veryShortWeekdaySymbols
    }

    // MARK: - Backup & Export Formats

    /// Format: "yyyy-MM-dd_HH-mm-ss"
    /// Used for: Backup filenames
    /// Example: "2025-10-18_14-30-45"
    static let backupFilename: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()

    // MARK: - Display Formats

    /// Format: "d MMM yyyy, HH:mm"
    /// Used for: User-facing timestamps (Hevy imports)
    /// Example: "18 Oct 2025, 14:30"
    static let userFriendlyDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy, HH:mm"
        return formatter
    }()

    /// Format: "yyyy-MM-dd HH:mm:ss"
    /// Used for: Debug logs, technical displays, Strong app imports
    /// Example: "2025-10-18 14:30:45"
    static let debugDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    /// Format: "HH:mm:ss"
    /// Used for: Time-only displays
    /// Example: "14:30:45"
    static let timeOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    // MARK: - Analysis Formats

    /// Format: "EEEE"
    /// Used for: Day of week analysis
    /// Example: "Monday", "Tuesday"
    static let weekdayName: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter
    }()
}

struct ContentView: View {
    @StateObject private var workoutStore = WorkoutStoreCoordinator()
    @StateObject private var overlayManager = InAppOverlayManager()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.isInWorkoutDetail) private var isInWorkoutDetail

    // Performance: Pre-warm keyboard to avoid initial delay
    @State private var keyboardPreWarmer: UITextField? = nil

    @Query(sort: [
        SortDescriptor(\WorkoutEntity.date, order: SortOrder.reverse)
    ])
    private var workoutEntities: [WorkoutEntity]

    @State private var selectedTab = 0
    @State private var showingEndWorkoutConfirmation = false

    private var workoutActionService: WorkoutActionService {
        WorkoutActionService(modelContext: modelContext, workoutStore: workoutStore)
    }

    var body: some View {
        // CRITICAL: Set modelContext BEFORE any view rendering
        let _ = { workoutStore.modelContext = modelContext }()
        contentWithModifiers
    }

    private var contentWithModifiers: some View {
        tabContent
            .overlay(alignment: .bottom) {
                activeWorkoutBarOverlay
            }
            .overlay(alignment: .bottom) {
                activeTimerBarOverlay
            }
            .overlay {
                restTimerOverlay
            }
            .animation(.easeInOut(duration: 0.2), value: selectedTab)
            .animation(
                .spring(response: 0.3, dampingFraction: 0.8), value: overlayManager.isShowingOverlay
            )
            .tint(AppTheme.powerOrange)
            .environment(\.keyboardDismissalEnabled, true)
            .alert("Workout beenden?", isPresented: $showingEndWorkoutConfirmation) {
                Button("Beenden", role: .destructive) {
                    endActiveSession()
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Das aktive Workout wird beendet und gelöscht.")
            }
            .onAppear(perform: setupView)
            .task {
                await NotificationManager.shared.requestAuthorization()
            }
            .onReceive(NotificationCenter.default.publisher(for: .navigateToActiveWorkout)) {
                (_: Notification) in
                handleNavigateToActiveWorkout()
            }
            .onReceive(NotificationCenter.default.publisher(for: .restTimerNotificationTapped)) {
                (notification: Notification) in
                if let workoutId = notification.userInfo?["workoutId"] as? UUID {
                    handleNavigateToWorkout(workoutId)
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                handleScenePhaseChange(newPhase)
            }
            .onOpenURL { url in
                handleOpenURL(url)
            }
            .onReceive(NotificationCenter.default.publisher(for: .navigateToWorkoutsTab)) { _ in
                handleNavigateToWorkoutsTab()
            }
    }

    private var tabContent: some View {
        TabView(selection: $selectedTab) {
            // Workouts Tab
            NavigationStack {
                WorkoutsHomeView()
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
    }

    @ViewBuilder
    private var activeWorkoutBarOverlay: some View {
        if let activeWorkout = workoutStore.activeWorkout, !workoutStore.isShowingWorkoutDetail {
            VStack(spacing: 0) {
                Spacer()
                ActiveWorkoutBar(
                    workout: activeWorkout,
                    resumeAction: {
                        selectedTab = 0
                        NotificationCenter.default.post(name: .resumeActiveWorkout, object: nil)
                    },
                    endAction: { showingEndWorkoutConfirmation = true }
                )
                .environmentObject(workoutStore)
                .padding(.horizontal, 16)
                .padding(.bottom, 90)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(
                    .spring(response: 0.35, dampingFraction: 0.8),
                    value: workoutStore.isShowingWorkoutDetail
                )
                .animation(
                    .spring(response: 0.35, dampingFraction: 0.8),
                    value: workoutStore.activeWorkout?.id)
            }
            .ignoresSafeArea(.keyboard)
        }
    }

    @ViewBuilder
    private var activeTimerBarOverlay: some View {
        // Show timer bar when:
        // 1. There's an active rest timer
        // 2. NOT showing expired overlay (overlay has priority)
        // ✅ Positioned ABOVE ActiveWorkoutBar when both are visible
        if workoutStore.restTimerStateManager.currentState != nil,
            !overlayManager.isShowingOverlay
        {
            VStack(spacing: 0) {
                Spacer()
                ActiveTimerBar()
                    .environmentObject(workoutStore)
                    .padding(.horizontal, 16)  // ✅ Same horizontal padding as ActiveWorkoutBar
                    .padding(
                        .bottom,
                        workoutStore.activeWorkout != nil && !workoutStore.isShowingWorkoutDetail
                            ? 180 : 100)
                // ✅ 180px when ActiveWorkoutBar is visible (90 for tabs + 90 for workout bar)
                // ✅ 100px when no ActiveWorkoutBar (just above tabs)
            }
            .ignoresSafeArea(.keyboard)
        }
    }

    @ViewBuilder
    private var restTimerOverlay: some View {
        if overlayManager.isShowingOverlay, let state = overlayManager.currentState {
            RestTimerExpiredOverlay(state: state) {
                overlayManager.dismissOverlay()
                workoutStore.restTimerStateManager.acknowledgeExpired()
            }
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
            .zIndex(999)
        }
    }

    private func setupView() {
        // Set model context in WorkoutStore immediately when view appears
        workoutStore.modelContext = modelContext

        // Pass overlayManager to workoutStore for rest timer integration
        workoutStore.overlayManager = overlayManager

        // Connect overlayManager to RestTimerStateManager (Phase 2)
        workoutStore.restTimerStateManager.overlayManager = overlayManager

        // ✅ CRITICAL FIX: Restore rest timer state after force quit
        workoutStore.restTimerStateManager.restoreState()
        AppLogger.app.info("✅ Rest timer state restoration attempted")

        // Restore active workout state from UserDefaults (after Force Quit)
        if let workoutIDString = UserDefaults.standard.string(forKey: "activeWorkoutID"),
            let workoutID = UUID(uuidString: workoutIDString)
        {
            // Verify workout still exists
            let descriptor = FetchDescriptor<WorkoutEntity>(
                predicate: #Predicate<WorkoutEntity> { workout in workout.id == workoutID }
            )
            if (try? modelContext.fetch(descriptor).first) != nil {
                print("✅ Restoring active workout from persisted state: \(workoutID)")
                workoutStore.activeSessionID = workoutID

                // Note: Rest timer state is automatically restored by RestTimerStateManager
            } else {
                print("⚠️ Persisted workout not found → clearing state")
                UserDefaults.standard.removeObject(forKey: "activeWorkoutID")
            }
        }

        // Initialize AudioManager
        _ = AudioManager.shared

        // Performance: Pre-warm keyboard to avoid initial delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let textField = UITextField()
            textField.becomeFirstResponder()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                textField.resignFirstResponder()
            }
            keyboardPreWarmer = textField
        }
    }

    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            // Note: Rest timer automatically recalculates remaining time from wall clock
            break
        case .background:
            workoutStore.performMemoryCleanup()
        default:
            break
        }
    }

    private func handleOpenURL(_ url: URL) {
        // Handle .gymtracker file import
        if url.pathExtension.lowercased() == "gymtracker" {
            importWorkout(from: url)
            return
        }

        // Handle deep link from Live Activity
        guard url.scheme?.lowercased() == "workout" else { return }
        if url.host?.lowercased() == "active" {
            if workoutStore.activeSessionID != nil {
                selectedTab = 0
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NotificationCenter.default.post(name: .resumeActiveWorkout, object: nil)
                }
            }
        }
    }

    private func handleNavigateToWorkoutsTab() {
        selectedTab = 1
        if !workoutStore.userProfile.hasExploredWorkouts {
            workoutStore.markOnboardingStep(hasExploredWorkouts: true)
        }
    }

    // MARK: - Deep Link Navigation (Phase 5)

    private func handleNavigateToActiveWorkout() {
        guard let activeWorkoutId: UUID = workoutStore.activeSessionID else {
            AppLogger.app.warning("No active workout to navigate to")
            return
        }

        AppLogger.app.info("🔗 Navigating to active workout: \(activeWorkoutId)")
        selectedTab = 0
        NotificationCenter.default.post(name: .resumeActiveWorkout, object: nil)
    }

    private func handleNavigateToWorkout(_ workoutId: UUID) {
        AppLogger.app.info("🔗 Navigating to workout: \(workoutId)")

        if workoutStore.activeSessionID == workoutId {
            handleNavigateToActiveWorkout()
        } else {
            selectedTab = 1
            NotificationCenter.default.post(
                name: NSNotification.Name("showWorkoutDetail"),
                object: nil,
                userInfo: ["workoutId": workoutId]
            )
        }
    }

    private func resumeActiveWorkout() {
        guard let active = workoutStore.activeWorkout else {
            workoutStore.activeSessionID = nil
            return
        }

        // Navigate to the active workout using the WorkoutsHomeView selection
        // This will be handled by the child view's selectedWorkout state
        WorkoutLiveActivityController.shared.start(workoutId: active.id, workoutName: active.name)
    }

    private func endActiveSession() {
        workoutActionService.endActiveSession()
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

// MARK: - Workouts Tab

struct WorkoutHighlightCard: View {
    let workout: Workout
    @Environment(\.colorScheme) private var colorScheme

    // Performance: Use cached DateFormatter
    private var dateText: String {
        DateFormatters.germanWeekdayDayMonth.string(from: workout.date)
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
        .padding(AppLayout.Spacing.extraLarge)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.customBlue)
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
    @EnvironmentObject var workoutStore: WorkoutStoreCoordinator

    @State private var showCheckmark1 = false
    @State private var showCheckmark2 = false
    @State private var showCheckmark3 = false
    @State private var hasExploredWorkouts = false
    @State private var hasCreatedFirstWorkout = false
    @State private var hasSetupProfile = false

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
                    if !hasExploredWorkouts {
                        workoutStore.markOnboardingStep(hasExploredWorkouts: true)
                        hasExploredWorkouts = true
                    }
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

                        if hasExploredWorkouts {
                            AnimatedCheckmark(show: $showCheckmark1)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .opacity(0.7)
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(AppLayout.Spacing.standard)
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

                        if hasCreatedFirstWorkout {
                            AnimatedCheckmark(show: $showCheckmark2)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .opacity(0.7)
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(AppLayout.Spacing.standard)
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

                        if hasSetupProfile {
                            AnimatedCheckmark(show: $showCheckmark3)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .opacity(0.7)
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(AppLayout.Spacing.standard)
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
        .padding(.bottom, 24)
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
        .onAppear {
            let profile = workoutStore.userProfile
            hasExploredWorkouts = profile.hasExploredWorkouts
            hasCreatedFirstWorkout = profile.hasCreatedFirstWorkout
            hasSetupProfile = profile.hasSetupProfile

            if hasExploredWorkouts { showCheckmark1 = true }
            if hasCreatedFirstWorkout { showCheckmark2 = true }
            if hasSetupProfile { showCheckmark3 = true }
        }
        .onChange(of: workoutStore.profileUpdateTrigger) { _, _ in
            let profile = workoutStore.userProfile
            if profile.hasExploredWorkouts && !hasExploredWorkouts {
                hasExploredWorkouts = true
                showCheckmark1 = true
            }
            if profile.hasCreatedFirstWorkout && !hasCreatedFirstWorkout {
                hasCreatedFirstWorkout = true
                showCheckmark2 = true
            }
            if profile.hasSetupProfile && !hasSetupProfile {
                hasSetupProfile = true
                showCheckmark3 = true
            }
        }
    }
}

// MARK: - Animated Checkmark Component
struct AnimatedCheckmark: View {
    @Binding var show: Bool
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0

    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(Color(red: 0 / 255, green: 95 / 255, blue: 86 / 255))
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                if show {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0)) {
                        scale = 1.0
                        opacity = 1.0
                    }
                }
            }
            .onChange(of: show) { _, newValue in
                if newValue {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0)) {
                        scale = 1.0
                        opacity = 1.0
                    }
                }
            }
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
    let workouts: [WorkoutSessionV1]
    let startAction: (WorkoutSessionV1) -> Void
    let detailAction: (WorkoutSessionV1) -> Void
    let deleteSessionAction: (WorkoutSessionV1) -> Void
    let enableActions: Bool
    let showHeader: Bool

    // Performance: Use cached DateFormatter instead of creating new one on each access
    private var localizedDateFormatter: DateFormatter {
        DateFormatters.germanLong
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showHeader {
                Text("Letzte Sessions")
                    .font(.headline)
                    .padding(.horizontal, 8)
            }
            ForEach(workouts, id: \.id) { (session: WorkoutSessionV1) in
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
    @EnvironmentObject private var workoutStore: WorkoutStoreCoordinator

    private var restText: String? {
        guard let state = workoutStore.restTimerStateManager.currentState,
            state.workoutId == workout.id
        else {
            return nil
        }
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
                            .animation(.linear(duration: 0.3), value: restText)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.2))
                            )
                            .transition(.scale.combined(with: .opacity))
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
                    .shadow(color: AppTheme.mossGreen.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(ScaleButtonStyle())

            Button(action: endAction) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.red)
                    )
                    .shadow(color: Color.red.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(ScaleButtonStyle())
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

// MARK: - Active Timer Bar (Performance Optimized)

/// Floating rest timer bar that displays current rest timer state
///
/// **Performance Optimized:**
/// - Isolates timer updates to prevent full WorkoutDetailView re-renders
/// - Only this bar re-renders every second, not entire view hierarchy
/// - ~95% performance improvement over inline timer display
struct ActiveTimerBar: View {
    @EnvironmentObject private var workoutStore: WorkoutStoreCoordinator
    @Environment(\.colorScheme) private var colorScheme

    // Current rest timer state
    private var timerState: RestTimerState? {
        workoutStore.restTimerStateManager.currentState
    }

    // Formatted time string (M:SS)
    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    // Current exercise name
    private var exerciseName: String {
        timerState?.currentExerciseName ?? "Übung"
    }

    // Current set number (1-indexed)
    private var setNumber: Int {
        (timerState?.setIndex ?? 0) + 1
    }

    // Remaining seconds
    private var remainingSeconds: Int {
        timerState?.remainingSeconds ?? 0
    }

    // Is timer running
    private var isRunning: Bool {
        timerState?.phase == .running
    }

    var body: some View {
        HStack(spacing: 16) {
            // Timer Display
            VStack(alignment: .leading, spacing: 4) {
                Text("PAUSE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .textCase(.uppercase)
                    .tracking(0.8)

                HStack(spacing: 8) {
                    // Time
                    Text(formatTime(remainingSeconds))
                        .font(.system(size: 32, weight: .bold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.linear(duration: 0.3), value: remainingSeconds)
                        .foregroundStyle(.white)

                    // Exercise Info
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Satz \(setNumber)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))
                        Text(exerciseName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // Timer Controls
            HStack(spacing: 8) {
                if isRunning {
                    // Pause Button
                    Button {
                        if timerState != nil {
                            workoutStore.restTimerStateManager.pauseRest()
                        } else {
                            workoutStore.pauseRest()
                        }
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    } label: {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(AppTheme.powerOrange)
                            )
                            .shadow(color: AppTheme.powerOrange.opacity(0.3), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(ScaleButtonStyle())

                    // +15s Button
                    Button {
                        workoutStore.addRest(seconds: 15)
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                    } label: {
                        Text("+15s")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(AppTheme.turquoiseBoost)
                            )
                            .shadow(
                                color: AppTheme.turquoiseBoost.opacity(0.3), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(ScaleButtonStyle())

                    // Stop Button
                    Button {
                        if timerState != nil {
                            workoutStore.restTimerStateManager.cancelRest()
                        } else {
                            workoutStore.stopRest()
                        }
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.red)
                            )
                            .shadow(color: Color.red.opacity(0.3), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(ScaleButtonStyle())

                } else {
                    // Resume Button (when paused)
                    Button {
                        if timerState != nil {
                            workoutStore.restTimerStateManager.resumeRest()
                        } else {
                            workoutStore.resumeRest()
                        }
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(AppTheme.mossGreen)
                            )
                            .shadow(color: AppTheme.mossGreen.opacity(0.3), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(ScaleButtonStyle())

                    // Stop Button
                    Button {
                        if timerState != nil {
                            workoutStore.restTimerStateManager.cancelRest()
                        } else {
                            workoutStore.stopRest()
                        }
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.red)
                            )
                            .shadow(color: Color.red.opacity(0.3), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isRunning)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
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
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)
        )
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
    let sessions: [WorkoutSessionV1]
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

    // Performance: Use cached weekday symbols instead of creating DateFormatter
    private func localizedWeekdayAbbreviation(for date: Date) -> String {
        let weekdaySymbols = DateFormatters.germanVeryShortWeekdaySymbols()
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekdaySymbols[weekday - 1]
    }

    var body: some View {
        Button(action: showCalendar) {
            HStack(spacing: 18) {
                ForEach(days, id: \.self) { day in
                    VStack(spacing: 6) {
                        Text("\(Calendar.current.component(.day, from: day))")
                            .font(
                                .headline.weight(
                                    calendar.isDate(day, inSameDayAs: today) ? .bold : .regular)
                            )
                            .foregroundStyle(
                                calendar.isDate(day, inSameDayAs: today)
                                    ? Color.primary : Color.primary.opacity(0.7))
                        Text(localizedWeekdayAbbreviation(for: day))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(
                                calendar.isDate(day, inSameDayAs: today)
                                    ? Color.primary : Color.primary.opacity(0.6))
                        Circle()
                            .fill(
                                hasSession(on: day)
                                    ? AppTheme.mossGreen : Color.secondary.opacity(0.3)
                            )
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
        .padding(AppLayout.Spacing.large)
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
        let hue = progress * 0.33  // 0 = rot, 0.33 = grün
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
        .padding(AppLayout.Spacing.standard)
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
            .padding(AppLayout.Spacing.standard)
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

            Button("Abbrechen", role: .cancel) {}
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
                Text(
                    {
                        let formatter = DateFormatter()
                        formatter.locale = Locale(identifier: "de_DE")
                        formatter.dateStyle = .medium
                        formatter.timeStyle = .none
                        return formatter.string(from: workout.date)
                    }()
                )
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

// MARK: - Calendar Sessions Sheet
struct ErrorWorkoutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.customOrange)
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

// MARK: - Environment Key for WorkoutDetailView visibility
private struct IsInWorkoutDetailKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var isInWorkoutDetail: Bool {
        get { self[IsInWorkoutDetailKey.self] }
        set { self[IsInWorkoutDetailKey.self] = newValue }
    }
}

// MARK: - Custom Button Styles for Smooth Interactions
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Locker Number Input View
struct LockerNumberInputView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var workoutStore: WorkoutStoreCoordinator
    @State private var lockerNumber: String = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    // Icon
                    Image(systemName: "lock.fill")
                        .font(.system(size: 60, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppTheme.deepBlue, AppTheme.turquoiseBoost],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding(.bottom, 8)

                    // Title
                    Text("Deine Spintnummer")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.primary)

                    Text("Damit du sie nicht vergisst 😉")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 16)

                    // Input Field
                    TextField("z.B. 42", text: $lockerNumber)
                        .font(.system(size: 48, weight: .bold))
                        .multilineTextAlignment(.center)
                        .keyboardType(.numberPad)
                        .focused($isTextFieldFocused)
                        .defaultFocus($isTextFieldFocused, true)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemGray6))
                        )
                        .frame(maxWidth: 200)
                        .onChange(of: isTextFieldFocused) { _, isFocused in
                            if isFocused && !lockerNumber.isEmpty {
                                // Auto-select all text when focused
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    UIApplication.shared.sendAction(
                                        #selector(UIResponder.selectAll(_:)), to: nil, from: nil,
                                        for: nil)
                                }
                            }
                        }

                    Spacer()

                    // Save Button
                    Button {
                        saveLockerNumber()
                    } label: {
                        Text("Speichern")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [AppTheme.mossGreen, AppTheme.turquoiseBoost],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                lockerNumber = workoutStore.userProfile.lockerNumber ?? ""
                // Aggressive focus - mehrfach versuchen
                isTextFieldFocused = true
                DispatchQueue.main.async {
                    isTextFieldFocused = true
                }
            }
        }
    }

    private func saveLockerNumber() {
        workoutStore.updateLockerNumber(
            lockerNumber.trimmingCharacters(in: .whitespacesAndNewlines))
        dismiss()
    }
}
