# GymTracker Smart-Konzept

## Ist-Zustand
- Der Assistent erzeugt Workouts aus Präferenzen wie Level, Ziel, Dauer, Frequenz und Equipment und bildet damit einen reduzierten Setup-Prozess ab (`GymTracker/Models/WorkoutPreferences.swift:1`, `GymTracker/ViewModels/WorkoutStore.swift:2553`).
- Rest-Timer, Live Activities und eine aktive Session-Bar halten Nutzer während der Einheit im Flow, ohne Kontextwechsel zu erzwingen (`GymTracker/ViewModels/WorkoutStore.swift:60`, `GymTracker/ContentView.swift:41`, `GymTracker/LiveActivities/WorkoutLiveActivityController.swift:7`).
- HealthKit-Anbindung liefert Profil- und Workoutdaten als Fundament für automatische Aktualisierung (`GymTracker/HealthKitManager.swift:1`).
- Spracheingabe und Audio-Feedback ermöglichen schnelles Logging ohne Tippen (`GymTracker/SpeechRecognizer.swift:7`, `GymTracker/AudioManager.swift:1`).
- SwiftData-Migrationen, Backups und Sharing sorgen für verlässlichen Datenzugriff (`GymTrackerApp.swift:10`, `GymTracker/BackupManager.swift:1`).

## Potenziale
- Wiederholungs- und Satzvorschläge basieren auf Zufall; persönliche Fortschritte bleiben unberücksichtigt (`GymTracker/ViewModels/WorkoutStore.swift:2641`).
- HealthKit-Daten werden nach dem Import kaum sichtbar genutzt; es fehlt unmittelbares Feedback (`GymTracker/HealthKitManager.swift:83`).
- Funktionsfülle (Live Activity, Sprachsteuerung, Backups) steht noch keinem kuratierten „smarten“ UI gegenüber.
- Keine explizite Erholungs- oder Belastungssteuerung; Pausen- und Frequenzempfehlungen bleiben statisch (`GymTracker/ViewModels/WorkoutStore.swift:2654`).
- Insights fokussieren nicht auf wenige, entscheidungsrelevante Kennzahlen (`GymTracker/ContentView.swift:66`).

## Konzept
### Onboarding & Setup
- Präferenz-Wizard beibehalten, zusätzlich ein leicht verständliches Zielgefühl („stärker fühlen“, „fit bleiben“) abfragen.
- HealthKit-Import sofort nutzen, um Startwerte zu bestätigen und Vertrauen zu schaffen.

### Smarte Session-Erfahrung
- Zentrale Smart Card mit drei Elementen: aktueller Satz, empfohlene nächste Last basierend auf Verlauf, Rest-Zeit.
- Sprachlogging als optionaler Shortcut integrieren, der automatisch den Satz bestätigt.

### Adaptive Progression
- Einfache Regel-Engine, die nach jeder Übung entscheidet: Gewicht steigern, halten oder Fokus auf Technik setzen (Gleitfenster über letzte drei Sessions).
- Hinweis-Badges auf der Smart Card zeigen rationale Empfehlung („+2,5 kg basierend auf letzter Einheit“).

### Recovery & Tagesfokus
- Wochenplan zeigt nur „Heute“, „Morgen“, „Erholung“; restliche Tage werden ausgeblendet.
- HealthKit-Signale (Ruhepuls, Schlaf) liefern kontextbezogene Empfehlung („Heute leichtes Tempo“).

### Insights & Motivation
- Wöchentliches Smart Summary mit drei Aussagen: erfüllte Workouts, bestes Highlight, Erholungsempfehlung.
- Optionaler Detail-Screen für tiefergehende Trends, standardmäßig versteckt.
- Erinnerungen als sanfte Check-ins: Karte im Home-Tab schlägt Short Sessions vor, wenn ein Workout ausgelassen wurde.

## Nächste Schritte
1. Lo-Fi-Prototyp der Smart Card und des Smart Summary erstellen, Nutzerflow testen.
2. Progressionslogik mit vorhandenen Workout-Daten simulieren und Feintuning vornehmen.
3. HealthKit-Signale priorisieren und prüfen, welche Daten zuverlässig verfügbar sind.
4. Sprach- und UI-Tonality für positive, minimalistische Nudges definieren und einpflegen.
