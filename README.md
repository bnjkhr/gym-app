# GymBo - iOS Fitness Tracking App

<div align="center">

**Intelligentes Workout-Tracking für iOS mit AI-Coach, HealthKit-Integration und Live Activities**

[![iOS](https://img.shields.io/badge/iOS-17.0+-black.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-blue.svg)](https://developer.apple.com/xcode/swiftui/)
[![SwiftData](https://img.shields.io/badge/SwiftData-green.svg)](https://developer.apple.com/xcode/swiftdata/)
[![License](https://img.shields.io/badge/License-Proprietary-red.svg)](LICENSE)

</div>

---

## 📖 Übersicht

**GymBo (GymTracker)** ist eine hochmoderne native iOS-App für intelligentes Workout-Tracking. Die App kombiniert modernes SwiftUI-Design mit leistungsstarken Features wie:

- 🧠 **AI-Coach** mit personalisierten Trainingstipps
- 💪 **161 vordefinierte Übungen** mit detaillierten Anleitungen
- 📊 **Umfassende Statistiken** und Fortschrittstracking
- ❤️ **HealthKit-Integration** mit Live Heart Rate Monitoring
- 📱 **Live Activities** und Dynamic Island Support
- ⏱️ **Intelligenter Rest-Timer** mit Push-Benachrichtigungen

---

## ✨ Haupt-Features

### 🏋️ Workout-Management
- **Live-Sessions** mit horizontaler Swipe-Navigation zwischen Übungen
- **Workout-Wizard**: KI-gestützter Generator für personalisierte Trainings
- **Home-Favoriten**: Quick Access für bis zu 4 Lieblings-Workouts
- **Workout-Sharing**: Export/Import als `.gymtracker` Dateien
- **Sample Workouts**: Vordefinierte Trainings nach Kategorien

### 📊 Tracking & Statistiken
- **Satz-für-Satz Tracking**: Gewicht, Wiederholungen, Completion-Status
- **Personal Records**: Automatische Erkennung (Max Weight, Max Reps, 1RM)
- **Volume Charts**: Visualisierung mit nativen Charts
- **Wochenstatistiken**: Workouts, Gesamtvolumen, Trainingszeit, Streak
- **Session-Historie**: Vollständige Trainingshistorie mit Detailansicht

### 🧠 Smart Features (AI Coach)
- **15 Analyseregeln** für intelligente Empfehlungen
- **Personalisierte Trainingstipps**: Progression, Balance, Recovery, Consistency
- **Plateau-Erkennung**: Identifiziert Stagnation und gibt Tipps
- **Muscle Group Balance**: Erkennt Ungleichgewichte
- **Previous Values**: Vorschläge basierend auf letzten Trainings

### 🎯 HealthKit-Integration
- **Bidirektionale Sync**: Lesen und Schreiben von Gesundheitsdaten
- **Live Heart Rate**: Echtzeit-Herzfrequenz während Workouts
- **Workout-Export**: Sessions werden als HKWorkout exportiert
- **Profildaten-Import**: Gewicht, Größe, Geburtsdatum

### 📱 Modern iOS Features
- **Live Activities** (iOS 16.1+): Dynamic Island Integration
- **Rest Timer**: Countdown mit Push-Benachrichtigungen
- **Glassmorphism UI**: Modernes Design mit Blur-Effekten
- **Deep Links**: `workout://active` für direkten Zugriff

---

## 🖼️ Screenshots

<div align="center">

| Home | Workout | Statistics | Profile |
|------|---------|------------|---------|
| ![Home](screenshots/home.png) | ![Workout](screenshots/workout.png) | ![Stats](screenshots/stats.png) | ![Profile](screenshots/profile.png) |

</div>

---

## 🚀 Installation

### Voraussetzungen
- **macOS 14.0+** (Sonoma oder neuer)
- **Xcode 15.0+**
- **iOS 17.0+** Device oder Simulator
- **Apple Developer Account** (für HealthKit und Live Activities)

### Build & Run

```bash
# Repository klonen
git clone https://github.com/yourusername/gym-app.git
cd gym-app

# Xcode öffnen
open GymBo.xcodeproj

# In Xcode: Cmd+R zum Starten
```

### Erste Schritte

1. **Onboarding durchlaufen**
   - Profil einrichten (Name, Geburtsdatum, Gewicht, Größe)
   - Beispielworkouts erkunden
   - Erstes eigenes Workout erstellen

2. **HealthKit aktivieren** (optional)
   - Settings → Health → Authorize
   - Profildaten werden automatisch importiert

3. **Notifications aktivieren** (optional)
   - Settings → Notifications → Allow
   - Für Rest-Timer-Benachrichtigungen

4. **Home-Favoriten setzen**
   - Workouts-Tab → Star-Icon bei max. 4 Workouts
   - Schnellzugriff auf dem Home-Tab

---

## 🏗️ Architektur

### MVVM + SwiftUI + SwiftData

```
┌─────────────────────────────────────────────────┐
│                    Views                         │
│   (SwiftUI Views mit @State, @Query, @Binding)  │
└──────────────────┬──────────────────────────────┘
                   ▼
┌─────────────────────────────────────────────────┐
│              ViewModel (WorkoutStore)            │
│  - Session-Management, Rest Timer, Caching      │
└──────────────────┬──────────────────────────────┘
                   ▼
┌─────────────────────────────────────────────────┐
│    Services (WorkoutAnalyzer, TipEngine, etc.)  │
└──────────────────┬──────────────────────────────┘
                   ▼
┌─────────────────────────────────────────────────┐
│     Data Layer (SwiftData + Domain Models)      │
└─────────────────────────────────────────────────┘
```

### Technologie-Stack

- **SwiftUI**: Deklaratives UI-Framework
- **SwiftData**: Persistenz-Layer (iOS 17+)
- **HealthKit**: Gesundheitsdaten-Integration
- **ActivityKit**: Live Activities & Dynamic Island
- **Combine**: Reactive Programming
- **Charts**: Native Datenvisualisierung

---

## 📂 Projektstruktur

```
GymTracker/
├── Models/                   # Domain Models (Structs)
├── Views/                    # SwiftUI Views (23+ Views)
├── ViewModels/               # WorkoutStore, Theme
├── Services/                 # WorkoutAnalyzer, TipEngine
├── Managers/                 # HealthKit, Notifications, Audio
├── LiveActivities/           # Live Activities Controller
├── Database/                 # ModelContainer Factory
├── Migrations/               # Datenbank-Migrationen
├── Seeders/                  # Exercise & Workout Seeders
└── Resources/                # CSV, Sounds
```

Vollständige Projektstruktur siehe [DOCUMENTATION.md](DOCUMENTATION.md).

---

## 📊 Datenmodell

### SwiftData Entities (7 Entities)

- **ExerciseEntity**: 161 vordefinierte Übungen
- **WorkoutEntity**: Trainingsvorlagen
- **WorkoutSessionEntity**: Trainingshistorie
- **ExerciseRecordEntity**: Personal Records
- **UserProfileEntity**: Benutzerprofil
- **WorkoutExerciseEntity** & **ExerciseSetEntity**: Beziehungen

### Domain Models

- **Exercise**: Business Logic + Similarity-Algorithmus
- **Workout**, **WorkoutSession**: Value Types (Structs)
- **TrainingTip**, **WorkoutPreferences**: AI-Coach

Detailliertes Datenmodell siehe [DOCUMENTATION.md](DOCUMENTATION.md#datenmodell).

---

## 🎯 Hauptkomponenten

### 1. WorkoutStore (ViewModel)
Zentrale State-Verwaltung:
- Session-Management (Start/End/Active)
- Rest-Timer mit Wall-Clock-Sync
- Exercise Stats Caching
- Home Favorites Management

### 2. WorkoutAnalyzer (Service)
Intelligente Trainingsanalyse:
- Plateau-Erkennung
- Muscle Group Balance
- Recovery Status
- Consistency Metrics

### 3. TipEngine (Service)
AI-Coach mit 15 Analyseregeln:
- Progressive Overload
- Goal-Specific Recommendations
- Personal Record Recognition
- Feedback-System

### 4. HealthKitManager (Manager)
HealthKit-Integration:
- Bidirektionale Synchronisation
- Live Heart Rate Monitoring
- Workout-Export
- Error Handling mit Timeout

---

## 🔧 Performance-Optimierungen

- ✅ **Cached DateFormatters**: 50ms → 0.001ms
- ✅ **Entity Caching**: Nur bei Änderungen neu mappen
- ✅ **LazyVStack/LazyVGrid**: On-Demand Rendering
- ✅ **Safe Mapping**: Context-basiert mit Refetch
- ✅ **Exercise Stats Caching**: In-Memory-Cache
- ✅ **Background Migrations**: Non-blocking
- ✅ **@Query Optimierung**: Filter auf DB-Ebene

---

## 📖 Dokumentation

Ausführliche Dokumentation finden Sie in:

- **[DOCUMENTATION.md](DOCUMENTATION.md)**: Vollständige technische Dokumentation
  - Views-Übersicht
  - Services & Manager
  - Features im Detail
  - Architektur-Entscheidungen

- **[DATABASE_VERSION_CONTROL.md](DATABASE_VERSION_CONTROL.md)**: Datenbank-Migrationen
- **[VIEWS_DOCUMENTATION.md](VIEWS_DOCUMENTATION.md)**: Views-Dokumentation
- **[HealthKit_Integration_README.md](GymTracker/HealthKit_Integration_README.md)**: HealthKit-Integration

---

## 🐛 Bekannte Limitierungen

### Technical Debt
- WorkoutStore sollte in kleinere Services aufgeteilt werden
- UserProfile-Persistierung via UserDefaults statt SwiftData
- Fehlende Unit Tests für kritische Business Logic

### Constraints
- Home-Favoriten: Max. 4 Workouts (UI-Design-Limitation)
- Live Activities: Nur iOS 16.1+ verfügbar
- HealthKit: Erfordert echtes Device für Testing

---

## 🚧 Roadmap

### Geplante Features
- [ ] Apple Watch Companion App
- [ ] iCloud Sync (Multi-Device)
- [ ] Workout-Templates Marketplace
- [ ] Social Features (Freunde, Challenges)
- [ ] Video-Anleitungen für Übungen
- [ ] Erweiterte Analytics (Trendlinien, Prognosen)
- [ ] Custom Exercises (Benutzer-definiert)
- [ ] Supersets & Circuits
- [ ] Nutrition Tracking
- [ ] iPad-Optimierung

---

## 🤝 Mitwirken

Contributions sind willkommen! Bitte beachten Sie:

### Code Style
- SwiftLint Configuration beachten
- Value Types bevorzugen (Structs over Classes)
- Explicit `self` in Closures
- Kommentare: Deutsch für UI, Englisch für Code

### Pull Request Guidelines
1. Feature Branch erstellen: `git checkout -b feature/my-feature`
2. Änderungen commiten mit aussagekräftiger Message
3. Tests hinzufügen (wenn vorhanden)
4. PR gegen `master` öffnen mit Beschreibung

---

## 📄 Lizenz

**Proprietär** - Alle Rechte vorbehalten

© 2025 Ben Kohler

---

## 📧 Kontakt

Bei Fragen oder Feedback:
- **GitHub Issues**: [Issues erstellen](https://github.com/yourusername/gym-app/issues)
- **Email**: [your.email@example.com](mailto:your.email@example.com)

---

## 🙏 Danksagungen

- **Apple** für SwiftUI, SwiftData, HealthKit und ActivityKit
- **Community** für Feedback und Unterstützung

---

<div align="center">

**Made with ❤️ and Swift**

[⬆ Back to Top](#gymbo---ios-fitness-tracking-app)

---

**Version:** 1.0
**Letzte Aktualisierung:** 2025-10-07
**Autor:** Ben Kohler
**Plattform:** iOS 17.0+
**Sprache:** Swift 5.9+

</div>
