import SwiftUI

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
        .onAppear {
            if isActiveSession {
                WorkoutLiveActivityController.shared.start(workoutName: workout.name)
                if let activeRest,
                   workout.exercises.indices.contains(activeRest.exerciseIndex),
                   workout.exercises[activeRest.exerciseIndex].sets.indices.contains(activeRest.setIndex) {
                    WorkoutLiveActivityController.shared.updateRest(
                        workoutName: workout.name,
                        remainingSeconds: remainingSeconds,
                        totalSeconds: Int(workout.exercises[activeRest.exerciseIndex].sets[activeRest.setIndex].restTime)
                    )
                } else {
                    WorkoutLiveActivityController.shared.clearRest(workoutName: workout.name)
                }
            }
        }
        .onDisappear {
            isTimerRunning = false
        }
        .onReceive(timer) { _ in
            guard isTimerRunning else { return }
            if remainingSeconds > 0 {
                remainingSeconds -= 1
                if isActiveSession,
                   let activeRest,
                   workout.exercises.indices.contains(activeRest.exerciseIndex),
                   workout.exercises[activeRest.exerciseIndex].sets.indices.contains(activeRest.setIndex) {
                    let total = Int(workout.exercises[activeRest.exerciseIndex].sets[activeRest.setIndex].restTime)
                    WorkoutLiveActivityController.shared.updateRest(
                        workoutName: workout.name,
                        remainingSeconds: remainingSeconds,
                        totalSeconds: max(total, 1)
                    )
                }
                if remainingSeconds <= 0 {
                    SoundPlayer.playBoxBell()
                    stopRestTimer()
                }
            } else {
                stopRestTimer()
            }
        }
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
            VStack(spacing: 12) {
                summaryRow(title: "Dauer", value: durationText)
                summaryRow(title: "Volumen", value: totalVolumeValueText)
                summaryRow(title: "Veränderung", value: progressDeltaText)
            }
        }
    }

    private func summaryRow(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func restTimerSection(activeRest: ActiveRest) -> some View {
        Section("Pause") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Aktive Pause: Satz \(activeRest.setIndex + 1) • \(workout.exercises[activeRest.exerciseIndex].exercise.name)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text(formatTime(remainingSeconds))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()

                HStack(spacing: 12) {
                    if isTimerRunning {
                        Button(role: .cancel) {
                            pauseRestTimer()
                        } label: {
                            Label("Anhalten", systemImage: "pause.circle.fill")
                        }
                    } else {
                        Button {
                            resumeRestTimer()
                        } label: {
                            Label("Fortsetzen", systemImage: "play.circle.fill")
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
                .font(.caption)
            }
        }
    }

    private var exerciseSections: some View {
        ForEach(workout.exercises.indices, id: \.self) { exerciseIndex in
            Section {
                ForEach(Array(workout.exercises[exerciseIndex].sets.enumerated()), id: \.element.id) { element in
                    let setIndex = element.offset

                    let previous = previousValues(for: exerciseIndex, setIndex: setIndex)

                    let setBinding = Binding(
                        get: { workout.exercises[exerciseIndex].sets[setIndex] },
                        set: { workout.exercises[exerciseIndex].sets[setIndex] = $0 }
                    )

                    WorkoutSetCard(
                        index: setIndex,
                        set: setBinding,
                        isActiveRest: activeRest == ActiveRest(exerciseIndex: exerciseIndex, setIndex: setIndex) && isTimerRunning,
                        remainingSeconds: remainingSeconds,
                        previousReps: previous.reps,
                        previousWeight: previous.weight,
                        onRestTimeUpdated: { newValue in
                            if activeRest == ActiveRest(exerciseIndex: exerciseIndex, setIndex: setIndex) {
                                remainingSeconds = Int(newValue)
                            }
                        },
                        onToggleCompletion: {
                            toggleCompletion(for: exerciseIndex, setIndex: setIndex)
                        }
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
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
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Satz hinzufügen")
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
                VStack(spacing: 8) {
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
                .padding(.vertical, 4)
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

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if workout.exercises[exerciseIndex].sets[setIndex].completed {
                startRest(for: exerciseIndex, setIndex: setIndex)
            } else if activeRest == ActiveRest(exerciseIndex: exerciseIndex, setIndex: setIndex) {
                stopRestTimer()
            }
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
        if isActiveSession {
            WorkoutLiveActivityController.shared.updateRest(
                workoutName: workout.name,
                remainingSeconds: remainingSeconds,
                totalSeconds: Int(restValue.rounded())
            )
        }
    }

    private func pauseRestTimer() {
        isTimerRunning = false
    }

    private func resumeRestTimer() {
        guard remainingSeconds > 0 else { return }
        isTimerRunning = true
        if isActiveSession {
            WorkoutLiveActivityController.shared.updateRest(
                workoutName: workout.name,
                remainingSeconds: remainingSeconds,
                totalSeconds: remainingSeconds
            )
        }
    }

    private func stopRestTimer() {
        activeRest = nil
        remainingSeconds = 0
        isTimerRunning = false
        if isActiveSession {
            WorkoutLiveActivityController.shared.clearRest(workoutName: workout.name)
        }
    }

    private func finalizeCompletion() {
        stopRestTimer()
        let elapsed = max(Date().timeIntervalSince(workout.date), 0)
        workout.duration = elapsed
        workoutStore.updateWorkout(workout)
        workoutStore.recordSession(from: workout)
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

    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remaining = seconds % 60
        return String(format: "%d:%02d", minutes, remaining)
    }

    private func previousValues(for exerciseIndex: Int, setIndex: Int) -> (reps: Int?, weight: Double?) {
        guard let previousWorkout = workoutStore.previousWorkout(before: workout) else {
            return (nil, nil)
        }
        let currentExercise = workout.exercises[exerciseIndex].exercise
        guard let previousExercise = previousWorkout.exercises.first(where: { $0.exercise.id == currentExercise.id }) else {
            return (nil, nil)
        }

        let sets = previousExercise.sets
        if sets.indices.contains(setIndex) {
            return (sets[setIndex].reps, sets[setIndex].weight)
        } else if let last = sets.last {
            return (last.reps, last.weight)
        } else {
            return (nil, nil)
        }
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
    var previousReps: Int?
    var previousWeight: Double?
    var onRestTimeUpdated: (Double) -> Void
    var onToggleCompletion: () -> Void

    @State private var weightText: String = ""
    @State private var showingRestEditor = false
    @State private var restMinutes: Int = 0
    @State private var restSeconds: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Kompakte Zeile: Nummer | Wiederholungen | Gewicht | ✓
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("\(index + 1)")
                    .font(.title3.weight(.semibold))

                verticalSeparator

                HStack(spacing: 6) {
                    TextField("0", value: $set.reps, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 64)
                        .font(.title3.weight(.semibold))
                    if let prev = previousReps {
                        Text("(\(prev))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                verticalSeparator

                HStack(spacing: 6) {
                    TextField("0.0", text: $weightText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .font(.title3.weight(.semibold))
                        .onAppear {
                            weightText = set.weight > 0 ? String(format: "%.1f", set.weight) : ""
                        }
                        .onChangeCompat(of: weightText) { newValue in
                            if let weight = Double(newValue.replacingOccurrences(of: ",", with: ".")) {
                                set.weight = max(0, min(weight, 999.9))
                            } else if newValue.isEmpty {
                                set.weight = 0
                            }
                        }
                        .onChangeCompat(of: set.weight) { newValue in
                            let formatted = newValue > 0 ? String(format: "%.1f", newValue) : ""
                            if weightText != formatted && !weightText.isEmpty {
                                DispatchQueue.main.async {
                                    weightText = formatted
                                }
                            }
                        }
                    Text("kg")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if let prevW = previousWeight {
                        Text(String(format: "(%.1f)", prevW))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 8)

                verticalSeparator

                Button(action: onToggleCompletion) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(set.completed ? Color.white : Color.mossGreen)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(set.completed ? Color.mossGreen : Color.mossGreen.opacity(0.15))
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.mossGreen, lineWidth: set.completed ? 0 : 1)
                        )
                        .accessibilityLabel(set.completed ? "Satz zurücksetzen" : "Satz abschließen")
                }
                .buttonStyle(.plain)
            }

            // Pause-Zeile darunter (klein), editierbar
            HStack(spacing: 6) {
                Image(systemName: "hourglass")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Pause: \(formattedTime)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                restMinutes = Int(set.restTime) / 60
                restSeconds = Int(set.restTime) % 60
                showingRestEditor = true
            }

            if isActiveRest {
                HStack(spacing: 8) {
                    Label("\(formattedRemaining)", systemImage: "timer")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    Spacer()
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 6)
        .sheet(isPresented: $showingRestEditor) {
            NavigationStack {
                VStack(spacing: 16) {
                    Text("Pausenzeit")
                        .font(.headline)

                    HStack(spacing: 24) {
                        VStack {
                            Text("Min")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Picker("Minuten", selection: $restMinutes) {
                                ForEach(0..<11, id: \.self) { m in
                                    Text("\(m)").tag(m)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(maxWidth: .infinity)
                        }
                        VStack {
                            Text("Sek")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Picker("Sekunden", selection: $restSeconds) {
                                ForEach([0,5,10,15,20,25,30,35,40,45,50,55], id: \.self) { s in
                                    Text("\(s)").tag(s)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 160)

                    Button("Übernehmen") {
                        let total = Double(restMinutes * 60 + restSeconds)
                        set.restTime = max(0, min(total, 600))
                        onRestTimeUpdated(set.restTime)
                        showingRestEditor = false
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.mossGreen)
                }
                .padding()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Abbrechen") {
                            showingRestEditor = false
                        }
                    }
                }
            }
            .presentationDetents([.height(320)])
        }
    }

    private var formattedTime: String {
        let seconds = Int(set.restTime)
        let minutes = seconds / 60
        let remaining = seconds % 60
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, remaining)
        } else {
            return "\(seconds) s"
        }
    }

    private var formattedRemaining: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var verticalSeparator: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.25))
            .frame(width: 1, height: 22)
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
