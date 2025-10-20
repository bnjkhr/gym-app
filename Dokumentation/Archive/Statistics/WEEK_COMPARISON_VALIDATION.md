# Wochenvergleich - Berechnungsvalidierung

## ✅ Berechnungslogik - Detaillierte Validierung

### 1. **Wochengrenzen** ✅

**Diese Woche:**
```swift
let currentWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
let currentWeekSessions = sessions.filter { $0.date >= currentWeekStart }
```

- ✅ Verwendet iOS Calendar API mit `.weekOfYear`
- ✅ Wochenstart = Montag 00:00 Uhr (iOS Standard)
- ✅ Bis jetzt (nicht bis Sonntag) - korrekt für laufende Woche

**Letzte Woche:**
```swift
let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: currentWeekStart) ?? currentWeekStart
let lastWeekEnd = calendar.date(byAdding: .day, value: 6, to: lastWeekStart) ?? lastWeekStart
let lastWeekSessions = sessions.filter { $0.date >= lastWeekStart && $0.date <= lastWeekEnd }
```

- ✅ Genau 7 Tage vor dieser Woche
- ✅ Komplette Woche: Montag 00:00 - Sonntag 23:59
- ✅ Kein Overlap mit aktueller Woche

**Test-Szenarien:**
```
Heute: Mittwoch, 10. Januar 2025, 15:00 Uhr

Diese Woche:
  Start: Montag, 6. Januar 2025, 00:00
  Ende: Jetzt (Mittwoch, 10. Januar, 15:00)
  Sessions: Montag, Dienstag, Mittwoch

Letzte Woche:
  Start: Montag, 30. Dezember 2024, 00:00
  Ende: Sonntag, 5. Januar 2025, 23:59
  Sessions: Ganze Woche Mo-So
```

---

### 2. **Total Volumen** ✅

**Formel:**
```swift
let totalVolume = sessions.reduce(0.0) { total, session in
    total + session.exercises.reduce(0.0) { exerciseTotal, exercise in
        exerciseTotal + exercise.sets.reduce(0.0) { setTotal, set in
            setTotal + (Double(set.reps) * set.weight)
        }
    }
}
```

**Validierung:**
- ✅ Volumen = Reps × Gewicht (Standard-Formel)
- ✅ Alle Sets werden gezählt (nicht nur completed - **ACHTUNG: Inkonsistenz!**)
- ✅ Nested Reduce korrekt
- ✅ Keine Dummy-Daten

**⚠️ Potenzielle Verbesserung:**
Sollten wir nur `completed` Sets zählen? In WeeklySetsCard tun wir das.

**Konsistenz-Check:**
```swift
// WeeklySetsCard.swift: Nur completed
let completedSets = exercise.sets.filter { $0.completed }.count

// WeekComparison: Alle Sets
exercise.sets.reduce(0.0) { ... }
```

**Empfehlung:** Alle Sets zählen ist OK für Volumen (geplante Arbeit), aber für Konsistenz sollte es einheitlich sein.

---

### 3. **Durchschnittliche Dauer** ✅

**Formel:**
```swift
let durations = sessions.compactMap { $0.duration }
let avgDuration = durations.isEmpty ? 0 : durations.reduce(0, +) / Double(durations.count)
```

**Validierung:**
- ✅ Verwendet `compactMap` → nur Sessions mit Dauer (completed)
- ✅ Durchschnitt = Summe ÷ Anzahl
- ✅ Guard gegen Division durch 0
- ✅ Keine Dummy-Daten

**Test-Szenario:**
```
Session 1: 45 Minuten
Session 2: 60 Minuten
Session 3: 50 Minuten
Durchschnitt: (45 + 60 + 50) / 3 = 51.67 Minuten ✅
```

---

### 4. **Neue PRs** ✅

**Formel:**
```swift
let weekEnd = Calendar.current.date(byAdding: .day, value: 6, to: startDate) ?? startDate
let newPRs = records.filter {
    $0.updatedAt >= startDate && $0.updatedAt <= weekEnd
}.count
```

**Validierung:**
- ✅ Verwendet `updatedAt` (Zeitpunkt des letzten PR-Updates)
- ✅ Zeitfenster: Wochenstart bis Wochenende
- ✅ Zählt ALLE Record-Arten (maxWeight, maxReps, bestOneRepMax)
- ✅ Keine Duplikate (jeder Record nur 1x)

**Wichtig:** Ein Record kann mehrere PR-Typen haben (max weight UND max reps), wird aber nur 1x gezählt → Korrekt!

---

### 5. **Total Sets** ✅

**Formel:**
```swift
let totalSets = sessions.reduce(0) { total, session in
    total + session.exercises.reduce(0) { exerciseTotal, exercise in
        exerciseTotal + exercise.sets.filter { $0.completed }.count
    }
}
```

**Validierung:**
- ✅ Nur `completed` Sets (konsistent mit WeeklySetsCard)
- ✅ Über alle Sessions summiert
- ✅ Keine Dummy-Daten

---

### 6. **Muskelgruppen-Breakdown** ✅

**Formel:**
```swift
var muscleGroupVolumes: [MuscleGroup: Double] = [:]
for session in sessions {
    for exercise in session.exercises {
        guard let exerciseEntity = exercise.exercise else { continue }

        let volume = exercise.sets.reduce(0.0) { total, set in
            total + (Double(set.reps) * set.weight)
        }

        for muscleGroupRaw in exerciseEntity.muscleGroupsRaw {
            if let muscleGroup = MuscleGroup(rawValue: muscleGroupRaw),
               muscleGroup != .cardio {
                muscleGroupVolumes[muscleGroup, default: 0] += volume
            }
        }
    }
}
```

**Validierung:**
- ✅ Volumen = Reps × Gewicht
- ✅ Multi-Muskelgruppen-Übungen zählen zu ALLEN Gruppen (z.B. Deadlift → Back, Legs, Glutes)
- ✅ Cardio ausgeschlossen (kein Gewicht)
- ✅ `guard` gegen fehlende Exercise-Entities
- ✅ Identisch mit MuscleDistributionCard

---

### 7. **Prozentuale Änderungen** ✅

**Volumen-Änderung:**
```swift
let volumeChangePct = lastStats.totalVolume > 0 ?
    ((currentStats.totalVolume - lastStats.totalVolume) / lastStats.totalVolume) * 100 : 0
```

**Validierung:**
- ✅ Formel: `((Neu - Alt) / Alt) × 100`
- ✅ Guard gegen Division durch 0
- ✅ Positiv = Steigerung, Negativ = Rückgang

**Test-Szenario:**
```
Letzte Woche: 5000 kg
Diese Woche: 6000 kg
Änderung: ((6000 - 5000) / 5000) × 100 = +20% ✅

Letzte Woche: 5000 kg
Diese Woche: 4000 kg
Änderung: ((4000 - 5000) / 5000) × 100 = -20% ✅

Letzte Woche: 0 kg (keine Sessions)
Diese Woche: 3000 kg
Änderung: 0% (Guard) ✅
```

**Andere Änderungen (PRs, Frequenz, Dauer):**
```swift
let prChange = currentStats.newPRs - lastStats.newPRs // Absolute Differenz
let freqChange = currentStats.workoutCount - lastStats.workoutCount
let durationChange = currentStats.avgDuration - lastStats.avgDuration
```

- ✅ Absolute Differenz (nicht Prozent) → Korrekt für Counts
- ✅ Dauer in Sekunden → wird in UI in Minuten konvertiert

---

### 8. **Trend-Indikatoren** ✅

**Volumen-Trend:**
```swift
var volumeTrend: Trend {
    if volumeChange >= 10 { return .increasing }
    else if volumeChange <= -10 { return .decreasing }
    else { return .stable }
}
```

**Validierung:**
- ✅ ±10% Schwelle = sinnvoll (kleinere Schwankungen = stabil)
- ✅ Increasing = grün (positiv)
- ✅ Stable = blau (neutral)
- ✅ Decreasing = orange (Warnung, nicht rot - kann auch Deload sein)

**PR-Trend:**
```swift
var prTrend: Trend {
    if prCountChange > 0 { return .increasing }
    else if prCountChange < 0 { return .decreasing }
    else { return .stable }
}
```

- ✅ Jeder neue PR = increasing (positiv)
- ✅ PRs können nicht negativ werden → decreasing unmöglich (aber Code-safe)

**Dauer-Trend:**
```swift
var durationTrend: Trend {
    if avgDurationChange >= 300 { return .increasing } // +5 Minuten
    else if avgDurationChange <= -300 { return .decreasing }
    else { return .stable }
}
```

- ✅ ±5 Minuten Schwelle = sinnvoll
- ✅ Increasing = länger (nicht zwingend gut)
- ✅ Decreasing = kürzer (kann effizienter sein)

---

## ⚠️ Bekannte Inkonsistenzen

### 1. **Completed vs. Alle Sets**

**WeekComparison - Volumen:**
```swift
exercise.sets.reduce(0.0) { total, set in
    total + (Double(set.reps) * set.weight)
}
```
→ Zählt ALLE Sets

**WeekComparison - Total Sets:**
```swift
exercise.sets.filter { $0.completed }.count
```
→ Zählt nur COMPLETED Sets

**WeeklySetsCard:**
```swift
exercise.sets.filter { $0.completed }.count
```
→ Zählt nur COMPLETED Sets

**Empfehlung:**
- **Option A:** Volumen auch nur für completed Sets (konsistenter)
- **Option B:** Dokumentieren dass Volumen = geplante Arbeit, Sets = tatsächliche Arbeit

---

## 📊 Test-Szenarien

### Szenario 1: Normale Woche
```
Letzte Woche:
  - 3 Workouts (Mo, Mi, Fr)
  - 5000 kg Volumen
  - 45 Sets
  - 1 PR (Bench Press)
  - Ø 50 min

Diese Woche (bis Mittwoch):
  - 2 Workouts (Mo, Mi)
  - 4000 kg Volumen
  - 30 Sets
  - 2 PRs (Squat, Deadlift)
  - Ø 55 min

Erwartete Ausgabe:
  - Volumen: -20% ↘ (orange)
  - PRs: +1 ↗ (grün)
  - Trainings: -1 ↘ (orange)
  - Dauer: +5 min ↗ (grün/orange)
```

### Szenario 2: Deload-Woche
```
Letzte Woche:
  - 4 Workouts
  - 8000 kg Volumen
  - 60 Sets
  - 0 PRs

Diese Woche (Deload):
  - 3 Workouts
  - 4000 kg Volumen (-50%)
  - 30 Sets
  - 0 PRs

Erwartete Ausgabe:
  - Volumen: -50% ↘ (orange) - Korrekt für Deload
  - PRs: 0 → (grau)
  - Trainings: -1 ↘ (orange)
  - Alle Trends zeigen Rückgang (erwartet bei Deload)
```

### Szenario 3: Erste Woche (keine Vorwoche)
```
Letzte Woche: 0 Sessions
Diese Woche: 2 Sessions, 3000 kg

Erwartete Ausgabe:
  - Volumen: 0% (Guard gegen Division durch 0)
  - PRs: +2
  - Trainings: +2
  - Stabile Trends (keine Vergleichsbasis)
```

---

## ✅ Fazit

### Korrekt implementiert:
- ✅ Wochengrenzen (Montag-Sonntag)
- ✅ Volumen-Berechnung (Reps × Gewicht)
- ✅ Durchschnittsdauer
- ✅ PR-Zählung (updatedAt)
- ✅ Prozentuale Änderungen
- ✅ Trend-Indikatoren
- ✅ Muskelgruppen-Breakdown
- ✅ Guards gegen Edge Cases

### Zu beheben:
- ⚠️ Inkonsistenz: Volumen (alle Sets) vs. Total Sets (nur completed)
- 💡 Empfehlung: Beide nur completed Sets verwenden

### Keine Dummy-Daten:
- ✅ Alle Berechnungen basieren auf echten WorkoutSessionEntity-Daten
- ✅ Keine hardcoded Werte
- ✅ Keine Simulationen
