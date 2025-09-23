import SwiftUI
#if canImport(ActivityKit)
import ActivityKit
#endif

struct WorkoutDetailView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @Environment(\.dismiss) private var dismiss
    @Binding var workout: Workout
    var isActiveSession: Bool = false
    var onActiveSessionEnd: (() -> Void)? = nil

    @State private var activeRest: ActiveRest?
    @State private var remainingSeconds: Int = 0
    @State private var isTimerRunning = false
    @State private var showingCompletionSheet = false
    @State private var completionDuration: TimeInterval = 0
    @State private var showingCompletionConfirmation = false
    @State private var showingReorderSheet = false
    @State private var reorderExercises: [WorkoutExercise] = []
#if canImport(ActivityKit)
    @State private var liveActivity: Activity<WorkoutActivityAttributes>?
#endif

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        List {
            summarySection

            if let activeRest {
                restTimerSection(activeRest: activeRest)
            }

            exerciseSections

            if isActiveSession && hasExercises {
                completionSection
            }

            if !workout.notes.isEmpty {
                Section("Notizen") {
                    Text(workout.notes)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(workout.name)
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(timer) { _ in
            guard isTimerRunning else { return }
            if remainingSeconds > 0 {
                remainingSeconds -= 1
#if canImport(ActivityKit)
                updateLiveActivityIfNeeded(remainingSeconds: remainingSeconds)
#endif
                if remainingSeconds <= 0 {
                    SoundPlayer.playBoxBell()
                    stopRestTimer()
                }
            } else {
                stopRestTimer()
            }
        }
        .onDisappear { stopRestTimer() }
        .sheet(isPresented: $showingCompletionSheet) {
            WorkoutCompletionSummaryView(
                name: workout.name,
                durationText: formattedDurationText,
                totalVolumeText: totalVolumeValueText,
                progressText: progressDeltaText
            ) {
                showingCompletionSheet = false
                dismiss()
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingReorderSheet) {
            NavigationStack {
                List {
                    ForEach(reorderExercises) { exercise in
                        Text(exercise.exercise.name)
                    }
                    .onMove { indices, newOffset in
                        reorderExercises.move(fromOffsets: indices, toOffset: newOffset)
                    }
                }
                .navigationTitle("Reihenfolge ändern")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Abbrechen") {
                            showingReorderSheet = false
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack {
                            EditButton()
                            Button("Fertig") {
                                workout.exercises = reorderExercises
                                showingReorderSheet = false
                            }
                        }
                    }
                }
            }
            .presentationDetents([.medium])
            .onAppear {
                reorderExercises = workout.exercises
            }
        }
    }

    private var summarySection: some View {
        Section("Überblick") {
            VStack(spacing: 16) {
                summaryRow(title: "Dauer", value: durationText)
                summaryRow(title: "Volumen", value: totalVolumeValueText)
                summaryRow(title: "Veränderung", value: progressDeltaText)
            }
        }
    }

    private func summaryRow(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func restTimerSection(activeRest: ActiveRest) -> some View {
        Section("Pause") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Aktive Pause: Satz \(activeRest.setIndex + 1) • \(workout.exercises[activeRest.exerciseIndex].exercise.name)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(formatTime(remainingSeconds))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()

                HStack(spacing: 16) {
                    if isTimerRunning {
                        Button(role: .cancel) {
                            pauseRestTimer()
                        } label: {
                            Label("Pause anhalten", systemImage: "pause.circle.fill")
                        }
                    } else {
                        Button {
                            resumeRestTimer()
                        } label: {
                            Label("Pause fortsetzen", systemImage: "play.circle.fill")
                        }
                        .disabled(remainingSeconds == 0)
                    }

                    Button {
                        remainingSeconds += 15
                        isTimerRunning = true
                    } label: {
                        Label("+15s", systemImage: "plus.circle")
                    }

                    if remainingSeconds == 0 {
                        Button {
                            stopRestTimer()
                        } label: {
                            Label("Zurücksetzen", systemImage: "gobackward")
                        }
                    }
                }
                .labelStyle(.titleAndIcon)
            }
        }
    }

    private var exerciseSections: some View {
        ForEach(workout.exercises.indices, id: \.self) { exerciseIndex in
            Section {
                ForEach(Array(workout.exercises[exerciseIndex].sets.enumerated()), id: \.element.id) { element in
                    let setIndex = element.offset
                    let setBinding = Binding(
                        get: { workout.exercises[exerciseIndex].sets[setIndex] },
                        set: { workout.exercises[exerciseIndex].sets[setIndex] = $0 }
                    )

                    WorkoutSetCard(
                        index: setIndex,
                        set: setBinding,
                        isActiveRest: activeRest == ActiveRest(exerciseIndex: exerciseIndex, setIndex: setIndex) && isTimerRunning,
                        remainingSeconds: remainingSeconds,
                        onToggleCompletion: {
                            toggleCompletion(for: exerciseIndex, setIndex: setIndex)
                        },
                        onRestTimeUpdated: { newValue in
                            if activeRest == ActiveRest(exerciseIndex: exerciseIndex, setIndex: setIndex) {
                                remainingSeconds = Int(newValue)
                            }
                        },
                        onRemove: {
                            removeSet(at: setIndex, for: exerciseIndex)
                        }
                    )
                    .swipeActions(
                        edge: .trailing,
                        allowsFullSwipe: true
                    ) {
                        Button(role: .destructive) {
                            removeSet(at: setIndex, for: exerciseIndex)
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
                }

                Button {
                    addSet(to: exerciseIndex)
                } label: {
                    Label("Satz hinzufügen", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .tint(Color.mossGreen)
            } header: {
                Text(workout.exercises[exerciseIndex].exercise.name)
                    .font(.headline)
                    .onLongPressGesture {
                        prepareReorder()
                    }
            }
        }
    }

    private var completionSection: some View {
        Section {
            if showingCompletionConfirmation {
                VStack(spacing: 12) {
                    Text("Workout abschließen?")
                        .font(.subheadline.weight(.semibold))
                    HStack(spacing: 12) {
                        Button("Abbrechen", role: .destructive) {
                            showingCompletionConfirmation = false
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)

                        Button("Abschließen") {
                            finalizeCompletion()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.mossGreen)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Button(action: completeWorkout) {
                HStack {
                    Spacer()
                    Label("Workout abschließen", systemImage: "checkmark.seal.fill")
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(Color.white)
                        .font(.headline.weight(.semibold))
                    Spacer()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.mossGreen)
            .controlSize(.large)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
    }

    // MARK: - Helpers

    private var durationText: String {
        if let duration = workout.duration {
            return "\(Int(duration / 60)) Minuten"
        }
        return "Dauer offen"
    }

    private var workoutTotalSets: Int {
        workout.exercises.reduce(0) { partialResult, exercise in
            partialResult + exercise.sets.count
        }
    }

    private var totalVolume: Double {
        workout.exercises.reduce(0) { partialResult, exercise in
            partialResult + exercise.sets.reduce(0) { $0 + (Double($1.reps) * $1.weight) }
        }
    }

    private var totalVolumeText: String {
        "Volumen: \(totalVolumeValueText)"
    }

    private var totalVolumeValueText: String {
        totalVolume.formatted(.number.precision(.fractionLength(1))) + " kg"
    }

    private var previousVolume: Double? {
        guard let previous = workoutStore.previousWorkout(before: workout) else { return nil }
        let volume = previous.exercises.reduce(0) { partialResult, exercise in
            partialResult + exercise.sets.reduce(0) { $0 + (Double($1.reps) * $1.weight) }
        }
        return volume
    }

    private var progressDeltaText: String {
        guard let previousVolume else {
            return "Neu: kein Vergleich"
        }

        let delta = totalVolume - previousVolume
        let formattedDelta = delta.magnitude.formatted(.number.precision(.fractionLength(1)))

        if delta == 0 {
            return "Gleich wie zuletzt"
        } else if delta > 0 {
            return "+\(formattedDelta) kg vs. letzte Session"
        } else {
            return "-\(formattedDelta) kg vs. letzte Session"
        }
    }

    private var hasExercises: Bool {
        workout.exercises.contains { !$0.sets.isEmpty }
    }

    private func toggleCompletion(for exerciseIndex: Int, setIndex: Int) {
        workout.exercises[exerciseIndex].sets[setIndex].completed.toggle()

        if workout.exercises[exerciseIndex].sets[setIndex].completed {
            startRest(for: exerciseIndex, setIndex: setIndex)
        } else if activeRest == ActiveRest(exerciseIndex: exerciseIndex, setIndex: setIndex) {
            stopRestTimer()
        }
    }

    private func completeWorkout() {
        showingCompletionConfirmation = true
    }

    private var formattedDurationText: String {
        let duration = completionDuration > 0 ? completionDuration : (workout.duration ?? 0)
        guard duration > 0 else { return "–" }
        let minutes = Int(duration / 60)
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return seconds > 0 ? "\(minutes) min \(seconds) s" : "\(minutes) min"
        }
        return "\(seconds) s"
    }

    private func startRest(for exerciseIndex: Int, setIndex: Int) {
        let restValue = workout.exercises[exerciseIndex].sets[setIndex].restTime
        activeRest = ActiveRest(exerciseIndex: exerciseIndex, setIndex: setIndex)
        remainingSeconds = max(Int(restValue.rounded()), 0)
        isTimerRunning = remainingSeconds > 0
#if canImport(ActivityKit)
        startLiveActivity(totalSeconds: remainingSeconds)
#endif
    }

    private func pauseRestTimer() {
        isTimerRunning = false
    }

    private func resumeRestTimer() {
        guard remainingSeconds > 0 else { return }
        isTimerRunning = true
#if canImport(ActivityKit)
        startLiveActivity(totalSeconds: remainingSeconds)
#endif
    }

    private func stopRestTimer() {
        activeRest = nil
        remainingSeconds = 0
        isTimerRunning = false
#if canImport(ActivityKit)
        endLiveActivity()
#endif
    }

    private func finalizeCompletion() {
        stopRestTimer()
        let elapsed = max(Date().timeIntervalSince(workout.date), 0)
        workout.duration = elapsed
        workoutStore.updateWorkout(workout)
        completionDuration = elapsed
        showingCompletionSheet = true
        showingCompletionConfirmation = false
        if isActiveSession {
            onActiveSessionEnd?()
        }
    }

    private func addSet(to exerciseIndex: Int) {
        let templateSet = workout.exercises[exerciseIndex].sets.last
        let newSet = ExerciseSet(
            reps: templateSet?.reps ?? 0,
            weight: templateSet?.weight ?? 0,
            restTime: templateSet?.restTime ?? workout.defaultRestTime,
            completed: false
        )
        workout.exercises[exerciseIndex].sets.append(newSet)
    }

    private func removeSet(at setIndex: Int, for exerciseIndex: Int) {
        guard workout.exercises.indices.contains(exerciseIndex) else { return }
        guard workout.exercises[exerciseIndex].sets.indices.contains(setIndex) else { return }

        let wasActiveRest = activeRest?.exerciseIndex == exerciseIndex && activeRest?.setIndex == setIndex
        workout.exercises[exerciseIndex].sets.remove(at: setIndex)

        if wasActiveRest {
            stopRestTimer()
        } else if let active = activeRest, active.exerciseIndex == exerciseIndex, active.setIndex >= workout.exercises[exerciseIndex].sets.count {
            stopRestTimer()
        }
    }

    private func prepareReorder() {
        reorderExercises = workout.exercises
        showingReorderSheet = true
    }

#if canImport(ActivityKit)
    private func startLiveActivity(totalSeconds: Int) {
        guard #available(iOS 16.1, *), ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let initialState = WorkoutActivityAttributes.ContentState(
            remainingSeconds: totalSeconds,
            totalSeconds: totalSeconds,
            title: "Pause"
        )

        if let existingActivity = liveActivity {
            updateLiveActivity(existingActivity, remainingSeconds: totalSeconds)
            return
        }

        let attributes = WorkoutActivityAttributes(workoutName: workout.name)

        do {
            liveActivity = try Activity<WorkoutActivityAttributes>.request(attributes: attributes, contentState: initialState, pushType: nil)
        } catch {
#if DEBUG
            print("Failed to start live activity: \(error)")
#endif
        }
    }

    private func updateLiveActivityIfNeeded(remainingSeconds: Int) {
        guard #available(iOS 16.1, *), let activity = liveActivity else { return }
        updateLiveActivity(activity, remainingSeconds: remainingSeconds)
    }

    private func updateLiveActivity(_ activity: Activity<WorkoutActivityAttributes>, remainingSeconds: Int) {
        Task {
            let state = WorkoutActivityAttributes.ContentState(
                remainingSeconds: max(remainingSeconds, 0),
                totalSeconds: activity.contentState.totalSeconds,
                title: "Pause"
            )

            await activity.update(using: state)
        }
    }

    private func endLiveActivity() {
        guard #available(iOS 16.1, *), let activity = liveActivity else { return }
        Task {
            let finalState = WorkoutActivityAttributes.ContentState(
                remainingSeconds: 0,
                totalSeconds: activity.contentState.totalSeconds,
                title: "Pause"
            )

            await activity.end(using: finalState, dismissalPolicy: .immediate)

            self.liveActivity = nil
        }
    }
#endif

    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remaining = seconds % 60
        return String(format: "%d:%02d", minutes, remaining)
    }

    private struct ActiveRest: Equatable {
        let exerciseIndex: Int
        let setIndex: Int
    }
}

private struct WorkoutSetCard: View {
    let index: Int
    @Binding var set: ExerciseSet
    var isActiveRest: Bool
    var remainingSeconds: Int
    var onToggleCompletion: () -> Void
    var onRestTimeUpdated: (Double) -> Void
    var onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Satz \(index + 1)")
                    .fontWeight(.semibold)
                Spacer()
                if set.completed {
                    Label("Abgeschlossen", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.footnote)
                }
            }

            HStack(spacing: 18) {
                HStack(spacing: 6) {
                    Image(systemName: "repeat")
                        .foregroundStyle(Color.mossGreen)
                    TextField("0", value: $set.reps, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                }

                HStack(spacing: 6) {
                    Image(systemName: "scalemass.fill")
                        .foregroundStyle(Color.mossGreen)
                    TextField("0", value: $set.weight, format: .number.precision(.fractionLength(1)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)
                    Text("kg")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.subheadline)

            Stepper(value: $set.restTime, in: 30...600, step: 5) {
                Text("Pause: \(formattedTime)")
            }
            .onChangeCompat(of: set.restTime, perform: onRestTimeUpdated)

            HStack(spacing: 12) {
                Button {
                    onToggleCompletion()
                } label: {
                    Label(set.completed ? "Zurücksetzen" : "Satz abschließen",
                          systemImage: set.completed ? "arrow.uturn.backward" : "checkmark.circle")
                }
                .buttonStyle(.borderedProminent)
                .tint(set.completed ? .orange : .green)

                if isActiveRest {
                    Label("\(formattedRemaining)", systemImage: "hourglass")
                        .font(.callout)
                        .foregroundStyle(.blue)
                }

                Spacer()

                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
            .labelStyle(.titleAndIcon)
        }
        .padding(.vertical, 6)
    }

    private var formattedTime: String {
        let seconds = Int(set.restTime)
        let minutes = seconds / 60
        let remaining = seconds % 60
        if minutes > 0 {
            return String(format: "%d:%02d Min", minutes, remaining)
        } else {
            return "\(seconds) Sek"
        }
    }

    private var formattedRemaining: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

private struct WorkoutCompletionSummaryView: View {
    let name: String
    let durationText: String
    let totalVolumeText: String
    let progressText: String
    let dismissAction: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.mossGreen)

                VStack(spacing: 12) {
                    Text(name)
                        .font(.title2.weight(.semibold))
                    Text("Workout gespeichert")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 18) {
                    summaryRow(title: "Dauer", value: durationText)
                    summaryRow(title: "Volumen", value: totalVolumeText)
                    summaryRow(title: "Veränderung", value: progressText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )

                Button("Zur Übersicht") {
                    dismissAction()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.mossGreen)
                .frame(maxWidth: .infinity)
            }
            .padding(24)
            .toolbar(.hidden)
        }
    }

    private func summaryRow(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
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
    let store = WorkoutStore()
    return NavigationStack {
        WorkoutDetailView(workout: .constant(store.workouts.first!))
            .environmentObject(store)
    }
}
