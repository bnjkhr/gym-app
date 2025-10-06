# GymTracker Smart-Konzept

## Ist-Zustand
Die App besitzt eine exzellente technische Grundlage:
- **Personalisierter Einstieg:** Der Workout-Assistent (`WorkoutWizardView.swift`) erstellt bereits individuelle Trainingspläne basierend auf Nutzerpräferenzen (Level, Ziel, Dauer, Frequenz, Equipment).
- **Fokussiertes Training:** Features wie der Rest-Timer, Live Activities und die prominente "Aktive Session"-Anzeige halten den Nutzer während des Workouts im Flow und reduzieren Ablenkungen.
- **Starke Datenbasis:** Die HealthKit-Anbindung (`HealthKitManager.swift`) und die Möglichkeit, Verlaufsdaten aus anderen Apps (z.B. Strong, Hevy) zu importieren (`SettingsView.swift`), schaffen ein reichhaltiges Datenfundament.
- **Robuste Architektur:** Ein durchdachter SwiftData-Startprozess mit Migrations- und Fallback-Logik (`GymTrackerApp.swift`) sowie ein Backup-System (`BackupView.swift`) sichern die Nutzerdaten zuverlässig.

## Potenziale
Trotz der technischen Stärke liegen Potenziale in der intelligenten *Nutzung* der vorhandenen Daten, um die App einfacher und proaktiver zu machen:
- **Statische Progression:** Die Workout-Generierung berücksichtigt noch nicht die tatsächliche Leistung aus vergangenen Trainingseinheiten. Vorschläge für Gewichte und Wiederholungen sind nicht adaptiv.
- **Passive Daten:** Importierte Verlaufsdaten und HealthKit-Werte werden gesammelt, aber noch nicht aktiv genutzt, um dem Nutzer proaktive Empfehlungen für sein nächstes Training zu geben.
- **Fehlende Belastungssteuerung:** Die App gibt keine Rückmeldung, ob das aktuelle Trainingspensum zur Erholung (z.B. aus HealthKit-Schlafdaten) passt. Die Frequenz ist eine statische Vorgabe.
- **Überinformation vs. Entscheidungshilfe:** Die App zeigt viele Daten, könnte aber noch besser darin werden, diese zu einer klaren, handlungsrelevanten Empfehlung zu verdichten (z.B. "Nächstes Mal 2.5 kg mehr bei Kniebeugen").

## Konzept
Das Ziel ist, die App von einem reaktiven Tracker zu einem proaktiven, smarten Partner zu entwickeln, der den Nutzer durch Reduktion und intelligente Vorschläge unterstützt.

### Onboarding & Setup
- Präferenz-Wizard beibehalten, zusätzlich ein leicht verständliches Zielgefühl („stärker fühlen“, „fit bleiben“) abfragen.
- HealthKit-Import sofort nutzen, um Startwerte zu bestätigen und Vertrauen zu schaffen.

### Smarte Session-Erfahrung
**Die "Nächster Satz"-Karte:** Im Workout-Screen wird die Ansicht auf eine zentrale Karte reduziert, die nur die absolut notwendigen Informationen für den *aktuellen* Satz anzeigt:
1.  **Übungsname:** Klar und deutlich.
2.  **Satz-Vorschlag:** Z.B. "8-12 Wdh. mit 60 kg".
3.  **Letztes Ergebnis:** Direkt darunter, z.B. "Letztes Mal: 10 Wdh. mit 57.5 kg".
4.  **Eingabefelder:** Minimalistische Stepper für Gewicht und Wiederholungen.

Nach Abschluss eines Satzes verwandelt sich die Karte in den Rest-Timer und zeigt bereits den Vorschlag für den nächsten Satz an.

### Adaptive Progression
**Progressive Overload Automatik:** Eine einfache Logik, die nach jeder Übung die Vorschläge für das nächste Mal anpasst.
- **Regel:** "Wenn du im letzten Satz die obere Grenze des Wiederholungsziels erreicht hast, erhöhe das Gewicht für das nächste Training um die kleinstmögliche Einheit (z.B. 2.5 kg)."
- **UI-Feedback:** Ein kleines Badge auf der "Nächster Satz"-Karte zeigt die Empfehlung an: „+2,5 kg Vorschlag“. Dies nimmt dem Nutzer die Denkarbeit ab, wie er sich steigern soll.

### Recovery & Tagesfokus
**Kontextbezogene Tagesempfehlung:** Nutze HealthKit-Daten, um den Home-Screen oder eine Benachrichtigung anzupassen.
- **Signal:** Hat der Nutzer deutlich weniger geschlafen als üblich oder ist der Ruhepuls erhöht?
- **Empfehlung:** Statt des geplanten schweren Workouts könnte die App vorschlagen: "Du scheinst heute eine Pause zu brauchen. Wie wäre es mit einem leichten Cardio-Training oder einem Ruhetag?" oder "Heute vielleicht etwas leichter trainieren?".

### Insights & Motivation
**Das "Smart Summary":** Reduziere die Statistik-Ansicht auf eine wöchentliche Zusammenfassung, die motiviert statt zu überfordern.
- **Highlight der Woche:** "Stark! Du hast dein Gewicht beim Bankdrücken um 2.5 kg gesteigert."
- **Konsistenz-Check:** "3 von 3 geplanten Workouts diese Woche geschafft. Super!"
- **Ausblick:** "Nächste Woche liegt der Fokus auf Bein-Kraft."

Detaillierte Graphen bleiben für Power-User auf einer zweiten Ebene verfügbar.

## Nächste Schritte
1.  **Adaptive Vorschläge implementieren:** Entwickle die Logik für die automatische Anpassung von Gewicht/Wiederholungen basierend auf den `WorkoutSessionEntity`-Daten. Integriere die Empfehlung in die `WorkoutDetailView`.
2.  **"Nächster Satz"-Karte entwerfen:** Gestalte die `WorkoutDetailView` neu, um den Fokus auf die zentrale Karte für den aktuellen Satz zu legen.
3.  **HealthKit-Signale nutzen:** Implementiere eine einfache Logik, die z.B. Schlafdaten oder den Ruhepuls aus dem `HealthKitManager` abruft und eine simple Tagesempfehlung ableitet.
4.  **Smart Summary entwickeln:** Erstelle eine neue View, die wöchentliche Highlights aus den `WorkoutSessionEntity`-Daten generiert und prägnant darstellt.
