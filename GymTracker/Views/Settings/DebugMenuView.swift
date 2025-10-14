import SwiftUI

/// Phase 6: Debug Menu für Entwickler - nur in Debug Builds verfügbar
#if DEBUG
    struct DebugMenuView: View {
        @EnvironmentObject var workoutStore: WorkoutStore
        @Environment(\.dismiss) private var dismiss
        @Environment(\.colorScheme) private var colorScheme

        @State private var showingStateClearConfirmation = false
        @State private var alertMessage: String?
        @State private var showingAlert = false

        // State Inspector
        private var currentState: RestTimerState? {
            workoutStore.restTimerStateManager.currentState
        }

        var body: some View {
            NavigationStack {
                ZStack {
                    AppTheme.background
                        .ignoresSafeArea()

                    List {
                        // Test Actions
                        Section {
                            Button {
                                testInAppOverlay()
                            } label: {
                                HStack {
                                    Image(systemName: "app.badge")
                                        .foregroundStyle(AppTheme.powerOrange)
                                    Text("Test In-App Overlay")
                                }
                            }

                            Button {
                                testPushNotification()
                            } label: {
                                HStack {
                                    Image(systemName: "bell.fill")
                                        .foregroundStyle(AppTheme.deepBlue)
                                    Text("Test Push Notification")
                                }
                            }

                            if #available(iOS 16.1, *) {
                                Button {
                                    testLiveActivity()
                                } label: {
                                    HStack {
                                        Image(systemName: "dot.radiowaves.left.and.right")
                                            .foregroundStyle(AppTheme.turquoiseBoost)
                                        Text("Test Live Activity")
                                    }
                                }
                            }

                            Button {
                                testFullFlow()
                            } label: {
                                HStack {
                                    Image(systemName: "play.circle.fill")
                                        .foregroundStyle(AppTheme.mossGreen)
                                    Text("Test Vollständiger Ablauf (5s)")
                                }
                            }
                        } header: {
                            Text("Notifications testen")
                        }

                        // State Inspector
                        Section {
                            if let state = currentState {
                                LabeledContent("Phase", value: state.phase.rawValue.capitalized)
                                LabeledContent("Workout", value: state.workoutName)
                                LabeledContent("Übung Index", value: "\(state.exerciseIndex)")
                                LabeledContent("Satz Index", value: "\(state.setIndex)")
                                LabeledContent("Verbleibend", value: "\(state.remainingSeconds)s")
                                LabeledContent("Total", value: "\(state.totalSeconds)s")
                                LabeledContent("Ist Aktiv", value: state.isActive ? "Ja" : "Nein")
                                LabeledContent(
                                    "Ist Abgelaufen", value: state.hasExpired ? "Ja" : "Nein")

                                if let currentExercise = state.currentExerciseName {
                                    LabeledContent("Aktuelle Übung", value: currentExercise)
                                }
                                if let nextExercise = state.nextExerciseName {
                                    LabeledContent("Nächste Übung", value: nextExercise)
                                }
                                if let heartRate = state.currentHeartRate {
                                    LabeledContent("Herzfrequenz", value: "\(heartRate) bpm")
                                }

                                // Date Info
                                LabeledContent("Start", value: formatDate(state.startDate))
                                LabeledContent("Ende", value: formatDate(state.endDate))
                                LabeledContent(
                                    "Letztes Update", value: formatDate(state.lastUpdateDate))
                            } else {
                                Text("Kein aktiver Timer-State")
                                    .foregroundStyle(.secondary)
                            }
                        } header: {
                            Text("State Inspector")
                        }

                        // Notification Manager Info
                        Section {
                            LabeledContent(
                                "Permission",
                                value: NotificationManager.shared.hasNotificationPermission
                                    ? "Erteilt" : "Verweigert"
                            )
                            LabeledContent(
                                "Pending Notifications",
                                value: "\(NotificationManager.shared.pendingNotificationCount)"
                            )
                        } header: {
                            Text("Notification Manager")
                        }

                        // User Preferences
                        Section {
                            LabeledContent(
                                "In-App Overlay",
                                value: boolString(
                                    UserDefaults.standard.bool(forKey: "showInAppOverlay")))
                            LabeledContent(
                                "Push Notifications",
                                value: boolString(
                                    UserDefaults.standard.bool(forKey: "enablePushNotifications")))
                            LabeledContent(
                                "Live Activity",
                                value: boolString(
                                    UserDefaults.standard.bool(forKey: "enableLiveActivity")))
                            LabeledContent(
                                "Sound",
                                value: boolString(
                                    UserDefaults.standard.bool(forKey: "soundEnabled")))
                            LabeledContent(
                                "Haptics",
                                value: boolString(
                                    UserDefaults.standard.bool(forKey: "hapticsEnabled")))
                        } header: {
                            Text("User Preferences (AppStorage)")
                        }

                        // State Actions
                        Section {
                            if currentState != nil {
                                Button(role: .destructive) {
                                    workoutStore.restTimerStateManager.cancelRest()
                                    showAlert("State gelöscht")
                                } label: {
                                    HStack {
                                        Image(systemName: "xmark.circle.fill")
                                        Text("State löschen")
                                    }
                                }
                            }

                            Button(role: .destructive) {
                                showingStateClearConfirmation = true
                            } label: {
                                HStack {
                                    Image(systemName: "trash.fill")
                                    Text("Force Clear State")
                                }
                            }

                            Button {
                                NotificationManager.shared.cancelAllNotifications()
                                showAlert("Alle Notifications gelöscht")
                            } label: {
                                HStack {
                                    Image(systemName: "bell.slash")
                                    Text("Alle Notifications löschen")
                                }
                            }
                        } header: {
                            Text("State Management")
                        } footer: {
                            Text("⚠️ Force Clear löscht auch persistierten State aus UserDefaults")
                        }

                        // System Info
                        Section {
                            LabeledContent("iOS Version", value: UIDevice.current.systemVersion)
                            LabeledContent("Device", value: UIDevice.current.model)
                            LabeledContent(
                                "App Version",
                                value: Bundle.main.infoDictionary?["CFBundleShortVersionString"]
                                    as? String ?? "Unknown")
                            LabeledContent(
                                "Build",
                                value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String
                                    ?? "Unknown")
                        } header: {
                            Text("System Info")
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
                .navigationTitle("Debug Menu")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Fertig") {
                            dismiss()
                        }
                        .foregroundColor(AppTheme.powerOrange)
                    }
                }
            }
            .alert("Confirmation", isPresented: $showingStateClearConfirmation) {
                Button("Abbrechen", role: .cancel) {}
                Button("Löschen", role: .destructive) {
                    forceClearState()
                }
            } message: {
                Text("Möchtest du wirklich den gesamten Timer-State (inkl. UserDefaults) löschen?")
            }
            .alert("Debug Info", isPresented: $showingAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage ?? "")
            }
        }

        // MARK: - Test Functions

        private func testInAppOverlay() {
            // Erstelle Test-State
            let testState = RestTimerState(
                id: UUID(),
                workoutId: UUID(),
                workoutName: "Test Workout",
                exerciseIndex: 0,
                setIndex: 2,
                startDate: Date().addingTimeInterval(-90),
                endDate: Date(),
                totalSeconds: 90,
                phase: .expired,
                lastUpdateDate: Date(),
                currentExerciseName: "Bankdrücken",
                nextExerciseName: "Bizeps Curls",
                currentHeartRate: 142
            )

            // Zeige Overlay
            if let overlayManager = workoutStore.overlayManager {
                overlayManager.showExpiredOverlay(for: testState)
                showAlert("In-App Overlay wurde getriggert")
            } else {
                showAlert("❌ OverlayManager nicht verfügbar")
            }
        }

        private func testPushNotification() {
            Task {
                // Request authorization if needed
                await NotificationManager.shared.requestAuthorization()

                // Schedule immediate test notification
                let content = UNMutableNotificationContent()
                content.title = "Test Notification"
                content.body = "Deine Pause ist vorbei! Weiter geht's! 💪🏼"
                content.sound = .default

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "debug_test_\(UUID().uuidString)",
                    content: content,
                    trigger: trigger
                )

                try? await UNUserNotificationCenter.current().add(request)

                await MainActor.run {
                    showAlert("Push Notification in 1 Sekunde geplant")
                }
            }
        }

        @available(iOS 16.1, *)
        private func testLiveActivity() {
            #if canImport(ActivityKit)
                let testState = RestTimerState(
                    id: UUID(),
                    workoutId: UUID(),
                    workoutName: "Test Workout",
                    exerciseIndex: 0,
                    setIndex: 2,
                    startDate: Date().addingTimeInterval(-60),
                    endDate: Date().addingTimeInterval(30),
                    totalSeconds: 90,
                    phase: .running,
                    lastUpdateDate: Date(),
                    currentExerciseName: "Bankdrücken",
                    nextExerciseName: "Bizeps Curls",
                    currentHeartRate: 138
                )

                WorkoutLiveActivityController.shared.updateForState(testState)
                showAlert("Live Activity aktualisiert")
            #else
                showAlert("ActivityKit nicht verfügbar")
            #endif
        }

        private func testFullFlow() {
            // Erstelle Test-Workout
            let testWorkout = Workout(
                name: "Debug Test Workout",
                exercises: [],
                defaultRestTime: 5,
                notes: "Debug Test"
            )

            // Starte 5-Sekunden Rest
            workoutStore.restTimerStateManager.startRest(
                for: testWorkout,
                exercise: 0,
                set: 2,
                duration: 5,
                currentExerciseName: "Bankdrücken",
                nextExerciseName: "Bizeps Curls"
            )

            showAlert(
                "5-Sekunden Test-Timer gestartet\n\nAlle aktivierten Notifications werden in 5s getriggert"
            )
        }

        private func forceClearState() {
            // Clear RestTimerStateManager
            workoutStore.restTimerStateManager.cancelRest()

            // Clear UserDefaults
            UserDefaults.standard.removeObject(forKey: "restTimerState")

            // Clear all notifications
            NotificationManager.shared.cancelAllNotifications()

            // Clear Live Activity
            if #available(iOS 16.1, *) {
                #if canImport(ActivityKit)
                    Task {
                        await WorkoutLiveActivityController.shared.endAllActivities()
                    }
                #endif
            }

            showAlert("✅ State vollständig gelöscht")
        }

        // MARK: - Helper Functions

        private func showAlert(_ message: String) {
            alertMessage = message
            showingAlert = true
        }

        private func boolString(_ value: Bool) -> String {
            value ? "✅ Aktiviert" : "❌ Deaktiviert"
        }

        private func formatDate(_ date: Date) -> String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            return formatter.string(from: date)
        }
    }

    // MARK: - NotificationManager Extensions for Debug

    extension NotificationManager {
        var pendingNotificationCount: Int {
            var count = 0
            let semaphore = DispatchSemaphore(value: 0)

            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                count = requests.count
                semaphore.signal()
            }

            semaphore.wait()
            return count
        }

        func cancelAllNotifications() {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        }
    }

    // MARK: - Preview

    #Preview {
        DebugMenuView()
            .environmentObject(WorkoutStore())
    }
#endif
