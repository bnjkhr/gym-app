import SwiftUI

/// Phase 6: Erweiterte Notification-Einstellungen für das neue Rest-Timer-System
struct NotificationSettingsView: View {
    @EnvironmentObject var workoutStore: WorkoutStoreCoordinator
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    // User Preferences (AppStorage für Persistierung)
    @AppStorage("showInAppOverlay") private var showInAppOverlay = true
    @AppStorage("enablePushNotifications") private var enablePushNotifications = true
    @AppStorage("enableLiveActivity") private var enableLiveActivity = true
    @AppStorage("soundEnabled") private var soundEnabled = true
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true

    // State für Preview-Testing
    @State private var showingPreview = false
    @State private var previewType: PreviewType = .inAppOverlay

    enum PreviewType {
        case inAppOverlay
        case pushNotification
        case liveActivity
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 20) {
                        // Header Info
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 12) {
                                Image(systemName: "bell.badge.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [AppTheme.powerOrange, AppTheme.deepBlue],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Rest-Timer Benachrichtigungen")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.primary)

                                    Text("Passe an, wie du über Pausenende informiert wirst")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(AppLayout.Spacing.large)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(AppTheme.cardBackground)
                        )
                        .shadow(
                            color: Color(red: 0, green: 0, blue: 0, opacity: 0.05), radius: 8, x: 0,
                            y: 2
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                        // Benachrichtigungs-Typen
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Benachrichtigungs-Arten")
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 20)

                            // In-App Overlay
                            NotificationToggleCard(
                                icon: "app.badge",
                                iconColor: AppTheme.powerOrange,
                                title: "In-App Overlay",
                                description: "Zeigt ein großes Overlay wenn die App aktiv ist",
                                isOn: $showInAppOverlay,
                                badge: "Neu"
                            )
                            .padding(.horizontal, 20)

                            // Push Notifications
                            NotificationToggleCard(
                                icon: "bell.fill",
                                iconColor: AppTheme.deepBlue,
                                title: "Push-Benachrichtigungen",
                                description:
                                    "Sendet eine Benachrichtigung wenn die App im Hintergrund ist",
                                isOn: $enablePushNotifications,
                                showSystemSettings: !NotificationManager.shared
                                    .hasNotificationPermission
                            )
                            .padding(.horizontal, 20)
                            .onChange(of: enablePushNotifications) { _, newValue in
                                if newValue {
                                    Task {
                                        await NotificationManager.shared.requestAuthorization()
                                    }
                                }
                            }

                            // Live Activity (Dynamic Island)
                            if #available(iOS 16.1, *) {
                                NotificationToggleCard(
                                    icon: "dot.radiowaves.left.and.right",
                                    iconColor: AppTheme.turquoiseBoost,
                                    title: "Live Activity",
                                    description:
                                        "Zeigt Timer in Dynamic Island (iPhone 14 Pro+) oder Sperrbildschirm",
                                    isOn: $enableLiveActivity,
                                    badge: "Pro"
                                )
                                .padding(.horizontal, 20)
                            }
                        }

                        // Feedback-Optionen
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Feedback & Sound")
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 20)

                            // Sound
                            NotificationToggleCard(
                                icon: "speaker.wave.3.fill",
                                iconColor: AppTheme.mossGreen,
                                title: "Sound-Effekte",
                                description: "Spielt einen Sound wenn der Timer abläuft",
                                isOn: $soundEnabled
                            )
                            .padding(.horizontal, 20)

                            // Haptic Feedback
                            NotificationToggleCard(
                                icon: "waveform",
                                iconColor: AppTheme.powerOrange,
                                title: "Haptisches Feedback",
                                description: "Vibriert wenn der Timer abläuft",
                                isOn: $hapticsEnabled
                            )
                            .padding(.horizontal, 20)
                        }

                        // Preview-Button
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Benachrichtigung testen")
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 20)

                            Button {
                                testNotifications()
                            } label: {
                                HStack {
                                    Image(systemName: "play.circle.fill")
                                    Text("Test-Benachrichtigung senden")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [AppTheme.mossGreen, AppTheme.turquoiseBoost],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundColor(.white)
                                .cornerRadius(AppLayout.CornerRadius.medium)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 20)

                            Text(
                                "Testet die aktivierten Benachrichtigungen mit einem 5-Sekunden-Timer"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)
                        }
                        .padding(.top, 8)

                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle("Benachrichtigungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.powerOrange)
                }
            }
        }
    }

    // MARK: - Test Notifications

    private func testNotifications() {
        // Erstelle Test-Workout
        let testWorkout = Workout(
            name: "Test Workout",
            exercises: [],
            defaultRestTime: 5,  // 5 Sekunden für Test
            notes: "Test"
        )

        // Starte Test-Rest-Timer
        workoutStore.restTimerStateManager.startRest(
            for: testWorkout,
            exercise: 0,
            set: 0,
            duration: 5,
            currentExerciseName: "Bankdrücken",
            nextExerciseName: "Bizeps Curls"
        )

        // Feedback
        if hapticsEnabled {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }

        // Show confirmation
        showingPreview = true

        // Auto-dismiss nach 2 Sekunden
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showingPreview = false
        }
    }
}

// MARK: - Notification Toggle Card Component

struct NotificationToggleCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    @Binding var isOn: Bool
    var badge: String? = nil
    var showSystemSettings: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundStyle(iconColor)
                }

                // Title with Badge
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)

                        if let badge = badge {
                            Text(badge)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(iconColor)
                                )
                        }
                    }
                }

                Spacer()

                // Toggle
                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .tint(iconColor)
            }

            // Description
            Text(description)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // System Settings Link (if needed)
            if showSystemSettings {
                Button {
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "gear")
                            .font(.system(size: 12))
                        Text("System-Einstellungen öffnen")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(iconColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(iconColor.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AppLayout.Spacing.standard)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    colorScheme == .dark
                        ? Color.white.opacity(0.08)
                        : Color.black.opacity(0.06),
                    lineWidth: 0.5
                )
        )
        .shadow(color: Color(red: 0, green: 0, blue: 0, opacity: 0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Preview

#Preview {
    NotificationSettingsView()
        .environmentObject(WorkoutStore())
}
