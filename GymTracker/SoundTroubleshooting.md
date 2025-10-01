# Sound-Probleme Diagnostik Anleitung

## Problem: Eigener Sound wird nicht abgespielt

### Schritt 1: Datei-Spezifikationen überprüfen
Ihre WAV-Datei muss folgende Spezifikationen erfüllen:
- **Format**: WAV (PCM)
- **Sample Rate**: 44.1 kHz oder 48 kHz
- **Bit Depth**: 16-bit oder 24-bit
- **Kanäle**: Mono oder Stereo
- **Länge**: Maximal 30 Sekunden für System Sounds
- **Größe**: Unter 5 MB

### Schritt 2: Bundle-Integration überprüfen
1. Datei ist in Xcode Projekt hinzugefügt ✓
2. Datei ist zu "Target Membership" hinzugefügt ✓
3. Datei erscheint in "Copy Bundle Resources" Build Phase ✓

### Schritt 3: Dateiname überprüfen
- Keine Sonderzeichen
- Keine Leerzeichen (oder durch _ ersetzt)
- Korrekter Case (achten Sie auf Groß-/Kleinschreibung)
- .wav Erweiterung ist korrekt

### Schritt 4: Audio Debug verwenden
1. Öffnen Sie Einstellungen → Audio → Audio Debug
2. Klicken Sie "Alle verfügbaren Sounds auflisten"
3. Suchen Sie Ihre Datei in der Liste
4. Testen Sie mit dem exakten Dateinamen (ohne .wav)

### Schritt 5: Häufige Lösungen

#### Problem: Datei nicht gefunden
**Lösung**: 
- Überprüfen Sie Dateinamen-Schreibweise
- Stellen Sie sicher, dass die Datei im Bundle ist
- Verwenden Sie Audio Debug zum Auflisten aller Dateien

#### Problem: Sound wird erstellt aber nicht gehört
**Lösung**:
- Überprüfen Sie Lautstärke (sowohl System als auch App)
- Testen Sie "Stummschaltung ignorieren" Einstellung
- Überprüfen Sie, ob andere Audio läuft
- Testen Sie mit Kopfhörern

#### Problem: Format nicht unterstützt
**Lösung**:
- Konvertieren Sie zu den oben genannten Spezifikationen
- Verwenden Sie Audio-Konverter wie Audacity (kostenlos)

### Audio-Konvertierung mit Audacity
1. Datei in Audacity öffnen
2. Menü → Tracks → Resample... → 44100 Hz
3. Menü → File → Export → Export as WAV
4. Format: WAV (Microsoft) signed 16-bit PCM

### Alternativ: Online Konverter
- CloudConvert.com
- Online-Audio-Converter.com
- Convertio.co

Stellen Sie sicher, dass die Ausgabeeinstellungen stimmen:
- Format: WAV
- Quality: 44100 Hz, 16 bit
- Kanäle: Stereo oder Mono

### Test-Code für manuelle Überprüfung
```swift
// In einer View oder im AudioManager
if let soundURL = Bundle.main.url(forResource: "IHR_SOUND_NAME", withExtension: "wav") {
    print("✅ Sound gefunden: \(soundURL)")
    // Test mit AVAudioPlayer
    do {
        let player = AVAudioPlayer(contentsOf: soundURL)
        player.play()
        print("✅ AVAudioPlayer gestartet")
    } catch {
        print("❌ AVAudioPlayer Fehler: \(error)")
    }
} else {
    print("❌ Sound nicht gefunden")
}
```