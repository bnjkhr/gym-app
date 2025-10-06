import SwiftUI
import SwiftData

// MARK: - Smart Tips Card

struct SmartTipsCard: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @StateObject private var feedbackManager = TipFeedbackManager()

    @Query(sort: [SortDescriptor(\WorkoutSessionEntity.date, order: .reverse)])
    private var sessionEntities: [WorkoutSessionEntity]

    @State private var tips: [TrainingTip] = []
    @State private var currentIndex: Int = 0
    @State private var showFeedbackAnimation: Bool = false
    @State private var feedbackGiven: Set<UUID> = []
    @State private var isRefreshing: Bool = false

    private var displaySessions: [WorkoutSession] {
        sessionEntities.map { WorkoutSession(entity: $0) }
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            headerView

            if !tips.isEmpty {
                // Tip Cards mit TabView
                tipCardsView
                    .frame(height: 220)

                // Feedback Buttons (nur wenn noch nicht bewertet)
                if currentIndex < tips.count && !feedbackGiven.contains(tips[currentIndex].id) {
                    feedbackButtonsView
                }

                // Page Indicator
                if tips.count > 1 {
                    pageIndicatorView
                }
            } else {
                emptyStateView
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
        .onAppear {
            generateTips()
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Dein Trainings-Coach")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.primary)

            Spacer()

            Button(action: refreshTips) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                    .animation(.linear(duration: 0.5), value: isRefreshing)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Tip Cards View

    private var tipCardsView: some View {
        TabView(selection: $currentIndex) {
            ForEach(Array(tips.enumerated()), id: \.element.id) { index, tip in
                TipCardView(tip: tip, hasFeedback: feedbackGiven.contains(tip.id))
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    // MARK: - Feedback Buttons

    private var feedbackButtonsView: some View {
        HStack(spacing: 16) {
            Button(action: { rateTip(.notHelpful) }) {
                HStack(spacing: 6) {
                    Image(systemName: "hand.thumbsdown")
                        .font(.system(size: 14))
                    Text("Nicht hilfreich")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray5))
                )
            }
            .buttonStyle(.plain)

            Button(action: { rateTip(.helpful) }) {
                HStack(spacing: 6) {
                    Image(systemName: "hand.thumbsup.fill")
                        .font(.system(size: 14))
                    Text("Hilfreich")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Page Indicator

    private var pageIndicatorView: some View {
        HStack(spacing: 8) {
            ForEach(0..<tips.count, id: \.self) { index in
                Circle()
                    .fill(index == currentIndex ? Color.purple : Color.gray.opacity(0.3))
                    .frame(width: 6, height: 6)
                    .animation(.spring(response: 0.3), value: currentIndex)
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.green)

            Text("Alles gut!")
                .font(.system(size: 16, weight: .semibold))

            Text("Trainiere weiter und ich gebe dir personalisierte Tipps.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 30)
    }

    // MARK: - Actions

    private func generateTips() {
        guard !displaySessions.isEmpty else {
            tips = []
            return
        }

        let analyzer = WorkoutAnalyzer()
        let tipEngine = TipEngine()

        // Analysiere Workouts
        let analysis = analyzer.analyze(
            sessions: displaySessions,
            profile: workoutStore.userProfile,
            healthData: getHealthData()
        )

        // Generiere Tips
        tips = tipEngine.generateTips(
            from: analysis,
            profile: workoutStore.userProfile,
            healthData: getHealthData(),
            maxTips: 3
        )

        currentIndex = 0
    }

    private func refreshTips() {
        isRefreshing = true

        // Animation
        withAnimation(.spring(response: 0.3)) {
            generateTips()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isRefreshing = false
        }
    }

    private func rateTip(_ rating: TipRating) {
        guard currentIndex < tips.count else { return }

        let currentTip = tips[currentIndex]

        // Speichere Feedback
        feedbackManager.rateTip(currentTip, rating: rating)
        feedbackGiven.insert(currentTip.id)

        // Animation
        withAnimation(.spring(response: 0.3)) {
            showFeedbackAnimation = true
        }

        // Zum nächsten Tip nach kurzer Verzögerung
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.3)) {
                if currentIndex < tips.count - 1 {
                    currentIndex += 1
                }
                showFeedbackAnimation = false
            }
        }
    }

    private func getHealthData() -> HealthData? {
        // Hole aktuelle Health-Daten aus HealthKit
        // Vereinfachte Version - kann später erweitert werden
        return nil
    }
}

// MARK: - Tip Card View

struct TipCardView: View {
    let tip: TrainingTip
    let hasFeedback: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Category Badge
            HStack(spacing: 6) {
                Image(systemName: tip.category.icon)
                    .font(.system(size: 12, weight: .semibold))

                Text(tip.category.displayName)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(tip.category.color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(tip.category.color.opacity(0.15))
            )

            // Message
            Text(tip.message)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.primary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            // Emoji and Priority
            HStack {
                Text(tip.emoji)
                    .font(.system(size: 32))

                Spacer()

                if hasFeedback {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                        Text("Bewertet")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.green.opacity(0.15))
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
        )
    }
}

// MARK: - Preview

#Preview {
    SmartTipsCard()
        .environmentObject(WorkoutStore())
        .padding()
        .background(Color(.systemGroupedBackground))
}
