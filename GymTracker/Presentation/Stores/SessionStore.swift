//
//  SessionStore.swift
//  GymTracker
//
//  Created on 2025-10-22.
//  V2 Clean Architecture - Presentation Layer
//

import Combine
import Foundation
import SwiftUI

/// Presentation layer store for workout session management
///
/// **Responsibility:**
/// - Manage UI state for active workout session
/// - Coordinate between UI and Use Cases
/// - Handle loading states and errors
/// - Provide @Published properties for SwiftUI
///
/// **Design Decisions:**
/// - @MainActor for UI thread safety
/// - ObservableObject for SwiftUI integration
/// - Delegates business logic to Use Cases
/// - No direct database access
///
/// **Usage:**
/// ```swift
/// struct ContentView: View {
///     @StateObject var sessionStore: SessionStore
///
///     var body: some View {
///         if let session = sessionStore.currentSession {
///             ActiveWorkoutSheetView(sessionStore: sessionStore)
///         }
///     }
/// }
/// ```
@MainActor
final class SessionStore: ObservableObject {

    // MARK: - Published State

    /// Currently active workout session (nil if no active session)
    @Published var currentSession: WorkoutSession?

    /// Loading state for async operations
    @Published var isLoading: Bool = false

    /// Error state (cleared on next operation)
    @Published var error: Error?

    /// Success message for user feedback (auto-clears after 3s)
    @Published var successMessage: String?

    // MARK: - Dependencies (Injected)

    private let startSessionUseCase: StartSessionUseCase
    private let completeSetUseCase: CompleteSetUseCase
    private let endSessionUseCase: EndSessionUseCase
    private let pauseSessionUseCase: PauseSessionUseCase
    private let resumeSessionUseCase: ResumeSessionUseCase
    private let sessionRepository: SessionRepositoryProtocol

    // MARK: - Private State

    private var successMessageTask: Task<Void, Never>?

    // MARK: - Initialization

    init(
        startSessionUseCase: StartSessionUseCase,
        completeSetUseCase: CompleteSetUseCase,
        endSessionUseCase: EndSessionUseCase,
        pauseSessionUseCase: PauseSessionUseCase,
        resumeSessionUseCase: ResumeSessionUseCase,
        sessionRepository: SessionRepositoryProtocol
    ) {
        self.startSessionUseCase = startSessionUseCase
        self.completeSetUseCase = completeSetUseCase
        self.endSessionUseCase = endSessionUseCase
        self.pauseSessionUseCase = pauseSessionUseCase
        self.resumeSessionUseCase = resumeSessionUseCase
        self.sessionRepository = sessionRepository
    }

    // MARK: - Public Actions

    /// Start a new workout session
    /// - Parameter workoutId: ID of the workout template to start
    /// - Throws: UseCaseError if session cannot be started
    func startSession(workoutId: UUID) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            currentSession = try await startSessionUseCase.execute(workoutId: workoutId)
            showSuccessMessage("Workout gestartet!")
        } catch {
            self.error = error
            print("❌ Failed to start session: \(error)")
        }
    }

    /// Complete a set in the current session
    /// - Parameters:
    ///   - exerciseId: ID of the exercise containing the set
    ///   - setId: ID of the set to complete
    func completeSet(exerciseId: UUID, setId: UUID) async {
        guard let sessionId = currentSession?.id else {
            error = NSError(
                domain: "SessionStore", code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey: "No active session"
                ])
            return
        }

        do {
            // Execute use case
            try await completeSetUseCase.execute(
                sessionId: sessionId,
                exerciseId: exerciseId,
                setId: setId
            )

            // Update local state (optimistic update)
            updateLocalSet(exerciseId: exerciseId, setId: setId, completed: true)

            // Refresh from repository to ensure consistency
            await refreshCurrentSession()

        } catch {
            self.error = error
            print("❌ Failed to complete set: \(error)")

            // Revert optimistic update on error
            await refreshCurrentSession()
        }
    }

    /// End the current workout session
    func endSession() async {
        guard let sessionId = currentSession?.id else {
            error = NSError(
                domain: "SessionStore", code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey: "No active session"
                ])
            return
        }

        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let completedSession = try await endSessionUseCase.execute(sessionId: sessionId)
            currentSession = completedSession

            // Clear current session after short delay (for UI feedback)
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5s
                currentSession = nil
            }

            showSuccessMessage("Workout abgeschlossen! 🎉")
        } catch {
            self.error = error
            print("❌ Failed to end session: \(error)")
        }
    }

    /// Pause the current workout session
    func pauseSession() async {
        guard let sessionId = currentSession?.id else { return }

        do {
            try await pauseSessionUseCase.execute(sessionId: sessionId)
            await refreshCurrentSession()
            showSuccessMessage("Workout pausiert")
        } catch {
            self.error = error
            print("❌ Failed to pause session: \(error)")
        }
    }

    /// Resume the current workout session
    func resumeSession() async {
        guard let sessionId = currentSession?.id else { return }

        do {
            try await resumeSessionUseCase.execute(sessionId: sessionId)
            await refreshCurrentSession()
            showSuccessMessage("Workout fortgesetzt")
        } catch {
            self.error = error
            print("❌ Failed to resume session: \(error)")
        }
    }

    /// Load the currently active session (if any)
    /// Call this on app launch to restore active session
    func loadActiveSession() async {
        isLoading = true
        defer { isLoading = false }

        do {
            currentSession = try await sessionRepository.fetchActiveSession()
        } catch {
            self.error = error
            print("❌ Failed to load active session: \(error)")
        }
    }

    /// Refresh current session from repository
    /// Useful after background operations or app returning from background
    func refreshCurrentSession() async {
        guard let sessionId = currentSession?.id else { return }

        do {
            currentSession = try await sessionRepository.fetch(id: sessionId)
        } catch {
            self.error = error
            print("❌ Failed to refresh session: \(error)")
        }
    }

    // MARK: - Private Helpers

    /// Optimistic update of set completion in local state
    /// This provides instant UI feedback while async operation completes
    private func updateLocalSet(exerciseId: UUID, setId: UUID, completed: Bool) {
        guard var session = currentSession else { return }

        // Find exercise index
        guard let exerciseIndex = session.exercises.firstIndex(where: { $0.id == exerciseId })
        else {
            return
        }

        // Find set index
        guard
            let setIndex = session.exercises[exerciseIndex].sets.firstIndex(where: {
                $0.id == setId
            })
        else {
            return
        }

        // Update set
        session.exercises[exerciseIndex].sets[setIndex].completed = completed
        session.exercises[exerciseIndex].sets[setIndex].completedAt = completed ? Date() : nil

        // Update published state
        currentSession = session
    }

    /// Show success message with auto-dismiss
    private func showSuccessMessage(_ message: String) {
        successMessage = message

        // Cancel previous task
        successMessageTask?.cancel()

        // Auto-clear after 3 seconds
        successMessageTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            successMessage = nil
        }
    }
}

// MARK: - Computed Properties

extension SessionStore {
    /// Check if there is an active session
    var hasActiveSession: Bool {
        currentSession != nil
    }

    /// Current session duration (live updating)
    var currentDuration: TimeInterval {
        currentSession?.duration ?? 0
    }

    /// Current session progress (0.0 to 1.0)
    var currentProgress: Double {
        currentSession?.progress ?? 0
    }

    /// Total sets in current session
    var totalSets: Int {
        currentSession?.totalSets ?? 0
    }

    /// Completed sets in current session
    var completedSets: Int {
        currentSession?.completedSets ?? 0
    }

    /// Check if current session is paused
    var isPaused: Bool {
        currentSession?.state == .paused
    }
}

// MARK: - Preview Helpers

#if DEBUG
    extension SessionStore {
        /// Create a mock SessionStore for previews
        static var preview: SessionStore {
            let repository = MockSessionRepository()
            return SessionStore(
                startSessionUseCase: DefaultStartSessionUseCase(sessionRepository: repository),
                completeSetUseCase: DefaultCompleteSetUseCase(sessionRepository: repository),
                endSessionUseCase: DefaultEndSessionUseCase(sessionRepository: repository),
                pauseSessionUseCase: DefaultPauseSessionUseCase(sessionRepository: repository),
                resumeSessionUseCase: DefaultResumeSessionUseCase(sessionRepository: repository),
                sessionRepository: repository
            )
        }

        /// Create a preview SessionStore with active session
        static var previewWithSession: SessionStore {
            let store = SessionStore.preview
            store.currentSession = .preview
            return store
        }
    }
#endif
