# HealthKit Integration

Diese Implementierung integriert Apple HealthKit in deine Workout-App und bietet folgende Funktionen:

## Funktionen

### 1. Profildaten aus HealthKit importieren
- Nutzer können ihre Körperdaten (Gewicht, Größe, Geburtsdatum, Geschlecht) direkt aus der Health App importieren
- Automatische Synchronisation der Profildaten
- Button "HealthKit importieren" im Profil-Editor

### 2. Workouts in HealthKit speichern
- Trainings werden automatisch als HKWorkout in HealthKit gespeichert
- Inklusive Kalorienschätzung und Metadaten
- Optional: Nutzer kann HealthKit-Sync in den Profil-Einstellungen aktivieren/deaktivieren

### 3. Herzfrequenz-Daten anzeigen
- Separater Tab für Herzfrequenz-Verlauf
- Verschiedene Zeiträume (1h, 24h, Woche, Monat)
- Statistiken: Durchschnitt, Maximum, Minimum
- Interaktives Diagramm mit Swift Charts

## Erforderliche Konfiguration

### 1. Info.plist Einträge
Füge folgende Einträge zur `Info.plist` hinzu:

```xml
<key>NSHealthShareUsageDescription</key>
<string>Diese App benötigt Zugriff auf HealthKit, um deine Trainingsdaten zu lesen und dein Profil zu vervollständigen.</string>
<key>NSHealthUpdateUsageDescription</key>
<string>Diese App möchte deine Workouts in HealthKit speichern, um sie mit anderen Health-Apps zu teilen.</string>
```

### 2. Entitlements
Stelle sicher, dass HealthKit in den App-Capabilities aktiviert ist:
- Gehe zu Target → Signing & Capabilities
- Klicke auf "+ Capability"
- Füge "HealthKit" hinzu

### 3. Deployment Target
HealthKit benötigt iOS 14.0 oder höher. Stelle sicher, dass dein Deployment Target entsprechend gesetzt ist.

## Neue Dateien

1. **HealthKitManager.swift**
   - Hauptklasse für alle HealthKit-Operationen
   - Berechtigung, Datenlesen, Daten schreiben
   - Singleton-Pattern für globalen Zugriff

2. **HeartRateView.swift**
   - SwiftUI-View für Herzfrequenz-Anzeige
   - Chart-Integration mit Swift Charts
   - Verschiedene Zeiträume und Statistiken

3. **HealthKitSetupView.swift**
   - Onboarding-View für HealthKit-Setup
   - Zeigt Funktionen und fordert Berechtigung an

## Geänderte Dateien

1. **UserProfile.swift**
   - Erweitert um `height`, `biologicalSex` und `healthKitSyncEnabled`
   - HealthKit-Import-Methoden

2. **SwiftDataEntities.swift**
   - UserProfileEntity um neue Felder erweitert
   - Unterstützung für HealthKit-Datentypen

3. **WorkoutStore.swift**
   - HealthKit-Manager-Integration
   - Methoden für Import/Export zu HealthKit
   - Automatische Synchronisation nach Workout-Abschluss

4. **ProfileEditView.swift**
   - HealthKit-Import-Funktionalität
   - Neue Felder für Größe und Geschlecht
   - Toggle für HealthKit-Synchronisation

5. **ContentView.swift**
   - Neuer Herzfrequenz-Tab
   - HealthKit-Import hinzugefügt

6. **SettingsView.swift**
   - HealthKit-Status-Anzeige
   - Setup-Button für HealthKit-Integration

## Nutzung

### Für neue Nutzer
1. App installieren und öffnen
2. Profil erstellen → "HealthKit importieren" tippen
3. Berechtigung erteilen
4. Daten werden automatisch importiert

### Für bestehende Nutzer
1. Einstellungen öffnen
2. HealthKit-Sektion → "Aktivieren"
3. Berechtigung erteilen
4. In Profil-Einstellungen Sync aktivieren

### Herzfrequenz anzeigen
1. Herzfrequenz-Tab öffnen
2. Zeitraum auswählen
3. Daten werden automatisch geladen
4. Pull-to-refresh für Aktualisierung

## Datenschutz

- Alle HealthKit-Daten bleiben auf dem Gerät
- Nutzer hat volle Kontrolle über Berechtigungen
- Daten werden nur bei expliziter Zustimmung synchronisiert
- Transparente Darstellung des HealthKit-Status

## Fehlerbehandlung

- Graceful Degradation wenn HealthKit nicht verfügbar
- Klare Fehlermeldungen bei Berechtigungsfehlern
- Fallback-UI wenn keine Herzfrequenz-Daten verfügbar

## Erweiterungsmöglichkeiten

- Schrittzähler-Integration
- Aktivitätsringe
- Schlafanalyse
- Körpertemperatur-Tracking
- Workout-Erkennungslogik verbessern
- Export-Funktionen