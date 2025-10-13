# Test Target Fix: "No such module 'GymTracker'"

## Problem
Tests können das Modul 'GymTracker' nicht finden, obwohl das GymTrackerTests Target existiert.

## Lösung: Build Settings prüfen und korrigieren

### Schritt 1: Öffne Xcode
```bash
open GymBo.xcodeproj
```

### Schritt 2: Test Target Build Settings prüfen

1. **Projekt auswählen**: Klicke auf "GymBo" (blaues Icon) in der Projektnavigation
2. **Test Target auswählen**: Klicke auf "GymTrackerTests" in der Target-Liste (mittlere Spalte)
3. **Build Settings Tab**: Wähle den "Build Settings" Tab
4. **Suche**: Tippe "test host" in die Suchleiste

### Schritt 3: Diese Build Settings MÜSSEN gesetzt sein

#### TEST_HOST
**Muss sein:**
```
$(BUILT_PRODUCTS_DIR)/GymTracker.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/GymTracker
```

Oder:
```
$(BUILT_PRODUCTS_DIR)/GymBo.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/GymBo
```

#### BUNDLE_LOADER
**Muss sein:**
```
$(TEST_HOST)
```

### Schritt 4: Weitere wichtige Settings

Suche nach "bundle" und prüfe:

#### BUNDLE_IDENTIFIER
Sollte sein: `com.yourcompany.GymTrackerTests` (oder ähnlich)

#### TARGET_NAME
Sollte sein: `GymTrackerTests`

### Schritt 5: Product Name prüfen

Suche nach "product name":

#### PRODUCT_NAME
Sollte sein: `GymTrackerTests`

### Schritt 6: Clean & Build

1. **⇧⌘K** (Shift + Command + K) - Clean Build Folder
2. **⌘B** (Command + B) - Build
3. **⌘U** (Command + U) - Run Tests

---

## Alternative Lösung: Test-Dateien neu hinzufügen

Falls das nicht hilft:

1. **Alle Test-Dateien aus Target entfernen**:
   - Rechtsklick auf `RestTimerStateTests.swift` → File Inspector (⌥⌘1)
   - Target Membership: ✅ GymTrackerTests **abwählen**
   - Wiederhole für alle 4 Test-Dateien

2. **Test-Dateien wieder hinzufügen**:
   - Rechtsklick auf `RestTimerStateTests.swift` → File Inspector (⌥⌘1)
   - Target Membership: ✅ GymTrackerTests **anwählen**
   - Wiederhole für alle 4 Test-Dateien

3. **Clean & Build** (siehe oben)

---

## Alternative Lösung 2: Import ändern

Falls BUILD_SETTINGS korrekt sind, aber Tests trotzdem nicht funktionieren:

### Option A: Verwende den App-Namen statt "GymTracker"

Ändere in **allen 4 Test-Dateien**:
```swift
// Von:
@testable import GymTracker

// Zu:
@testable import GymBo
```

### Option B: Prüfe PRODUCT_MODULE_NAME

1. Projekt → GymTracker Target → Build Settings
2. Suche "module name"
3. PRODUCT_MODULE_NAME sollte "GymTracker" sein
4. Falls anders: entweder ändern oder in Tests den korrekten Namen verwenden

---

## Verifizierung

Nach dem Fix sollte:
1. Build ohne Fehler durchlaufen (⌘B)
2. Tests sichtbar sein im Test Navigator (⌘6)
3. Tests ausführbar sein (⌘U)
4. Alle 93 Tests grün sein

---

## Was ich bereits getan habe

✅ Phase 1 Code erstellt (RestTimerState, TimerEngine, RestTimerStateManager)
✅ Phase 2 Code erstellt (InAppOverlayManager, HapticManager, RestTimerExpiredOverlay)
✅ WorkoutStore.init() erweitert → RestTimerStateManager initialisiert
✅ WorkoutStore.startRest() erweitert → Nutzt neues System
✅ ContentView.onAppear erweitert → overlayManager verbunden

**Das Overlay sollte jetzt funktionieren!**

---

## Nächste Schritte nach Test-Fix

1. Tests ausführen und sicherstellen, dass alle grün sind
2. App auf Simulator starten
3. Workout starten → Set abschließen → Rest Timer starten
4. Timer ablaufen lassen → **Overlay sollte erscheinen!**
5. Falls Overlay erscheint: Phase 2 abgeschlossen ✅
6. Weiter mit Phase 3: Live Activity Integration

