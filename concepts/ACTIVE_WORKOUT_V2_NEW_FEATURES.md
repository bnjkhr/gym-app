# Active Workout V2 - New Features Plan

**Created:** 2025-10-21  
**Status:** Planning Phase  
**Goal:** Add 3 advanced UX features to Active Workout V2

---

## 📋 Features Overview

### 1. Swipe-to-Delete Sets ✅
**Priority:** High  
**Complexity:** Low  
**Estimated Time:** 30 minutes

### 2. Drag-and-Drop Set Reordering ✅
**Priority:** High  
**Complexity:** Medium  
**Estimated Time:** 1 hour

### 3. Exercise History Chart 📊
**Priority:** Medium  
**Complexity:** High  
**Estimated Time:** 2-3 hours

---

## 🎯 Feature 1: Swipe-to-Delete Sets

### User Story
> "As a user, I want to swipe left on a set to delete it, so I can quickly remove mistakes without tapping through menus."

### Design

**Interaction:**
```
┌─────────────────────────────────────┐
│ 100 kg  8 reps          [✓]  ←←←   │  Swipe left
└─────────────────────────────────────┘
         ↓
┌─────────────────────────────────────┐
│ 100 kg  8 reps  [🗑️ Delete]        │  Delete button appears
└─────────────────────────────────────┘
```

### Implementation

**File:** `ExerciseCard.swift`

**Current Structure:**
```swift
ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, _ in
    setRowView(index: index)
        .padding(.horizontal, Layout.headerPadding)
        .padding(.vertical, 12)
}
```

**New Structure:**
```swift
ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, _ in
    setRowView(index: index)
        .padding(.horizontal, Layout.headerPadding)
        .padding(.vertical, 12)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                HapticManager.shared.light()
                onDeleteSet?(index)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
}
```

### Edge Cases
- ✅ Last set in exercise → Allow deletion (exercise can have 0 sets)
- ✅ Completed sets → Can still be deleted
- ✅ Active rest timer → No conflict (swipe is on different UI element)

### Testing
- [ ] Swipe on first set
- [ ] Swipe on last set
- [ ] Swipe on middle set
- [ ] Delete all sets
- [ ] Swipe with completed sets

---

## 🎯 Feature 2: Drag-and-Drop Set Reordering

### User Story
> "As a user, I want to drag sets to reorder them, so I can adjust my workout plan on the fly."

### Design

**Interaction:**
```
Before:
1. 100kg x 8 reps
2. 100kg x 8 reps
3. 105kg x 6 reps  ← Drag this up
4. 95kg x 10 reps

After:
1. 100kg x 8 reps
2. 105kg x 6 reps  ← Now here
3. 100kg x 8 reps
4. 95kg x 10 reps
```

### Implementation

**File:** `ExerciseCard.swift`

**Current Structure:**
```swift
ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, _ in
    setRowView(index: index)
}
```

**New Structure (iOS 16+):**
```swift
@State private var draggedSet: ExerciseSet?

ForEach(exercise.sets) { set in
    setRowView(for: set)
        .draggable(set) {
            // Drag preview
            setRowView(for: set)
                .opacity(0.8)
        }
        .dropDestination(for: ExerciseSet.self) { droppedSets, location in
            guard let droppedSet = droppedSets.first,
                  let fromIndex = exercise.sets.firstIndex(where: { $0.id == droppedSet.id }),
                  let toIndex = exercise.sets.firstIndex(where: { $0.id == set.id })
            else { return false }
            
            withAnimation {
                exercise.sets.move(fromOffsets: IndexSet(integer: fromIndex), 
                                   toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
            }
            HapticManager.shared.light()
            return true
        }
}
```

**Alternative (More Control):**
```swift
// Use .onMove modifier for simpler implementation
ForEach(exercise.sets) { set in
    setRowView(for: set)
}
.onMove { source, destination in
    withAnimation {
        exercise.sets.move(fromOffsets: source, toOffset: destination)
    }
    HapticManager.shared.light()
}
```

**Problem:** `.onMove` requires `EditMode` (Edit button in toolbar)

**Better Solution:** Custom drag gesture with visual feedback

```swift
@State private var draggedSetID: UUID?
@State private var dragOffset: CGFloat = 0

ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, _ in
    setRowView(index: index)
        .background(draggedSetID == exercise.sets[index].id ? 
                    Color.gray.opacity(0.2) : Color.clear)
        .offset(y: draggedSetID == exercise.sets[index].id ? dragOffset : 0)
        .gesture(
            DragGesture()
                .onChanged { value in
                    draggedSetID = exercise.sets[index].id
                    dragOffset = value.translation.height
                }
                .onEnded { value in
                    let dragDistance = value.translation.height
                    let itemHeight: CGFloat = 60 // Approximate row height
                    let indexChange = Int(round(dragDistance / itemHeight))
                    
                    if indexChange != 0 {
                        let newIndex = max(0, min(exercise.sets.count - 1, index + indexChange))
                        if newIndex != index {
                            withAnimation {
                                exercise.sets.move(
                                    fromOffsets: IndexSet(integer: index),
                                    toOffset: newIndex > index ? newIndex + 1 : newIndex
                                )
                            }
                            HapticManager.shared.impact()
                        }
                    }
                    
                    draggedSetID = nil
                    dragOffset = 0
                }
        )
}
```

### Challenges
- ⚠️ `@Binding var exercise: WorkoutExercise` - Mutations need to propagate
- ⚠️ Drag preview should show the set being moved
- ⚠️ Drop target visual feedback (line indicator)

### Recommended Approach
**Use iOS 16+ `.onMove` with EditMode for simplicity**

Add a reorder button that toggles edit mode:
```swift
@Environment(\.editMode) var editMode

// In bottom actions
Button {
    withAnimation {
        editMode?.wrappedValue = editMode?.wrappedValue == .active ? .inactive : .active
    }
} label: {
    Image(systemName: editMode?.wrappedValue == .active ? "checkmark" : "arrow.up.arrow.down")
}
```

### Testing
- [ ] Drag first set down
- [ ] Drag last set up
- [ ] Drag middle set to top
- [ ] Drag middle set to bottom
- [ ] Quick drag and release
- [ ] Drag with haptic feedback

---

## 🎯 Feature 3: Exercise History Chart

### User Story
> "As a user, I want to see my progress over time for each exercise, so I can track strength gains and plan progressive overload."

### Design

**UI Mockup:**
```
┌─────────────────────────────────────┐
│ Bench Press         [Freie Gewichte]│
│ ••• (Menu)                           │
├─────────────────────────────────────┤
│ 📊 HISTORY                           │
│                                      │
│  110kg ●                             │
│  105kg   ●                           │
│  100kg ●   ●                         │
│   95kg       ●                       │
│        ─────────────────             │
│       Oct15 Oct18 Oct21              │
│                                      │
│  Last: 105kg x 8 (Oct 18)           │
│  Best: 110kg x 6 (Oct 21)           │
│  Avg:  102kg                         │
└─────────────────────────────────────┘
```

### Implementation

**New File:** `ExerciseHistoryChart.swift` (~150 LOC)

**Data Structure:**
```swift
struct ExerciseHistoryEntry: Identifiable {
    let id: UUID
    let date: Date
    let maxWeight: Double
    let totalVolume: Double  // weight × reps × sets
    let sets: [ExerciseSet]
}
```

**Chart Library:** Use SwiftUI Charts (iOS 16+)

```swift
import Charts

struct ExerciseHistoryChart: View {
    let exerciseID: UUID
    let history: [ExerciseHistoryEntry]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("HISTORY")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            // Chart
            Chart(history) { entry in
                LineMark(
                    x: .value("Date", entry.date),
                    y: .value("Weight", entry.maxWeight)
                )
                .foregroundStyle(.orange)
                .symbol(.circle)
                
                PointMark(
                    x: .value("Date", entry.date),
                    y: .value("Weight", entry.maxWeight)
                )
                .foregroundStyle(.orange)
            }
            .frame(height: 120)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 3)) { value in
                    AxisValueLabel(format: .dateTime.month().day())
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let weight = value.as(Double.self) {
                            Text("\(Int(weight))kg")
                        }
                    }
                }
            }
            
            // Stats
            statsView
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var statsView: some View {
        HStack(spacing: 20) {
            StatItem(label: "Last", value: lastWorkoutText)
            StatItem(label: "Best", value: bestWorkoutText)
            StatItem(label: "Avg", value: avgWeightText)
        }
        .font(.caption)
    }
}

struct StatItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
                .fontWeight(.semibold)
        }
    }
}
```

### Data Fetching

Need to query SwiftData for previous workouts with this exercise:

```swift
@Query(
    filter: #Predicate<Workout> { workout in
        workout.exercises.contains { $0.exercise.id == exerciseID }
    },
    sort: \Workout.date,
    order: .reverse
)
var workoutHistory: [Workout]
```

**Problem:** Can't use `@Query` inside a subview without `@Model`

**Solution:** Pass history data from parent or use a ViewModel

```swift
class ExerciseHistoryViewModel: ObservableObject {
    @Published var history: [ExerciseHistoryEntry] = []
    
    func loadHistory(for exerciseID: UUID, from modelContext: ModelContext) {
        // Fetch workouts containing this exercise
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { workout in
                workout.exercises.contains { $0.exercise.id == exerciseID }
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        do {
            let workouts = try modelContext.fetch(descriptor)
            history = workouts.compactMap { workout in
                guard let exercise = workout.exercises.first(where: { $0.exercise.id == exerciseID }) else { return nil }
                
                let maxWeight = exercise.sets.map { $0.weight }.max() ?? 0
                let totalVolume = exercise.sets.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
                
                return ExerciseHistoryEntry(
                    id: workout.id,
                    date: workout.date,
                    maxWeight: maxWeight,
                    totalVolume: totalVolume,
                    sets: exercise.sets
                )
            }
        } catch {
            print("Failed to fetch history: \(error)")
        }
    }
}
```

### Integration into ExerciseCard

**Option 1:** Show chart in expanded state (tap to expand card)
**Option 2:** Show chart in menu (tap ••• → "View History")
**Option 3:** Always visible at top of card

**Recommended:** Option 2 (Menu) - Cleaner UI, on-demand

```swift
// In ExerciseCard header menu
Menu {
    Button("Add Set") { onAddSet?() }
    Button("View History") { showingHistory = true }
    Button("Delete Exercise", role: .destructive) { }
} label: {
    Image(systemName: "ellipsis")
}
.sheet(isPresented: $showingHistory) {
    ExerciseHistorySheet(
        exercise: exercise.exercise,
        history: historyViewModel.history
    )
}
```

### Challenges
- ⚠️ SwiftData query performance (need to index?)
- ⚠️ Chart library iOS 16+ requirement
- ⚠️ Empty state (no history yet)
- ⚠️ Different exercise variations (Bench Press vs Incline Bench Press)

### Testing
- [ ] Exercise with 0 previous workouts
- [ ] Exercise with 1 previous workout
- [ ] Exercise with 10+ previous workouts
- [ ] Chart rendering performance
- [ ] Different date ranges

---

## 📊 Implementation Priority

### Phase 1: Quick Wins (Session 5A - 1 hour)
1. ✅ Swipe-to-Delete Sets (30 min)
2. ✅ Basic Drag-and-Drop (30 min using .onMove + EditMode)

### Phase 2: Polish (Session 5B - 1 hour)
3. ✅ Drag visual feedback improvements
4. ✅ Haptic feedback tuning
5. ✅ Edge case testing

### Phase 3: Advanced Feature (Session 6 - 2-3 hours)
6. ✅ Exercise History Chart
7. ✅ Data fetching from SwiftData
8. ✅ Chart UI polish

---

## 🎯 Success Criteria

### Feature 1: Swipe-to-Delete
- ✅ Swipe gesture smooth (60fps)
- ✅ Delete button appears on swipe
- ✅ Haptic feedback on delete
- ✅ Undo option? (Nice-to-have)

### Feature 2: Drag-and-Drop
- ✅ Can reorder any set
- ✅ Visual feedback during drag
- ✅ Animation smooth
- ✅ State persists after reorder

### Feature 3: History Chart
- ✅ Shows last 10 workouts
- ✅ Chart renders correctly
- ✅ Stats accurate
- ✅ Performance acceptable (<100ms load)

---

## 🔧 Technical Decisions

### Swipe-to-Delete
- **Approach:** Native `.swipeActions()` modifier
- **Reason:** Built-in, iOS-native, no custom gesture code

### Drag-and-Drop
- **Approach:** `.onMove()` with EditMode
- **Reason:** Simpler than custom DragGesture, well-tested by Apple
- **Alternative:** Custom DragGesture if more control needed

### History Chart
- **Approach:** SwiftUI Charts framework
- **Reason:** Native, performant, declarative
- **Fallback:** Custom chart if iOS 16+ not available (check deployment target)

---

## 📝 Next Steps

1. Start with Feature 1 (Swipe-to-Delete) - Easiest
2. Then Feature 2 (Drag-and-Drop) - Medium complexity
3. Finally Feature 3 (History Chart) - Most complex

**Estimated Total Time:** 4-5 hours for all 3 features

Ready to start implementation? 🚀
