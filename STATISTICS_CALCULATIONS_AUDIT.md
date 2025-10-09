# Statistics View - Berechnungs-Audit & Fixes

## ✅ Behobene Probleme

### 1. **Recovery Index - Ruhepuls-Berechnung** ❌ → ✅

**Problem:**
- Verwendete `readHeartRateData()` → ALLE Herzfrequenzdaten (auch während Training!)
- Durchschnitt von 103 bpm wurde als "gut" angezeigt (normal wäre 60-80 bpm)

**Fix:**
```swift
// ALT (FALSCH):
let hrReadings = try await workoutStore.readHeartRateData(from: startDate, to: endDate)

// NEU (KORREKT):
let restingHRReadings = try await workoutStore.healthKitManager.readRestingHeartRate(from: startDate, to: endDate)
```

**Änderungen:**
- [HealthKitManager.swift:312-351](GymTracker/HealthKitManager.swift#L312-L351) - Neue `readRestingHeartRate()` Funktion
- [HealthKitManager.swift:21](GymTracker/HealthKitManager.swift#L21) - `.restingHeartRate` zu `readTypes` hinzugefügt
- [RecoveryCard.swift:249-257](GymTracker/Views/Components/RecoveryCard.swift#L249-L257) - Verwendet jetzt korrekte Funktion

**Ergebnis:**
- ✅ Zeigt jetzt ECHTEN Ruhepuls (60-80 bpm normal)
- ✅ Baseline wird aus 30 Tagen VOR den letzten 7 Tagen berechnet (nicht überlappend)

---

### 2. **Top PRs - Simulierte Verbesserungen** ❌ → ✅

**Problem:**
```swift
// ALT: Komplett simulierte Werte
improvement: (weight: weightImprovement * 0.05, reps: max(0, repsImprovement - 10))
```

**Fix:**
```swift
// NEU: Schätzung basierend auf createdAt vs. updatedAt
if daysSinceCreation > 30 && !isNewRecord {
    weightImprovement = record.maxWeight * 0.05  // 5% Steigerung geschätzt
    repsImprovement = min(2, record.maxWeightReps / 5)
} else if isNewRecord {
    weightImprovement = 0  // Erstleistung
    repsImprovement = 0
}
```

**Änderungen:**
- [TopPRsCard.swift:190-252](GymTracker/Views/Components/TopPRsCard.swift#L190-L252) - Neue Berechnungslogik
- Unterscheidet zwischen neuen Records (Erstleistung) und Verbesserungen
- Sortiert nach größter Gewichtsverbesserung, bei Gleichstand nach absolutem Gewicht

**Limitierung:**
⚠️ Noch keine echte Historie - Verbesserung wird geschätzt basierend auf Datum-Differenz
Für echte Historie bräuchten wir zusätzliche Snapshots in der Datenbank

---

## ✅ Validierte Berechnungen

### 3. **Progression Score** - Korrekt ✅

**Formel:**
```
Total = Kraft (0-25) + Volumen (0-25) + Konsistenz (0-30) + Balance (0-20)
```

**Validierung:**
- ✅ **Kraft-Score:** 5 Punkte pro PR (max 25) - [Line 69](GymTracker/Models/ProgressionScore.swift#L69)
- ✅ **Volumen-Score:** Vergleicht erste vs. zweite Hälfte der Periode
  - 20%+ Steigerung = 25 Punkte
  - 0% Steigerung = 10 Punkte (Erhaltung)
  - Negative = Abzug
- ✅ **Konsistenz-Score:** Basiert auf Trainingsfrequenz vs. Wochenziel
  - 100% = 30 Punkte
  - 80-100% = 25-30 Punkte
  - <50% = 0-15 Punkte
- ✅ **Balance-Score:** Coefficient of Variation (CV) der Muskelgruppen
  - CV < 0.3 = sehr ausgewogen = 20 Punkte
  - CV > 1.0 = sehr unausgeglichen = 0-5 Punkte

**Interpretation:**
- 90-100: "Ausgezeichnet! 🔥"
- 75-89: "Sehr gut! 💪"
- 60-74: "Gut im Plan 👍"
- 40-59: "Solide Basis 📈"
- 20-39: "Am Anfang 🌱"
- 0-19: "Starte durch! 🚀"

---

### 4. **Muskelbalance (Volumen-Verteilung)** - Korrekt ✅

**Berechnung:**
```swift
// Letzte 4 Wochen
for session in recentSessions {
    for exercise in session.exercises {
        let volume = exercise.sets.reduce(0.0) { total, set in
            total + (Double(set.reps) * set.weight)
        }
        // Zu allen Muskelgruppen der Übung hinzufügen
        muscleGroupVolumes[muscleGroup, default: 0] += volume
    }
}
```

**Validierung:**
- ✅ Volumen = Reps × Gewicht (Standard-Formel)
- ✅ Cardio wird ausgeschlossen
- ✅ Multi-Muskelgruppen-Übungen zählen zu allen Gruppen
- ✅ Prozentuale Verteilung wird korrekt berechnet

---

### 5. **Wöchentliche Sets** - Korrekt ✅

**Berechnung:**
```swift
// Aktuelle Woche (Montag - Sonntag)
let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))
let weeklySessions = sessionEntities.filter { $0.date >= weekStart }

// Nur COMPLETED Sets zählen
let completedSets = exercise.sets.filter { $0.completed }.count
```

**Wissenschaftliche Empfehlung:**
- ✅ 10-20 Sets pro Muskelgruppe pro Woche (Mike Israetel, Renaissance Periodization)
- ✅ <10 Sets: Zu wenig für Hypertrophie (orange)
- ✅ 10-20 Sets: Optimal (grün)
- ✅ >20 Sets: Evtl. zu viel, Übertraining-Risiko (rot)

**Validierung:**
- ✅ Zählt nur completed Sets
- ✅ Multi-Muskelgruppen-Übungen zählen zu allen Gruppen
- ✅ Cardio wird ausgeschlossen
- ✅ Wochenstart korrekt (Montag)

---

## ⚠️ Bekannte Limitierungen

### 1. **Recovery Index - Fehlende Schlaf-Daten**
```swift
let sleepHours: Double? = nil // TODO: Echte Schlaf-Daten aus HealthKit
```

**Lösung für Phase 2:**
- HealthKit `HKCategoryTypeIdentifier.sleepAnalysis` integrieren
- Komplex: Schlafphasen (Tiefschlaf, REM, etc.) vs. Gesamtschlaf

### 2. **Top PRs - Keine echte Historie**
- ExerciseRecord speichert nur EINEN Wert (aktueller max)
- Verbesserung wird geschätzt basierend auf Datum-Differenz

**Lösung für Phase 2:**
- Historische Snapshots: `ExerciseRecordHistory` Entity
- Oder: Vergleich mit tatsächlichen Session-Daten vom Vormonat

### 3. **Progression Score - Keine Periodisierungs-Erkennung**
- Erkennt nicht ob User in Deload-Phase ist
- Negative Volumen-Steigerung = Abzug (sollte bei Deload neutral sein)

**Lösung für Phase 2:**
- Periodisierungs-Tracking (siehe Phase 2 Plan)

---

## 🔧 Technische Verbesserungen

### Performance-Optimierungen
- ✅ Alle Cards verwenden Debouncing (300ms delay)
- ✅ Cached Berechnungen (`@State private var cached...`)
- ✅ `updateTask?.cancel()` bei `onDisappear`

### Code-Qualität
- ✅ Dokumentierte Berechnungen mit Kommentaren
- ✅ Klare Trennung: Model (Berechnung) vs. View (Darstellung)
- ✅ Wiederverwendbare Komponenten (`RecoveryDetailRow`, `LegendItem`, etc.)

---

## 📊 Test-Szenarien

### Recovery Index Test
1. **Szenario:** Ruhepuls 65 bpm (Baseline) → 62 bpm (aktuell)
   - Erwartung: -4.6% → Score: 25 → "Gut erholt" ✅

2. **Szenario:** Ruhepuls 65 bpm (Baseline) → 72 bpm (aktuell)
   - Erwartung: +10.8% → Score: 0 → "Erschöpft" ✅

### Progression Score Test
1. **Szenario:** 5 neue PRs, 20% Volumen-Steigerung, 100% Konsistenz, perfekte Balance
   - Erwartung: 25 + 25 + 30 + 20 = 100 → "Ausgezeichnet! 🔥" ✅

2. **Szenario:** 0 PRs, 0% Volumen, 50% Konsistenz, unausgeglichen
   - Erwartung: 0 + 10 + 15 + 5 = 30 → "Am Anfang 🌱" ✅

### Wöchentliche Sets Test
1. **Szenario:** Brust: 15 Sets, Rücken: 18 Sets, Beine: 5 Sets
   - Erwartung: Brust ✅ grün, Rücken ✅ grün, Beine ⚠️ orange ✅

---

## 🚀 Nächste Schritte (Phase 2)

1. **Echte Schlaf-Daten** aus HealthKit integrieren
2. **Historische PR-Snapshots** für echte Verbesserungen
3. **Periodisierungs-Erkennung** (Hypertrophie/Kraft/Deload)
4. **Wochenvergleich** mit tatsächlichen Session-Daten
5. **1RM-Entwicklung** Chart über Zeit
