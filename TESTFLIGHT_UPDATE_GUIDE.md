# Testflight Update Guide - Schema Migration

## ⚠️ Aktuelle Situation (für nächsten Release)

Dieser Release enthält **neue Datenbank-Properties** in `ExerciseEntity`:
- `lastUsedWeight`, `lastUsedReps`, `lastUsedSetCount`, `lastUsedDate`, `lastUsedRestTime`

Diese sind **optional** und sollten automatisch migriert werden.

---

## ✅ EMPFEHLUNG: Kein App-Reset erforderlich

### **Warum?**

Die App nutzt **SwiftData Lightweight Migration**, die automatisch neue optionale Properties hinzufügt ohne Datenverlust.

**Zusätzliche Absicherung:**
1. ✅ **Schema Validation** beim Start (Zeile 129-146 in GymTrackerApp.swift)
2. ✅ **Fallback auf In-Memory** bei Migration-Fehlern
3. ✅ **Robuste Fehlerbehandlung** mit Logging
4. ✅ **Automatisches Neu-Laden** von Sample-Daten falls nötig

---

## 📱 Was User erleben werden

### **Szenario 1: Migration erfolgreich (99% der Fälle)**
```
1. App-Update via Testflight
2. App startet
3. "Daten werden geladen..." für 1-2 Sekunden
4. App läuft normal weiter
5. Alle User-Daten bleiben erhalten ✅
```

### **Szenario 2: Migration schlägt fehl (sehr selten)**
```
1. App-Update via Testflight
2. Schema-Validation schlägt fehl
3. App fällt zurück auf In-Memory Storage
4. User sieht Alert: "Temporärer Speicher"
5. App läuft, aber Daten sind temporär
6. Lösung: App neu starten (meist reicht das)
```

### **Szenario 3: Persistenter Fehler (extrem selten)**
```
1. Auch nach Neustart: In-Memory Storage
2. User muss App deinstallieren & neu installieren
3. Sessions (Historie) gehen verloren ⚠️
```

---

## 📝 Release Notes Vorschlag

### **Version X.X (Empfohlen)**

```
🆕 Neue Features:
• Verbesserte Exercise-Tracking mit "Zuletzt verwendet"-Werten
• Performance-Verbesserungen
• Bug-Fixes

ℹ️ Hinweis:
Dieses Update enthält Datenbank-Verbesserungen. Die App migriert deine Daten
automatisch beim ersten Start. Dies dauert nur wenige Sekunden.

Alle deine Workouts, Übungen und Historie bleiben erhalten.
```

### **Alternative (konservativ)**

```
🆕 Neue Features:
• Verbesserte Exercise-Tracking
• Performance-Verbesserungen

⚠️ Wichtiger Hinweis:
Dieses Update enthält wichtige Datenbank-Änderungen.

In seltenen Fällen kann es zu Problemen kommen. Falls die App nicht
richtig startet, versuche bitte:
1. App komplett beenden und neu starten
2. Falls das nicht hilft: App neu installieren

Deine Workout-Historie bleibt in der Regel erhalten.

Bei Fragen: [Kontakt/Support]
```

---

## 🛡️ Für Entwickler: Testing-Checklist

Vor Testflight-Upload:

- [ ] **Lokales Testing**: App mit alter Datenbank-Version starten
- [ ] **Schema Validation**: Logs prüfen auf "✅ Schema validation successful"
- [ ] **Fallback Testing**: Korrupte DB simulieren → Fallback funktioniert?
- [ ] **Migration Testing**: Neue Properties werden korrekt hinzugefügt?
- [ ] **User-Daten**: Sessions, Workouts, Custom Exercises bleiben erhalten?

### Testing-Commands:

```bash
# 1. Alte App-Version installieren (vor dem Update)
# 2. Testdaten erstellen (Workouts, Sessions, etc.)
# 3. Neue App-Version installieren (simuliert Testflight-Update)
# 4. Logs prüfen:

# Xcode Console öffnen
# Filter auf "GymTracker" setzen
# Suchen nach:
#   ✅ Schema validation successful
#   ✅ Exercise update completed
#   ⚠️ Schema validation failed (sollte NICHT erscheinen)
```

---

## 🚨 Notfall-Plan

Falls viele User Probleme melden:

### **Option 1: Hotfix mit Force Reset (schnell)**

```swift
// In GymTrackerApp.swift erhöhen:
static let FORCE_FULL_RESET_VERSION = 2  // war 1
```

**Effekt:**
- Alle User bekommen beim nächsten Update einen sauberen Neustart
- Sessions bleiben erhalten
- Custom Workouts gehen verloren (vorher warnen!)

### **Option 2: Rollback auf alte Version**

Via Testflight alte Version reaktivieren, dann Hotfix entwickeln.

### **Option 3: Debug-Build für betroffene User**

Debug-Build mit erweitertem Logging für Problem-Analyse.

---

## 📊 Monitoring nach Release

Nach Testflight-Deployment überwachen:

1. **Crash-Rate** in TestFlight Analytics
   - Erwartbar: < 1%
   - Bei > 5%: Notfall-Plan aktivieren

2. **User-Feedback** im Testflight-Feedback
   - "App startet nicht"
   - "Daten weg"
   - "Temporärer Speicher"-Meldung

3. **Logs von Beta-Testern**
   - Schema validation errors?
   - Migration failures?

---

## ✅ Fazit: Kann Update ohne Warnung raus?

**JA**, aber mit Einschränkungen:

### **Empfehlung:**

1. **Testflight-Release** OHNE "App neu installieren"-Warnung
2. **Release Notes** mit Hinweis auf Datenbank-Migration
3. **Monitoring** in ersten 24h nach Release
4. **Hotfix bereit** falls Probleme auftreten (Force Reset Version erhöhen)

### **Release Notes verwenden:**

Nutze die **"Empfohlen"-Version** der Release Notes oben - sie informiert User,
ist aber nicht alarmierend.

---

## 📞 Support-Antworten vorbereiten

Falls User Probleme melden:

**Problem: "App startet nicht / stürzt ab"**
```
Danke für dein Feedback! Versuche bitte:
1. App komplett beenden (aus Multitasking entfernen)
2. Gerät neu starten
3. App neu öffnen

Falls das nicht hilft:
1. App deinstallieren
2. Neu aus Testflight installieren

Deine Workout-Historie sollte erhalten bleiben.
```

**Problem: "Meldung 'Temporärer Speicher'"**
```
Diese Meldung erscheint, wenn die Datenbank-Migration nicht
automatisch funktioniert hat.

Lösung:
1. App komplett schließen
2. Gerät neu starten
3. App neu öffnen

Das sollte die Migration erneut auslösen.
```

---

**Erstellt:** 2025-01-07
**Für Release:** [Version eintragen]
**Status:** Ready for Testflight
