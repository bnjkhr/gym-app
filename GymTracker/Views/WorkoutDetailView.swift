import SwiftUI
import UIKit

struct WorkoutDetailView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @Environment(\.dismiss) private var dismiss
    @Binding var workout: Workout
    var isActiveSession: Bool = false
    var onActiveSessionEnd: (() -> Void)? = nil

    // Lokaler Timer-State entfernt – wir nutzen den zentralen Store
    @State private var showingCompletionSheet = false
    @State private var completionDuration: TimeInterval = 0
    @State private var showingCompletionConfirmation = false
    @State private var showingReorderSheet = false
    @State private var reorderExercises: [WorkoutExercise] = []

    var body: some View {
        List {
            summarySection

            // Fortschritt
            progressOverviewSection
            progressInfoBoxSection

            if let activeRest = activeRestForThisWorkout {
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

    // MARK: - Fortschritt

    private var progressOverviewSection: some View {
        Section("Fortschritt") {
            VStack(spacing: 12) {
                HStack {
                    summaryRow(title: "Letztes Gewicht", value: previousVolumeValueText)
                    summaryRow(title: "Letztes Datum", value: previousDateText)
                    summaryRow(title: "Übungen zuletzt", value: previousExerciseCountText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var progressInfoBoxSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundStyle(Color.mossGreen)
                    Text("Veränderungen seit letzter Session")
                        .font(.subheadline.weight(.semibold))
                }

                VStack(spacing: 8) {
                    HStack {
                        Text("Gewicht")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(progressDeltaText)
                            .font(.subheadline.weight(.semibold))
                            .contentTransition(.numericText())
                    }
                    HStack {
                        Text("Wiederholungen")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(repsDeltaText)
                            .font(.subheadline.weight(.semibold))
                            .contentTransition(.numericText())
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
    }

    private func summaryRow(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func restTimerSection(activeRest: WorkoutStore.ActiveRestState) -> some View {
        Section("Pause") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Aktive Pause: \(activeRest.setIndex + 1) • \(workout.exercises[safe: activeRest.exerciseIndex]?.exercise.name ?? "Übung")")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text(formatTime(activeRest.remainingSeconds))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                    .monospacedDigit()

                HStack(spacing: 12) {
                    if activeRest.isRunning {
                        Button(role: .cancel) {
                            workoutStore.pauseRest()
                        } label: {
                            Label("Anhalten", systemImage: "pause.circle.fill")
                        }
                    } else {
                        Button {
                            workoutStore.resumeRest()
                        } label: {
                            Label("Fortsetzen", systemImage: "play.circle.fill")
                        }
                        .disabled(activeRest.remainingSeconds == 0)
                    }

                    Button {
                        workoutStore.addRest(seconds: 15)
                    } label: {
                        Label("+15s", systemImage: "plus.circle")
                    }

                    if activeRest.remainingSeconds == 0 {
                        Button {
                            workoutStore.stopRest()
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
                        isActiveRest: isActiveRest(exerciseIndex: exerciseIndex, setIndex: setIndex),
                        remainingSeconds: activeRestForThisWorkout?.remainingSeconds ?? 0,
                        previousReps: previous.reps,
                        previousWeight: previous.weight,
                        onRestTimeUpdated: { newValue in
                            if isActiveRest(exerciseIndex: exerciseIndex, setIndex: setIndex) {
                                workoutStore.setRest(remaining: Int(newValue), total: Int(newValue))
                            }
                        },
                        onToggleCompletion: {
                            toggleCompletion(for: exerciseIndex, setIndex: setIndex)
                        }
                    )
                    .listRowSeparator(.hidden)
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

    private var previousVolumeValueText: String {
        guard let previousVolume else { return "–" }
        return previousVolume.formatted(.number.precision(.fractionLength(1))) + " kg"
    }

    private var previousDateText: String {
        guard let previous = workoutStore.previousWorkout(before: workout) else { return "–" }
        return previous.date.formatted(.dateTime.day().month().year())
    }

    private var previousExerciseCountText: String {
        guard let previous = workoutStore.previousWorkout(before: workout) else { return "–" }
        return "\(previous.exercises.count)"
    }

    private var currentTotalReps: Int {
        workout.exercises.reduce(0) { $0 + $1.sets.reduce(0) { $0 + $1.reps } }
    }

    private var previousTotalReps: Int? {
        guard let previous = workoutStore.previousWorkout(before: workout) else { return nil }
        return previous.exercises.reduce(0) { $0 + $1.sets.reduce(0) { $0 + $1.reps } }
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

    private var repsDeltaText: String {
        guard let prevReps = previousTotalReps else {
            return "Neu: kein Vergleich"
        }
        let delta = currentTotalReps - prevReps
        if delta == 0 {
            return "Gleich wie zuletzt"
        } else if delta > 0 {
            return "+\(delta) Wdh. vs. letzte Session"
        } else {
            return "\(delta) Wdh. vs. letzte Session"
        }
    }

    private var hasExercises: Bool {
        workout.exercises.contains { !$0.sets.isEmpty }
    }

    private var activeRestForThisWorkout: WorkoutStore.ActiveRestState? {
        guard let state = workoutStore.activeRestState, state.workoutId == workout.id else { return nil }
        return state
    }

    private func isActiveRest(exerciseIndex: Int, setIndex: Int) -> Bool {
        guard let state = activeRestForThisWorkout else { return false }
        return state.exerciseIndex == exerciseIndex && state.setIndex == setIndex && state.isRunning
    }

    private func toggleCompletion(for exerciseIndex: Int, setIndex: Int) {
        workout.exercises[exerciseIndex].sets[setIndex].completed.toggle()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if workout.exercises[exerciseIndex].sets[setIndex].completed {
                let rest = Int(workout.exercises[exerciseIndex].sets[setIndex].restTime.rounded())
                workoutStore.startRest(for: workout, exerciseIndex: exerciseIndex, setIndex: setIndex, totalSeconds: rest)
            } else if let state = activeRestForThisWorkout,
                      state.exerciseIndex == exerciseIndex,
                      state.setIndex == setIndex {
                workoutStore.stopRest()
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

    private func finalizeCompletion() {
        workoutStore.stopRest()
        let elapsed = max(Date().timeIntervalSince(workout.date), 0)
        workout.duration = elapsed
        workoutStore.updateWorkout(workout)
        workoutStore.recordSession(from: workout)
        completionDuration = elapsed
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
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

        let isActive = activeRestForThisWorkout?.exerciseIndex == exerciseIndex &&
                       activeRestForThisWorkout?.setIndex == setIndex
        workout.exercises[exerciseIndex].sets.remove(at: setIndex)

        if isActive {
            workoutStore.stopRest()
        } else if let state = activeRestForThisWorkout,
                  state.exerciseIndex == exerciseIndex,
                  state.setIndex >= workout.exercises[exerciseIndex].sets.count {
            workoutStore.stopRest()
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
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
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
                .sensoryFeedback(.success, trigger: set.completed)
            }

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
                        .contentTransition(.numericText())
                    Spacer()
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 6)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: set.completed)
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
