# Xcode Test Target Erstellen

## Problem
Das GymTrackerTests Target existiert nicht im Xcode-Projekt. Es muss erst erstellt werden, bevor die Test-Dateien hinzugefügt werden können.

---

## Schritt 1: Test Target in Xcode erstellen

### 1.1 Projekt öffnen
```bash
open GymBo.xcodeproj
```

### 1.2 Neues Target erstellen
1. **Projekt auswählen**: Klicke auf "GymBo" in der Projektnavigation (ganz oben, blaues Icon)
2. **Target hinzufügen**: 
   - Im Hauptbereich unten auf das **"+"** klicken (unter der Target-Liste)
   - Oder: **File → New → Target...**

### 1.3 Template auswählen
1. Platform: **iOS** (links in der Sidebar)
2. Template: **Unit Testing Bundle** auswählen
3. Klicke **Next**

### 1.4 Target konfigurieren
- **Product Name**: `GymTrackerTests` (exakt dieser Name!)
- **Team**: (dein Development Team auswählen)
- **Organization Identifier**: (sollte automatisch gefüllt sein)
- **Project**: `GymBo`
- **Target to be Tested**: `GymTracker` (Hauptapp auswählen)
- **Language**: Swift
- Klicke **Finish**

### 1.5 Automatisch erstellte Datei löschen
Xcode erstellt automatisch eine `GymTrackerTests.swift` Datei mit einem Beispieltest. Diese können wir löschen:
1. Rechtsklick auf `GymTrackerTests.swift` in der Projektnavigation
2. **Delete** → **Move to Trash**

---

## Schritt 2: Test-Dateien zum Target hinzufügen

Jetzt können wir die 4 vorhandenen Test-Dateien hinzufügen:

### 2.1 Test-Dateien finden
Die Test-Dateien befinden sich hier:
```
GymTracker/Tests/
├── RestTimerStateTests.swift
├── TimerEngineTests.swift
├── RestTimerStateManagerTests.swift
└── RestTimerPersistenceTests.swift
```

### 2.2 Dateien zum Test Target hinzufügen
Für jede der 4 Test-Dateien:

1. **Datei in Projektnavigation finden**
2. **Rechtsklick** auf die Datei → **Show File Inspector** (⌥⌘1)
3. Im **File Inspector** (rechte Sidebar) unter **Target Membership**:
   - ✅ **GymTrackerTests** anhaken
   - ⬜ GymTracker sollte NICHT angehakt sein (nur GymTrackerTests!)

**Wiederhole dies für alle 4 Test-Dateien!**

---

## Schritt 3: Produktionscode für Tests zugänglich machen

### 3.1 @testable import hinzufügen
Die Test-Dateien importieren bereits `@testable import GymTracker` am Anfang:
```swift
import XCTest
@testable import GymTracker

final class RestTimerStateTests: XCTestCase {
    // ...
}
```

### 3.2 Test Target Build Settings prüfen
1. Projekt auswählen → **GymTrackerTests** Target
2. **Build Settings** Tab
3. Suche nach "Host Application"
4. Stelle sicher, dass **GymTracker.app** ausgewählt ist

---

## Schritt 4: Tests ausführen

### 4.1 Test Target in Scheme auswählen
1. Klicke auf das **Scheme** (oben links, neben Play/Stop Button)
2. Wähle **GymTrackerTests** aus (oder behalte GymTracker - beide sollten funktionieren)

### 4.2 Tests bauen
```
⌘B (Command + B) - Build Project
```

Wenn der Build erfolgreich ist, sollten keine Fehler erscheinen.

### 4.3 Alle Tests ausführen
```
⌘U (Command + U) - Run All Tests
```

Oder:
1. **Product → Test** im Menü
2. Oder klicke auf den **Diamant-Button** neben einer Testklasse/Testmethode

### 4.4 Test Navigator öffnen
```
⌘6 (Command + 6) - Test Navigator
```

Hier solltest du jetzt sehen:
```
GymTrackerTests
├── RestTimerStateTests (23 tests)
├── TimerEngineTests (20 tests)
├── RestTimerStateManagerTests (30 tests)
└── RestTimerPersistenceTests (20 tests)
```

**Gesamtzahl: 93 Tests**

---

## Schritt 5: Verifizierung

### ✅ Erfolgskriterien:
- [ ] GymTrackerTests Target existiert im Projekt
- [ ] Alle 4 Test-Dateien sind im GymTrackerTests Target (File Inspector zeigt Häkchen)
- [ ] Test Navigator (⌘6) zeigt alle 93 Tests
- [ ] Build erfolgreich (⌘B)
- [ ] Alle Tests grün (⌘U)

### ❌ Häufige Probleme:

**Problem: "No such module 'GymTracker'"**
- **Lösung**: Prüfe "Target to be Tested" in Test Target Settings
- Oder: Prüfe dass `@testable import GymTracker` korrekt ist

**Problem: "Use of unresolved identifier"**
- **Lösung**: Produktionscode-Dateien müssen zum GymTracker Target gehören
- Prüfe RestTimerState.swift, TimerEngine.swift etc. im File Inspector

**Problem: "No tests found"**
- **Lösung**: Test-Dateien müssen zum GymTrackerTests Target gehören (nicht zum Haupt-Target!)

---

## Schritt 6: Nach erfolgreicher Verifizierung

Wenn alle Tests grün sind:
1. Commit der Test-Dateien
2. Update des NOTIFICATION_SYSTEM_IMPLEMENTIERUNGSPLAN.md
3. Weiter mit **Phase 3: Live Activity Integration**

---

## Referenzen

- **Test-Dateien erstellt**: 4 Files, 93 Tests total
- **Produktionscode**: 7 neue Files (Models, Services, ViewModels, Managers, Views, Protocols)
- **Architektur**: @MainActor isolation, Protocol-based dependency injection, Single Source of Truth pattern
- **Persistenz**: JSON zu UserDefaults für Force-Quit Recovery

