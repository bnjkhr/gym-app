# Test-Checkliste: Notification & Dynamic Island System

---

## Voraussetzungen:
- [ ] iPhone 14 Pro oder neuer (oder Simulator mit iOS 17+)
- [ ] Notifications erlaubt (Settings → GymTracker → Notifications)
- [ ] Dynamic Island verfügbar

---

## Test 1: Dynamic Island im Background ⭐ HAUPTTEST

### Schritte:
1. [ ] App starten → Workout auswählen → "Starten"
2. [ ] Ersten Satz machen (Gewicht/Reps eingeben, Häkchen setzen)
3. [ ] Rest-Timer startet automatisch (z.B. 60 Sekunden)
4. [ ] Dynamic Island erscheint mit Timer: `⏸ 1:00`

5. [ ] **App verlassen** (Home-Button oder nach oben wischen)
6. [ ] Dynamic Island beobachten für 10 Sekunden:
   - [ ] Timer zählt runter: `0:59`, `0:58`, `0:57`...
   - [ ] Timer bleibt **NICHT** nach 2 Sekunden stehen ✅

7. [ ] Weiter warten bis Timer bei `0:00` ist
8. [ ] Bei `0:00`:
   - [ ] **Notification erscheint** mit Titel "Pause beendet" ✅
   - [ ] Standard iOS Sound spielt ab ✅
   - [ ] Dynamic Island zeigt `0:00` ✅

**Ergebnis:** ✅ / ❌

---

## Test 2: Timer verschwindet automatisch

### Schritte:
1. [ ] App ist geschlossen, Timer ist bei `0:00` (von Test 1)
2. [ ] **App wieder öffnen** (auf App-Icon tippen, NICHT Notification)
3. [ ] Warten 2-3 Sekunden
4. [ ] Beobachten:
   - [ ] Rest-Timer Section **verschwindet automatisch** ✅
   - [ ] Workout ist normal sichtbar ✅
   - [ ] Kein "Weiter"-Button mehr nötig ✅

**Ergebnis:** ✅ / ❌

---

## Test 3: Dynamic Island Tap bei 0:00

### Schritte:
1. [ ] Neuen Timer starten (10 Sekunden)
2. [ ] App verlassen
3. [ ] Bei `0:00`: **Auf Dynamic Island tippen**
4. [ ] App öffnet sich
5. [ ] Prüfen:
   - [ ] Workout ist **noch da** (nicht verschwunden) ✅
   - [ ] Timer verschwindet nach 2 Sekunden ✅
   - [ ] Alles funktioniert normal ✅

**Ergebnis:** ✅ / ❌

---

## Test 4: +15s Button im Background

### Schritte:
1. [ ] Timer starten (30 Sekunden)
2. [ ] Warten bis Timer bei ~25 Sekunden ist
3. [ ] **+15s Button drücken**
4. [ ] Timer sollte auf **40 Sekunden** springen
5. [ ] **App sofort schließen**
6. [ ] Dynamic Island beobachten:
   - [ ] Timer zeigt **~40 Sekunden** (nicht 25) ✅
   - [ ] Timer zählt von 40 runter ✅
7. [ ] Nach **40 Sekunden**: Notification sollte kommen ✅

**Ergebnis:** ✅ / ❌

---

## Test 5: Foreground Timer-Ablauf

### Schritte:
1. [ ] Timer starten (5 Sekunden)
2. [ ] **App offen lassen**
3. [ ] Bei `0:00`:
   - [ ] **Boxing Bell Sound** spielt ab ✅
   - [ ] **Haptic Feedback** (Vibration) ✅
   - [ ] Timer zeigt `0:00` kurz an ✅
4. [ ] Nach 2 Sekunden:
   - [ ] Timer verschwindet automatisch ✅

**Ergebnis:** ✅ / ❌

---

## Test 6: Pause & Resume

### Schritte:
1. [ ] Timer starten (30 Sekunden)
2. [ ] **"Anhalten"** drücken bei ~20 Sekunden
3. [ ] Timer pausiert bei 20 Sekunden
4. [ ] App schließen, 10 Sekunden warten
5. [ ] App wieder öffnen
6. [ ] Prüfen:
   - [ ] Timer zeigt noch **20 Sekunden** ✅
   - [ ] **"Fortsetzen"** Button ist da ✅
7. [ ] "Fortsetzen" drücken
8. [ ] Timer läuft weiter von 20 Sekunden ✅

**Ergebnis:** ✅ / ❌

---

## Test 7: Timer abbrechen

### Schritte:
1. [ ] Timer starten (20 Sekunden)
2. [ ] **"Beenden"** drücken
3. [ ] Prüfen:
   - [ ] Timer verschwindet sofort ✅
   - [ ] Keine Notification kommt später ✅

**Ergebnis:** ✅ / ❌

---

## Test 8: App-Resume während Timer läuft

### Schritte:
1. [ ] Timer starten (60 Sekunden)
2. [ ] App schließen bei ~50 Sekunden
3. [ ] 10 Sekunden warten
4. [ ] App wieder öffnen
5. [ ] Prüfen:
   - [ ] Timer zeigt **~40 Sekunden** (synchronisiert) ✅
   - [ ] Timer läuft normal weiter ✅

**Ergebnis:** ✅ / ❌

---

## Test 9: Mehrere Rest-Timer nacheinander

### Schritte:
1. [ ] Satz 1 machen → Timer startet (30 Sekunden)
2. [ ] Warten bis Timer abläuft
3. [ ] Timer verschwindet automatisch
4. [ ] Satz 2 machen → Timer startet wieder
5. [ ] Prüfen:
   - [ ] Zweiter Timer funktioniert normal ✅
   - [ ] Notification kommt beim zweiten Timer ✅

**Ergebnis:** ✅ / ❌

---

## Bekannte OK-Szenarien:

- ✅ Custom Sound ist entfernt (Standard iOS Sound wird verwendet)
- ✅ Timer verschwindet automatisch nach 2 Sekunden bei 0:00
- ✅ Kein manueller "Weiter"-Button mehr nötig
- ✅ Dynamic Island läuft im Background weiter

---

## Häufige Fehler (sollten NICHT passieren):

- ❌ Dynamic Island bleibt nach 2 Sekunden stehen → BUG
- ❌ Keine Notification bei 0:00 im Background → BUG
- ❌ Workout verschwindet beim Öffnen nach Timer-Ablauf → BUG
- ❌ +15s wird nicht im Background übernommen → BUG
- ❌ Timer synchronisiert sich nicht nach App-Resume → BUG

---

## Gesamt-Bewertung:

**Tests bestanden:** __ / 9

**Status:** ✅ Alles funktioniert / ⚠️ Kleine Probleme / ❌ Große Probleme

---

## Notizen:
_[Hier Notizen zu Problemen oder Beobachtungen eintragen]_

---

## Implementierungs-Details (für Entwickler):

### Was wurde geändert:
1. **Native Timer im Widget** - `Text(timerInterval:countsDown:)` statt manuelle Updates
2. **endDate statt remainingSeconds** - State basiert auf absolutem Zeitpunkt
3. **Kein `stopRest()` bei Timer-Ablauf** - State bleibt 2 Sekunden erhalten
4. **Auto-Clear nach 2 Sekunden** - `clearRestState()` wird automatisch aufgerufen
5. **Standard iOS Sound** - Custom Sound System entfernt

### Geänderte Dateien:
- `WorkoutStore.swift` - State-Management & Timer-Logik
- `WorkoutLiveActivityController.swift` - endDate Support
- `WorkoutActivityAttributes.swift` - timerEndDate hinzugefügt
- `WorkoutWidgetsLiveActivity.swift` - Native Timer implementiert
- `NotificationManager.swift` - Standard-Sound statt Custom
- `WorkoutDetailView.swift` - Timer verschwindet bei remainingSeconds == 0

### Getestet am:
**Datum:** _____________
**iOS Version:** _____________
**Device:** _____________
**Tester:** _____________
