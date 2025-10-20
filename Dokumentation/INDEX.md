# Dokumentations-Index

Alle technischen Dokumentationen für das GymBo (GymTracker) Projekt.

**Letzte Aktualisierung:** 20. Oktober 2025

---

## 📁 Aktive Dokumentation

### 🎯 Core Documentation

| Dokument | Beschreibung | Zielgruppe |
|----------|--------------|------------|
| [CLAUDE.md](CLAUDE.md) | AI Assistant Guide - Projekt-Übersicht, Tech Stack, Architektur | AI Assistants, Entwickler |
| [DOCUMENTATION.md](DOCUMENTATION.md) | Vollständige technische Dokumentation aller Komponenten | Entwickler, Team |
| [CODE_REVIEW_REPORT.md](CODE_REVIEW_REPORT.md) | Code-Review Findings (Rating: B+, 83/100) - Kritische Issues & Action Plan | Entwickler, Tech Lead |
| [README.md](README.md) | Projekt-README und Quick Start Guide | Alle |
| **[INDEX.md](INDEX.md)** | **Dieser Dokumentations-Index** | Alle |

### 📊 Progress & Planning

| Dokument | Beschreibung | Status |
|----------|--------------|--------|
| [PROGRESS.md](PROGRESS.md) | Live Progress Tracking - Phasen, Metriken, Tasks | ✅ Aktuell |
| [MODULARIZATION_PLAN.md](MODULARIZATION_PLAN.md) | Refactoring-Plan (Phase 1-6, 13-14 Wochen) | ✅ Phasen 1-3 abgeschlossen |
| [WORKOUTSTORE_MODULARISIERUNG.md](WORKOUTSTORE_MODULARISIERUNG.md) | WorkoutStore Modularisierungs-Plan & Status | ✅ Phase 1 & 2 abgeschlossen |
| [TEST_COVERAGE_PLAN.md](TEST_COVERAGE_PLAN.md) | Test-Strategie (Ziel: 60-70% Coverage, 3 Phasen) | 🔵 In Arbeit |

### 🧪 Testing & Quality

| Dokument | Beschreibung | Status |
|----------|--------------|--------|
| [TEST_INFRASTRUCTURE_STATUS.md](TEST_INFRASTRUCTURE_STATUS.md) | Test-Infrastructure Status & Blocker | ✅ Infrastruktur komplett |
| [TEST_SESSION_DAY2_SUMMARY.md](TEST_SESSION_DAY2_SUMMARY.md) | Test Session Day 2 Summary | 🆕 Neu |

### 🗄️ System Documentation

| Dokument | Beschreibung | Zielgruppe |
|----------|--------------|------------|
| [DATABASE_VERSION_CONTROL.md](DATABASE_VERSION_CONTROL.md) | SwiftData Migration System - Version Control & Rollback | Entwickler |
| [SECURITY.md](SECURITY.md) | Security Best Practices - HealthKit, Keychain, API | Entwickler, Security |

### 💡 Active Concepts

| Dokument | Beschreibung | Status |
|----------|--------------|--------|
| [INDICATION_PILL_KONZEPT.md](INDICATION_PILL_KONZEPT.md) | UI-Konzept für Indication Pills | 🆕 Untracked |

---

## 📦 Archiv

Ältere Dokumentationen, die für Referenzzwecke aufbewahrt werden:

### [Archive/AlarmKit/](Archive/README.md)
- AlarmKit POC Dokumentation (Migration abgebrochen)
- 12 Dateien mit vollständiger POC-Historie
- **Status:** ❌ Migration nicht feasible (iOS 26 Beta Crashes)

### [Archive/Xcode-Integration/](Archive/Xcode-Integration/)
- Xcode Setup Guides für Phasen 2 & 3
- Manual Integration Steps
- Test Target Setup
- **Status:** ✅ Alle Phasen abgeschlossen, Guides nicht mehr benötigt

### [Archive/Phase-Summaries/](Archive/Phase-Summaries/)
- Phase 2-6 Abschluss-Summaries
- Live Activity Implementation (Phase 3)
- Notifications Implementation (Phase 4)
- Integration Summary (Phase 5)
- **Status:** ✅ Abgeschlossen, archiviert für Historie

### [Archive/Implementation-Plans/](Archive/Implementation-Plans/)
- Notification System Konzept & Implementierungsplan
- Code Optimization Plan
- Allgemeiner Implementierungsplan
- **Status:** ✅ Implementiert, nicht mehr aktiv

### [Archive/Statistics/](Archive/Statistics/)
- Statistics Calculations Audit
- Performance Optimization
- Week Comparison Validation
- **Status:** ✅ Validiert und optimiert, archiviert

### [Archive/Sessions/](Archive/Sessions/)
- Session Summaries (15. Oktober 2025)
- Quick Wins Session Summary
- **Status:** ✅ Abgeschlossen, archiviert

---

## 🔍 Quick Reference

### Häufig verwendete Dokumente

| Aufgabe | Dokument |
|---------|----------|
| **Projekt verstehen** | [CLAUDE.md](CLAUDE.md), [DOCUMENTATION.md](DOCUMENTATION.md) |
| **Code Review Findings** | [CODE_REVIEW_REPORT.md](CODE_REVIEW_REPORT.md) |
| **Fortschritt tracken** | [PROGRESS.md](PROGRESS.md) |
| **Refactoring-Plan** | [MODULARIZATION_PLAN.md](MODULARIZATION_PLAN.md) |
| **Test-Strategie** | [TEST_COVERAGE_PLAN.md](TEST_COVERAGE_PLAN.md) |
| **Datenbank-Migration** | [DATABASE_VERSION_CONTROL.md](DATABASE_VERSION_CONTROL.md) |
| **Security Guidelines** | [SECURITY.md](SECURITY.md) |

---

## 📝 Dokumentations-Guidelines

### Neue Dokumentation erstellen

1. **Speicherort:** `/Dokumentation/<DOKUMENTNAME>.md`
2. **Naming Convention:** `UPPERCASE_WITH_UNDERSCORES.md`
3. **Template verwenden:**

```markdown
# Dokument-Titel

**Zweck:** Was ist der Zweck dieses Dokuments?
**Zielgruppe:** Wer sollte dieses Dokument lesen?
**Letzte Aktualisierung:** YYYY-MM-DD
**Status:** ✅ Aktuell / 🔵 In Arbeit / 📦 Archiviert

---

## Übersicht

[Kurze Beschreibung]

---

## Inhalt

[Hauptinhalt]

---

## Siehe auch

- [Verwandte Dokumente]
```

4. **INDEX.md aktualisieren:** Neues Dokument in passende Kategorie eintragen
5. **CLAUDE.md aktualisieren:** Falls für AI Assistant relevant

### Dokumentation archivieren

1. Datei nach `Archive/<Kategorie>/` verschieben
2. INDEX.md aktualisieren (Eintrag nach Archive verschieben)
3. Git commit mit Grund für Archivierung

### Dokumentation löschen

**Nur bei Redundanz oder wenn komplett veraltet!**
1. Prüfen: Ist Info woanders dokumentiert?
2. Bestätigung von Team einholen
3. Löschen + INDEX.md aktualisieren
4. Git commit mit Begründung

---

## 📊 Statistiken

- **Aktive Dokumentationen:** 14 Dateien
- **Archivierte Dokumentationen:** ~40 Dateien (6 Kategorien)
- **Letzte Bereinigung:** 20. Oktober 2025
- **Dokumentations-Coverage:** Hoch (alle wichtigen Bereiche abgedeckt)

---

## 🔄 Changelog

### 2025-10-20 - Große Dokumentations-Bereinigung

**Archiviert:**
- 11 Xcode Integration Guides → `Archive/Xcode-Integration/`
- 7 Phase Summaries → `Archive/Phase-Summaries/`
- 4 Implementation Plans → `Archive/Implementation-Plans/`
- 3 Statistics Validations → `Archive/Statistics/`
- 2 Session Summaries → `Archive/Sessions/`
- 12 AlarmKit Dokumente → `Archive/AlarmKit/` (bereits am 20.10.)

**Gelöscht (redundant):**
- VIEWS_DOCUMENTATION.md (in DOCUMENTATION.md integriert)
- TEST_NOTIFICATION_SYSTEM.md (veraltet)
- TESTFLIGHT_UPDATE_GUIDE.md (Standard-Prozess)
- VERSION_CONTROL_QUICK_GUIDE.md (in DATABASE_VERSION_CONTROL.md)
- SMART_GYM_KONZEPT.md (veraltet)
- APP_VERBESSERUNGS_KONZEPT.md (umgesetzt)
- BUGFIXES.md (Git-History ausreichend)

**Ergebnis:**
- Von ~47 Dateien → 14 aktive Dateien
- Klare Struktur: Core / Progress / Testing / System / Concepts
- Archiv gut organisiert in 6 Kategorien
- INDEX.md komplett neu strukturiert (von 500+ Zeilen → ~200 Zeilen)

### 2025-10-18 - Code Quality Update

**Hinzugefügt:**
- QUICK_WINS_SESSION_SUMMARY.md
- INDEX.md erweitert mit Quick Wins Section

### 2025-10-15 - Initiale Dokumentation

**Erstellt:**
- Umfassende Projekt-Dokumentation
- Code-Review Report
- Modularization Plan
- Progress Tracking

---

**Hinweis:** Dieses INDEX.md wird manuell gepflegt. Bei neuen Dokumentationen bitte aktualisieren.

**Version:** 2.0  
**Maintainer:** Development Team
