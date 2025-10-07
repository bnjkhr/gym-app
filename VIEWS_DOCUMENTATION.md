# Views Übersicht

## ContentView
**Dateipfad:** /Users/benkohler/Projekte/gym-app/GymTracker/ContentView.swift
**Beschreibung:** Die Haupt-View der App mit TabView-Navigation zwischen Home, Workouts und Insights. Zeigt eine schwebende ActiveWorkoutBar am unteren Bildschirmrand, wenn ein Workout aktiv ist. Enthält WorkoutsHomeView mit Begrüßung, Wochenziel-Fortschritt, Favoriten-Workouts und Onboarding-Karte. Verwaltet Deep-Link-Navigation zu aktiven Workouts und Workout-Imports (.gymtracker-Dateien). Enthält DateFormatters für Performance-Optimierung und ShareSheet für Workout-Export.

## WorkoutsTabView
**Dateipfad:** /Users/benkohler/Projekte/gym-app/WorkoutsTabView.swift
**Beschreibung:** Zeigt alle gespeicherten Workouts in einem Grid-Layout an. Bietet einen Plus-Button zum Erstellen neuer Workouts mit drei Optionen: Workout-Assistent (personalisiert), manuell erstellen oder 1-Klick-Workout mit Profil. Enthält WorkoutTileCards mit Kontextmenüs zum Starten, Bearbeiten, Löschen, Duplizieren, Teilen und Home-Favoriten setzen. Navigiert zu WorkoutDetailView, EditWorkoutView und WorkoutWizardView.

## WizardSelectionStepView
**Dateipfad:** /Users/benkohler/Projekte/gym-app/GymTracker/Views/WizardSelectionStepView.swift
**Beschreibung:** Eine generische View-Komponente für Auswahlschritte im Workout-Wizard. Zeigt einen Titel, Untertitel und eine Liste von SelectionCards für verschiedene Optionen (z.B. ExperienceLevel, FitnessGoal, etc.). Wird in WorkoutWizardView für jeden Schritt wiederverwendet.

## ProfileImageView
**Dateipfad:** /Users/benkohler/Projekte/gym-app/GymTracker/Views/ProfileImageView.swift
**Beschreibung:** Eine wiederverwendbare Komponente zur Anzeige des Profilbilds. Zeigt entweder das übergebene UIImage oder ein Standard-Person-Icon. Das Bild wird als Kreis mit Schatten und leichtem Overlay-Stroke dargestellt. Unterstützt verschiedene Größen über den size-Parameter.

## StartView
**Dateipfad:** /Users/benkohler/Projekte/gym-app/GymTracker/ViewModels/StartView.swift
**Beschreibung:** Eine Design-Vorschau-View im Apple-Stil mit dunklem Hintergrund, Suchleiste, großem Titel "Starte deine Trainingsreise", Avatar-Reihe und Beispiel-Workout-Liste. Scheint eine Konzept-/Design-Referenz zu sein und wird wahrscheinlich nicht in der aktiven App verwendet.

## BackupView
**Dateipfad:** /Users/benkohler/Projekte/gym-app/GymTracker/BackupView.swift
**Beschreibung:** Verwaltet Backup und Wiederherstellung aller App-Daten. Ermöglicht Export von Workouts, Übungen, Sessions und Profildaten als JSON-Datei. Import mit drei Merge-Strategien: alles ersetzen, zusammenführen oder nur fehlende Daten hinzufügen. Zeigt Statistiken (Anzahl Workouts, Übungen, Sessions) und wichtige Sicherheitshinweise. Verwendet BackupManager für die eigentliche Datenverwaltung.

## HealthKitSetupView
**Dateipfad:** /Users/benkohler/Projekte/gym-app/GymTracker/HealthKitSetupView.swift
**Beschreibung:** Onboarding-View für HealthKit-Integration. Erklärt die Vorteile: automatischer Profildaten-Import, Workout-Synchronisation und Herzfrequenz-Tracking. Fordert Berechtigungen an und zeigt Fehler-Alerts bei Problemen. Kann übersprungen werden und später in den Einstellungen aktiviert werden.

## HeartRateView
**Dateipfad:** /Users/benkohler/Projekte/gym-app/GymTracker/HeartRateView.swift
**Beschreibung:** Zeigt Herzfrequenzdaten aus HealthKit an. Bietet Zeitraum-Auswahl (1h, 24h, Woche, Monat) und zeigt Durchschnitt, Maximum und Minimum in StatCards. Enthält ein Linien-Chart mit Farbverlauf für die Herzfrequenz-Visualisierung. Fordert HealthKit-Berechtigung an, wenn nicht autorisiert, und zeigt "Keine Daten"-Meldung bei leerem Zeitraum.

## WorkoutsView
**Dateipfad:** /Users/benkohler/Projekte/gym-app/GymTracker/Views/WorkoutsView.swift
**Beschreibung:** Eine einfache Listen-View aller Workouts mit Swipe-to-Delete. Zeigt WorkoutRowView-Komponenten mit Name, Datum und Anzahl der Übungen. Hat einen Button "Neues Workout anlegen" am unteren Bildschirmrand. Navigiert zu WorkoutDetailView beim Antippen und öffnet AddWorkoutView für neue Workouts.

## ProfileView
**Dateipfad:** /Users/benkohler/Projekte/gym-app/GymTracker/Views/ProfileView.swift
**Beschreibung:** Kompakte Profil-Karte mit Gradient-Hintergrund (MossGreen zu DeepBlue). Zeigt Profilbild, Name, Alter, Gewicht und das aktuelle Trainingsziel mit Icon und Farbe. Hat einen "Bearbeiten"-Button zum Öffnen von ProfileEditView. Aktualisiert sich automatisch über profileUpdateTrigger.

## WorkoutWizardView
**Dateipfad:** /Users/benkohler/Projekte/gym-app/GymTracker/Views/WorkoutWizardView.swift
**Beschreibung:** Mehrstufiger Assistent zur Erstellung personalisierter Workouts. Fünf Schritte: Erfahrungslevel, Trainingsziel, Trainingsfrequenz, Equipment und Dauer. Zeigt einen Fortschrittsbalken und bietet einen "Schnellstart mit Profil"-Button, der Ziel und Frequenz aus dem Benutzerprofil übernimmt. Generiert am Ende ein Workout und zeigt es in GeneratedWorkoutPreviewView zur Bestätigung.

## AddExerciseView
**Dateipfad:** /Users/benkohler/Projekte/gym-app/GymTracker/Views/AddExerciseView.swift
**Beschreibung:** Formular zum Erstellen neuer Übungen. Eingabefelder für Name, Beschreibung, Muskelgruppen (mehrfach auswählbar als Chips) und optionale Schritt-für-Schritt-Anweisungen. Prüft auf doppelte Übungsnamen vor dem Speichern. Speichert neue ExerciseEntity in SwiftData.

## EditExerciseView
**Dateipfad:** /Users/benkohler/Projekte/gym-app/GymTracker/Views/EditExerciseView.swift
**Beschreibung:** Formular zum Bearbeiten bestehender Übungen. Zeigt Name, Beschreibung und Muskelgruppen-Auswahl als interaktive Chips. Hat einen "Übung löschen"-Button mit Bestätigungs-Alert. Speichert Änderungen über Callback-Funktionen (saveAction, deleteAction) statt direkt in SwiftData.

## ExercisesView
**Dateipfad:** /Users/benkohler/Projekte/gym-app/GymTracker/Views/ExercisesView.swift
**Beschreibung:** Verwaltet die Übungsdatenbank mit Suche und Filtern. Zeigt Anzahl der hinterlegten Übungen, scrollbare Liste mit ExerciseRowView-Komponenten. LiquidGlassSearchBar am unteren Rand mit Glasmorphismus-Design für Suche nach Name/Muskelgruppe. FilterSheet mit Muskelgruppen- und Equipment-Filtern. Debounced Search für Performance. Plus-Button zum Hinzufügen neuer Übungen.

## EditWorkoutView
**Dateipfad:** /Users/benkohler/Projekte/gym-app/GymTracker/Views/EditWorkoutView.swift
**Beschreibung:** Komplexer Editor für Workout-Vorlagen. Header-Card mit Name, Notizen und Standard-Pausenzeit. Workout-Übungen in drei Modi: CollapsedExerciseRow (Zusammenfassung), QuickEditView (Bulk-Bearbeitung aller Sätze) und ExpandedSetListView (einzelne Sätze in Tabellenform). ReorderModeOverlay für Drag-and-Drop-Neuordnung. ExercisePickerView zum Hinzufügen neuer Übungen. Speichert Änderungen direkt in WorkoutEntity.

## RecoveryModeView
**Dateipfad:** /Users/benkohler/Projekte/gym-app/GymTracker/Views/RecoveryModeView.swift
**Beschreibung:** Fehlerbehandlungs-View, wenn die Datenbank nicht initialisiert werden kann. Zeigt Diagnose-Informationen (Fehlerdetails, iOS-Version, Gerätemodell, freier Speicher), Lösungsvorschläge (Speicher freigeben, Neustart, Neuinstallation) und Action-Buttons ("App neu starten", "Diagnose anzeigen"). Verhindert App-Absturz durch benutzerfreundliche Fehlerbehandlung.

## AddWorkoutView
**Dateipfad:** /Users/benkohler/Projekte/gym-app/GymTracker/Views/AddWorkoutView.swift
**Beschreibung:** Formular zur manuellen Erstellung neuer Workouts. Eingabe für Name, Datum, Notizen und Standard-Pausenzeit. ExercisePickerView zum Auswählen von Übungen mit Anzeige der letzten verwendeten Gewichte/Sätze. Stepper für Anzahl Sätze und Gewicht pro Übung. Erstellt WorkoutEntity mit voreingestellten Sets. Markiert Onboarding-Schritt "hasCreatedFirstWorkout" als abgeschlossen.

## ExercisePickerView
**Dateipfad:** /Users/benkohler/Projekte/gym-app/GymTracker/Views/ExercisePickerView.swift
**Beschreibung:** Durchsuchbare Liste aller Übungen zum Hinzufügen zu Workouts. Horizontale Muskelgruppen-Filter-Chips mit "Alle"-Option. Zeigt Übungen mit Namen und Muskelgruppen als Untertitel. Plus/Checkmark-Button zum Hinzufügen/Entfernen (Callbacks: onAdd, onRemove). Suchleiste und Plus-Button zum Erstellen neuer Übungen. Verwendet ExerciseEntity aus SwiftData.

## ExerciseSwapView
**Dateipfad:** /Users/benkohler/Projekte/gym-app/GymTracker/Views/ExerciseSwapView.swift
**Beschreibung:** Intelligente Übungs-Austausch-View für Workouts. Zeigt aktuelle Übung mit Details (Muskelgruppen, Schwierigkeit, Equipment). Findet ähnliche Übungen über WorkoutStore.getSimilarExercises() mit Similarity-Score. Drei Filter: Alle, Mein Level, Gleiches Equipment. ExerciseSimilarityCards zeigen Match-Prozent, DifficultyBadge und "Passt zu deinem Level"-Indikator. Tauscht Übung über Callback aus, behält Sets bei.

## GeneratedWorkoutPreviewView
**Dateipfad:** /Users/benkohler/Projekte/gym-app/GymTracker/Views/GeneratedWorkoutPreviewView.swift
**Beschreibung:** Vorschau für vom Wizard generierte Workouts. Zeigt Header mit Hinweis "Erstellt mit deinem Profil" (wenn usedProfileInfo true), WorkoutStatsCard (Übungen, geschätzte Dauer, Pause), editierbare Übungsliste. ExercisePreviewCards mit Swap-Button zum Austauschen einzelner Übungen. Bearbeitungsmodus mit EditableExerciseCard für Sätze und Wiederholungen. Name-Input und "Speichern"-Button zum Finalisieren.

## SettingsView
**Dateipfad:** /Users/benkohler/Projekte/gym-app/GymTracker/Views/SettingsView.swift
**Beschreibung:** Zentrale Einstellungen-View mit ProfileView, Wochenziel-Stepper, SettingsCards für Übungen, Backup, Workout-Import (CSV), HealthKit-Integration, Benachrichtigungen-Toggle und "App zurücksetzen"-Button mit doppelter Bestätigung. CSV-Import unterstützt eigene CSVs, Strong und Hevy mit automatischer Format-Erkennung. Zeigt Import-Progress-Overlay. Popover mit detaillierter Import-Hilfe.

## StatisticsView
**Dateipfad:** /Users/benkohler/Projekte/gym-app/GymTracker/Views/StatisticsView.swift
**Beschreibung:** Insights-Tab mit modernem Karten-Design. FloatingInsightsHeader mit Kalender-Button, HeroStreakCard (Wochen-Streak, Wochenziel-Fortschritt), SmartTipsCard (KI-Coach-Tipps), QuickStatsGrid (Trainings/Monat, Volumen/Woche, neue PRs, Volumen-Trend), expandierbares VolumeChartCard, CompactPersonalRecordsCard und CompactHealthCard (nur wenn HealthKit autorisiert). Alle Karten mit Gradient-Hintergründen und Glasmorphismus-Effekten.

## ProfileEditView
**Dateipfad:** /Users/benkohler/Projekte/gym-app/GymTracker/Views/ProfileEditView.swift
**Beschreibung:** Umfassendes Profil-Bearbeitungsformular. Profilbild-Upload (Kamera/Galerie), persönliche Infos (Name, Geburtsdatum, Gewicht, Größe, Geschlecht), "HealthKit importieren"-Button für automatischen Daten-Import, Trainingsziel-Auswahl mit Icons und Beschreibungen, Präferenzen für 1-Klick-Workout (Erfahrung, Equipment, Dauer), HealthKit-Sync-Toggle. Speichert alles in WorkoutStore, markiert Onboarding-Schritt "hasSetupProfile".

## WorkoutDetailView
**Dateipfad:** /Users/benkohler/Projekte/gym-app/GymTracker/Views/WorkoutDetailView.swift
**Beschreibung:** Die zentrale View zum Durchführen und Anzeigen von Workouts. Hat zwei Modi: ActiveWorkoutNavigationView (horizontales Swipe-Interface für aktive Workouts mit Live-Timer und Rest-Timer) oder Listen-Interface (für Vorlagen). Drei Tabs: Überblick (aktuelle Werte), Fortschritt (letzte Sessions), Veränderung (Vergleich). Zeigt REST-Timer-Section, Übungen mit Sets, Checkbox-Completion, Previous-Values, Add/Remove-Set-Buttons. Completion-Section mit Workout-Statistiken, WorkoutCompletionSummaryView bei Abschluss. Notizen-Section mit inline Editor.
