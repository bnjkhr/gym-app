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
│  Start   │Training  │Fortschritt│ Profil  │         │
└──────────┴──────────┴──────────┴──────────┴─────────┘
```

### Tab 1: 🏠 Start (Schnellzugriff & Übersicht)

**Icon:** `house.fill`
**Primäre Funktion:** Dashboard & Schnellzugriff

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

### ⭐ Nice-to-Have Features (v2.1+)

| Feature | Warum Nice | Priorität |
|---------|------------|-----------|
| **Soziales Teilen** | Community-Aspekt | Mittel |
| **Workout-Herausforderungen** | Gamification | Mittel |
| **Apple Watch App** | Komfort im Studio | Hoch |
| **Supersatz-Unterstützung** | Fortgeschrittenes Training | Hoch |
| **Sprachsteuerung** | Freihändig | Niedrig |
| **Übungs-Videos** | Form-Anleitung | Hoch |
| **Offline-Modus** | Zuverlässigkeit | Hoch |
| **Workout-Erinnerungen** | Konstanz | Mittel |

### ❌ Out of Scope (v2.0)

- Soziales Netzwerk / Freunde
- Mahlzeiten-Tracking / Ernährung
- Workout-Klassen / Videos
- Wearables außer Apple Watch
- Premium / Abo-Modell

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

**Fragen zur Diskussion:**

1. **Tab-Reihenfolge:** Start → Training → Fortschritt → Profil OK? Oder anders?
2. **KI-Assistent:** Soll der IMMER prominent sein oder nur für neue Nutzer?
3. **Übungs-Videos:** v2.0 oder v2.1?
4. **Apple Watch:** Priorität für v2.0?
5. **Offline-Modus:** Wie wichtig?

---

**Lass uns diskutieren! 🚀**
