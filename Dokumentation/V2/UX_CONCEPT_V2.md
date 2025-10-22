# GymBo v2.0 - UX/UI Konzept & User Flows
**Nutzerzentriertes Design für optimale Workout Experience**

**Version:** 2.0.0
**Erstellt:** 2025-10-21
**Aktualisiert:** 2025-10-22
**Status:** ✅ Active Workout UI IMPLEMENTIERT | 🔄 Architecture Implementation

---

## 🎉 Implementation Status Update (2025-10-22)

### ✅ FERTIG: Active Workout UI (Phase 1-7 Complete)

Die **Active Workout View** wurde vollständig implementiert und getestet im `archive/v2-ui-experiments` Branch:

**Implementierte Komponenten (3762 LOC):**
- ✅ `ActiveWorkoutSheetView.swift` (676 LOC) - Modal Sheet Container
- ✅ `ExerciseCard.swift` (297 LOC) - Übungs-Karte mit Sets
- ✅ `TimerSection.swift` (354 LOC) - Rest Timer + Workout Duration
- ✅ `CompactSetRow.swift` (182 LOC) - Einzelne Set-Zeile
- ✅ `DraggableExerciseSheet.swift` (110 LOC) - Draggable Sheet mit Gesture Handling
- ✅ `EdgeCaseTests.swift` (257 LOC) - Comprehensive Testing

**Features:**
- ✅ Modal Sheet Presentation (Drag-to-Dismiss)
- ✅ Live Timers (Rest + Workout Duration, 1s updates)
- ✅ Haptic Feedback (Light, Success, Warning, Selection)
- ✅ Swipe-to-Delete Sets
- ✅ Fade-out/Slide-up Transitions für completed exercises
- ✅ Exercise Counter + Show/Hide Toggle
- ✅ Universal In-App Notification System ("Nächste Übung")
- ✅ Keyboard Dismiss on Scroll
- ✅ Dark Mode Compatible
- ✅ Edge Case Testing (8/8 cases, 1 critical bug fixed)

**User Testing:** ✅ Complete (basierend auf User Screenshots & Feedback)

**Nächster Schritt:** Integration in Clean Architecture (siehe Plan unten)

---

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
- **App übernimmt die Arbeit:** Auswertungen, Progression, Empfehlungen automatisch

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
│  Start   │Training  │Fortschritt│ Profil  │         │
└──────────┴──────────┴──────────┴──────────┴─────────┘
```

### Tab 1: 🏠 Start (Schnellzugriff & Übersicht)

**Icon:** `house.fill`
**Primäre Funktion:** Dashboard & Schnellzugriff

> ⚠️ **HINWEIS:** Dieser Tab ist aktuell zu voll und wird noch vereinfacht.
> Prinzip: "So einfach wie möglich - App übernimmt die Arbeit"

**Inhalt:**
```
┌─────────────────────────────────────────┐
│ Kopfzeile                               │
│ • Zeitbasierte Begrüßung                │
│ • Streak-Badge                          │
│ • Schnellzugriff (Einstellungen, Profil)│
├─────────────────────────────────────────┤
│ Aktives Workout (falls aktiv)           │
│ • Aktuelles Workout                     │
│ • Timer, erledigte Sätze                │
│ • "Fortsetzen" Button                   │
├─────────────────────────────────────────┤
│ Heutiger Fokus (AI-generiert)           │
│ • "Heute ist Push-Tag!" oder            │
│ • "Ruhetag - 1 Tag seit letztem Pull"   │
│ • Schnellstart-Button                   │
├─────────────────────────────────────────┤
│ Wochenübersicht                         │
│ • Mini-Kalender (7 Tage)                │
│ • Workout-Punkte auf Tagen              │
│ • Streak-Visualisierung                 │
├─────────────────────────────────────────┤
│ Schnell-Statistiken (4 Karten)          │
│ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐   │
│ │ 12 💪│ │450kg │ │ 5:30 │ │ 142  │   │
│ │ Diese│ │Volumen│ │ Ø    │ │ BPM  │   │
│ │ Woche│ │      │ │ Zeit │ │      │   │
│ └──────┘ └──────┘ └──────┘ └──────┘   │
├─────────────────────────────────────────┤
│ Favoriten (Horizontal scrollen)         │
│ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐   │
│ │ Push │ │ Pull │ │ Beine│ │  +   │   │
│ │ Tag  │ │ Tag  │ │      │ │ Mehr │   │
│ └──────┘ └──────┘ └──────┘ └──────┘   │
│ • Antippen = Workout starten           │
│ • Lange drücken = Bearbeiten           │
├─────────────────────────────────────────┤
│ AI Coach Tipp (1 prominent)             │
│ "💡 Erhöhe das Gewicht beim Bankdrücken"│
│ "Du schaffst seit 3 Wochen 10 Wdh."    │
│ • Wischen für mehr Tipps               │
└─────────────────────────────────────────┘
```

**Warum Start-Tab wichtig ist:**
- ✅ **Schnellster Weg** zum Training (1 Tap)
- ✅ **Motivierend** - Zeigt Fortschritt sofort
- ✅ **Personalisiert** - AI schlägt vor, was heute Sinn macht
- ✅ **Auf einen Blick** - Alle wichtigen Infos sofort sichtbar

---

### Tab 2: 💪 Training (Workouts & Sessions)

**Icon:** `dumbbell.fill`
**Primäre Funktion:** Workout-Verwaltung & Ausführung

**Segmented Control (oben):**
```
┌──────────────┬──────────────┬──────────────┐
│  Vorlagen    │   Verlauf    │   Erstellen  │
└──────────────┴──────────────┴──────────────┘
```

#### Segment 1: Vorlagen (Workout-Bibliothek)

```
┌─────────────────────────────────────────┐
│ Suchleiste                              │
│ 🔍 Workouts suchen...                   │
├─────────────────────────────────────────┤
│ Filter-Chips (Horizontal scrollen)      │
│ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐   │
│ │ Alle │ │ Favs │ │ Push │ │ Pull │   │
│ └──────┘ └──────┘ └──────┘ └──────┘   │
├─────────────────────────────────────────┤
│ Ordner (Ausklappbare Bereiche)          │
│                                         │
│ 📂 Meine Workouts (12)                 │
│   ┌─────────────────────────────────┐  │
│   │ Push-Tag - Oberkörper           │  │
│   │ 8 Übungen • 45 Min. • ⭐        │  │
│   └─────────────────────────────────┘  │
│   ┌─────────────────────────────────┐  │
│   │ Pull-Tag - Rücken & Bizeps      │  │
│   │ 7 Übungen • 40 Min.             │  │
│   └─────────────────────────────────┘  │
│                                         │
│ 📂 Beispiel-Workouts (6)               │
│   (eingeklappt)                         │
│                                         │
│ + Neuer Ordner                         │
└─────────────────────────────────────────┘
```

**Aktionen pro Workout (Wischen):**
- **Nach rechts wischen:** ▶️ Workout starten
- **Nach links wischen:** 🗑️ Löschen, ✏️ Bearbeiten, 📤 Teilen, ⭐ Favorit

**Antippen:** Öffnet Workout-Details (Vorschau + Bearbeiten)

#### Segment 2: Verlauf (Session-Historie)

```
┌─────────────────────────────────────────┐
│ Filter: Letzte 30 Tage ▼                │
├─────────────────────────────────────────┤
│ Zeitstrahl (Nach Wochen gruppiert)      │
│                                         │
│ Diese Woche (3 Workouts)                │
│ ┌─────────────────────────────────────┐ │
│ │ 🏋️ Push-Tag                         │ │
│ │ Heute, 14:30 • 42 Min.              │ │
│ │ 8/8 Übungen • 450kg Volumen         │ │
│ │ ❤️ Ø HF: 142 bpm                    │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ │ 🏋️ Pull-Tag                         │ │
│ │ Montag, 10:00 • 38 Min.             │ │
│ │ 7/7 Übungen • 380kg Volumen         │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ Letzte Woche (5 Workouts)               │
│   (eingeklappt)                         │
│                                         │
│ Vor 2 Wochen (4 Workouts)               │
│   (eingeklappt)                         │
└─────────────────────────────────────────┘
```

**Antippen:** Session-Detail-Ansicht (mit Diagrammen, PRs, etc.)

#### Segment 3: Erstellen (Workout erstellen)

```
┌─────────────────────────────────────────┐
│ 3 große Karten                          │
│                                         │
│ ┌───────────────────────────────────┐   │
│ │  🧠 KI-Assistent                  │   │
│ │                                   │   │
│ │  "Lass mich dir ein Workout       │   │
│ │   basierend auf deinen Zielen     │   │
│ │   zusammenstellen"                │   │
│ │                                   │   │
│ │  [Assistent starten] →            │   │
│ └───────────────────────────────────┘   │
│                                         │
│ ┌───────────────────────────────────┐   │
│ │  ✏️ Leere Vorlage                 │   │
│ │                                   │   │
│ │  "Erstelle ein leeres Workout     │   │
│ │   von Grund auf"                  │   │
│ │                                   │   │
│ │  [Leer erstellen] →               │   │
│ └───────────────────────────────────┘   │
│                                         │
│ ┌───────────────────────────────────┐   │
│ │  📋 Aus Vorlage                   │   │
│ │                                   │   │
│ │  "Wähle ein Beispiel-Workout      │   │
│ │   und passe es an"                │   │
│ │                                   │   │
│ │  [Vorlagen durchsuchen] →         │   │
│ └───────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

**Warum 3 Segmente?**
- ✅ **Klare Trennung:** Vorlagen ≠ Verlauf ≠ Erstellen
- ✅ **Weniger Überwältigung:** Nicht alles gleichzeitig
- ✅ **Schneller Zugriff:** Zwischen Modi wischen

---

### Tab 3: 📊 Fortschritt (Statistiken & Analysen)

**Icon:** `chart.line.uptrend.xyaxis`
**Primäre Funktion:** Fortschritt visualisieren & verstehen

**Segmented Control:**
```
┌──────────────┬──────────────┬──────────────┐
│  Übersicht   │   Übungen    │    Körper    │
└──────────────┴──────────────┴──────────────┘
```

#### Segment 1: Übersicht (Gesamtfortschritt)

```
┌─────────────────────────────────────────┐
│ Zeitraum-Auswahl                        │
│ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐   │
│ │Woche │ │ Monat│ │  3M  │ │ Jahr │   │
│ └──────┘ └──────┘ └──────┘ └──────┘   │
├─────────────────────────────────────────┤
│ Haupt-Statistiken (4 große Karten)      │
│ ┌──────────────────┬──────────────────┐ │
│ │   42 Workouts    │    18.450 kg    │ │
│ │   Dieser Monat   │ Gesamt-Volumen  │ │
│ │   ▲ +8 vs letzter│  ▲ +2.300 kg    │ │
│ └──────────────────┴──────────────────┘ │
│ ┌──────────────────┬──────────────────┐ │
│ │   12h 30min      │    28 Tage      │ │
│ │  Gesamtzeit      │    Streak       │ │
│ │   ▼ -30min       │🔥 Neuer Rekord! │ │
│ └──────────────────┴──────────────────┘ │
├─────────────────────────────────────────┤
│ Volumen-Diagramm (Liniendiagramm)       │
│   ▲                                     │
│ kg│         ╱╲                          │
│   │    ╱╲  ╱  ╲  ╱╲                     │
│   │   ╱  ╲╱    ╲╱  ╲                    │
│   └─────────────────────────→ Wochen   │
├─────────────────────────────────────────┤
│ Muskelgruppen-Verteilung (Balkendia.)   │
│   Brust  ████████░░ 80%                │
│   Rücken ██████░░░░ 60%                │
│   Beine  ███████░░░ 70%                │
│   ...                                   │
├─────────────────────────────────────────┤
│ Wochen-Vergleich (Nebeneinander)        │
│ Diese Woche    vs    Letzte Woche       │
│ 5 Workouts           4 Workouts         │
│ 2.100 kg             1.850 kg           │
│ ▲ +13,5%                                │
├─────────────────────────────────────────┤
│ KI-Einblicke Karte                      │
│ "💡 Du trainierst konstant!             │
│  Dein Brustvolumen ist um 20% gestiegen │
│  diesen Monat. Erwäge mehr Rücken-      │
│  übungen für bessere Balance."          │
└─────────────────────────────────────────┘
```

#### Segment 2: Übungen (Übungs-Statistiken)

```
┌─────────────────────────────────────────┐
│ Suche: 🔍 Bankdrücken                   │
├─────────────────────────────────────────┤
│ Top-Übungen (Nach Volumen/Häufigkeit)   │
│                                         │
│ 1. Bankdrücken                          │
│    ├─ 42 Einheiten diesen Monat         │
│    ├─ 3.200 kg Gesamtvolumen            │
│    ├─ PR: 100kg x 8 Wdh.                │
│    └─ [Details ansehen] →              │
│                                         │
│ 2. Kniebeugen                           │
│    ├─ 38 Einheiten                      │
│    ├─ 4.500 kg Volumen                  │
│    └─ PR: 120kg x 6 Wdh.                │
│                                         │
│ 3. Kreuzheben                           │
│    ...                                  │
└─────────────────────────────────────────┘
```

**Übungs-Detailansicht:**
```
┌─────────────────────────────────────────┐
│ Bankdrücken                             │
├─────────────────────────────────────────┤
│ Persönliche Rekorde                     │
│ ┌─────────────┬─────────────┬─────────┐ │
│ │ Max Gewicht │  Max Wdh.   │  1RM    │ │
│ │   100 kg    │  15 Wdh.    │ 115 kg  │ │
│ │   x8 Wdh.   │  @70kg      │ Brzycki │ │
│ │ Vor 5 Tagen │ Vor 2 Wochen│         │ │
│ └─────────────┴─────────────┴─────────┘ │
├─────────────────────────────────────────┤
│ Fortschritts-Diagramm (Gewicht/Zeit)    │
│   ▲                                     │
│ kg│              ╱                      │
│   │         ╱───╱                       │
│   │    ╱───╱                            │
│   └─────────────────────────→ Datum    │
├─────────────────────────────────────────┤
│ Volumen-Verteilung                      │
│ • 45% Schwer (1-5 Wdh.)                 │
│ • 35% Moderat (6-12 Wdh.)               │
│ • 20% Leicht (13+ Wdh.)                 │
├─────────────────────────────────────────┤
│ Letzte Einheiten (Letzte 10)            │
│ ┌─────────────────────────────────────┐ │
│ │ Heute: 4 Sätze x 90kg x 8 Wdh.      │ │
│ │ Volumen: 2.880 kg                   │ │
│ └─────────────────────────────────────┘ │
│ ┌─────────────────────────────────────┐ │
│ │ Vor 3 Tagen: 4 x 85kg x 10          │ │
│ └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

#### Segment 3: Körper (Körper-Metriken)

```
┌─────────────────────────────────────────┐
│ HealthKit-Integration                   │
│ ┌─────────────────────────────────────┐ │
│ │ ❤️ Herzfrequenz-Trends              │ │
│ │ Ø: 142 bpm • Max: 178 bpm          │ │
│ │ [In Health-App ansehen] →          │ │
│ └─────────────────────────────────────┘ │
├─────────────────────────────────────────┤
│ Körpermaße                              │
│ ┌──────────────────┬──────────────────┐ │
│ │   Gewicht        │    Größe        │ │
│ │   82,5 kg        │    180 cm       │ │
│ │   ▲ +0,3kg       │                 │ │
│ └──────────────────┴──────────────────┘ │
│                                         │
│ Gewichts-Diagramm (3 Monate)            │
│   ▲                                     │
│ kg│     ╱╲  ╱╲                          │
│   │  ╱╲╱  ╲╱  ╲╱╲                       │
│   └─────────────────────────→ Wochen   │
├─────────────────────────────────────────┤
│ Kalorien & Aktivität                    │
│ • Aktive Energie: 450 kcal/Tag Ø       │
│ • Gesamtenergie: 2.800 kcal/Tag Ø      │
│ • Schritte: 8.500 Schritte/Tag Ø       │
└─────────────────────────────────────────┘
```

**Warum Fortschritt eigener Tab?**
- ✅ **Motivation:** Fortschritt sehen = weiter machen
- ✅ **Einblicke:** KI-gestützte Empfehlungen
- ✅ **Transparenz:** Alle Daten an einem Ort

---

### Tab 4: 👤 Profil (Einstellungen & Account)

**Icon:** `person.fill`
**Primäre Funktion:** Benutzerprofil & App-Einstellungen

```
┌─────────────────────────────────────────┐
│ Header (Avatar + Name)                  │
│ ┌───────┐                               │
│ │       │  Max Mustermann               │
│ │  👤   │  Fortgeschritten • 28 Tage 🔥 │
│ │       │  [Profil bearbeiten]          │
│ └───────┘                               │
├─────────────────────────────────────────┤
│ Schnell-Übersicht                       │
│ ┌─────────────────────────────────────┐ │
│ │ Gesamt-Workouts: 342                │ │
│ │ Gesamt-Volumen: 125.000 kg          │ │
│ │ Mitglied seit: Jan 2025             │ │
│ └─────────────────────────────────────┘ │
├─────────────────────────────────────────┤
│ Profil                                  │
│ ┌─────────────────────────────────────┐ │
│ │ 📸 Profilbild                       │ │
│ │ 🎯 Ziele & Einstellungen            │ │
│ │ 📏 Körpermaße                       │ │
│ │ 🔒 Schließfach-Nummer               │ │
│ └─────────────────────────────────────┘ │
├─────────────────────────────────────────┤
│ App-Einstellungen                       │
│ ┌─────────────────────────────────────┐ │
│ │ 🔔 Benachrichtigungen               │ │
│ │ ❤️ HealthKit-Integration            │ │
│ │ 🎨 Erscheinungsbild (Hell/Dunkel)   │ │
│ │ 📊 Einheiten (kg/lbs, cm/ft)        │ │
│ │ 🔊 Sounds & Haptik                  │ │
│ └─────────────────────────────────────┘ │
├─────────────────────────────────────────┤
│ Daten & Backup                          │
│ ┌─────────────────────────────────────┐ │
│ │ 💾 Daten exportieren                │ │
│ │ 📥 Workouts importieren             │ │
│ │ 🗑️ Cache leeren                     │ │
│ └─────────────────────────────────────┘ │
├─────────────────────────────────────────┤
│ Über                                    │
│ ┌─────────────────────────────────────┐ │
│ │ ℹ️ App-Version 2.0.0                │ │
│ │ 📖 Hilfe & FAQ                      │ │
│ │ 🐛 Fehler melden                    │ │
│ │ ⭐ Im App Store bewerten            │ │
│ │ 🔒 Datenschutz                      │ │
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
│  │Start │Train.│Fortsc│Profil│                   │
│  └──┬───┴───┬──┴───┬──┴───┬──┘                   │
└─────┼───────┼──────┼──────┼────────────────────────┘
      │       │      │      │
      │       │      │      └─▶ Profil-Ansicht
      │       │      │          ├─ Profil bearbeiten
      │       │      │          ├─ Einstellungs-Details
      │       │      │          └─ Über/Hilfe
      │       │      │
      │       │      └─▶ Fortschritt-Ansicht
      │       │          ├─ Segment: Übersicht
      │       │          ├─ Segment: Übungen
      │       │          │   └─ Übungs-Details
      │       │          └─ Segment: Körper
      │       │
      │       └─▶ Training-Ansicht
      │           ├─ Segment: Vorlagen
      │           │   ├─ Workout-Details (Sheet)
      │           │   │   └─ Workout bearbeiten
      │           │   └─ Workout starten
      │           │       └─ Aktive Workout-Ansicht ★
      │           │           ├─ Übungsliste (Wischen)
      │           │           ├─ Rest-Timer
      │           │           └─ Session abschließen
      │           │
      │           ├─ Segment: Verlauf
      │           │   └─ Session-Details (Sheet)
      │           │       ├─ Session-Statistiken
      │           │       └─ Vergleich mit vorherigen
      │           │
      │           └─ Segment: Erstellen
      │               ├─ KI-Assistent Flow
      │               │   ├─ Zielauswahl
      │               │   ├─ Equipment
      │               │   ├─ Dauer
      │               │   └─ Generierte Vorschau
      │               ├─ Leeres Workout
      │               └─ Aus Vorlage
      │
      └─▶ Start-Ansicht
          ├─ Aktive Workout-Leiste (falls aktiv)
          │   └─ Fortsetzen → Aktive Workout-Ansicht ★
          ├─ Schnellstart Favorit
          │   └─ Aktive Workout-Ansicht ★
          ├─ Wochenkalender
          │   └─ Kalender-Details (Sheet)
          ├─ KI-Coach Tipp
          │   └─ Tipps-Liste (Sheet)
          └─ Einstellungen/Profil Icons
              └─ Navigation zu jeweiligen Tabs
```

**★ Aktive Workout-Ansicht** ist der zentrale Workout-Bildschirm, erreichbar von:
- Start Tab (Fortsetzen)
- Start Tab (Schnellstart Favorit)
- Training Tab → Vorlagen → Starten

### 🎯 Primäre Aktionen pro Tab

| Tab | Primäre Aktion | Sekundäre Aktionen |
|-----|---------------|-------------------|
| **Start** | Favorit-Workout starten | Aktives fortsetzen, Kalender ansehen |
| **Training** | Workout aus Vorlagen starten | Bearbeiten, Erstellen, Verlauf ansehen |
| **Fortschritt** | Statistiken ansehen | Zeitraum filtern, Übungs-Details ansehen |
| **Profil** | Profil bearbeiten | Einstellungen, Daten exportieren |

---

## User Flows

### Flow 1: Neues Workout starten (Schnellster Weg)

```
Nutzer öffnet App
    ↓
Start Tab (automatisch)
    ↓
Antippen eines Favorit-Workouts
    ↓
Aktive Workout-Ansicht öffnet sich
    ↓
Horizontales Wischen zwischen Übungen
    ↓
Antippen "Satz abschließen"
    ↓
Rest-Timer startet automatisch
    ↓
... Workout durchführen ...
    ↓
Letzten Satz abschließen
    ↓
"Workout beenden" Button erscheint
    ↓
Antippen "Beenden"
    ↓
Zusammenfassungs-Sheet zeigt Statistiken
    ↓
Antippen "Speichern" oder "Teilen"
    ↓
Zurück zum Start Tab

Gesamt-Taps: 2 (Favorit → Letzten Satz abschließen)
```

### Flow 2: Workout mit KI-Assistent erstellen

```
Nutzer öffnet App
    ↓
Training Tab → Erstellen Segment
    ↓
Antippen "KI-Assistent"
    ↓
Schritt 1: Was ist dein Ziel?
    ├─ Muskelaufbau
    ├─ Kraft
    ├─ Ausdauer
    └─ Allgemeine Fitness ✓
    ↓
Schritt 2: Welches Equipment?
    ├─ Fitnessstudio (Alles)
    ├─ Heimtraining (Hanteln + Bodyweight)
    └─ Nur Bodyweight ✓
    ↓
Schritt 3: Wie viel Zeit?
    ├─ 30 Min.
    ├─ 45 Min. ✓
    └─ 60 Min.
    ↓
KI generiert Workout (2 Sekunden)
    ↓
Vorschau:
    • 6 Übungen
    • Geschätzte Dauer: 42 Min.
    • Muskelgruppen: Ganzkörper
    ↓
Aktionen:
    ├─ [Jetzt starten]
    ├─ [Zuerst bearbeiten]
    └─ [In Bibliothek speichern]
    ↓
Nutzer wählt [In Bibliothek speichern]
    ↓
Zurück zu Training → Vorlagen
    ↓
Neues Workout erscheint ganz oben

Gesamt-Taps: 7 (sehr akzeptabel für komplexen Ablauf)
```

### Flow 3: Fortschritt für eine Übung checken

```
Nutzer öffnet App
    ↓
Fortschritt Tab → Übungen Segment
    ↓
Suche "Bankdrücken" (oder scrollen)
    ↓
Antippen "Bankdrücken"
    ↓
Übungs-Detailansicht:
    ├─ Persönliche Rekorde (Max Gewicht, Wdh., 1RM)
    ├─ Fortschritts-Diagramm
    ├─ Volumen-Verteilung
    └─ Letzte Sessions
    ↓
Nutzer scrollt durch Diagramme
    ↓
Antippen "Letzte Session" → Session-Details
    ↓
Vollständige Session-Daten
    ↓
Zurück → Übungs-Details
    ↓
Zurück → Fortschritt-Übersicht

Gesamt-Taps: 2 (Fortschritt Tab → Übung)
```

### Flow 4: Workout pausieren und später fortsetzen

```
Nutzer ist in der Aktiven Workout-Ansicht
    ↓
Antippen "..." (Mehr-Menü)
    ↓
Antippen "Workout pausieren"
    ↓
Bestätigung:
    "Workout pausieren? Du kannst später fortfahren."
    [Pausieren] [Abbrechen]
    ↓
Nutzer tippt [Pausieren]
    ↓
Workout wird gespeichert
    ↓
Zurück zum Start Tab
    ↓
"Pausiertes Workout" Karte erscheint:
    "Push-Tag - Pausiert bei Übung 3/8"
    [Fortsetzen] [Workout beenden]
    ↓
... später (z.B. nach 2 Stunden) ...
    ↓
Nutzer öffnet App
    ↓
Start zeigt "Pausiertes Workout" Karte
    ↓
Antippen [Fortsetzen]
    ↓
Aktive Workout-Ansicht öffnet an genau der Stelle
    ↓
Nutzer macht weiter

Gesamt-Taps: 3 (Pausieren) + 1 (Fortsetzen)
```

### Flow 5: Übung tauschen während Workout

```
Nutzer ist in der Aktiven Workout-Ansicht
    bei Übung "Bankdrücken"
    ↓
Langes Drücken auf Übungsnamen
    ↓
Schnellaktion-Menü:
    ├─ 🔄 Übung tauschen
    ├─ ℹ️ Anleitung ansehen
    ├─ ⏭️ Übung überspringen
    └─ ✏️ Sätze bearbeiten
    ↓
Nutzer tippt "Übung tauschen"
    ↓
Übungsauswahl-Sheet:
    • Ähnliche Vorschläge (Top 5):
      ├─ Schrägbankdrücken ⭐
      ├─ Kurzhantel-Drücken
      └─ Liegestütze
    • Alle Übungen (Suche + Filter)
    ↓
Nutzer tippt "Schrägbankdrücken"
    ↓
Bestätigung:
    "Bankdrücken durch Schrägbankdrücken ersetzen?"
    • Gleiche Sätze/Wdh. behalten
    • Vorheriges Gewicht behalten
    [Tauschen] [Abbrechen]
    ↓
Nutzer tippt [Tauschen]
    ↓
Übung wird ersetzt
    ↓
Aktive Workout-Ansicht aktualisiert
    ↓
Nutzer macht weiter

Gesamt-Taps: 3 (Langes Drücken → Tauschen → Auswählen)
```

---

## Feature-Priorisierung

### 🚀 Must-Have Features (v2.0 Launch)

| Feature | Warum Critical | Tab |
|---------|----------------|-----|
| **Workout-Vorlagen** | Kern-Funktionalität | Training |
| **Aktive Workout-Ausführung** | Hauptzweck der App | Training/Start |
| **Rest-Timer** | Essentiell für Training | Universal |
| **Session-Verlauf** | Fortschritt nachvollziehen | Training/Fortschritt |
| **Persönliche Rekorde** | Motivation | Fortschritt |
| **Basis-Statistiken** | Feedback & Einblicke | Fortschritt |
| **KI-Coach Tipps** | USP der App | Start/Fortschritt |
| **HealthKit-Integration** | iOS-Standard | Profil |
| **Profil-Verwaltung** | Personalisierung | Profil |
| **Offline-Modus** | Zuverlässigkeit im Studio | Universal |

### ⭐ Nice-to-Have Features (v2.1+)

| Feature | Warum Nice | Priorität |
|---------|------------|-----------|
| **Supersatz-Unterstützung** | Fortgeschrittenes Training | Hoch |
| **Workout-Erinnerungen** | Konstanz fördern | Mittel |
| **Soziales Teilen** | Community-Aspekt | Mittel |
| **Workout-Herausforderungen** | Gamification | Mittel |
| **Sprachsteuerung** | Freihändig | Niedrig |

### ❌ Out of Scope (v2.0)

- **Apple Watch App** (v2.1+)
- **Übungs-Videos** (v2.1+)
- Soziales Netzwerk / Freunde
- Mahlzeiten-Tracking / Ernährung
- Workout-Klassen / Videos
- Wearables (außer iPhone HealthKit)
- Premium / Abo-Modell

### 📱 Offline-Modus (Must-Have v2.0)

**Warum Critical:**
- Fitnessstudios haben oft schlechten Empfang (Keller, dicke Wände)
- Workout darf NIEMALS wegen fehlender Verbindung unterbrochen werden
- Nutzer muss sich auf die App verlassen können

**Technische Anforderungen:**
- Alle Workout-Daten lokal in SwiftData gespeichert
- Keine Netzwerk-Calls während aktivem Workout
- Sync zu HealthKit erfolgt im Hintergrund (auch offline möglich)
- KI-Tipps werden vorab geladen und gecacht
- Nur für optionale Features (z.B. Teilen) ist Internet nötig

**UX-Hinweis:**
- Nutzer merkt idealerweise nicht, ob online oder offline
- Kein "Offline-Modus Badge" → einfach funktioniert es

---

## Interaction Design

### 🎨 Gesten & Muster

#### Wisch-Gesten

| Kontext | Wisch-Richtung | Aktion |
|---------|----------------|--------|
| **Workout in Liste** | → Rechts | Workout starten |
| **Workout in Liste** | ← Links | Löschen/Bearbeiten Menü |
| **Übung in Aktivem Workout** | → Rechts | Nächste Übung |
| **Übung in Aktivem Workout** | ← Links | Vorherige Übung |
| **Satz-Zeile** | → Rechts | Satz abschließen |
| **KI-Tipp Karte** | → Rechts | Nächster Tipp |
| **KI-Tipp Karte** | ← Links | Vorheriger Tipp |

#### Langes Drücken Aktionen

| Element | Langes Drücken Aktion |
|---------|------------------|
| **Workout-Karte** | Bearbeiten-Menü (Bearbeiten, Duplizieren, Teilen, Löschen) |
| **Übungsname** | Schnellaktionen (Tauschen, Anleitung, Überspringen) |
| **Satz-Zeile** | Gewicht/Wdh. inline bearbeiten |
| **Statistik-Karte** | Als Bild exportieren |

#### Ziehen zum Aktualisieren

| Ansicht | Aktion |
|------|--------|
| **Start Tab** | Statistiken & KI-Tipps aktualisieren |
| **Training → Vorlagen** | Workout-Liste neu laden |
| **Training → Verlauf** | Sessions neu laden |
| **Fortschritt** | Statistiken neu berechnen |

#### Haptisches Feedback

| Ereignis | Haptik |
|-------|--------|
| **Satz abgeschlossen** | Erfolg (Mittlerer Impact) |
| **Rest-Timer abgelaufen** | Benachrichtigung (Starker Impact) |
| **PR erreicht** | Erfolg (Starker Impact) + Sound |
| **Fehler** | Fehler (Leichter Impact) |
| **Navigation** | Auswahl (Leichter Impact) |

### 🎯 Floating Action Button (FAB)

**Kontextbezogener FAB pro Tab:**

| Tab | FAB Icon | Aktion |
|-----|----------|--------|
| **Start** | `play.fill` | Schnellstart (Letztes Workout oder Favorit) |
| **Training → Vorlagen** | `plus` | Neues Workout erstellen |
| **Training → Verlauf** | `chart.bar` | Bericht generieren |
| **Fortschritt** | `arrow.down.doc` | Statistiken exportieren |
| **Profil** | `camera` | Profilbild aktualisieren |

**FAB Position:** Unten-Rechts, 80px vom unteren Rand, 20px vom rechten Rand

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
  - Übungen
  - Sätze
  - Aktionen
- ✅ Hints für komplexe Gesten
  - "Doppeltippen zum Starten des Workouts"
  - "Nach rechts wischen zum Abschließen des Satzes"

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

### 🎓 Erstes Starten der App

```
App-Start (Erstes Mal)
    ↓
┌─────────────────────────────────────┐
│ Willkommens-Bildschirm              │
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
│ Schritt 4: HealthKit (Optional)     │
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
│ Schritt 5: Benachrichtigungen (Opt.)│
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
│ Alles bereit! 🎉                    │
│                                     │
│ "Dein Profil ist eingerichtet!"     │
│                                     │
│ "Die KI hat dir 3 passende          │
│  Workouts erstellt, basierend       │
│  auf deinen Angaben."               │
│                                     │
│ [Workouts ansehen] →               │
└─────────────────────────────────────┘
    ↓
Start Tab mit 3 generierten Workouts
```

**Onboarding-Prinzipien:**
- ✅ **Kurz:** Max. 5 Screens
- ✅ **Optional:** Nur kritische Infos sind required
- ✅ **Value First:** Zeige Nutzen, nicht Features
- ✅ **Skip-fähig:** Power User können überspringen
- ✅ **Contextual:** HealthKit/Notifications beim ersten Bedarf

---

## Vergleich v1.x vs v2.0

### 📊 Feature-Vergleich

| Feature | v1.x | v2.0 | Verbesserung |
|---------|------|------|--------------|
| **Tab-Anzahl** | 3 (Start, Workouts, Insights) | 4 (Start, Training, Fortschritt, Profil) | ✅ Klarere Trennung |
| **Workout Start** | 3-4 Taps | 2 Taps (Start → Favorit) | ✅ 50% schneller |
| **Statistiken** | Versteckt in Tab 3 | Eigener Tab mit Segmenten | ✅ Prominenter |
| **Profil** | Hamburger-Menü | Eigener Tab | ✅ Besser erreichbar |
| **KI-Assistent** | Versteckt | Prominent in Training → Erstellen | ✅ Höhere Nutzung |
| **Session-Verlauf** | Nur in Statistiken | Training Tab + Fortschritt | ✅ Mehrere Zugangspunkte |
| **Übung tauschen** | Komplex, viele Taps | Langes Drücken → Schnellmenü | ✅ 66% weniger Taps |
| **Onboarding** | Minimal | Geführt, personalisiert | ✅ Bessere erste Erfahrung |

### 🎯 UX-Verbesserungen

| Aspekt | v1.x Problem | v2.0 Lösung |
|--------|-------------|-------------|
| **Navigation** | Unklar wo was ist | 4 klare Tabs mit eindeutigen Rollen |
| **Feature-Entdeckung** | Assistent, Tauschen versteckt | Prominente Platzierung |
| **Informations-Hierarchie** | Flach, alles gleichwertig | Haupt-Statistiken, dann Details |
| **Kontext-Bewusstsein** | Statisch | FAB ändert sich pro Tab |
| **Auf-einen-Blick** | Viel Text | Große Zahlen, visuelle Hierarchie |
| **Aktions-Geschwindigkeit** | Viele Taps nötig | Wisch-Gesten, Langes Drücken |

### 📈 Erwartete Auswirkungen

| Metrik | v1.x | v2.0 Ziel | Begründung |
|--------|------|-----------|------------|
| **Session-Startzeit** | 8s Ø | < 4s | Favoriten auf Start, 2 Taps |
| **Assistenten-Nutzung** | 12% | > 40% | Prominente Platzierung |
| **Profil-Vollständigkeit** | 45% | > 80% | Eigener Tab, Onboarding |
| **Täglich aktive Nutzer** | Baseline | +30% | Bessere UX = höheres Engagement |
| **Feature-Akzeptanz** | 60% | > 85% | Klare Navigation |

---

## Zusammenfassung & Empfehlung

### ✅ Key Decisions für v2.0

#### 1. **4-Tab-Struktur statt 3**
**Begründung:**
- Klare Trennung: Schnellzugriff (Start) ≠ Verwaltung (Training) ≠ Analyse (Fortschritt) ≠ Einstellungen (Profil)
- Standard in modernen Apps (Fitness+, Nike Training, Strong)
- Bessere Auffindbarkeit aller Features

#### 2. **Segmented Control in Training & Fortschritt**
**Begründung:**
- Reduziert Überwältigung (nicht alles gleichzeitig)
- Schneller Wechsel zwischen Modi
- Klare mentale Modelle (Vorlagen vs Verlauf vs Erstellen)

#### 3. **Start Tab als Dashboard**
**Begründung:**
- Schnellster Weg zum Training (1-2 Taps)
- Motivierend durch sofortige Statistiken
- Personalisiert durch KI

#### 4. **Prominente KI-Features**
**Begründung:**
- USP der App (nicht von Konkurrenz kopierbar)
- Hoher Nutzen für Nutzer
- Aktuell zu versteckt

#### 5. **Gesten statt Taps**
**Begründung:**
- Schneller (Wischen zum Abschließen des Satzes)
- Intuitiver (Langes Drücken für Optionen)
- iOS-Standard

### 🎯 Nächste Schritte

1. **Wireframes erstellen** für alle 4 Tabs
2. **Prototyp** in Figma/Sketch
3. **User Testing** mit 5-10 Usern
4. **Iteration** basierend auf Feedback
5. **Implementation** nach Technical Concept

---

**Entscheidungen getroffen:**

1. ✅ **Tab-Reihenfolge:** Home → Train → Progress → Profile (bestätigt)
2. ✅ **KI-Assistent:** Nur in "Training → Erstellen" als Auswahl, kein extra Button
3. ✅ **Übungs-Videos:** v2.1+ (nicht v2.0)
4. ✅ **Apple Watch:** v2.1+ (nicht v2.0)
5. ✅ **Offline-Modus:** Must-Have für v2.0 (wichtig!)

**Offene Punkte:**

- ⚠️ **Home Tab zu voll:** Vereinfachung notwendig - wird noch überarbeitet
- 📌 **Grundprinzip:** So einfach wie möglich, App übernimmt die Arbeit (Auswertungen, Progression, etc.)

---

**Bereit für Implementation! 🚀**

---

## 🏗️ V2 Clean Architecture Implementation Plan

**Branch:** `feature/v2-clean-architecture`  
**Basis:** Vorhandene UI Components aus `archive/v2-ui-experiments`  
**Strategie:** Architecture-First mit UI Component Reuse

---

### Phase 1: Foundation & UI Component Migration (Woche 1) ⏳

**Ziel:** Architektur-Fundament schaffen + ActiveWorkoutV2 UI integrieren

#### Sprint 1.1: Project Structure (Tag 1-2)

```bash
# Neue Ordnerstruktur erstellen
GymTracker/
├── Domain/                     # ✅ Pure Swift, Framework-unabhängig
│   ├── Entities/
│   │   ├── Workout.swift
│   │   ├── Exercise.swift
│   │   └── WorkoutSession.swift
│   ├── UseCases/
│   │   └── Session/
│   │       ├── StartSessionUseCase.swift
│   │       ├── CompleteSetUseCase.swift
│   │       └── EndSessionUseCase.swift
│   └── RepositoryProtocols/
│       └── SessionRepositoryProtocol.swift
│
├── Data/                       # ✅ Persistence & Mapping
│   ├── Repositories/
│   │   └── SwiftDataSessionRepository.swift
│   └── Mappers/
│       └── SessionMapper.swift
│
├── Presentation/               # ✅ UI Layer
│   ├── Stores/
│   │   └── SessionStore.swift
│   └── Views/
│       └── ActiveWorkout/
│           ├── ActiveWorkoutSheetView.swift    # FROM ARCHIVE
│           ├── ExerciseCard.swift              # FROM ARCHIVE
│           ├── TimerSection.swift              # FROM ARCHIVE
│           └── ...
│
└── Infrastructure/             # ✅ Framework Integration
    └── DI/
        └── DependencyContainer.swift
```

**Tasks:**
- [ ] Create folder structure (Domain, Data, Presentation, Infrastructure)
- [ ] Copy ActiveWorkoutV2 components from `archive/v2-ui-experiments`
- [ ] Create `DependencyContainer.swift` (empty scaffold)
- [ ] Update `GymTrackerApp.swift` to use DI container

**Deliverable:** Ordnerstruktur steht, UI Components kopiert, App kompiliert

---

#### Sprint 1.2: Domain Layer - Session Management (Tag 3-5)

**Domain Entities:**

```swift
// Domain/Entities/WorkoutSession.swift
struct WorkoutSession {
    let id: UUID
    let workoutId: UUID
    let startDate: Date
    var endDate: Date?
    var exercises: [SessionExercise]
    var state: SessionState
    
    enum SessionState {
        case active
        case paused
        case completed
    }
}

struct SessionExercise {
    let id: UUID
    let exerciseId: UUID
    var sets: [SessionSet]
    var notes: String?
}

struct SessionSet {
    let id: UUID
    var weight: Double
    var reps: Int
    var completed: Bool
    var completedAt: Date?
}
```

**Use Cases:**

```swift
// Domain/UseCases/Session/StartSessionUseCase.swift
protocol StartSessionUseCase {
    func execute(workoutId: UUID) async throws -> WorkoutSession
}

final class DefaultStartSessionUseCase: StartSessionUseCase {
    private let sessionRepository: SessionRepositoryProtocol
    
    init(sessionRepository: SessionRepositoryProtocol) {
        self.sessionRepository = sessionRepository
    }
    
    func execute(workoutId: UUID) async throws -> WorkoutSession {
        let session = WorkoutSession(
            id: UUID(),
            workoutId: workoutId,
            startDate: Date(),
            exercises: [], // Load from workout template
            state: .active
        )
        try await sessionRepository.save(session)
        return session
    }
}

// Domain/UseCases/Session/CompleteSetUseCase.swift
protocol CompleteSetUseCase {
    func execute(sessionId: UUID, exerciseId: UUID, setId: UUID) async throws
}

// Domain/UseCases/Session/EndSessionUseCase.swift
protocol EndSessionUseCase {
    func execute(sessionId: UUID) async throws -> WorkoutSession
}
```

**Repository Protocol:**

```swift
// Domain/RepositoryProtocols/SessionRepositoryProtocol.swift
protocol SessionRepositoryProtocol {
    func save(_ session: WorkoutSession) async throws
    func fetch(id: UUID) async throws -> WorkoutSession?
    func fetchActiveSession() async throws -> WorkoutSession?
    func update(_ session: WorkoutSession) async throws
    func delete(id: UUID) async throws
}
```

**Tasks:**
- [ ] Create Domain Entities (WorkoutSession, SessionExercise, SessionSet)
- [ ] Create Repository Protocol (SessionRepositoryProtocol)
- [ ] Create Use Cases (Start, CompleteSet, End)
- [ ] Write Unit Tests for Use Cases (Mock Repository)

**Deliverable:** Domain Layer komplett, 100% testbar, keine Framework-Dependencies

---

#### Sprint 1.3: Data Layer - Repository Implementation (Tag 6-7)

**SwiftData Repository:**

```swift
// Data/Repositories/SwiftDataSessionRepository.swift
import SwiftData

final class SwiftDataSessionRepository: SessionRepositoryProtocol {
    private let modelContext: ModelContext
    private let mapper: SessionMapper
    
    init(modelContext: ModelContext, mapper: SessionMapper = SessionMapper()) {
        self.modelContext = modelContext
        self.mapper = mapper
    }
    
    func save(_ session: WorkoutSession) async throws {
        let entity = mapper.toEntity(session)
        modelContext.insert(entity)
        try modelContext.save()
    }
    
    func fetch(id: UUID) async throws -> WorkoutSession? {
        let descriptor = FetchDescriptor<WorkoutSessionEntity>(
            predicate: #Predicate { $0.id == id }
        )
        let entity = try modelContext.fetch(descriptor).first
        return entity.map(mapper.toDomain)
    }
    
    func fetchActiveSession() async throws -> WorkoutSession? {
        let descriptor = FetchDescriptor<WorkoutSessionEntity>(
            predicate: #Predicate { $0.state == "active" }
        )
        let entity = try modelContext.fetch(descriptor).first
        return entity.map(mapper.toDomain)
    }
    
    func update(_ session: WorkoutSession) async throws {
        guard let entity = try await fetchEntity(id: session.id) else { return }
        mapper.updateEntity(entity, from: session)
        try modelContext.save()
    }
    
    func delete(id: UUID) async throws {
        guard let entity = try await fetchEntity(id: id) else { return }
        modelContext.delete(entity)
        try modelContext.save()
    }
    
    private func fetchEntity(id: UUID) async throws -> WorkoutSessionEntity? {
        let descriptor = FetchDescriptor<WorkoutSessionEntity>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }
}
```

**Mapper:**

```swift
// Data/Mappers/SessionMapper.swift
struct SessionMapper {
    func toDomain(_ entity: WorkoutSessionEntity) -> WorkoutSession {
        WorkoutSession(
            id: entity.id,
            workoutId: entity.workoutId,
            startDate: entity.startDate,
            endDate: entity.endDate,
            exercises: entity.exercises.map(toDomain),
            state: WorkoutSession.SessionState(rawValue: entity.state) ?? .active
        )
    }
    
    func toEntity(_ domain: WorkoutSession) -> WorkoutSessionEntity {
        let entity = WorkoutSessionEntity()
        entity.id = domain.id
        entity.workoutId = domain.workoutId
        entity.startDate = domain.startDate
        entity.endDate = domain.endDate
        entity.state = domain.state.rawValue
        entity.exercises = domain.exercises.map(toEntity)
        return entity
    }
    
    func updateEntity(_ entity: WorkoutSessionEntity, from domain: WorkoutSession) {
        entity.endDate = domain.endDate
        entity.state = domain.state.rawValue
        // Update exercises, sets...
    }
}
```

**Tasks:**
- [ ] Create SwiftData Entities (WorkoutSessionEntity, SessionExerciseEntity, SessionSetEntity)
- [ ] Create SessionMapper
- [ ] Implement SwiftDataSessionRepository
- [ ] Write Integration Tests (with in-memory ModelContext)

**Deliverable:** Data Layer funktioniert, SwiftData persistence works

---

#### Sprint 1.4: Presentation Layer - SessionStore (Tag 8-10)

**SessionStore (Presentation Layer):**

```swift
// Presentation/Stores/SessionStore.swift
import SwiftUI
import Combine

@MainActor
final class SessionStore: ObservableObject {
    // Published State
    @Published var currentSession: WorkoutSession?
    @Published var isLoading: Bool = false
    @Published var error: Error?
    
    // Dependencies (injected)
    private let startSessionUseCase: StartSessionUseCase
    private let completeSetUseCase: CompleteSetUseCase
    private let endSessionUseCase: EndSessionUseCase
    
    init(
        startSessionUseCase: StartSessionUseCase,
        completeSetUseCase: CompleteSetUseCase,
        endSessionUseCase: EndSessionUseCase
    ) {
        self.startSessionUseCase = startSessionUseCase
        self.completeSetUseCase = completeSetUseCase
        self.endSessionUseCase = endSessionUseCase
    }
    
    // MARK: - Actions (called by Views)
    
    func startSession(workoutId: UUID) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            currentSession = try await startSessionUseCase.execute(workoutId: workoutId)
        } catch {
            self.error = error
        }
    }
    
    func completeSet(exerciseId: UUID, setId: UUID) async {
        guard let sessionId = currentSession?.id else { return }
        
        do {
            try await completeSetUseCase.execute(
                sessionId: sessionId,
                exerciseId: exerciseId,
                setId: setId
            )
            // Update local state (optimistic update)
            updateLocalSet(exerciseId: exerciseId, setId: setId, completed: true)
        } catch {
            self.error = error
        }
    }
    
    func endSession() async {
        guard let sessionId = currentSession?.id else { return }
        isLoading = true
        defer { isLoading = false }
        
        do {
            currentSession = try await endSessionUseCase.execute(sessionId: sessionId)
        } catch {
            self.error = error
        }
    }
    
    private func updateLocalSet(exerciseId: UUID, setId: UUID, completed: Bool) {
        guard var session = currentSession else { return }
        
        if let exerciseIndex = session.exercises.firstIndex(where: { $0.id == exerciseId }),
           let setIndex = session.exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setId }) {
            session.exercises[exerciseIndex].sets[setIndex].completed = completed
            session.exercises[exerciseIndex].sets[setIndex].completedAt = Date()
            currentSession = session
        }
    }
}
```

**Refactored ActiveWorkoutSheetView:**

```swift
// Presentation/Views/ActiveWorkout/ActiveWorkoutSheetView.swift
struct ActiveWorkoutSheetView: View {
    @ObservedObject var sessionStore: SessionStore  // ✅ Injected Store
    @Environment(\.dismiss) var dismiss
    
    // NO direct dependencies on WorkoutStore, SwiftData, etc.
    
    var body: some View {
        VStack(spacing: 0) {
            // Header...
            // Timer Section...
            
            ScrollView {
                ForEach(sessionStore.currentSession?.exercises ?? []) { exercise in
                    ExerciseCard(
                        exercise: exercise,
                        onCompleteSet: { setId in
                            Task {
                                await sessionStore.completeSet(
                                    exerciseId: exercise.id,
                                    setId: setId
                                )
                            }
                        }
                    )
                }
            }
            
            // Bottom Action Bar...
        }
    }
}
```

**DI Container Integration:**

```swift
// Infrastructure/DI/DependencyContainer.swift
final class DependencyContainer {
    // Singletons
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Repositories
    
    func makeSessionRepository() -> SessionRepositoryProtocol {
        SwiftDataSessionRepository(modelContext: modelContext)
    }
    
    // MARK: - Use Cases
    
    func makeStartSessionUseCase() -> StartSessionUseCase {
        DefaultStartSessionUseCase(sessionRepository: makeSessionRepository())
    }
    
    func makeCompleteSetUseCase() -> CompleteSetUseCase {
        DefaultCompleteSetUseCase(sessionRepository: makeSessionRepository())
    }
    
    func makeEndSessionUseCase() -> EndSessionUseCase {
        DefaultEndSessionUseCase(sessionRepository: makeSessionRepository())
    }
    
    // MARK: - Stores
    
    func makeSessionStore() -> SessionStore {
        SessionStore(
            startSessionUseCase: makeStartSessionUseCase(),
            completeSetUseCase: makeCompleteSetUseCase(),
            endSessionUseCase: makeEndSessionUseCase()
        )
    }
}
```

**App Integration:**

```swift
// GymTrackerApp.swift
@main
struct GymTrackerApp: App {
    let container: ModelContainer
    let dependencyContainer: DependencyContainer
    
    init() {
        do {
            container = try ModelContainer(for: WorkoutSessionEntity.self)
            dependencyContainer = DependencyContainer(
                modelContext: container.mainContext
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dependencyContainer.makeSessionStore())
        }
    }
}
```

**Tasks:**
- [ ] Create SessionStore (Presentation Layer)
- [ ] Refactor ActiveWorkoutSheetView (remove direct dependencies)
- [ ] Create DependencyContainer
- [ ] Update GymTrackerApp.swift
- [ ] Test end-to-end flow (Start Session → Complete Set → End Session)

**Deliverable:** Phase 1 Complete! Clean Architecture funktioniert, ActiveWorkoutV2 UI integriert

---

### Phase 2: Workout Management & Home View (Woche 2-3) ⏳

**Scope:**
- Workout CRUD (Create, Read, Update, Delete)
- HomeViewV2 Integration (from archive)
- Workout Library Management
- Exercise Library

**Details:** TBD (nach Phase 1 Review)

---

### Phase 3: Statistics & Progress (Woche 4) ⏳

**Scope:**
- Statistics Calculation Use Cases
- Progress Tracking
- HealthKit Integration (Clean Architecture style)

**Details:** TBD

---

### Phase 4: Polish, Testing, Migration (Woche 5-6) ⏳

**Scope:**
- Comprehensive Testing (Unit, Integration, UI)
- Performance Optimization
- Data Migration von v1.x zu v2.0
- Old WorkoutStore deletion

**Details:** TBD

---

## 📊 Success Metrics

| Metrik | Aktuell (v1.x) | Ziel (v2.0) |
|--------|----------------|-------------|
| Test Coverage | 15% | **70%+** |
| Largest File Size | 130KB (WorkoutStore) | **< 30KB** |
| Compile Time | 45s | **< 20s** |
| Session Start Time | 8s | **< 4s** |
| App Launch | 3-5s | **< 1.5s** |

---

## 🎯 Immediate Next Steps (Morgen starten)

1. ✅ UX_CONCEPT_V2.md committed in v2-clean-architecture branch
2. ⏳ **Sprint 1.1 starten:** Ordnerstruktur + UI Component Migration
3. ⏳ **Sprint 1.2:** Domain Layer (Entities + Use Cases)
4. ⏳ **Sprint 1.3:** Data Layer (Repository + Mapper)
5. ⏳ **Sprint 1.4:** Presentation Layer (SessionStore + DI)

**Geschätzter Zeitaufwand Phase 1:** 2-3 Tage (mit vorhandenen UI Components!)

---

**Status:** 🟢 READY TO START - Architecture Foundation mit UI Component Reuse  
**Branch:** `feature/v2-clean-architecture`  
**Next Action:** Sprint 1.1 - Create folder structure & copy UI components
