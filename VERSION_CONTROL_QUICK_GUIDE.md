# Version Control Quick Guide - Wann musst du Zähler erhöhen?

## 🎯 Grundprinzip

**Standardmäßig passiert bei Updates NICHTS** - alle User-Daten bleiben erhalten.

Datenbank-Änderungen werden **NUR** durchgeführt, wenn du **manuell** eine Versionsnummer im Code erhöhst.

---

## 📊 Entscheidungsmatrix

| Was änderst du? | Zähler erhöhen? | Welcher Zähler? | Was passiert? |
|-----------------|-----------------|-----------------|---------------|
| Neues UI-Feature | ❌ **NEIN** | - | Nichts, App läuft normal |
| Bug-Fix (ohne DB) | ❌ **NEIN** | - | Nichts, App läuft normal |
| Neue optionale Property | ❌ **NEIN** | - | Automatische Lightweight Migration |
| `exercises_with_ids.csv` ändern | ✅ **JA** | `EXERCISE_DATABASE_VERSION` | Exercises neu laden |
| `workouts_with_ids.csv` ändern | ✅ **JA** | `SAMPLE_WORKOUT_VERSION` | Sample-Workouts neu laden |
| Property löschen | ✅ **JA** | `FORCE_FULL_RESET_VERSION` | Kompletter Reset |
| Property-Typ ändern | ✅ **JA** | `FORCE_FULL_RESET_VERSION` | Kompletter Reset |
| Entity löschen/umbenennen | ✅ **JA** | `FORCE_FULL_RESET_VERSION` | Kompletter Reset |

---

## 🔄 Update-Szenarien

### Szenario 1: Normales Update (häufigster Fall)

**Du änderst:** UI, fügt Features hinzu, fixst Bugs

**Code-Änderung:** KEINE - Zähler bleiben wie sie sind

**Was beim User passiert:**
```
Update installiert
→ App startet
→ Versionen prüfen:
  • forceResetVersion = 2 (UserDefaults)
  • FORCE_FULL_RESET_VERSION = 2 (Code)
  → GLEICH = kein Reset
→ App läuft normal
→ Alle Daten bleiben ✅
```

**Ergebnis:** User merkt nichts außer neuen Features.

---

### Szenario 2: Neue optionale Properties

**Du änderst:** Fügst neue Property hinzu

```swift
// In ExerciseEntity:
var newFeature: String? = nil  // WICHTIG: Optional!
var anotherThing: Int? = nil
```

**Code-Änderung:** KEINE - Zähler bleiben wie sie sind

**Was beim User passiert:**
```
Update installiert
→ App startet
→ SwiftData erkennt neue Properties
→ Lightweight Migration läuft automatisch
→ Properties werden mit nil initialisiert
→ App läuft normal ✅
```

**Ergebnis:** Automatische Migration ohne Datenverlust.

---

### Szenario 3: Exercises CSV geändert

**Du änderst:** `exercises_with_ids.csv` (neue Übungen, Beschreibungen geändert, etc.)

**Code-Änderung:**
```swift
// In GymTrackerApp.swift Zeile 120:
static let EXERCISE_DATABASE_VERSION = 2  // War: 1
```

**Was beim User passiert:**
```
Update installiert
→ App startet
→ Prüft: exerciseDatabaseVersion (1) < EXERCISE_DATABASE_VERSION (2)
→ performExerciseUpdate() läuft:
  • Löscht ALLE Exercises (Sample + Custom)
  • Lädt 161 neue Exercises aus CSV
→ Workouts bleiben erhalten
→ Sessions bleiben erhalten ✅
```

**User-Impact:** ⚠️ Custom Exercises gehen verloren

---

### Szenario 4: Sample-Workouts CSV geändert

**Du änderst:** `workouts_with_ids.csv` (neue Sample-Workouts, bestehende überarbeitet)

**Code-Änderung:**
```swift
// In GymTrackerApp.swift Zeile 121:
static let SAMPLE_WORKOUT_VERSION = 3  // War: 2
```

**Was beim User passiert:**
```
Update installiert
→ App startet
→ Prüft: sampleWorkoutVersion (2) < SAMPLE_WORKOUT_VERSION (3)
→ Löscht nur Sample-Workouts (isSampleWorkout == true)
→ Lädt neue Sample-Workouts aus CSV
→ User-Workouts bleiben ALLE erhalten ✅
→ Exercises bleiben erhalten ✅
→ Sessions bleiben erhalten ✅
```

**User-Impact:** ✅ Minimal - nur Beispiele werden aktualisiert

---

### Szenario 5: Breaking Change (Nuclear Option)

**Du änderst:** Schema grundlegend (Property löschen, Typ ändern, Entity umbenennen)

**Code-Änderung:**
```swift
// In GymTrackerApp.swift Zeile 122:
static let FORCE_FULL_RESET_VERSION = 3  // War: 2
```

**Was beim User passiert:**
```
Update installiert
→ App startet
→ Prüft: forceResetVersion (2) < FORCE_FULL_RESET_VERSION (3)
→ performForceReset() läuft:
  🗑️ Löscht ALLE Exercises
  🗑️ Löscht ALLE Workouts (Sample + Custom)
  🗑️ Löscht User Profile
  🗑️ Löscht ExerciseRecords
  ✅ Sessions bleiben erhalten!
  🔄 Lädt alles neu aus CSV
  🔄 Erstellt neues Profile
  🔄 Regeneriert ExerciseRecords aus Sessions
→ App läuft mit frischen Daten ✅
```

**User-Impact:** ⚠️⚠️ **MAXIMAL** - Custom-Daten weg (außer History)

**⚠️ Wichtig:** Immer im Release-Notes warnen!

---

## 🎯 Faustregel: Wann welchen Zähler?

### EXERCISE_DATABASE_VERSION erhöhen wenn:
- ✅ `exercises_with_ids.csv` geändert
- ✅ Neue Übungen hinzugefügt
- ✅ Übungs-Beschreibungen überarbeitet
- ✅ Übungen gelöscht/umbenannt in CSV

### SAMPLE_WORKOUT_VERSION erhöhen wenn:
- ✅ `workouts_with_ids.csv` geändert
- ✅ Neue Sample-Workouts hinzugefügt
- ✅ Bestehende Samples überarbeitet
- ✅ Samples gelöscht

### FORCE_FULL_RESET_VERSION erhöhen wenn:
- ✅ Property in Entity gelöscht
- ✅ Property-Typ geändert (`String` → `Int`)
- ✅ Entity gelöscht oder umbenannt
- ✅ Relationship geändert (cascade rules, etc.)
- ✅ Schema-Breaking-Change
- ✅ Datenbank korrupt und nicht reparierbar

---

## 💡 Pro-Tips

### ✅ DO:

1. **Test lokal BEVOR du erhöhst:**
   ```bash
   # Simuliere Update:
   # 1. Alte Version installieren
   # 2. Testdaten erstellen
   # 3. Version erhöhen & neu builden
   # 4. Prüfen ob Migration funktioniert
   ```

2. **Nur EINEN Zähler pro Update erhöhen** (außer bei Force Reset)
   - Nicht gleichzeitig EXERCISE + SAMPLE_WORKOUT erhöhen
   - Ausnahme: Force Reset überschreibt alles

3. **Logs prüfen nach Update:**
   ```
   ✅ Exercise update completed: 161 exercises loaded
   ✅ Sample workouts updated to version 3
   🚨 Force full reset triggered
   ```

4. **Release Notes schreiben** bei Force Reset:
   ```
   ⚠️ Wichtiges Update: Datenbank wird aktualisiert.
   Custom-Workouts gehen verloren. Geschichte bleibt erhalten.
   ```

### ❌ DON'T:

1. **NICHT** Zähler erhöhen ohne zu testen
2. **NICHT** Force Reset für kleine Änderungen nutzen
3. **NICHT** Zähler ohne Grund erhöhen ("nur für den Fall")
4. **NICHT** vergessen CSV-Dateien zu updaten, wenn Zähler erhöht

---

## 📖 Beispiel-Workflow

### Beispiel: Neue Übungen hinzufügen

```bash
# 1. CSV bearbeiten
vim exercises_with_ids.csv
# → 20 neue Übungen hinzugefügt

# 2. Code ändern
vim GymTracker/GymTrackerApp.swift
# → EXERCISE_DATABASE_VERSION = 2 (war 1)

# 3. Lokal testen
# → Build & Run
# → Prüfe Logs: "Exercise update completed: 181 exercises loaded"

# 4. Commit & Push
git add .
git commit -m "feat: Add 20 new exercises to database (v2)"
git push

# 5. Build & Upload Testflight

# 6. Release Notes:
"""
🆕 20 neue Übungen hinzugefügt
⚠️ Datenbank wird beim ersten Start aktualisiert (5-10 Sek)
✅ Deine Geschichte bleibt erhalten
"""

# 7. Monitor Crash-Rate nach Release
```

---

## 🔍 Debug-Befehle

### Lokale Version-Werte prüfen:
```swift
// In Debug-Menü oder direkt im Code:
print("Force Reset Version:", UserDefaults.standard.integer(forKey: "forceResetVersion"))
print("Exercise DB Version:", UserDefaults.standard.integer(forKey: "exerciseDatabaseVersion"))
print("Sample Workout Version:", UserDefaults.standard.integer(forKey: "sampleWorkoutVersion"))
```

### Version zurücksetzen für Testing:
```swift
// Simuliert "frische Installation":
UserDefaults.standard.set(0, forKey: "forceResetVersion")
UserDefaults.standard.set(0, forKey: "exerciseDatabaseVersion")
UserDefaults.standard.set(0, forKey: "sampleWorkoutVersion")
```

### Schema-Validation testen:
```swift
// App mit alter DB starten → sollte "Schema validation successful" zeigen
// Oder bei Inkompatibilität: "Schema validation failed"
```

---

## 📝 Checklist vor Testflight-Upload

- [ ] Zähler erhöht? (falls nötig)
- [ ] CSV-Dateien aktualisiert? (falls nötig)
- [ ] Lokal getestet mit alter Datenbank?
- [ ] Logs geprüft auf Erfolgs-Meldungen?
- [ ] Release Notes geschrieben?
- [ ] Bei Force Reset: User vorgewarnt?

---

## 🆘 Notfall: "Ich habe vergessen den Zähler zu erhöhen!"

**Szenario:** Du hast `exercises.csv` geändert, aber vergessen `EXERCISE_DATABASE_VERSION` zu erhöhen.

**Lösung:**

1. **Sofort Hotfix erstellen:**
   ```swift
   static let EXERCISE_DATABASE_VERSION = 2  // jetzt erhöhen
   ```

2. **Oder alternativ Force Reset:**
   ```swift
   static let FORCE_FULL_RESET_VERSION = 3
   ```

3. **Schnell auf Testflight hochladen**

4. **User informieren:** "Hotfix verfügbar, bitte updaten"

---

## 📚 Weitere Dokumentation

- [DATABASE_VERSION_CONTROL.md](DATABASE_VERSION_CONTROL.md) - Vollständige Dokumentation
- [TESTFLIGHT_UPDATE_GUIDE.md](TESTFLIGHT_UPDATE_GUIDE.md) - Testflight-spezifische Infos
- [GymTrackerApp.swift:118-122](GymTracker/GymTrackerApp.swift#L118-L122) - Versionen im Code

---

**TL;DR:**

- 🟢 **Normales Update**: Nichts tun, Zähler bleiben wie sie sind
- 🟡 **CSV geändert**: Entsprechenden Zähler erhöhen
- 🔴 **Breaking Change**: Force Reset erhöhen + User warnen

**Erstellt:** 2025-01-07
**Version:** 1.0
