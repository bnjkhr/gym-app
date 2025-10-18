# 📚 GymBo Dokumentation

Willkommen zur technischen Dokumentation des GymBo (GymTracker) Projekts.

---

## 🚀 Schnellstart

### Für neue Entwickler
1. Start: [CLAUDE.md](CLAUDE.md) - AI Assistant Guide
2. Dann: [DOCUMENTATION.md](DOCUMENTATION.md) - Vollständige technische Dokumentation
3. Review: [CODE_REVIEW_REPORT.md](CODE_REVIEW_REPORT.md) - Aktuelle Code-Qualität & Empfehlungen

### Für erfahrene Team-Mitglieder
- [INDEX.md](INDEX.md) - Vollständiger Dokumentations-Index
- [PROGRESS.md](PROGRESS.md) - Aktueller Projekt-Status
- [MODULARIZATION_PLAN.md](MODULARIZATION_PLAN.md) - Refactoring Roadmap

---

## 📁 Dokumentations-Kategorien

### 📖 Core Documentation
Kern-Dokumentation für tägliche Arbeit
- CLAUDE.md, DOCUMENTATION.md, CODE_REVIEW_REPORT.md, PROGRESS.md, BUGFIXES.md

### 🏗️ Architecture & Planning
Architektur & Refactoring-Pläne
- MODULARIZATION_PLAN.md, PHASE_2_PLAN.md, CODE_OPTIMIZATION_PLAN.md

### 📖 Technical Guides
Technische Anleitungen & Best Practices
- DATABASE_VERSION_CONTROL.md, TESTFLIGHT_UPDATE_GUIDE.md, SECURITY.md

### 📊 Phase Summaries
Zusammenfassungen abgeschlossener Phasen
- PHASE_5_ABSCHLUSS.md, PHASE_6_ABSCHLUSS.md, PHASE3_LIVE_ACTIVITY_SUMMARY.md

### 🔧 System Documentation
System-spezifische Dokumentation
- NOTIFICATION_SYSTEM_KONZEPT.md, STATISTICS_PERFORMANCE_OPTIMIZATION.md

### 🔨 Xcode Integration
Xcode-spezifische Guides
- XCODE_INTEGRATION.md, ADD_FILES_TO_XCODE.md, XCODE_TEST_TARGET_SETUP.md

### 💡 Concept Documents
Konzepte & Ideen
- SMART_GYM_KONZEPT.md, APP_VERBESSERUNGS_KONZEPT.md

---

## 🔍 Häufig gesucht

| Frage | Antwort |
|-------|---------|
| Wie starte ich das Projekt? | [CLAUDE.md](CLAUDE.md) → Build & Development Commands |
| Wie ist die Architektur? | [DOCUMENTATION.md](DOCUMENTATION.md) → Architecture Overview |
| Was sind die größten Probleme? | [CODE_REVIEW_REPORT.md](CODE_REVIEW_REPORT.md) → Critical Findings |
| Wo stehen wir im Refactoring? | [PROGRESS.md](PROGRESS.md) |
| Wie deploye ich auf TestFlight? | [TESTFLIGHT_UPDATE_GUIDE.md](TESTFLIGHT_UPDATE_GUIDE.md) |
| Wie funktioniert die Datenbank? | [DATABASE_VERSION_CONTROL.md](DATABASE_VERSION_CONTROL.md) |
| Welche Tests gibt es? | [CODE_REVIEW_REPORT.md](CODE_REVIEW_REPORT.md) → Tests Section |
| Wie teste ich Notifications? | [TEST_NOTIFICATION_SYSTEM.md](TEST_NOTIFICATION_SYSTEM.md) |

---

## 📊 Projekt-Status (Stand: 18. Oktober 2025)

### ✅ Abgeschlossene Phasen
- **Phase 1:** Rest Timer System (Complete)
- **Phase 2:** Coordinator Pattern (9 Coordinators)
- **Phase 3:** Views Modularization (21 Components extracted)
- **Phase 4:** Notification System (Smart Notifications)
- **Phase 5:** WorkoutStore Integration (83% Code Reduction)
- **Phase 6:** User Settings & Debug Tools

### 🔴 Kritische Issues (aus Code Review)
1. **Test-Coverage <5%** - Nur 5 Test-Dateien für 126 Swift-Dateien
2. **WorkoutStore.swift zu groß** - 2177 Zeilen (sollte <500 sein)
3. **Massive View-Dateien** - StatisticsView (1834), ContentView (1672)
4. **UserProfile in UserDefaults** - Sollte in SwiftData sein

### 🎯 Nächste Schritte
Siehe [CODE_REVIEW_REPORT.md](CODE_REVIEW_REPORT.md) → 3-Monats Action Plan

---

## 🤝 Beitragen zur Dokumentation

### Neue Dokumentation erstellen
```bash
# 1. Neue MD-Datei im Dokumentation-Ordner erstellen
touch Dokumentation/NEUE_DOKU.md

# 2. Template verwenden (siehe INDEX.md)
# 3. INDEX.md aktualisieren
# 4. Falls relevant: CLAUDE.md aktualisieren
```

### Dokumentations-Guidelines
- **Speicherort:** Alle `.md` Dateien in `/Dokumentation/`
- **Naming:** `UPPERCASE_WITH_UNDERSCORES.md`
- **Sprache:** Deutsch für Konzepte, Englisch für technische Details
- **Format:** Markdown mit Syntax Highlighting
- **Update:** INDEX.md bei neuen Dokumenten aktualisieren

---

## 📞 Kontakt & Support

Bei Fragen zur Dokumentation:
1. Prüfe [INDEX.md](INDEX.md) für Übersicht
2. Suche in relevanter Kategorie
3. Falls nicht gefunden: Neue Dokumentation erstellen

---

**Letzte Aktualisierung:** 18. Oktober 2025
**Dokumentations-Version:** 1.0
**Gesamt-Dateien:** 39 MD-Dateien + INDEX.md + README.md = 41
