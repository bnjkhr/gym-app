# GymBo v2.0 - UX/UI Konzept & User Flows
**Nutzerzentriertes Design für optimale Workout Experience**

**Version:** 2.0.0
**Erstellt:** 2025-10-21
**Status:** Design Phase

---

## Inhaltsverzeichnis

1. [Design-Philosophie](#design-philosophie)
2. [Analyse v1.x UI (Was funktioniert, was nicht)](#analyse-v1x-ui)
3. [Tab-Bar-Struktur v2.0](#tab-bar-struktur-v20)
4. [View-Hierarchie & Navigation](#view-hierarchie--navigation)
5. [User Flows (Step-by-Step)](#user-flows)
6. [Feature-Priorisierung](#feature-priorisierung)
7. [Interaction Design](#interaction-design)
8. [Accessibility & Usability](#accessibility--usability)
9. [Onboarding-Flow](#onboarding-flow)
10. [Vergleich v1.x vs v2.0](#vergleich-v1x-vs-v20)

---

## Design-Philosophie

### 🎯 Core Principles

#### 1. **Workout-First Design**
> "Der Nutzer kommt zum Trainieren, nicht um eine App zu bedienen"

- **Minimale Taps** von Home bis Training: **2 Taps**
- **Keine Ablenkungen** während des Workouts
- **Schneller Zugriff** auf häufige Aktionen

#### 2. **Progressive Disclosure**
> "Zeige nur, was jetzt relevant ist"

- Anfänger sehen **einfache Optionen**
- Fortgeschrittene bekommen **erweiterte Features**
- Komplexität wächst mit Nutzung

#### 3. **Glanceable Information**
> "Wichtige Infos auf einen Blick"

- **Große Zahlen** für schnelles Erfassen
- **Farbcodierung** für Status (Grün = gut, Orange = Achtung)
- **Visuelle Hierarchie** statt Text-Wände

#### 4. **Contextual Actions**
> "Die richtigen Buttons zur richtigen Zeit"

- **Floating Action Button** für primäre Aktion im Context
- **Swipe Gestures** für häufige Aktionen
- **Long Press** für erweiterte Optionen

#### 5. **Consistent & Predictable**
> "Gleiche Patterns = weniger Denkaufwand"

- **Tab Bar** bleibt immer sichtbar
- **Navigation Bar** konsistente Actions
- **Farbschema** durchgängig (Power Orange = Primary)

---

## Analyse v1.x UI

### ✅ Was gut funktioniert

| Feature | Warum es funktioniert | Behalten? |
|---------|----------------------|-----------|
| **Home Tab Dashboard** | Schneller Überblick, personalisiert | ✅ Verbessern |
| **Active Workout Bar** | Immer sichtbar, Quick Actions | ✅ Ja |
| **Horizontal Exercise Swipe** | Schnelle Navigation im Workout | ✅ Ja |
| **Rest Timer Integration** | Wall-Clock, überlebt Force Quit | ✅ Ja |
| **HealthKit Integration** | Automatisch, transparent | ✅ Ja |
| **AI Coach Tips** | Personalisiert, hilfreich | ✅ Verbessern |
| **Glassmorphism Design** | Modern, ansprechend | ✅ Ja |

### ❌ Was nicht optimal ist

| Problem | Impact | v2.0 Lösung |
|---------|--------|-------------|
| **3 Tabs** (Home, Workouts, Insights) | **Verwirrend** - Home = Workouts? | **4 Tabs** mit klarer Trennung |
| **Workouts Tab zu voll** | Überwältigend, unübersichtlich | Aufteilen: Library + Wizard |
| **Statistics versteckt** | Wichtige Infos schwer zu finden | Eigener Tab + Home-Integration |
| **Kein Profil-Tab** | Settings versteckt im Hamburger-Menü | Eigener Profile-Tab |
| **Workout Wizard versteckt** | Klasse Feature, aber schwer zu finden | Prominenter platzieren |
| **Exercise Swap komplex** | Zu viele Taps | Vereinfachen, direkter Zugriff |
| **Sessions History** | Nur in Statistics, kein direkter Zugriff | Eigene Section in Training-Tab |

---

## Tab-Bar-Struktur v2.0

### 📱 4 Haupt-Tabs (Bottom Navigation)

```
┌──────────────────────────────────────────────────────┐
│                                                       │
│                   CONTENT AREA                        │
│                                                       │
│                                                       │
└──────────────────────────────────────────────────────┘
┌──────────┬──────────┬──────────┬──────────┬─────────┐
│  🏠       │  💪      │  📊      │  👤      │         │
│  Home    │  Train   │ Progress │ Profile  │         │
└──────────┴──────────┴──────────┴──────────┴─────────┘
```

### Tab 1: 🏠 Home (Schnellzugriff & Übersicht)

**Icon:** `house.fill`
**Primäre Funktion:** Dashboard & Quick Actions

**Inhalt:**
```
┌─────────────────────────────────────────┐
│ Header                                   │
│ • Zeitbasierte Begrüßung                │
│ • Streak-Badge                          │
│ • Quick Actions (Settings, Profile)     │
├─────────────────────────────────────────┤
│ Active Workout Card (falls aktiv)       │
│ • Aktuelles Workout                     │
│ • Timer, Sets completed                 │
│ • "Fortsetzen" CTA                      │
├─────────────────────────────────────────┤
│ Today's Focus (AI-generiert)            │
│ • "Heute ist Push Day!" oder            │
│ • "Rest Day - 1 Tag seit letztem Pull" │
│ • Quick Start Button                    │
├─────────────────────────────────────────┤
│ Week at a Glance                        │
│ • Mini-Kalender (7 Tage)                │
│ • Workout-Dots auf Tagen                │
│ • Streak-Visualisierung                 │
├─────────────────────────────────────────┤
│ Quick Stats (4 Cards horizontal)        │
│ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐   │
│ │ 12 💪│ │450kg │ │ 5:30 │ │ 142  │   │
│ │  This│ │Volume│ │ Avg  │ │ BPM  │   │
│ │ Week │ │      │ │ Time │ │      │   │
│ └──────┘ └──────┘ └──────┘ └──────┘   │
├─────────────────────────────────────────┤
│ Favorites (Horizontal Scroll)           │
│ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐   │
│ │ Push │ │ Pull │ │ Legs │ │  +   │   │
│ │ Day  │ │ Day  │ │      │ │ More │   │
│ └──────┘ └──────┘ └──────┘ └──────┘   │
│ • Tap = Start Workout                  │
│ • Long Press = Edit                    │
├─────────────────────────────────────────┤
│ AI Coach Tip (1 prominent)              │
│ "💡 Increase bench press weight"        │
│ "You've hit 10 reps for 3 weeks"       │
│ • Swipe for more tips                  │
└─────────────────────────────────────────┘
```

**Warum Home wichtig ist:**
- ✅ **Schnellster Weg** zum Training (1 Tap)
- ✅ **Motivierend** - Zeigt Fortschritt sofort
- ✅ **Personalisiert** - AI schlägt vor, was heute Sinn macht
- ✅ **Glanceable** - Alle wichtigen Infos auf einen Blick

---

### Tab 2: 💪 Train (Workouts & Sessions)

**Icon:** `dumbbell.fill`
**Primäre Funktion:** Workout-Verwaltung & Ausführung

**Segmented Control (oben):**
```
┌──────────────┬──────────────┬──────────────┐
│  Templates   │   History    │    Create    │
└──────────────┴──────────────┴──────────────┘
```

#### Segment 1: Templates (Workout-Bibliothek)

```
┌─────────────────────────────────────────┐
│ Search Bar                              │
│ 🔍 Suche Workouts...                    │
├─────────────────────────────────────────┤
│ Filter Chips (Horizontal Scroll)        │
│ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐   │
│ │  All │ │ Favs │ │ Push │ │ Pull │   │
│ └──────┘ └──────┘ └──────┘ └──────┘   │
├─────────────────────────────────────────┤
│ Folders (Collapsible Sections)         │
│                                         │
│ 📂 My Workouts (12)                    │
│   ┌─────────────────────────────────┐  │
│   │ Push Day - Upper Body           │  │
│   │ 8 exercises • 45 min • ⭐       │  │
│   └─────────────────────────────────┘  │
│   ┌─────────────────────────────────┐  │
│   │ Pull Day - Back & Biceps        │  │
│   │ 7 exercises • 40 min            │  │
│   └─────────────────────────────────┘  │
│                                         │
│ 📂 Sample Workouts (6)                 │
│   (collapsed)                           │
│                                         │
│ + New Folder                           │
└─────────────────────────────────────────┘
```

**Actions per Workout (Swipe):**
- **Swipe Right:** ▶️ Start Workout
- **Swipe Left:** 🗑️ Delete, ✏️ Edit, 📤 Share, ⭐ Favorite

**Tap:** Öffnet Workout Detail (Preview + Edit)

#### Segment 2: History (Session-Historie)

```
┌─────────────────────────────────────────┐
│ Filter: Last 30 Days ▼                  │
├─────────────────────────────────────────┤
│ Timeline (Grouped by Week)              │
│                                         │
│ Diese Woche (3 Workouts)                │
│ ┌─────────────────────────────────────┐ │
│ │ 🏋️ Push Day                         │ │
│ │ Heute, 14:30 • 42 min               │ │
│ │ 8/8 exercises • 450kg volume        │ │
│ │ ❤️ Avg HR: 142 bpm                  │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ │ 🏋️ Pull Day                         │ │
│ │ Montag, 10:00 • 38 min              │ │
│ │ 7/7 exercises • 380kg volume        │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ Letzte Woche (5 Workouts)               │
│   (collapsed)                           │
│                                         │
│ Vor 2 Wochen (4 Workouts)               │
│   (collapsed)                           │
└─────────────────────────────────────────┘
```

**Tap:** Session Detail View (mit Charts, PRs, etc.)

#### Segment 3: Create (Workout erstellen)

```
┌─────────────────────────────────────────┐
│ 2 große Cards                           │
│                                         │
│ ┌───────────────────────────────────┐   │
│ │  🧠 AI Wizard                     │   │
│ │                                   │   │
│ │  "Lass mich dir ein Workout       │   │
│ │   basierend auf deinen Zielen     │   │
│ │   zusammenstellen"                │   │
│ │                                   │   │
│ │  [Start Wizard] →                │   │
│ └───────────────────────────────────┘   │
│                                         │
│ ┌───────────────────────────────────┐   │
│ │  ✏️ Blank Template                │   │
│ │                                   │   │
│ │  "Erstelle ein leeres Workout     │   │
│ │   von Grund auf"                  │   │
│ │                                   │   │
│ │  [Create Blank] →                │   │
│ └───────────────────────────────────┘   │
│                                         │
│ ┌───────────────────────────────────┐   │
│ │  📋 From Template                 │   │
│ │                                   │   │
│ │  "Wähle ein Sample Workout        │   │
│ │   und passe es an"                │   │
│ │                                   │   │
│ │  [Browse Samples] →              │   │
│ └───────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

**Warum 3 Segments?**
- ✅ **Klare Trennung:** Templates ≠ History ≠ Create
- ✅ **Weniger Überwältigung:** Nicht alles gleichzeitig
- ✅ **Schneller Zugriff:** Swipe zwischen Modi

---

### Tab 3: 📊 Progress (Statistiken & Analysen)

**Icon:** `chart.line.uptrend.xyaxis`
**Primäre Funktion:** Fortschritt visualisieren & verstehen

**Segmented Control:**
```
┌──────────────┬──────────────┬──────────────┐
│   Overview   │   Exercise   │    Body      │
└──────────────┴──────────────┴──────────────┘
```

#### Segment 1: Overview (Gesamtfortschritt)

```
┌─────────────────────────────────────────┐
│ Time Range Picker                       │
│ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐   │
│ │ Week │ │ Month│ │  3M  │ │ Year │   │
│ └──────┘ └──────┘ └──────┘ └──────┘   │
├─────────────────────────────────────────┤
│ Hero Stats (4 large cards)              │
│ ┌──────────────────┬──────────────────┐ │
│ │   42 Workouts    │    18,450 kg    │ │
│ │   This Month     │  Total Volume   │ │
│ │   ▲ +8 vs last   │  ▲ +2,300 kg    │ │
│ └──────────────────┴──────────────────┘ │
│ ┌──────────────────┬──────────────────┐ │
│ │   12h 30min      │    28 Days      │ │
│ │   Total Time     │    Streak       │ │
│ │   ▼ -30min       │  🔥 New Record! │ │
│ └──────────────────┴──────────────────┘ │
├─────────────────────────────────────────┤
│ Volume Chart (Line Chart)               │
│   ▲                                     │
│ kg│         ╱╲                          │
│   │    ╱╲  ╱  ╲  ╱╲                     │
│   │   ╱  ╲╱    ╲╱  ╲                    │
│   └─────────────────────────→ Weeks    │
├─────────────────────────────────────────┤
│ Muscle Group Distribution (Bar Chart)   │
│   Chest  ████████░░ 80%                │
│   Back   ██████░░░░ 60%                │
│   Legs   ███████░░░ 70%                │
│   ...                                   │
├─────────────────────────────────────────┤
│ Week Comparison (Side by Side)         │
│ This Week    vs    Last Week            │
│ 5 Workouts        4 Workouts            │
│ 2,100 kg          1,850 kg              │
│ ▲ +13.5%                                │
├─────────────────────────────────────────┤
│ AI Insights Card                        │
│ "💡 You're training consistently!       │
│  Your chest volume increased 20%        │
│  this month. Consider adding more       │
│  back exercises for balance."           │
└─────────────────────────────────────────┘
```

#### Segment 2: Exercise (Übungs-Statistiken)

```
┌─────────────────────────────────────────┐
│ Search: 🔍 Bench Press                  │
├─────────────────────────────────────────┤
│ Top Exercises (By Volume/Frequency)     │
│                                         │
│ 1. Bench Press                          │
│    ├─ 42 sessions this month            │
│    ├─ 3,200 kg total volume             │
│    ├─ PR: 100kg x 8 reps                │
│    └─ [View Details] →                 │
│                                         │
│ 2. Squat                                │
│    ├─ 38 sessions                       │
│    ├─ 4,500 kg volume                   │
│    └─ PR: 120kg x 6 reps                │
│                                         │
│ 3. Deadlift                             │
│    ...                                  │
└─────────────────────────────────────────┘
```

**Exercise Detail View:**
```
┌─────────────────────────────────────────┐
│ Bench Press                             │
├─────────────────────────────────────────┤
│ Personal Records                        │
│ ┌─────────────┬─────────────┬─────────┐ │
│ │ Max Weight  │  Max Reps   │  1RM    │ │
│ │   100 kg    │  15 reps    │ 115 kg  │ │
│ │   x8 reps   │  @70kg      │ Brzycki │ │
│ │ 5 days ago  │ 2 weeks ago │         │ │
│ └─────────────┴─────────────┴─────────┘ │
├─────────────────────────────────────────┤
│ Progress Chart (Weight over Time)       │
│   ▲                                     │
│ kg│              ╱                      │
│   │         ╱───╱                       │
│   │    ╱───╱                            │
│   └─────────────────────────→ Date     │
├─────────────────────────────────────────┤
│ Volume Distribution                     │
│ • 45% Heavy (1-5 reps)                  │
│ • 35% Moderate (6-12 reps)              │
│ • 20% Light (13+ reps)                  │
├─────────────────────────────────────────┤
│ Recent Sessions (Last 10)               │
│ ┌─────────────────────────────────────┐ │
│ │ Today: 4 sets x 90kg x 8 reps       │ │
│ │ Volume: 2,880 kg                    │ │
│ └─────────────────────────────────────┘ │
│ ┌─────────────────────────────────────┐ │
│ │ 3 days ago: 4 x 85kg x 10           │ │
│ └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

#### Segment 3: Body (Körper-Metriken)

```
┌─────────────────────────────────────────┐
│ HealthKit Integration                   │
│ ┌─────────────────────────────────────┐ │
│ │ ❤️ Heart Rate Trends                │ │
│ │ Avg: 142 bpm • Peak: 178 bpm       │ │
│ │ [View in Health App] →             │ │
│ └─────────────────────────────────────┘ │
├─────────────────────────────────────────┤
│ Body Measurements                       │
│ ┌──────────────────┬──────────────────┐ │
│ │   Weight         │    Height       │ │
│ │   82.5 kg        │    180 cm       │ │
│ │   ▲ +0.3kg       │                 │ │
│ └──────────────────┴──────────────────┘ │
│                                         │
│ Weight Chart (3 months)                 │
│   ▲                                     │
│ kg│     ╱╲  ╱╲                          │
│   │  ╱╲╱  ╲╱  ╲╱╲                       │
│   └─────────────────────────→ Weeks    │
├─────────────────────────────────────────┤
│ Calories & Activity                     │
│ • Active Energy: 450 kcal/day avg      │
│ • Total Energy: 2,800 kcal/day avg     │
│ • Steps: 8,500 steps/day avg           │
└─────────────────────────────────────────┘
```

**Warum Progress eigener Tab?**
- ✅ **Motivation:** Fortschritt sehen = weiter machen
- ✅ **Insights:** AI-gestützte Empfehlungen
- ✅ **Transparenz:** Alle Daten an einem Ort

---

### Tab 4: 👤 Profile (Einstellungen & Account)

**Icon:** `person.fill`
**Primäre Funktion:** Benutzerprofil & App-Einstellungen

```
┌─────────────────────────────────────────┐
│ Header (Avatar + Name)                  │
│ ┌───────┐                               │
│ │       │  Max Mustermann               │
│ │  👤   │  Intermediate • 28 Tage 🔥    │
│ │       │  [Edit Profile]               │
│ └───────┘                               │
├─────────────────────────────────────────┤
│ Quick Stats Summary                     │
│ ┌─────────────────────────────────────┐ │
│ │ Total Workouts: 342                 │ │
│ │ Total Volume: 125,000 kg            │ │
│ │ Member since: Jan 2025              │ │
│ └─────────────────────────────────────┘ │
├─────────────────────────────────────────┤
│ Profile                                 │
│ ┌─────────────────────────────────────┐ │
│ │ 📸 Profile Picture                  │ │
│ │ 🎯 Goals & Preferences              │ │
│ │ 📏 Body Measurements                │ │
│ │ 🔒 Locker Number                    │ │
│ └─────────────────────────────────────┘ │
├─────────────────────────────────────────┤
│ App Settings                            │
│ ┌─────────────────────────────────────┐ │
│ │ 🔔 Notifications                    │ │
│ │ ❤️ HealthKit Integration            │ │
│ │ 🎨 Appearance (Light/Dark/Auto)     │ │
│ │ 📊 Units (kg/lbs, cm/ft)            │ │
│ │ 🔊 Sounds & Haptics                 │ │
│ └─────────────────────────────────────┘ │
├─────────────────────────────────────────┤
│ Data & Backup                           │
│ ┌─────────────────────────────────────┐ │
│ │ 💾 Export Data                      │ │
│ │ 📥 Import Workouts                  │ │
│ │ 🗑️ Clear Cache                      │ │
│ └─────────────────────────────────────┘ │
├─────────────────────────────────────────┤
│ About                                   │
│ ┌─────────────────────────────────────┐ │
│ │ ℹ️ App Version 2.0.0                │ │
│ │ 📖 Help & FAQ                       │ │
│ │ 🐛 Report a Bug                     │ │
│ │ ⭐ Rate on App Store                │ │
│ │ 🔒 Privacy Policy                   │ │
│ └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

**Warum Profile eigener Tab?**
- ✅ **Sichtbarkeit:** Einstellungen nicht mehr versteckt
- ✅ **Personalisierung:** Profil im Fokus
- ✅ **Standard:** Üblich in modernen Apps (Instagram, Twitter, etc.)

---

## View-Hierarchie & Navigation

### 🗺️ Complete Navigation Map

```
App Launch
    │
    ▼
┌───────────────────────────────────────────────────┐
│              Tab Bar Container                    │
│  ┌──────┬──────┬──────┬──────┐                   │
│  │ Home │Train │Progr.│Profil│                   │
│  └──┬───┴───┬──┴───┬──┴───┬──┘                   │
└─────┼───────┼──────┼──────┼────────────────────────┘
      │       │      │      │
      │       │      │      └─▶ Profile View
      │       │      │          ├─ Edit Profile
      │       │      │          ├─ Settings Detail
      │       │      │          └─ About/Help
      │       │      │
      │       │      └─▶ Progress View
      │       │          ├─ Segment: Overview
      │       │          ├─ Segment: Exercise
      │       │          │   └─ Exercise Detail
      │       │          └─ Segment: Body
      │       │
      │       └─▶ Train View
      │           ├─ Segment: Templates
      │           │   ├─ Workout Detail (Sheet)
      │           │   │   └─ Edit Workout
      │           │   └─ Start Workout
      │           │       └─ Active Workout View ★
      │           │           ├─ Exercise List (Swipe)
      │           │           ├─ Rest Timer
      │           │           └─ Complete Session
      │           │
      │           ├─ Segment: History
      │           │   └─ Session Detail (Sheet)
      │           │       ├─ Session Stats
      │           │       └─ Compare with Previous
      │           │
      │           └─ Segment: Create
      │               ├─ AI Wizard Flow
      │               │   ├─ Goal Selection
      │               │   ├─ Equipment
      │               │   ├─ Duration
      │               │   └─ Generated Preview
      │               ├─ Blank Workout
      │               └─ From Template
      │
      └─▶ Home View
          ├─ Active Workout Bar (if active)
          │   └─ Resume → Active Workout View ★
          ├─ Quick Start Favorite
          │   └─ Active Workout View ★
          ├─ Week Calendar
          │   └─ Calendar Detail (Sheet)
          ├─ AI Coach Tip
          │   └─ Tips List (Sheet)
          └─ Settings/Profile Icons
              └─ Navigate to respective tabs
```

**★ Active Workout View** ist der zentrale Workout-Bildschirm, erreichbar von:
- Home Tab (Resume Active)
- Home Tab (Quick Start Favorite)
- Train Tab → Templates → Start

### 🎯 Primary Actions per Tab

| Tab | Primary Action | Secondary Actions |
|-----|---------------|-------------------|
| **Home** | Start Favorite Workout | Resume Active, View Calendar |
| **Train** | Start Workout from Templates | Edit, Create, View History |
| **Progress** | View Stats | Filter Time Range, View Exercise Detail |
| **Profile** | Edit Profile | Settings, Export Data |

---

## User Flows

### Flow 1: Neues Workout starten (Schnellster Weg)

```
User öffnet App
    ↓
Home Tab (automatisch)
    ↓
Tap auf Favorite Workout Card
    ↓
Active Workout View öffnet sich
    ↓
Horizontal Swipe zwischen Exercises
    ↓
Tap "Complete Set"
    ↓
Rest Timer startet automatisch
    ↓
... Workout durchführen ...
    ↓
Letzten Satz abschließen
    ↓
"Finish Workout" Button erscheint
    ↓
Tap "Finish"
    ↓
Summary Sheet zeigt Stats
    ↓
Tap "Save" oder "Share"
    ↓
Zurück zu Home Tab

Total Taps: 2 (Favorite → Complete Last Set)
```

### Flow 2: Workout mit AI Wizard erstellen

```
User öffnet App
    ↓
Train Tab → Create Segment
    ↓
Tap "AI Wizard"
    ↓
Step 1: Was ist dein Ziel?
    ├─ Muscle Building
    ├─ Strength
    ├─ Endurance
    └─ General Fitness ✓
    ↓
Step 2: Welches Equipment?
    ├─ Gym (Alles)
    ├─ Home (Hanteln + Bodyweight)
    └─ Bodyweight Only ✓
    ↓
Step 3: Wie viel Zeit?
    ├─ 30 min
    ├─ 45 min ✓
    └─ 60 min
    ↓
AI generiert Workout (2 Sekunden)
    ↓
Preview:
    • 6 Exercises
    • Est. Duration: 42 min
    • Muscle Groups: Full Body
    ↓
Actions:
    ├─ [Start Now]
    ├─ [Edit First]
    └─ [Save to Library]
    ↓
User wählt [Save to Library]
    ↓
Zurück zu Train → Templates
    ↓
Neues Workout erscheint ganz oben

Total Taps: 7 (sehr akzeptabel für komplexen Flow)
```

### Flow 3: Fortschritt für eine Übung checken

```
User öffnet App
    ↓
Progress Tab → Exercise Segment
    ↓
Search "Bench Press" (oder scroll)
    ↓
Tap auf "Bench Press"
    ↓
Exercise Detail View:
    ├─ Personal Records (Max Weight, Reps, 1RM)
    ├─ Progress Chart
    ├─ Volume Distribution
    └─ Recent Sessions
    ↓
User scrollt durch Charts
    ↓
Tap auf "Recent Session" → Session Detail
    ↓
Vollständige Session-Daten
    ↓
Back → Exercise Detail
    ↓
Back → Progress Overview

Total Taps: 2 (Progress Tab → Exercise)
```

### Flow 4: Workout pausieren und später fortsetzen

```
User ist im Active Workout View
    ↓
Tap "..." (More Menu)
    ↓
Tap "Pause Workout"
    ↓
Confirmation:
    "Workout pausieren? Du kannst später fortfahren."
    [Pause] [Cancel]
    ↓
User tappt [Pause]
    ↓
Workout wird gespeichert
    ↓
Zurück zu Home Tab
    ↓
"Paused Workout" Card erscheint:
    "Push Day - Paused at Exercise 3/8"
    [Resume] [End Workout]
    ↓
... später (z.B. nach 2 Stunden) ...
    ↓
User öffnet App
    ↓
Home zeigt "Paused Workout" Card
    ↓
Tap [Resume]
    ↓
Active Workout View öffnet an genau der Stelle
    ↓
User macht weiter

Total Taps: 3 (Pause) + 1 (Resume)
```

### Flow 5: Exercise Swap während Workout

```
User ist im Active Workout View
    bei Exercise "Bench Press"
    ↓
Long Press auf Exercise Name
    ↓
Quick Action Menu:
    ├─ 🔄 Swap Exercise
    ├─ ℹ️ View Instructions
    ├─ ⏭️ Skip Exercise
    └─ ✏️ Edit Sets
    ↓
User tappt "Swap Exercise"
    ↓
Exercise Picker Sheet:
    • Suggested Similar (Top 5):
      ├─ Incline Bench Press ⭐
      ├─ Dumbbell Press
      └─ Push-Ups
    • All Exercises (Search + Filter)
    ↓
User tappt "Incline Bench Press"
    ↓
Confirmation:
    "Replace Bench Press with Incline Bench Press?"
    • Keep same sets/reps
    • Keep previous weight
    [Swap] [Cancel]
    ↓
User tappt [Swap]
    ↓
Exercise wird ersetzt
    ↓
Active Workout View aktualisiert
    ↓
User macht weiter

Total Taps: 3 (Long Press → Swap → Select)
```

---

## Feature-Priorisierung

### 🚀 Must-Have Features (v2.0 Launch)

| Feature | Warum Critical | Tab |
|---------|----------------|-----|
| **Workout Templates** | Core Functionality | Train |
| **Active Workout Execution** | Hauptzweck der App | Train/Home |
| **Rest Timer** | Essentiell für Training | Universal |
| **Session History** | Fortschritt nachvollziehen | Train/Progress |
| **Personal Records** | Motivation | Progress |
| **Basic Statistics** | Feedback & Insights | Progress |
| **AI Coach Tips** | USP der App | Home/Progress |
| **HealthKit Integration** | iOS-Standard | Profile |
| **Profile Management** | Personalisierung | Profile |

### ⭐ Nice-to-Have Features (v2.1+)

| Feature | Warum Nice | Priorität |
|---------|------------|-----------|
| **Social Sharing** | Community-Aspekt | Medium |
| **Workout Challenges** | Gamification | Medium |
| **Apple Watch App** | Gym Convenience | High |
| **Superset Support** | Advanced Training | High |
| **Voice Control** | Hands-free | Low |
| **Exercise Videos** | Form Guidance | High |
| **Offline Mode** | Zuverlässigkeit | High |
| **Workout Reminders** | Consistency | Medium |

### ❌ Out of Scope (v2.0)

- Soziales Netzwerk / Friends
- Meal Tracking / Nutrition
- Workout-Klassen / Videos
- Wearables außer Apple Watch
- Premium / Subscription Model

---

## Interaction Design

### 🎨 Gestures & Patterns

#### Swipe Gestures

| Context | Swipe Direction | Action |
|---------|----------------|--------|
| **Workout in List** | → Right | Start Workout |
| **Workout in List** | ← Left | Delete/Edit Menu |
| **Exercise in Active Workout** | → Right | Next Exercise |
| **Exercise in Active Workout** | ← Left | Previous Exercise |
| **Set Row** | → Right | Complete Set |
| **AI Tip Card** | → Right | Next Tip |
| **AI Tip Card** | ← Left | Previous Tip |

#### Long Press Actions

| Element | Long Press Action |
|---------|------------------|
| **Workout Card** | Edit Menu (Edit, Duplicate, Share, Delete) |
| **Exercise Name** | Quick Actions (Swap, Instructions, Skip) |
| **Set Row** | Edit Weight/Reps inline |
| **Stats Card** | Export as Image |

#### Pull to Refresh

| View | Action |
|------|--------|
| **Home Tab** | Refresh Stats & AI Tips |
| **Train → Templates** | Reload Workout List |
| **Train → History** | Reload Sessions |
| **Progress** | Recalculate Stats |

#### Haptic Feedback

| Event | Haptic |
|-------|--------|
| **Set Completed** | Success (Medium Impact) |
| **Rest Timer Expired** | Notification (Heavy Impact) |
| **PR Achieved** | Success (Heavy Impact) + Sound |
| **Error** | Error (Light Impact) |
| **Navigation** | Selection (Light Impact) |

### 🎯 Floating Action Button (FAB)

**Contextual FAB per Tab:**

| Tab | FAB Icon | Action |
|-----|----------|--------|
| **Home** | `play.fill` | Quick Start (Last Workout oder Favorit) |
| **Train → Templates** | `plus` | Create New Workout |
| **Train → History** | `chart.bar` | Generate Report |
| **Progress** | `arrow.down.doc` | Export Stats |
| **Profile** | `camera` | Update Profile Picture |

**FAB Position:** Bottom-Right, 80px vom Bottom, 20px vom Right Edge

---

## Accessibility & Usability

### ♿ Accessibility Features

#### Dynamic Type Support
- ✅ Alle Texte skalieren mit iOS Dynamic Type
- ✅ Min Size: Body (17pt), Max Size: AX5 (53pt)
- ✅ Layouts passen sich automatisch an

#### VoiceOver
- ✅ Alle interaktiven Elemente haben Labels
- ✅ Custom Rotor für schnelle Navigation
  - Workouts
  - Exercises
  - Sets
  - Actions
- ✅ Hints für komplexe Gestures
  - "Double tap to start workout"
  - "Swipe right to complete set"

#### Reduced Motion
- ✅ Animationen werden deaktiviert/reduziert
- ✅ Crossfade statt Slide Transitions
- ✅ Static Icons statt animierte

#### Color Contrast
- ✅ WCAG AA Standard (4.5:1 für Text)
- ✅ High Contrast Mode Support
- ✅ Keine Information nur über Farbe

#### Reachability
- ✅ Tab Bar am Bottom (Daumen-freundlich)
- ✅ Wichtige Actions im unteren Drittel
- ✅ Große Tap-Targets (min. 44x44pt)

### 👥 Usability Principles

#### Consistency
- ✅ Gleiche Patterns über alle Tabs
- ✅ Konsistente Icon-Verwendung
- ✅ Einheitliche Farbschemata

#### Feedback
- ✅ Jede Aktion gibt visuelles Feedback
- ✅ Loading States für async Operationen
- ✅ Success/Error Messages

#### Error Prevention
- ✅ Confirmations für destruktive Actions
- ✅ Input Validation mit Hints
- ✅ Undo für häufige Actions

#### Efficiency
- ✅ Shortcuts für Power User
- ✅ Quick Actions (3D Touch / Long Press)
- ✅ Keyboard Shortcuts (iPad)

---

## Onboarding-Flow

### 🎓 First Launch Experience

```
App Launch (First Time)
    ↓
┌─────────────────────────────────────┐
│ Welcome Screen                      │
│                                     │
│ "Willkommen bei GymBo!"             │
│ "Dein intelligenter Workout-Partner"│
│                                     │
│ [Los geht's] →                     │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│ Step 1: Dein Ziel                   │
│                                     │
│ "Was möchtest du erreichen?"        │
│ ┌─────────────────────────────────┐ │
│ │ 💪 Muskelaufbau                 │ │
│ │ 🏋️ Kraft steigern              │ │
│ │ 🏃 Ausdauer verbessern          │ │
│ │ 🎯 Allgemeine Fitness           │ │
│ └─────────────────────────────────┘ │
│                                     │
│ [Weiter] →                         │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│ Step 2: Erfahrung                   │
│                                     │
│ "Wie oft trainierst du?"            │
│ ┌─────────────────────────────────┐ │
│ │ 🌱 Anfänger (< 3 Monate)        │ │
│ │ 📈 Fortgeschritten (3-12 M.)    │ │
│ │ 💎 Profi (> 1 Jahr)             │ │
│ └─────────────────────────────────┘ │
│                                     │
│ [Weiter] →                         │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│ Step 3: Equipment                   │
│                                     │
│ "Was steht dir zur Verfügung?"      │
│ ┌─────────────────────────────────┐ │
│ │ 🏢 Fitnessstudio (Alles)        │ │
│ │ 🏠 Heimtraining (Hanteln)       │ │
│ │ 🤸 Nur Bodyweight               │ │
│ └─────────────────────────────────┘ │
│                                     │
│ [Weiter] →                         │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│ Step 4: HealthKit (Optional)        │
│                                     │
│ "HealthKit verbinden?"              │
│ "Sync Gewicht, Herzfrequenz, etc."  │
│                                     │
│ ✓ Gewicht & Größe importieren      │
│ ✓ Herzfrequenz während Training    │
│ ✓ Kalorien exportieren             │
│                                     │
│ [Verbinden] [Später]               │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│ Step 5: Notifications (Optional)    │
│                                     │
│ "Erinnerungen aktivieren?"          │
│ "Bleib am Ball mit Trainings-       │
│  Erinnerungen und Rest-Timer-       │
│  Benachrichtigungen"                │
│                                     │
│ [Aktivieren] [Später]              │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│ All Set! 🎉                         │
│                                     │
│ "Dein Profil ist eingerichtet!"     │
│                                     │
│ "Die AI hat dir 3 passende          │
│  Workouts erstellt, basierend       │
│  auf deinen Angaben."               │
│                                     │
│ [Workouts ansehen] →               │
└─────────────────────────────────────┘
    ↓
Home Tab mit 3 generierten Workouts
```

**Onboarding-Prinzipien:**
- ✅ **Kurz:** Max. 5 Screens
- ✅ **Optional:** Nur kritische Infos sind required
- ✅ **Value First:** Zeige Nutzen, nicht Features
- ✅ **Skip-fähig:** Power User können überspringen
- ✅ **Contextual:** HealthKit/Notifications beim ersten Bedarf

---

## Vergleich v1.x vs v2.0

### 📊 Feature Comparison

| Feature | v1.x | v2.0 | Verbesserung |
|---------|------|------|--------------|
| **Tab-Anzahl** | 3 (Home, Workouts, Insights) | 4 (Home, Train, Progress, Profile) | ✅ Klarere Trennung |
| **Workout Start** | 3-4 Taps | 2 Taps (Home → Favorite) | ✅ 50% schneller |
| **Statistics** | Versteckt in Tab 3 | Eigener Tab mit Segments | ✅ Prominenter |
| **Profile** | Hamburger Menu | Eigener Tab | ✅ Besser erreichbar |
| **AI Wizard** | Versteckt | Prominent in Train → Create | ✅ Höhere Nutzung |
| **Session History** | Nur in Statistics | Train Tab + Progress | ✅ Mehrere Zugangspunkte |
| **Exercise Swap** | Komplex, viele Taps | Long Press → Quick Menu | ✅ 66% weniger Taps |
| **Onboarding** | Minimal | Geführt, personalisiert | ✅ Bessere First Experience |

### 🎯 UX Improvements

| Aspekt | v1.x Problem | v2.0 Lösung |
|--------|-------------|-------------|
| **Navigation** | Unklar wo was ist | 4 klare Tabs mit eindeutigen Rollen |
| **Feature Discovery** | Wizard, Swap versteckt | Prominente Platzierung |
| **Information Hierarchy** | Flach, alles gleichwertig | Hero Stats, dann Details |
| **Context Awareness** | Statisch | FAB ändert sich per Tab |
| **Glanceability** | Viel Text | Große Zahlen, visuelle Hierarchie |
| **Action Speed** | Viele Taps nötig | Swipe Gestures, Long Press |

### 📈 Expected Impact

| Metrik | v1.x | v2.0 Ziel | Begründung |
|--------|------|-----------|------------|
| **Session Start Time** | 8s avg | < 4s | Favoriten auf Home, 2 Taps |
| **Wizard Usage** | 12% | > 40% | Prominente Platzierung |
| **Profile Completion** | 45% | > 80% | Eigener Tab, Onboarding |
| **Daily Active Users** | Baseline | +30% | Bessere UX = höheres Engagement |
| **Feature Adoption** | 60% | > 85% | Klare Navigation |

---

## Zusammenfassung & Empfehlung

### ✅ Key Decisions für v2.0

#### 1. **4-Tab-Struktur statt 3**
**Begründung:**
- Klare Trennung: Schnellzugriff (Home) ≠ Verwaltung (Train) ≠ Analyse (Progress) ≠ Settings (Profile)
- Standard in modernen Apps (Fitness+, Nike Training, Strong)
- Bessere Auffindbarkeit aller Features

#### 2. **Segmented Control in Train & Progress**
**Begründung:**
- Reduziert Überwältigung (nicht alles gleichzeitig)
- Schneller Wechsel zwischen Modi
- Klare mentale Modelle (Templates vs History vs Create)

#### 3. **Home Tab als Dashboard**
**Begründung:**
- Schnellster Weg zum Training (1-2 Taps)
- Motivierend durch sofortige Stats
- Personalisiert durch AI

#### 4. **Prominente AI-Features**
**Begründung:**
- USP der App (nicht von Konkurrenz kopierbar)
- Hoher Nutzen für User
- Aktuell zu versteckt

#### 5. **Gesten statt Taps**
**Begründung:**
- Schneller (Swipe to Complete Set)
- Intuitiver (Long Press for Options)
- iOS-Standard

### 🎯 Nächste Schritte

1. **Wireframes erstellen** für alle 4 Tabs
2. **Prototyp** in Figma/Sketch
3. **User Testing** mit 5-10 Usern
4. **Iteration** basierend auf Feedback
5. **Implementation** nach Technical Concept

---

**Fragen zur Diskussion:**

1. **Tab-Reihenfolge:** Home → Train → Progress → Profile OK? Oder anders?
2. **AI Wizard:** Soll der IMMER prominent sein oder nur für neue User?
3. **Exercise Videos:** v2.0 oder v2.1?
4. **Apple Watch:** Priorität für v2.0?
5. **Offline Mode:** Wie wichtig?

---

**Let's discuss! 🚀**
