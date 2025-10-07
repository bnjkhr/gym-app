# Database Version Control & Manual Reset System

## 📋 Übersicht

Dieses Dokument beschreibt das manuelle Datenbank-Versionierungssystem für die GymTracker App. Es ermöglicht dir als Entwickler, gezielt zu steuern, wann Datenbank-Updates bei Testflight-Releases durchgeführt werden sollen.

## 🎯 Konzept

Die App verwendet **drei unabhängige Versionsnummern**, die du manuell erhöhen kannst, um verschiedene Arten von Datenbank-Updates auszulösen:

1. **EXERCISE_DATABASE_VERSION** - Für Exercise-CSV-Updates
2. **SAMPLE_WORKOUT_VERSION** - Für Sample-Workout-CSV-Updates
3. **FORCE_FULL_RESET_VERSION** - Für kritische Breaking Changes (Nuclear Option)

**Wichtig:** Updates passieren **NUR**, wenn du die Version-Konstante im Code erhöhst. Es gibt keine automatischen Updates bei jedem App-Update!

## 📍 Location im Code

Alle Versionskonstanten befinden sich in: [`GymTrackerApp.swift`](GymTracker/GymTrackerApp.swift#L118-L122)

```swift
private struct DataVersions {
    static let EXERCISE_DATABASE_VERSION = 1  // Increment when exercises.csv changes
    static let SAMPLE_WORKOUT_VERSION = 2     // Increment when workouts.csv changes
    static let FORCE_FULL_RESET_VERSION = 1   // Increment for critical breaking changes
}
```

## 🔄 Die 3 Reset-Level

### Level 1: Exercise Database Update

**Wann verwenden?**
- Du hast neue Übungen zu `exercises_with_ids.csv` hinzugefügt
- Du hast Übungs-Attribute geändert (Muskelgruppen, Beschreibungen, etc.)
- Du hast Übungen gelöscht oder umbenannt

**Was passiert?**
- ✅ Löscht **ALLE** Exercises (Sample + Custom)
- ✅ Lädt Exercises neu aus CSV
- ⚠️ Workouts bleiben erhalten (aber referenzieren neue Exercise-IDs)
- ⚠️ Sessions (Historie) bleiben erhalten

**Impact auf User:**
- Mittlerer Impact: Custom Exercises gehen verloren
- Workouts funktionieren weiterhin, wenn Exercise-Namen gleich bleiben

**Wie verwenden:**
```swift
// In GymTrackerApp.swift:
static let EXERCISE_DATABASE_VERSION = 2  // War: 1
```

---

### Level 2: Sample Workout Update

**Wann verwenden?**
- Du hast neue Sample-Workouts zu `workouts_with_ids.csv` hinzugefügt
- Du hast bestehende Sample-Workouts überarbeitet
- Du willst Sample-Workouts aktualisieren ohne User-Daten zu beeinflussen

**Was passiert?**
- ✅ Löscht **nur** Sample-Workouts (`isSampleWorkout == true`)
- ✅ Lädt neue Sample-Workouts aus CSV
- ✅ User-Workouts bleiben **vollständig** erhalten
- ✅ Exercises bleiben erhalten
- ✅ Sessions bleiben erhalten

**Impact auf User:**
- Minimaler Impact: Nur Beispiel-Workouts werden aktualisiert
- User-erstellte Workouts sind nicht betroffen

**Wie verwenden:**
```swift
// In GymTrackerApp.swift:
static let SAMPLE_WORKOUT_VERSION = 3  // War: 2
```

---

### Level 3: Force Full Reset (Nuclear Option)

**Wann verwenden?**
- ⚠️ **NUR BEI KRITISCHEN BREAKING CHANGES!**
- Du hast das Datenbank-Schema grundlegend geändert
- Es gibt Datenkorruptions-Probleme, die nicht anders lösbar sind
- Du machst einen kompletten Neustart der Datenstruktur

**Was passiert?**
- 🗑️ Löscht **ALLE** Exercises (Sample + Custom)
- 🗑️ Löscht **ALLE** Workouts (Sample + Custom)
- 🗑️ Löscht User Profile
- 🗑️ Löscht ExerciseRecords
- ✅ Sessions (Workout-Historie) bleiben **erhalten**!
- 🔄 Lädt alles neu: Exercises, Sample-Workouts, User Profile

**Impact auf User:**
- ⚠️ **Maximaler Impact**: Alle Custom-Daten außer History gehen verloren
- ✅ Workout-Historie bleibt erhalten
- User müssen Custom-Workouts neu erstellen

**Wie verwenden:**
```swift
// In GymTrackerApp.swift:
static let FORCE_FULL_RESET_VERSION = 2  // War: 1
```

**⚠️ Empfehlung:** Zeige einen Alert/Warning vor dem Update, damit User vorbereitet sind!

---

## 📝 Workflow für Updates

### Beispiel 1: Neue Übungen hinzufügen

```bash
# 1. Füge neue Übungen zu exercises_with_ids.csv hinzu
vim exercises_with_ids.csv

# 2. Erhöhe Exercise-Version im Code
# In GymTrackerApp.swift:
static let EXERCISE_DATABASE_VERSION = 2  # war 1

# 3. Build & Deploy
xcodebuild -project GymBo.xcodeproj -scheme GymTracker build
# Upload to Testflight

# 4. User Update durchführen
# → App erkennt neue Version
# → Löscht alte Exercises
# → Lädt neue aus CSV
```

### Beispiel 2: Sample-Workouts überarbeiten

```bash
# 1. Überarbeite workouts_with_ids.csv
vim workouts_with_ids.csv

# 2. Erhöhe Sample-Workout-Version
# In GymTrackerApp.swift:
static let SAMPLE_WORKOUT_VERSION = 3  # war 2

# 3. Build & Deploy
# → User-Workouts bleiben erhalten
# → Nur Sample-Workouts werden aktualisiert
```

### Beispiel 3: Breaking Change (z.B. neues Schema)

```bash
# 1. Implementiere Datenbank-Schema-Änderungen
# 2. Erhöhe Force-Reset-Version
# In GymTrackerApp.swift:
static let FORCE_FULL_RESET_VERSION = 2  # war 1

# 3. Optional: Füge User-Warning hinzu in ContentView.swift:
.alert("Wichtiges Update", isPresented: $showUpdateWarning) {
    Button("Verstanden") { }
} message: {
    Text("Die Datenbank wurde grundlegend überarbeitet. Deine Workout-Historie bleibt erhalten.")
}

# 4. Build & Deploy mit Release Notes
```

---

## 🔍 Logging & Debugging

Die App loggt alle Datenbank-Operationen mit OSLog. Du kannst Logs in Xcode Console sehen:

**Exercise Updates:**
```
🔄 Exercise database update needed (version 1 → 2)
🗑️ Deleting 161 exercises for update
🔄 Loading exercises from CSV
✅ Exercise update completed: 161 exercises loaded
```

**Sample-Workout Updates:**
```
Deleting 4 outdated sample workouts
Loading sample workouts (Version 3)
✅ Seeded 4 sample workouts
```

**Force Reset:**
```
🚨 Force full reset triggered (version 1 → 2)
🗑️ Deleting 161 exercises
🗑️ Deleting 12 workouts
✅ Preserving 45 workout sessions (history)
✅ Force reset completed successfully
```

---

## 💾 UserDefaults Keys

Die App speichert folgende Keys in UserDefaults, um Versionen zu tracken:

| Key | Beschreibung | Initial Value |
|-----|--------------|---------------|
| `exerciseDatabaseVersion` | Letzte Exercise-DB-Version | 0 |
| `sampleWorkoutVersion` | Letzte Sample-Workout-Version | 0 |
| `forceResetVersion` | Letzte Force-Reset-Version | 0 |

**Debug-Tipp:** Du kannst diese Werte manuell zurücksetzen für lokales Testing:
```swift
// In Debug-Menü oder direkt im Code:
UserDefaults.standard.set(0, forKey: "exerciseDatabaseVersion")
// → Nächster App-Start triggert Exercise-Update
```

---

## ⚠️ Best Practices

### DO ✅
- Erhöhe Versionen **vor** Testflight-Deployment
- Teste Updates **lokal** mit verschiedenen Datenbank-Zuständen
- Dokumentiere Breaking Changes in Release Notes
- Verwende Level 1 & 2 häufiger, Level 3 nur bei Notwendigkeit
- Prüfe Logs nach Updates, ob alles erfolgreich war

### DON'T ❌
- Erhöhe nicht mehrere Versionen gleichzeitig (außer bei Force Reset)
- Verwende Force Reset nicht für kleine Änderungen
- Vergiss nicht, CSV-Dateien zu aktualisieren, bevor du Version erhöhst
- Erhöhe Versionen nicht ohne Testing
- Lösche keine UserDefaults-Keys in Production-Code

---

## 🐛 Troubleshooting

### "Exercise update läuft, aber Exercises sind nicht da"
→ Prüfe, ob `exercises_with_ids.csv` korrekt im Bundle liegt
→ Check Logs für `⚠️ exercises_with_ids.csv file not found`

### "Sample-Workouts werden nicht aktualisiert"
→ Stelle sicher, dass `isSampleWorkout == true` gesetzt ist
→ Prüfe, ob Version wirklich erhöht wurde

### "Force Reset hängt/crasht"
→ Prüfe, ob genug Speicherplatz vorhanden ist
→ Check StorageHealth-Logs
→ Migration könnte bei großen Datenmengen dauern (Sessions)

### "Nach Update sind User-Daten weg"
→ **NUR bei Force Reset möglich**
→ Sessions sollten IMMER erhalten bleiben
→ Prüfe Logs: `✅ Preserving X workout sessions`

---

## 📊 Migration-Reihenfolge

Die Migrationen laufen in dieser Reihenfolge ab (siehe [`GymTrackerApp.swift:125`](GymTrackerApp.swift#L125)):

```
1. Force Reset Check (wenn FORCE_FULL_RESET_VERSION erhöht)
   ↓ (Falls ausgeführt → ENDE, sonst weiter)

2. Exercise Update Check (wenn EXERCISE_DATABASE_VERSION erhöht)
   ↓

3. Legacy Exercise Migration (Fallback für alte Installationen)
   ↓

4. Exercise UUID Check (Fallback, falls Datenbank leer)
   ↓

5. Sample-Workout Update (wenn SAMPLE_WORKOUT_VERSION erhöht)
   ↓

6. ExerciseRecord Migration (aus Sessions generieren)
   ↓

7. LastUsed Migration (für bessere UX)
```

**Wichtig:** Force Reset überspringt alle anderen Migrations-Steps, da bereits alles neu geladen wird.

---

## 📞 Support

Bei Fragen oder Problemen:
1. Prüfe Console-Logs in Xcode
2. Checke UserDefaults-Werte für Version-Keys
3. Teste Migration lokal mit verschiedenen Szenarien
4. Im Notfall: Erhöhe `FORCE_FULL_RESET_VERSION` für kompletten Neustart

---

## 🔄 Schema Migrations & Testflight Updates

### Automatische Lightweight Migration

Die App nutzt **SwiftData Lightweight Migration** für:
- ✅ Neue optionale Properties (z.B. `lastUsedWeight?`)
- ✅ Neue Relationships
- ✅ Property-Umbenennung

**Wichtig:** Diese Migrations laufen automatisch - OHNE dass du eine Version erhöhen musst!

### Wann brauchst du Force Reset?

Force Reset ist **NUR** nötig bei:
- ❌ Properties löschen oder Typ ändern (z.B. `String` → `Int`)
- ❌ Entity löschen oder umbenennen
- ❌ Relationship-Änderungen (cascade rules, etc.)
- ❌ Breaking Changes im Datenmodell

**Neue optionale Properties = KEIN Force Reset nötig!**

### Schema Validation

Die App prüft beim Start automatisch die Schema-Kompatibilität ([GymTrackerApp.swift:129](GymTrackerApp.swift#L129)):
```swift
// Try to fetch one entity to verify schema
_ = try context.fetch(FetchDescriptor<ExerciseEntity>(...))
```

Falls Schema inkompatibel → Fallback auf In-Memory Storage → Fresh Data

---

## 📱 Testflight Updates

Siehe [TESTFLIGHT_UPDATE_GUIDE.md](TESTFLIGHT_UPDATE_GUIDE.md) für Details zu:
- Migration Testing
- Release Notes Vorschläge
- Notfall-Pläne
- Support-Antworten

---

**Erstellt:** 2025-01-07
**Letzte Änderung:** 2025-01-07
**Version:** 1.1
