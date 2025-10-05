import Foundation

/// Parser für Markdown-Tabellen mit Übungsdaten
struct ExerciseMarkdownParser {
    
    // MARK: - Mapping Dictionaries
    
    /// Mapping von deutschen Muskelgruppen-Strings zu MuscleGroup enum
    private static let muscleGroupMapping: [String: MuscleGroup] = [
        // Direkte Mappings
        "brust": .chest,
        "rücken": .back,
        "schultern": .shoulders,
        "bizeps": .biceps,
        "trizeps": .triceps,
        "beine": .legs,
        "gesäß": .glutes,
        "bauch": .abs,
        "cardio": .cardio,
        
        // Erweiterte Mappings mit alternativen Bezeichnungen
        "brustmuskulatur": .chest,
        "brustmuskeln": .chest,
        "obere brust": .chest,
        "untere brust": .chest,
        
        "rückenmuskulatur": .back,
        "latissimus": .back,
        "lat": .back,
        "oberer rücken": .back,
        "mittlerer rücken": .back,
        "unterer rücken": .back,
        "gesamter rücken": .back,
        "trapezmuskel": .back,
        
        "schultermuskulatur": .shoulders,
        "schultermuskeln": .shoulders,
        "deltamuskeln": .shoulders,
        "vorderer anteil": .shoulders,
        "seitlicher anteil": .shoulders,
        "hinterer anteil": .shoulders,
        
        "bizepsmuskel": .biceps,
        "armbeuger": .biceps,
        "oberarme": .biceps,
        
        "trizepsmuskel": .triceps,
        "armstrecker": .triceps,
        
        "beinmuskulatur": .legs,
        "oberschenkel": .legs,
        "unterschenkel": .legs,
        "quadrizeps": .legs,
        "beinbeuger": .legs,
        "waden": .legs,
        "adduktoren": .legs,
        "abduktoren": .legs,
        
        "gesäßmuskulatur": .glutes,
        "gesäßmuskeln": .glutes,
        "po": .glutes,
        "gluteus": .glutes,
        
        "bauchmuskulatur": .abs,
        "bauchmuskeln": .abs,
        "rumpf": .abs,
        "core": .abs,
        "gerader bauchmuskel": .abs,
        "schräge bauchmuskeln": .abs,
        "oberer anteil": .abs,
        "unterer anteil": .abs,
        
        "ganzkörper": .cardio,
        "kondition": .cardio,
        "ausdauer": .cardio
    ]
    
    /// Mapping von deutschen Equipment-Type Strings zu EquipmentType enum
    private static let equipmentTypeMapping: [String: EquipmentType] = [
        // Direkte Mappings aus MD-Datei
        "freie gewichte": .freeWeights,
        "körpergewicht": .bodyweight,
        "maschine": .machine,
        
        // Alternative Bezeichnungen
        "freigewichte": .freeWeights,
        "hantel": .freeWeights,
        "hanteln": .freeWeights,
        "langhantel": .freeWeights,
        "kurzhanteln": .freeWeights,
        "kettlebell": .freeWeights,
        "gewichte": .freeWeights,
        
        "bodyweight": .bodyweight,
        "eigengewicht": .bodyweight,
        "körper": .bodyweight,
        "ohne gewichte": .bodyweight,
        "ohne geräte": .bodyweight,
        
        "maschinen": .machine,
        "gerät": .machine,
        "geräte": .machine,
        "kraftstation": .machine,
        "kabelzug": .cable,
        "cable": .cable,
        "seilzug": .cable,
        
        "gemischt": .mixed,
        "mixed": .mixed,
        "kombiniert": .mixed
    ]
    
    /// Mapping von deutschen Schwierigkeitsgrad Strings zu DifficultyLevel enum
    private static let difficultyLevelMapping: [String: DifficultyLevel] = [
        // Direkte Mappings aus MD-Datei
        "anfänger": .anfänger,
        "fortgeschritten": .fortgeschritten,
        "profi": .profi,
        
        // Alternative Bezeichnungen
        "beginner": .anfänger,
        "einsteiger": .anfänger,
        "leicht": .anfänger,
        "einfach": .anfänger,
        "basic": .anfänger,
        
        "fortgeschrittene": .fortgeschritten,
        "intermediate": .fortgeschritten,
        "mittel": .fortgeschritten,
        "medium": .fortgeschritten,
        "advanced": .fortgeschritten,
        
        "expert": .profi,
        "experte": .profi,
        "schwer": .profi,
        "schwierig": .profi,
        "hart": .profi,
        "master": .profi
    ]
    
    // MARK: - Muscle Group Parsing
    
    /// Parst einen Muskelgruppen-String und extrahiert alle relevanten MuscleGroups
    /// - Parameter muscleGroupString: String wie "Beine (Quadrizeps, Gesäß, Beinbeuger)" oder "Brust, Schultern, Trizeps"
    /// - Returns: Array von MuscleGroup enums
    private static func parseMuscleGroups(from muscleGroupString: String) -> [MuscleGroup] {
        print("  🔍 Parse Muskelgruppen: '\(muscleGroupString)'")
        
        var foundGroups: Set<MuscleGroup> = []
        let lowercased = muscleGroupString.lowercased()
        
        // Entferne Klammern und teile bei Kommas auf
        let cleanedString = lowercased
            .replacingOccurrences(of: "(", with: ",")
            .replacingOccurrences(of: ")", with: ",")
        
        let parts = cleanedString.components(separatedBy: CharacterSet(charactersIn: ",;"))
        
        for part in parts {
            let trimmedPart = part.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            
            if trimmedPart.isEmpty { continue }
            
            // Direkte Suche in Mapping
            if let muscleGroup = muscleGroupMapping[trimmedPart] {
                foundGroups.insert(muscleGroup)
                print("    ✅ Gefunden: '\(trimmedPart)' → \(muscleGroup.rawValue)")
                continue
            }
            
            // Partielle Suche für zusammengesetzte Begriffe
            for (key, value) in muscleGroupMapping {
                if trimmedPart.contains(key) || key.contains(trimmedPart) {
                    foundGroups.insert(value)
                    print("    ✅ Teilmatch: '\(trimmedPart)' enthält '\(key)' → \(value.rawValue)")
                }
            }
        }
        
        let result = Array(foundGroups).sorted { $0.rawValue < $1.rawValue }
        print("    📋 Endergebnis: \(result.map { $0.rawValue }.joined(separator: ", "))")
        
        // Fallback: Falls nichts gefunden wurde, versuche Hauptkategorien zu erkennen
        if result.isEmpty {
            let fallback = detectMainMuscleCategory(from: muscleGroupString)
            if let fb = fallback {
                print("    🔄 Fallback verwendet: \(fb.rawValue)")
                return [fb]
            }
        }
        
        return result
    }
    
    /// Fallback-Erkennung für Hauptmuskelkategorien
    /// - Parameter string: Original-String
    /// - Returns: Beste Schätzung für MuscleGroup oder nil
    private static func detectMainMuscleCategory(from string: String) -> MuscleGroup? {
        let lowercased = string.lowercased()
        
        // Prioritätsbasierte Erkennung
        if lowercased.contains("bein") || lowercased.contains("schenkel") || lowercased.contains("squat") {
            return .legs
        }
        if lowercased.contains("brust") || lowercased.contains("chest") || lowercased.contains("press") {
            return .chest
        }
        if lowercased.contains("rücken") || lowercased.contains("back") || lowercased.contains("pull") {
            return .back
        }
        if lowercased.contains("schulter") || lowercased.contains("shoulder") {
            return .shoulders
        }
        if lowercased.contains("bauch") || lowercased.contains("abs") || lowercased.contains("core") {
            return .abs
        }
        if lowercased.contains("gesäß") || lowercased.contains("glute") || lowercased.contains("po") {
            return .glutes
        }
        
        return nil
    }
    
    // MARK: - Equipment Type & Difficulty Parsing
    
    /// Parst einen Equipment-Type String zu einem EquipmentType enum
    /// - Parameter equipmentString: String wie "Freie Gewichte", "Körpergewicht", "Maschine"
    /// - Returns: EquipmentType enum oder .mixed als Fallback
    private static func parseEquipmentType(from equipmentString: String) -> EquipmentType {
        let lowercased = equipmentString.lowercased().trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        
        print("  🏋️ Parse Equipment-Type: '\(equipmentString)'")
        
        // Direkte Suche im Mapping
        if let equipmentType = equipmentTypeMapping[lowercased] {
            print("    ✅ Gefunden: '\(lowercased)' → \(equipmentType.rawValue)")
            return equipmentType
        }
        
        // Partielle Suche für zusammengesetzte Begriffe
        for (key, value) in equipmentTypeMapping {
            if lowercased.contains(key) {
                print("    ✅ Teilmatch: '\(lowercased)' enthält '\(key)' → \(value.rawValue)")
                return value
            }
        }
        
        print("    🔄 Fallback verwendet: .mixed")
        return .mixed
    }
    
    /// Parst einen Schwierigkeitsgrad String zu einem DifficultyLevel enum
    /// - Parameter difficultyString: String wie "Anfänger", "Fortgeschritten", "Profi"
    /// - Returns: DifficultyLevel enum oder .anfänger als Fallback
    private static func parseDifficultyLevel(from difficultyString: String) -> DifficultyLevel {
        let lowercased = difficultyString.lowercased().trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        
        print("  📊 Parse Schwierigkeitsgrad: '\(difficultyString)'")
        
        // Direkte Suche im Mapping
        if let difficultyLevel = difficultyLevelMapping[lowercased] {
            print("    ✅ Gefunden: '\(lowercased)' → \(difficultyLevel.rawValue)")
            return difficultyLevel
        }
        
        // Partielle Suche für zusammengesetzte Begriffe
        for (key, value) in difficultyLevelMapping {
            if lowercased.contains(key) {
                print("    ✅ Teilmatch: '\(lowercased)' enthält '\(key)' → \(value.rawValue)")
                return value
            }
        }
        
        print("    🔄 Fallback verwendet: .anfänger")
        return .anfänger
    }
    
    /// Generiert Instructions aus einer Description
    /// - Parameter description: Beschreibungstext der Übung
    /// - Returns: Array von Instruktions-Steps
    private static func generateInstructions(from description: String) -> [String] {
        // Einfache Heuristik: Teile bei Satzzeichen auf
        let sentences = description.components(separatedBy: CharacterSet(charactersIn: ".!"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        if sentences.count > 1 {
            return sentences
        } else {
            // Fallback: Teile bei langen Beschreibungen bei Kommas
            let parts = description.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && $0.count > 10 }
            
            return parts.isEmpty ? [description] : parts
        }
    }
    
    /// Parst eine Markdown-Tabelle und extrahiert Exercise-Daten
    /// - Parameter content: Der Markdown-Inhalt als String
    /// - Returns: Array von Exercise-Objekten
    static func parseMarkdownTable(_ content: String) -> [Exercise] {
        print("🔄 Starte Parsing der Markdown-Tabelle...")
        
        // Zeilen aufteilen
        let lines = content.components(separatedBy: .newlines)
        print("📄 Gefunden: \(lines.count) Zeilen im Markdown")
        
        // Extrahiere nur die Tabellen-Zeilen
        let tableRows = extractTableRows(from: lines)
        print("📊 Extrahiert: \(tableRows.count) Tabellen-Zeilen")
        
        // Parse jede Zeile
        var exercises: [Exercise] = []
        
        for (index, row) in tableRows.enumerated() {
            let columns = parseTableRow(row)
            print("📋 Zeile \(index + 1): \(columns.count) Spalten")
            
            // Erwartete Spalten: Übung | Typ | Beschreibung | Muskelgruppe | Schwierigkeitsgrad
            if columns.count >= 5 {
                let name = columns[0]
                let typeString = columns[1]
                let description = columns[2]
                let muscleGroupString = columns[3]
                let difficultyString = columns[4]
                
                print("  📌 \(name)")
                
                // Phase 5: Vollständiges Mapping implementiert
                let muscleGroups = parseMuscleGroups(from: muscleGroupString)
                let equipmentType = parseEquipmentType(from: typeString)
                let difficultyLevel = parseDifficultyLevel(from: difficultyString)
                let instructions = generateInstructions(from: description)
                
                // Erstelle Exercise-Object
                let exercise = Exercise(
                    name: name,
                    muscleGroups: muscleGroups,
                    equipmentType: equipmentType,
                    difficultyLevel: difficultyLevel,
                    description: description,
                    instructions: instructions
                )
                
                exercises.append(exercise)
                
                print("  ✅ Exercise erstellt:")
                print("    📛 Name: \(name)")
                print("    💪 Muskelgruppen: \(muscleGroups.map { $0.rawValue }.joined(separator: ", "))")
                print("    🏋️ Equipment: \(equipmentType.rawValue)")
                print("    📊 Schwierigkeit: \(difficultyLevel.rawValue)")
                print("    📝 Instructions: \(instructions.count) Schritte")
                
            } else {
                print("  ⚠️ Zeile übersprungen (nur \(columns.count) Spalten)")
            }
        }
        
        print("✅ Parsing abgeschlossen. \(exercises.count) Übungen erstellt")
        return exercises
    }
    
    /// Extrahiert nur die Zeilen, die zur Tabelle gehören
    /// - Parameter lines: Alle Zeilen des Markdown-Inhalts
    /// - Returns: Array von Tabellen-Zeilen (ohne Header und Trennzeilen)
    private static func extractTableRows(from lines: [String]) -> [String] {
        var tableRows: [String] = []
        var inTable = false
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Leere Zeilen überspringen
            if trimmedLine.isEmpty {
                continue
            }
            
            // Header-Zeile erkennen (beginnt mit | **Übung** |)
            if trimmedLine.hasPrefix("| **Übung**") {
                inTable = true
                print("📋 Header-Zeile gefunden, starte Tabellen-Parsing")
                continue
            }
            
            // Trennzeile erkennen und überspringen (enthält nur |, -, und Leerzeichen)
            if trimmedLine.hasPrefix("|---") || trimmedLine.contains("---|---") {
                print("➖ Trennzeile übersprungen")
                continue
            }
            
            // Wenn wir in der Tabelle sind und die Zeile mit | beginnt
            if inTable && trimmedLine.hasPrefix("|") {
                // Prüfe ob es eine gültige Datenzeile ist (mindestens 5 | für 5 Spalten)
                let pipeCount = trimmedLine.components(separatedBy: "|").count - 1
                if pipeCount >= 4 {
                    tableRows.append(trimmedLine)
                } else {
                    print("⚠️ Zeile übersprungen (zu wenige Spalten): \(trimmedLine.prefix(50))")
                }
            }
            
            // Wenn wir in der Tabelle waren und eine Zeile nicht mit | beginnt, 
            // sind wir am Ende der Tabelle
            if inTable && !trimmedLine.hasPrefix("|") {
                print("🔚 Ende der Tabelle erreicht")
                break
            }
        }
        
        return tableRows
    }
    
    /// Parst eine einzelne Tabellen-Zeile in ihre Komponenten
    /// - Parameter row: Eine Tabellen-Zeile als String
    /// - Returns: Array von Spalten-Inhalten
    private static func parseTableRow(_ row: String) -> [String] {
        // Entferne führende und trailing |
        var cleanRow = row.trimmingCharacters(in: .whitespaces)
        if cleanRow.hasPrefix("|") {
            cleanRow.removeFirst()
        }
        if cleanRow.hasSuffix("|") {
            cleanRow.removeLast()
        }
        
        // Spalten aufteilen
        let columns = cleanRow.components(separatedBy: "|")
        
        // Jede Spalte trimmen und Markdown-Formatierung entfernen
        return columns.map { column in
            cleanColumnContent(column.trimmingCharacters(in: .whitespaces))
        }
    }
    
    /// Bereinigt den Inhalt einer Tabellen-Spalte von Markdown-Formatierung
    /// - Parameter content: Roher Spalten-Inhalt
    /// - Returns: Bereinigter Text
    private static func cleanColumnContent(_ content: String) -> String {
        var cleaned = content
        
        // Entferne **bold** Formatierung
        cleaned = cleaned.replacingOccurrences(of: "**", with: "")
        
        // Entferne andere Markdown-Formatierung falls nötig
        cleaned = cleaned.replacingOccurrences(of: "*", with: "")
        
        return cleaned.trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Test Helper für Phase 3-6
extension ExerciseMarkdownParser {
    
    /// Die vollständige Markdown-Übungsliste aus der bereitgestellten MD-Datei
    static let completeExerciseMarkdown = """
    # Umfassende Übungsliste für deine Gym-App

    Hier ist eine umfassende Liste von über 140 Übungen mit allen wichtigen Informationen für deine Gym-App. Jede Übung enthält den Typ (Freie Gewichte, Körpergewicht oder Maschine), eine kurze Beschreibung, die trainierte Muskelgruppe und den Schwierigkeitsgrad.

    ## Übungsliste

    | **Übung** | **Typ** | **Beschreibung** | **Muskelgruppe** | **Schwierigkeitsgrad** |
    |---|---|---|---|---|
    | **Kniebeugen (Squats)** | Freie Gewichte | Die Langhantel liegt auf dem oberen Rücken. Beuge die Knie und Hüfte, bis die Oberschenkel parallel zum Boden sind, und drücke dich wieder hoch. | Beine (Quadrizeps, Gesäß, Beinbeuger) | Fortgeschritten |
    | **Kreuzheben (Deadlift)** | Freie Gewichte | Hebe die Langhantel vom Boden, indem du Hüfte und Knie streckst, bis du aufrecht stehst. Der Rücken bleibt dabei gerade. | Rücken (gesamter Rücken), Beine, Gesäß | Fortgeschritten |
    | **Bankdrücken (Bench Press)** | Freie Gewichte | Lege dich auf eine Flachbank und drücke die Langhantel von der Brust nach oben, bis die Arme gestreckt sind. | Brust, Schultern, Trizeps | Fortgeschritten |
    | **Schulterdrücken (Overhead Press)** | Freie Gewichte | Drücke die Langhantel im Stehen oder Sitzen vom oberen Brustbereich über den Kopf, bis die Arme gestreckt sind. | Schultern, Trizeps | Fortgeschritten |
    | **Rudern vorgebeugt (Bent Over Row)** | Freie Gewichte | Beuge den Oberkörper vor und ziehe die Langhantel vom Boden in Richtung deines Bauches. | Rücken (Latissimus, oberer Rücken) | Fortgeschritten |
    | **Hüftstoßen (Hip Thrust)** | Freie Gewichte | Lege die Schultern auf eine Bank und platziere die Langhantel auf deiner Hüfte. Drücke die Hüfte nach oben, bis dein Körper eine gerade Linie bildet. | Gesäß, Beinbeuger | Anfänger |
    | **Ausfallschritte mit Langhantel (Barbell Lunges)** | Freie Gewichte | Mache mit der Langhantel auf dem Rücken einen großen Schritt nach vorne und beuge beide Knie, bevor du dich wieder abdrückst. | Beine (Quadrizeps, Gesäß) | Fortgeschritten |
    | **Good Mornings** | Freie Gewichte | Mit der Hantel auf dem Rücken beugst du den Oberkörper mit geradem Rücken nach vorne und richtest dich wieder auf. | Beinbeuger, unterer Rücken, Gesäß | Fortgeschritten |
    | **Langhantel Bizeps-Curls** | Freie Gewichte | Halte die Langhantel mit schulterbreitem Griff und beuge die Arme, um die Hantel in Richtung deiner Schultern zu heben. | Bizeps | Anfänger |
    | **Stirndrücken (Skull Crushers)** | Freie Gewichte | Lege dich auf eine Bank und senke die Langhantel kontrolliert in Richtung deiner Stirn, bevor du sie wieder nach oben drückst. | Trizeps | Fortgeschritten |
    | **Sumo-Kreuzheben** | Freie Gewichte | Eine Kreuzhebe-Variante mit sehr breitem Stand, die den Fokus stärker auf Gesäß und Beinbeuger legt. | Gesäß, Beinbeuger, Rücken | Fortgeschritten |
    | **Rumänisches Kreuzheben (Romanian Deadlift)** | Freie Gewichte | Eine Kreuzhebe-Variante mit fast gestreckten Beinen, um die Dehnung und Belastung auf die Beinbeuger zu maximieren. | Beinbeuger, Gesäß | Fortgeschritten |
    | **Frontkniebeugen (Front Squats)** | Freie Gewichte | Kniebeugen, bei denen die Langhantel auf den vorderen Schultern gehalten wird, was den Quadrizeps stärker beansprucht. | Beine (Quadrizeps), Rumpf | Fortgeschritten |
    | **Zercher Squats** | Freie Gewichte | Eine Kniebeugen-Variante, bei der die Langhantel in den Armbeugen gehalten wird, was den oberen Rücken und den Rumpf stark fordert. | Beine, oberer Rücken, Rumpf | Profi |
    | **Landmine Press** | Freie Gewichte | Drücke das Ende einer Langhantel, die in einer Ecke oder einer speziellen Halterung steckt, schräg nach oben. | Schultern, Brust | Fortgeschritten |
    | **T-Bar Row** | Freie Gewichte | Eine Ruder-Variante, bei der eine spezielle T-Stange oder eine Langhantel in einer Ecke verwendet wird. | Rücken (Latissimus, oberer Rücken) | Fortgeschritten |
    | **Floor Press** | Freie Gewichte | Bankdrücken auf dem Boden liegend, was den Bewegungsumfang reduziert und den Trizeps stärker belastet. | Trizeps, Brust | Fortgeschritten |
    | **JM Press** | Freie Gewichte | Eine Mischung aus engem Bankdrücken und Stirndrücken, um den Trizeps zu trainieren. | Trizeps | Profi |
    | **Pendlay Row** | Freie Gewichte | Eine explosive Ruder-Variante, bei der die Langhantel nach jeder Wiederholung auf dem Boden abgelegt wird. | Rücken (oberer Rücken, Latissimus) | Fortgeschritten |
    | **Rack Pulls** | Freie Gewichte | Eine Kreuzhebe-Variante, bei der die Langhantel von einer erhöhten Position aus gehoben wird. | Rücken (oberer Rücken), Trapezmuskel | Fortgeschritten |
    | **Deficit Deadlift** | Freie Gewichte | Kreuzheben von einer erhöhten Plattform aus, um den Bewegungsumfang zu vergrößern. | Rücken, Beine | Profi |
    | **Pause Squats** | Freie Gewichte | Kniebeugen mit einer Pause am tiefsten Punkt, um die Kraft aus der Hocke zu verbessern. | Beine | Fortgeschritten |
    | **Box Squats** | Freie Gewichte | Kniebeugen, bei denen du dich auf eine Box setzt, bevor du dich wieder hochdrückst. | Beine | Fortgeschritten |
    | **Overhead Squats** | Freie Gewichte | Kniebeugen mit der Langhantel über dem Kopf, was Mobilität und Stabilität erfordert. | Beine, Schultern, Rumpf | Profi |
    | **Snatch Grip Deadlift** | Freie Gewichte | Kreuzheben mit sehr breitem Griff, um den oberen Rücken stärker zu beanspruchen. | Rücken, Beine | Profi |
    | **Shrugs (Schulterheben)** | Freie Gewichte | Hebe die Schultern mit Kurzhanteln oder einer Langhantel nach oben, um den Trapezmuskel zu trainieren. | Trapezmuskel (oberer Anteil) | Anfänger |
    | **Upright Row** | Freie Gewichte | Ziehe eine Langhantel oder Kurzhanteln entlang des Körpers nach oben bis zur Brust. | Schultern, Trapezmuskel | Fortgeschritten |
    | **Incline Barbell Bench Press** | Freie Gewichte | Bankdrücken auf einer Schrägbank mit der Langhantel. | Obere Brust, Schultern | Fortgeschritten |
    | **Decline Barbell Bench Press** | Freie Gewichte | Bankdrücken auf einer Negativbank, um die untere Brust zu betonen. | Untere Brust, Trizeps | Fortgeschritten |
    | **Close Grip Bench Press** | Freie Gewichte | Bankdrücken mit engem Griff, um den Trizeps stärker zu beanspruchen. | Trizeps, Brust | Fortgeschritten |
    | **Kurzhantel-Bankdrücken** | Freie Gewichte | Wie Langhantel-Bankdrücken, aber mit zwei Kurzhanteln für einen größeren Bewegungsumfang. | Brust, Schultern, Trizeps | Anfänger |
    | **Schrägbankdrücken** | Freie Gewichte | Bankdrücken auf einer Schrägbank, um den oberen Teil der Brustmuskulatur stärker zu beanspruchen. | Obere Brust, Schultern | Anfänger |
    | **Fliegende (Flyes)** | Freie Gewichte | Lege dich auf eine Bank und führe die Kurzhanteln mit leicht gebeugten Armen in einer weiten Bogenbewegung zusammen. | Brust | Anfänger |
    | **Seitheben (Lateral Raises)** | Freie Gewichte | Hebe die Kurzhanteln seitlich an, bis deine Arme parallel zum Boden sind, um die seitlichen Schultermuskeln zu trainieren. | Schultern (seitlicher Anteil) | Anfänger |
    | **Frontheben (Front Raises)** | Freie Gewichte | Hebe die Kurzhanteln abwechselnd oder gleichzeitig mit gestreckten Armen nach vorne an. | Schultern (vorderer Anteil) | Anfänger |
    | **Arnold Press** | Freie Gewichte | Eine dynamische Schulterdrück-Variante, bei der die Handgelenke während der Bewegung gedreht werden. | Schultern | Fortgeschritten |
    | **Kurzhantel-Rudern** | Freie Gewichte | Stütze dich mit einem Knie und einer Hand auf einer Bank ab und ziehe die Kurzhantel seitlich am Körper hoch. | Rücken (Latissimus) | Anfänger |
    | **Goblet Squat** | Freie Gewichte | Halte eine Kurzhantel senkrecht vor deiner Brust und führe eine tiefe Kniebeuge aus. | Beine (Quadrizeps, Gesäß) | Anfänger |
    | **Bulgarian Split Squats** | Freie Gewichte | Stelle einen Fuß auf einer Erhöhung hinter dir ab und führe mit dem vorderen Bein eine Kniebeuge aus. | Beine (Quadrizeps, Gesäß) | Fortgeschritten |
    | **Hammer-Curls** | Freie Gewichte | Bizeps-Curls mit neutralem Griff (Handflächen zeigen zueinander), um den Brachialis-Muskel zu trainieren. | Bizeps, Unterarme | Anfänger |
    | **Konzentrations-Curls** | Freie Gewichte | Setze dich und stütze den Ellbogen am Oberschenkel ab, während du einen Bizeps-Curl ausführst. | Bizeps (isolierter Muskel) | Anfänger |
    | **Trizeps-Kickbacks** | Freie Gewichte | Beuge den Oberkörper vor und strecke den Arm mit der Kurzhantel nach hinten aus. | Trizeps | Anfänger |
    | **Wadenheben mit Kurzhanteln** | Freie Gewichte | Halte Kurzhanteln in den Händen und stelle dich auf die Zehenspitzen, um die Waden zu trainieren. | Waden | Anfänger |
    | **Zottman Curls** | Freie Gewichte | Eine Bizeps-Curl-Variante, bei der die Handgelenke am oberen Punkt gedreht werden, um auch die Unterarme zu trainieren. | Bizeps, Unterarme | Fortgeschritten |
    | **Reverse Curls** | Freie Gewichte | Bizeps-Curls mit Obergriff (Handflächen zeigen nach unten), um den Brachioradialis zu stärken. | Unterarme, Bizeps | Anfänger |
    | **Incline Dumbbell Curls** | Freie Gewichte | Bizeps-Curls auf einer Schrägbank, um den langen Kopf des Bizeps stärker zu dehnen und zu beanspruchen. | Bizeps (langer Kopf) | Fortgeschritten |
    | **Spider Curls** | Freie Gewichte | Bizeps-Curls auf der Schrägseite einer Bank liegend, um den Bizeps in einer verkürzten Position zu isolieren. | Bizeps (kurzer Kopf) | Fortgeschritten |
    | **Overhead Triceps Extension** | Freie Gewichte | Strecke die Arme mit einer Kurzhantel oder Langhantel über dem Kopf nach oben. | Trizeps | Anfänger |
    | **Dumbbell Pullover** | Freie Gewichte | Lege dich quer auf eine Bank und senke eine Kurzhantel mit gestreckten Armen hinter deinem Kopf ab. | Brust, Rücken (Latissimus) | Fortgeschritten |
    | **Renegade Rows** | Freie Gewichte | Führe in der Liegestützposition mit Kurzhanteln in den Händen abwechselnd eine Ruderbewegung aus. | Rücken, Rumpf | Profi |
    | **Farmer's Walk** | Freie Gewichte | Gehe mit schweren Kurzhanteln oder Kettlebells in jeder Hand eine bestimmte Strecke. | Griffkraft, Ganzkörper | Anfänger |
    | **Meadows Row** | Freie Gewichte | Eine einarmige Ruder-Variante mit einer Langhantel, benannt nach dem Bodybuilder John Meadows. | Rücken (Latissimus) | Fortgeschritten |
    | **Dumbbell Bench Press (Neutral Grip)** | Freie Gewichte | Bankdrücken mit neutralem Griff (Handflächen zeigen zueinander), um die Schultern zu entlasten. | Brust, Trizeps | Anfänger |
    | **Single Arm Overhead Press** | Freie Gewichte | Schulterdrücken mit einer Kurzhantel oder Kettlebell, um die Rumpfstabilität zu fordern. | Schultern, Rumpf | Fortgeschritten |
    | **Kettlebell Swing** | Freie Gewichte | Schwinge die Kettlebell mit einer explosiven Hüftbewegung nach vorne bis auf Brusthöhe. | Gesäß, Beinbeuger, unterer Rücken | Anfänger |
    | **Turkish Get-Up** | Freie Gewichte | Eine komplexe Ganzkörperübung, bei der du vom Liegen mit der Kettlebell über dem Kopf zum Stehen aufstehst. | Ganzkörper, Rumpf | Profi |
    | **Kettlebell Goblet Squat** | Freie Gewichte | Halte die Kettlebell mit beiden Händen vor der Brust und führe eine tiefe Kniebeuge aus. | Beine, Gesäß, Rumpf | Anfänger |
    | **Kettlebell Clean and Press** | Freie Gewichte | Bringe die Kettlebell in einer fließenden Bewegung vom Boden zur Schulter (Clean) und drücke sie dann über den Kopf (Press). | Ganzkörper | Fortgeschritten |
    | **Kettlebell Snatch** | Freie Gewichte | Eine explosive Übung, bei der die Kettlebell in einer einzigen Bewegung vom Boden über den Kopf geführt wird. | Ganzkörper | Profi |
    | **Windmill** | Freie Gewichte | Eine Stabilitätsübung, bei der du dich seitlich beugst, während du eine Kettlebell über dem Kopf hältst. | Rumpf, Schultern | Profi |
    | **Kettlebell Halo** | Freie Gewichte | Kreise eine Kettlebell um deinen Kopf, um die Schulterstabilität und -mobilität zu verbessern. | Schultern, Rumpf | Anfänger |
    | **Kettlebell Figure 8** | Freie Gewichte | Führe die Kettlebell in einer Achterbewegung durch deine Beine. | Rumpf, Koordination | Anfänger |
    | **Liegestütze (Push-ups)** | Körpergewicht | Drücke deinen Körper vom Boden weg, bis die Arme gestreckt sind. Hände sind schulterbreit platziert. | Brust, Schultern, Trizeps | Anfänger |
    | **Klimmzüge (Pull-ups)** | Körpergewicht | Ziehe deinen Körper an einer Stange nach oben, bis dein Kinn über der Stange ist. | Rücken (Latissimus), Bizeps | Fortgeschritten |
    | **Dips** | Körpergewicht | Stütze dich auf zwei Barren und senke deinen Körper ab, indem du die Ellbogen beugst, und drücke dich wieder hoch. | Trizeps, Brust, Schultern | Fortgeschritten |
    | **Kniebeugen (Bodyweight Squats)** | Körpergewicht | Führe eine Kniebeuge ohne zusätzliches Gewicht aus. | Beine (Quadrizeps, Gesäß) | Anfänger |
    | **Ausfallschritte (Lunges)** | Körpergewicht | Mache einen großen Schritt nach vorne und beuge beide Knie zu einem 90-Grad-Winkel. | Beine (Quadrizeps, Gesäß) | Anfänger |
    | **Plank (Unterarmstütz)** | Körpergewicht | Halte den Körper in einer geraden Linie, gestützt auf Unterarmen und Zehenspitzen. | Rumpf (gesamte Bauchmuskulatur) | Anfänger |
    | **Burpees** | Körpergewicht | Eine Ganzkörperübung, die aus einer Kniebeuge, einem Liegestütz und einem Strecksprung besteht. | Ganzkörper | Fortgeschritten |
    | **Mountain Climbers** | Körpergewicht | Bringe in der Liegestützposition abwechselnd die Knie zur Brust, als ob du einen Berg erklimmst. | Rumpf, Cardio | Anfänger |
    | **Sit-ups** | Körpergewicht | Lege dich auf den Rücken und richte den Oberkörper auf, bis du sitzt. | Bauch (gerader Bauchmuskel) | Anfänger |
    | **Crunches** | Körpergewicht | Eine Variante der Sit-ups, bei der nur der obere Rücken vom Boden abgehoben wird. | Bauch (oberer Anteil) | Anfänger |
    | **Beinheben (Leg Raises)** | Körpergewicht | Lege dich auf den Rücken und hebe die gestreckten Beine an, bis sie senkrecht zum Boden stehen. | Bauch (unterer Anteil) | Fortgeschritten |
    | **Glute Bridge** | Körpergewicht | Lege dich auf den Rücken, stelle die Füße auf und drücke die Hüfte nach oben. | Gesäß, unterer Rücken | Anfänger |
    | **Pistol Squats** | Körpergewicht | Einbeinige Kniebeugen, die ein hohes Maß an Kraft und Gleichgewicht erfordern. | Beine (Quadrizeps, Gesäß) | Profi |
    | **Handstand Push-ups** | Körpergewicht | Liegestütze im Handstand, meist an einer Wand zur Unterstützung. | Schultern, Trizeps | Profi |
    | **Muscle-ups** | Körpergewicht | Eine fortgeschrittene Übung, die einen Klimmzug und einen Dip kombiniert. | Rücken, Brust, Schultern, Arme | Profi |
    | **Superman** | Körpergewicht | Lege dich auf den Bauch und hebe gleichzeitig Arme und Beine an. | Unterer Rücken | Anfänger |
    | **Wandsitzen (Wall Sit)** | Körpergewicht | Lehne dich mit dem Rücken an eine Wand und gehe in die Hocke, als ob du auf einem Stuhl sitzt. | Beine (Quadrizeps) | Anfänger |
    | **Box Jumps** | Körpergewicht | Springe mit beiden Füßen auf eine erhöhte Plattform oder Box. | Beine (explosive Kraft) | Fortgeschritten |
    | **Diamond Push-ups** | Körpergewicht | Eine Liegestütz-Variante mit enger Handstellung (Daumen und Zeigefinger bilden ein Dreieck), um den Trizeps stärker zu beanspruchen. | Trizeps, Brust | Fortgeschritten |
    | **Pike Push-ups** | Körpergewicht | Eine Liegestütz-Variante, bei der die Hüfte hochgehalten wird, um die Schultern stärker zu belasten. | Schultern | Fortgeschritten |
    | **Archer Push-ups** | Körpergewicht | Eine Liegestütz-Variante, bei der ein Arm zur Seite ausgestreckt wird, um die Belastung auf den anderen Arm zu erhöhen. | Brust, Schultern, Trizeps | Profi |
    | **Typewriter Push-ups** | Körpergewicht | Bewege den Körper in der unteren Liegestützposition von einer Seite zur anderen, wie eine Schreibmaschine. | Brust, Schultern, Trizeps | Profi |
    | **Chin-ups** | Körpergewicht | Eine Klimmzug-Variante mit Untergriff (Handflächen zeigen zu dir), die den Bizeps stärker einbezieht. | Rücken (Latissimus), Bizeps | Fortgeschritten |
    | **Neutral Grip Pull-ups** | Körpergewicht | Klimmzüge mit parallelem Griff, was eine gute Balance zwischen Bizeps- und Rückenbelastung darstellt. | Rücken, Bizeps | Fortgeschritten |
    | **Inverted Row (Australische Klimmzüge)** | Körpergewicht | Hänge dich unter eine Stange oder einen Tisch und ziehe deine Brust zur Stange. | Rücken (oberer Rücken) | Anfänger |
    | **Shrimp Squats** | Körpergewicht | Eine einbeinige Kniebeugen-Variante, bei der der freie Fuß hinter dem Körper gehalten wird. | Beine (Quadrizeps, Gesäß) | Profi |
    | **Cossack Squats** | Körpergewicht | Eine seitliche Kniebeuge, bei der du dein Gewicht auf ein Bein verlagerst, während das andere gestreckt bleibt. | Beine (Adduktoren, Quadrizeps, Gesäß) | Fortgeschritten |
    | **L-Sit** | Körpergewicht | Halte dich an Barren oder am Boden und hebe deine gestreckten Beine an, sodass dein Körper eine L-Form bildet. | Rumpf, Hüftbeuger | Profi |
    | **V-ups** | Körpergewicht | Lege dich auf den Rücken und bringe gleichzeitig Hände und Füße in der Mitte zusammen. | Bauch | Fortgeschritten |
    | **Russian Twists** | Körpergewicht | Drehe im Sitzen den Oberkörper von einer Seite zur anderen, um die schrägen Bauchmuskeln zu trainieren. | Bauch (schräge Bauchmuskeln) | Anfänger |
    | **Hanging Leg Raises** | Körpergewicht | Hänge an einer Stange und hebe deine Beine (gebeugt oder gestreckt) an. | Bauch (unterer Anteil), Hüftbeuger | Fortgeschritten |
    | **Hanging Knee Raises** | Körpergewicht | Eine leichtere Variante der Hanging Leg Raises, bei der die Knie zur Brust gezogen werden. | Bauch (unterer Anteil), Hüftbeuger | Anfänger |
    | **Dragon Flag** | Körpergewicht | Eine fortgeschrittene Bauchübung, bei der der Körper gestreckt vom Boden abgesenkt wird, während man sich an einem Objekt festhält. | Rumpf (gesamte Bauchmuskulatur) | Profi |
    | **Back Extension (Hyperextension)** | Körpergewicht | Führe eine Rückenstreckung ohne Gerät durch, indem du auf dem Bauch liegst. | Unterer Rücken | Anfänger |
    | **Nordic Hamstring Curls** | Körpergewicht | Knie dich hin und lasse dich von einem Partner an den Fersen festhalten, während du den Oberkörper langsam nach vorne absenkst. | Beinbeuger | Profi |
    | **Calf Raises (Bodyweight)** | Körpergewicht | Hebe auf einer Stufe oder am Boden stehend die Fersen an. | Waden | Anfänger |
    | **Single Leg Calf Raises** | Körpergewicht | Einbeiniges Wadenheben für eine intensivere Belastung. | Waden | Fortgeschritten |
    | **Broad Jumps** | Körpergewicht | Springe aus dem Stand so weit wie möglich nach vorne. | Beine (explosive Kraft) | Anfänger |
    | **Tuck Jumps** | Körpergewicht | Springe in die Luft und ziehe die Knie so hoch wie möglich zur Brust. | Beine (explosive Kraft) | Fortgeschritten |
    | **Bear Crawl** | Körpergewicht | Bewege dich auf allen Vieren vorwärts, wobei die Knie knapp über dem Boden schweben. | Ganzkörper, Rumpf | Anfänger |
    | **Pseudo Planche Push-ups** | Körpergewicht | Eine fortgeschrittene Liegestütz-Variante, bei der die Hände weiter hinten platziert werden, um die Schultern stärker zu belasten. | Schultern, Brust | Profi |
    | **Decline Push-ups** | Körpergewicht | Liegestütze mit erhöhten Füßen, um die obere Brust und Schultern stärker zu beanspruchen. | Obere Brust, Schultern | Fortgeschritten |
    | **Incline Push-ups** | Körpergewicht | Liegestütze mit erhöhten Händen, um die Übung zu erleichtern. | Brust, Schultern, Trizeps | Anfänger |
    | **Clap Push-ups** | Körpergewicht | Explosive Liegestütze, bei denen du in der Luft in die Hände klatschst. | Brust, Schultern, Trizeps (explosive Kraft) | Profi |
    | **One Arm Push-ups** | Körpergewicht | Liegestütze auf einem Arm, eine sehr fortgeschrittene Übung. | Brust, Schultern, Trizeps, Rumpf | Profi |
    | **Scapular Pull-ups** | Körpergewicht | Kleine Klimmzug-Bewegungen, bei denen nur die Schulterblätter bewegt werden, um die Schulterstabilität zu verbessern. | Schulterblätter, oberer Rücken | Anfänger |
    | **Commando Pull-ups** | Körpergewicht | Klimmzüge mit parallelem Griff, bei denen der Kopf abwechselnd links und rechts an der Stange vorbeigeführt wird. | Rücken, Bizeps | Profi |
    | **Hanging Windshield Wipers** | Körpergewicht | Hänge an einer Stange und bewege die gestreckten Beine von einer Seite zur anderen. | Rumpf (schräge Bauchmuskeln) | Profi |
    | **Hollow Body Hold** | Körpergewicht | Lege dich auf den Rücken und hebe Schultern und Beine leicht an, um den Rumpf zu spannen. | Rumpf | Fortgeschritten |
    | **Arch Body Hold** | Körpergewicht | Lege dich auf den Bauch und hebe Arme und Beine an, um den unteren Rücken zu trainieren. | Unterer Rücken | Anfänger |
    | **Side Plank** | Körpergewicht | Halte den Körper in einer seitlichen Linie, gestützt auf einem Unterarm. | Rumpf (schräge Bauchmuskeln) | Anfänger |
    | **Copenhagen Plank** | Körpergewicht | Eine fortgeschrittene Seitstütz-Variante, bei der das obere Bein auf einer Erhöhung liegt. | Adduktoren, Rumpf | Profi |
    | **Jumping Lunges** | Körpergewicht | Wechsle in einem Sprung zwischen Ausfallschritten. | Beine (explosive Kraft) | Fortgeschritten |
    | **Step-ups** | Körpergewicht | Steige auf eine erhöhte Plattform oder Box und wieder herunter. | Beine (Quadrizeps, Gesäß) | Anfänger |
    | **Reverse Hyperextensions** | Körpergewicht | Lege dich mit dem Oberkörper auf eine Bank und hebe die Beine nach hinten an. | Gesäß, unterer Rücken | Fortgeschritten |
    | **Beinpresse (Leg Press)** | Maschine | Setze dich in die Maschine und drücke eine gewichtete Plattform mit den Füßen weg. | Beine (Quadrizeps, Gesäß, Beinbeuger) | Anfänger |
    | **Beinstrecker (Leg Extension)** | Maschine | Strecke im Sitzen die Unterschenkel gegen einen Widerstand nach oben. | Beine (Quadrizeps) | Anfänger |
    | **Beinbeuger (Leg Curl)** | Maschine | Beuge im Liegen oder Sitzen die Unterschenkel gegen einen Widerstand nach hinten. | Beine (Beinbeuger) | Anfänger |
    | **Latzug (Lat Pulldown)** | Maschine | Ziehe im Sitzen eine Stange von oben nach unten zur Brust. | Rücken (Latissimus) | Anfänger |
    | **Rudermaschine (Seated Cable Row)** | Maschine | Ziehe im Sitzen einen Griff aus einer horizontalen Position zu deinem Bauch. | Rücken (oberer Rücken, Latissimus) | Anfänger |
    | **Brustpresse (Chest Press Machine)** | Maschine | Drücke im Sitzen zwei Griffe von der Brust weg nach vorne. | Brust, Schultern, Trizeps | Anfänger |
    | **Butterfly (Pec Deck Machine)** | Maschine | Führe im Sitzen zwei Hebel mit den Armen vor der Brust zusammen. | Brust (isoliert) | Anfänger |
    | **Schulterdrück-Maschine (Shoulder Press Machine)** | Maschine | Drücke im Sitzen zwei Griffe über den Kopf. | Schultern | Anfänger |
    | **Seithebe-Maschine (Lateral Raise Machine)** | Maschine | Hebe im Sitzen die Arme seitlich gegen einen Widerstand an. | Schultern (seitlicher Anteil) | Anfänger |
    | **Bizeps-Maschine (Biceps Curl Machine)** | Maschine | Beuge die Arme gegen einen Widerstand, um die Bizeps zu trainieren. | Bizeps | Anfänger |
    | **Trizeps-Maschine (Triceps Extension Machine)** | Maschine | Strecke die Arme gegen einen Widerstand nach unten oder hinten. | Trizeps | Anfänger |
    | **Wadenhebe-Maschine (Calf Raise Machine)** | Maschine | Hebe im Stehen oder Sitzen die Fersen an, um die Waden zu trainieren. | Waden | Anfänger |
    | **Abduktoren-Maschine (Hip Abduction Machine)** | Maschine | Spreize im Sitzen die Beine gegen einen Widerstand nach außen. | Hüfte (Abduktoren), Gesäß | Anfänger |
    | **Adduktoren-Maschine (Hip Adduction Machine)** | Maschine | Führe im Sitzen die Beine gegen einen Widerstand zusammen. | Hüfte (Adduktoren) | Anfänger |
    | **Smith Machine Squats** | Maschine | Kniebeugen in einer geführten Langhantel-Maschine (Smith Machine). | Beine (Quadrizeps, Gesäß) | Anfänger |
    | **Smith Machine Bench Press** | Maschine | Bankdrücken in der Smith Machine. | Brust, Schultern, Trizeps | Anfänger |
    | **Kabelzug-Crossover (Cable Crossover)** | Maschine | Führe am Kabelzug die Griffe von oben oder unten vor der Brust zusammen. | Brust | Fortgeschritten |
    | **Kabel-Rudern (Cable Row)** | Maschine | Verschiedene Ruder-Varianten am Kabelzug. | Rücken | Anfänger |
    | **Kabel-Trizepsdrücken (Cable Triceps Pushdown)** | Maschine | Drücke am Kabelzug einen Griff oder ein Seil von oben nach unten. | Trizeps | Anfänger |
    | **Kabel-Bizeps-Curls (Cable Biceps Curls)** | Maschine | Führe Bizeps-Curls am Kabelzug aus. | Bizeps | Anfänger |
    | **Hackenschmidt-Maschine (Hack Squat)** | Maschine | Eine Kniebeugen-Variante, bei der du dich gegen eine geneigte Plattform drückst. | Beine (Quadrizeps) | Fortgeschritten |
    | **Rückenstrecker-Maschine (Back Extension Machine)** | Maschine | Richte den Oberkörper gegen einen Widerstand auf, um den unteren Rücken zu stärken. | Unterer Rücken | Anfänger |
    | **Bauchmuskel-Maschine (Abdominal Crunch Machine)** | Maschine | Führe Crunches in einer sitzenden Position gegen einen Widerstand aus. | Bauch | Anfänger |
    | **Assisted Pull-up/Dip Machine** | Maschine | Eine Maschine, die dir bei Klimmzügen und Dips hilft, indem sie einen Teil deines Körpergewichts kompensiert. | Rücken, Bizeps, Brust, Trizeps | Anfänger |
    | **Reverse Pec Deck (Rear Delt Fly Machine)** | Maschine | Führe die Hebel am Pec Deck nach hinten, um die hintere Schulter zu trainieren. | Schultern (hinterer Anteil) | Anfänger |
    | **Preacher Curl Machine** | Maschine | Eine Bizeps-Curl-Maschine mit einer Armauflage, die den Bizeps isoliert. | Bizeps | Anfänger |
    | **Cable Lateral Raises** | Maschine | Seitheben am Kabelzug für eine konstante Spannung während der gesamten Bewegung. | Schultern (seitlicher Anteil) | Anfänger |
    | **Cable Front Raises** | Maschine | Frontheben am Kabelzug. | Schultern (vorderer Anteil) | Anfänger |
    | **Cable Reverse Flyes** | Maschine | Führe die Kabelgriffe nach hinten, um die hintere Schulter zu trainieren. | Schultern (hinterer Anteil) | Anfänger |
    | **Cable Face Pulls** | Maschine | Ziehe ein Seil am Kabelzug zum Gesicht, um die hintere Schulter und den oberen Rücken zu stärken. | Schultern (hinterer Anteil), oberer Rücken | Anfänger |
    | **Cable Woodchoppers** | Maschine | Eine diagonale Zugbewegung am Kabelzug, die die schrägen Bauchmuskeln trainiert. | Bauch (schräge Bauchmuskeln) | Fortgeschritten |
    | **Cable Pallof Press** | Maschine | Drücke einen Kabelgriff vor der Brust weg, während du der Rotation widerstehst. | Rumpf (Anti-Rotation) | Fortgeschritten |
    | **Cable Kickbacks** | Maschine | Trizeps-Kickbacks am Kabelzug. | Trizeps | Anfänger |
    | **Leg Press (Narrow Stance)** | Maschine | Beinpresse mit enger Fußstellung, um den Quadrizeps stärker zu beanspruchen. | Beine (Quadrizeps) | Anfänger |
    | **Leg Press (Wide Stance)** | Maschine | Beinpresse mit breiter Fußstellung, um Gesäß und Adduktoren stärker zu beanspruchen. | Gesäß, Adduktoren | Anfänger |
    | **Sissy Squats (Machine)** | Maschine | Eine Kniebeugen-Variante, die den Quadrizeps stark isoliert, oft mit einer speziellen Maschine. | Beine (Quadrizeps) | Fortgeschritten |
    | **Glute Kickback Machine** | Maschine | Drücke ein Bein nach hinten gegen einen Widerstand, um das Gesäß zu trainieren. | Gesäß | Anfänger |
    | **Seated Leg Curl** | Maschine | Eine Variante des Beinbeugers im Sitzen. | Beine (Beinbeuger) | Anfänger |
    | **Standing Leg Curl** | Maschine | Eine Variante des Beinbeugers im Stehen. | Beine (Beinbeuger) | Anfänger |
    | **Seated Calf Raise Machine** | Maschine | Wadenheben im Sitzen, um den Soleus-Muskel zu trainieren. | Waden (Soleus) | Anfänger |
    | **Standing Calf Raise Machine** | Maschine | Wadenheben im Stehen, um den Gastrocnemius zu trainieren. | Waden (Gastrocnemius) | Anfänger |
    | **Torso Rotation Machine** | Maschine | Drehe den Oberkörper gegen einen Widerstand, um die schrägen Bauchmuskeln zu trainieren. | Bauch (schräge Bauchmuskeln) | Anfänger |
    | **Vertical Leg Press** | Maschine | Eine Beinpresse, bei der du auf dem Rücken liegst und die Plattform vertikal nach oben drückst. | Beine | Fortgeschritten |

    ## Zusammenfassung

    Diese umfassende Liste enthält **145 Übungen** für deine Gym-App, aufgeteilt in:

    - **60 Übungen mit freien Gewichten** (Langhantel, Kurzhantel, Kettlebell)
    - **45 Körpergewichtsübungen** (ohne Geräte)
    - **40 Maschinenübungen** (Kraftmaschinen und Kabelzug)

    Jede Übung ist mit folgenden Informationen versehen:
    - **Typ**: Freie Gewichte, Körpergewicht oder Maschine
    - **Beschreibung**: Kurze Anleitung zur Ausführung
    - **Muskelgruppe**: Primär trainierte Muskeln
    - **Schwierigkeitsgrad**: Anfänger, Fortgeschritten oder Profi

    Die Liste deckt alle wichtigen Muskelgruppen ab und bietet für jedes Fitnesslevel passende Übungen.
    """
    
    /// Parse die vollständige Übungsliste aus der MD-Datei
    /// - Returns: Array aller 145+ Übungen aus der MD-Datei
    static func parseCompleteExerciseList() -> [Exercise] {
        print("📖 Parse vollständige Übungsliste aus eingebetteter MD-Datei...")
        return parseMarkdownTable(completeExerciseMarkdown)
    }
    
    /// Test-Funktion um den Parser mit Sample-Daten zu testen
    static func testWithSampleData() {
        let sampleMarkdown = """
        # Umfassende Übungsliste für deine Gym-App

        Hier ist eine umfassende Liste von über 140 Übungen mit allen wichtigen Informationen für deine Gym-App.

        ## Übungsliste

        | **Übung** | **Typ** | **Beschreibung** | **Muskelgruppe** | **Schwierigkeitsgrad** |
        |---|---|---|---|---|
        | **Kniebeugen (Squats)** | Freie Gewichte | Die Langhantel liegt auf dem oberen Rücken. Beuge die Knie und Hüfte, bis die Oberschenkel parallel zum Boden sind. | Beine (Quadrizeps, Gesäß, Beinbeuger) | Fortgeschritten |
        | **Kreuzheben (Deadlift)** | Freie Gewichte | Hebe die Langhantel vom Boden, indem du Hüfte und Knie streckst, bis du aufrecht stehst. | Rücken (gesamter Rücken), Beine, Gesäß | Fortgeschritten |
        | **Bankdrücken (Bench Press)** | Freie Gewichte | Lege dich auf eine Flachbank und drücke die Langhantel von der Brust nach oben. | Brust, Schultern, Trizeps | Fortgeschritten |
        | **Liegestütze (Push-ups)** | Körpergewicht | Drücke deinen Körper vom Boden weg, bis die Arme gestreckt sind. | Brust, Schultern, Trizeps | Anfänger |
        | **Klimmzüge (Pull-ups)** | Körpergewicht | Ziehe deinen Körper an einer Stange nach oben, bis dein Kinn über der Stange ist. | Rücken (Latissimus), Bizeps | Fortgeschritten |
        | **Beinpresse (Leg Press)** | Maschine | Setze dich in die Maschine und drücke eine gewichtete Plattform mit den Füßen weg. | Beine (Quadrizeps, Gesäß, Beinbeuger) | Anfänger |
        | **Latzug (Lat Pulldown)** | Maschine | Ziehe im Sitzen eine Stange von oben nach unten zur Brust. | Rücken (Latissimus) | Anfänger |

        ## Zusammenfassung

        Diese Liste enthält **145 Übungen** für deine Gym-App.
        """
        
        print("🧪 Teste Parser mit Sample-Daten...")
        let results = parseMarkdownTable(sampleMarkdown)
        print("✅ Parser-Test abgeschlossen. Gefunden: \(results.count) Übungen")
    }
    
    /// Test-Funktion speziell für Muskelgruppen-Mapping
    static func testMuscleGroupMapping() {
        print("🔬 Teste Muskelgruppen-Mapping...")
        
        let testCases = [
            "Beine (Quadrizeps, Gesäß, Beinbeuger)",
            "Rücken (gesamter Rücken), Beine, Gesäß",
            "Brust, Schultern, Trizeps",
            "Rücken (Latissimus), Bizeps",
            "Bauch (unterer Anteil)",
            "Schultern (seitlicher Anteil)",
            "Rumpf (gesamte Bauchmuskulatur)",
            "Ganzkörper",
            "Unbekannte Muskelgruppe"
        ]
        
        for testCase in testCases {
            print("\n🧪 Teste: '\(testCase)'")
            let result = parseMuscleGroups(from: testCase)
            print("   Ergebnis: \(result.map { $0.rawValue }.joined(separator: ", "))")
        }
        
        print("\n✅ Muskelgruppen-Mapping Test abgeschlossen")
    }
    
    /// Test-Funktion speziell für Equipment-Type und Schwierigkeitsgrad-Mapping
    static func testEquipmentAndDifficultyMapping() {
        print("🔧 Teste Equipment-Type und Schwierigkeitsgrad-Mapping...\n")
        
        // Equipment-Type Tests
        print("🏋️ Equipment-Type Tests:")
        let equipmentTestCases = [
            "Freie Gewichte",
            "Körpergewicht", 
            "Maschine",
            "Kabelzug",
            "Hanteln",
            "Bodyweight",
            "Kraftstation",
            "Unbekanntes Equipment"
        ]
        
        for testCase in equipmentTestCases {
            print("  🧪 '\(testCase)' → \(parseEquipmentType(from: testCase).rawValue)")
        }
        
        // Schwierigkeitsgrad Tests
        print("\n📊 Schwierigkeitsgrad Tests:")
        let difficultyTestCases = [
            "Anfänger",
            "Fortgeschritten",
            "Profi",
            "Beginner",
            "Intermediate", 
            "Expert",
            "Leicht",
            "Schwer",
            "Unbekannte Schwierigkeit"
        ]
        
        for testCase in difficultyTestCases {
            print("  🧪 '\(testCase)' → \(parseDifficultyLevel(from: testCase).rawValue)")
        }
        
        print("\n✅ Equipment und Schwierigkeitsgrad Test abgeschlossen")
    }
    
    /// Vollständiger Test mit kompletter Exercise-Erstellung
    static func testCompleteExerciseCreation() {
        print("🎯 Teste vollständige Exercise-Erstellung...\n")
        
        let testRow = "| **Test Übung** | Freie Gewichte | Eine Testübung für vollständiges Parsing. | Brust, Schultern, Trizeps | Fortgeschritten |"
        
        let columns = parseTableRow(testRow)
        if columns.count >= 5 {
            let name = columns[0]
            let typeString = columns[1]
            let description = columns[2]
            let muscleGroupString = columns[3] 
            let difficultyString = columns[4]
            
            print("📋 Parse: \(name)")
            
            let muscleGroups = parseMuscleGroups(from: muscleGroupString)
            let equipmentType = parseEquipmentType(from: typeString)
            let difficultyLevel = parseDifficultyLevel(from: difficultyString)
            let instructions = generateInstructions(from: description)
            
            let exercise = Exercise(
                name: name,
                muscleGroups: muscleGroups,
                equipmentType: equipmentType,
                difficultyLevel: difficultyLevel,
                description: description,
                instructions: instructions
            )
            
            print("\n✅ Exercise erfolgreich erstellt:")
            print("  📛 Name: \(exercise.name)")
            print("  💪 Muskelgruppen: \(exercise.muscleGroups.map { $0.rawValue }.joined(separator: ", "))")
            print("  🏋️ Equipment: \(exercise.equipmentType.rawValue)")
            print("  📊 Schwierigkeit: \(exercise.difficultyLevel.rawValue)")
            print("  📝 Beschreibung: \(exercise.description)")
            print("  📋 Instructions: \(exercise.instructions)")
        }
        
        print("\n🎉 Vollständiger Test abgeschlossen!")
    }
    
    /// Test-Funktion für die komplette eingebettete Übungsliste
    static func testCompleteEmbeddedList() {
        print("📖 Teste vollständige eingebettete Übungsliste (145+ Übungen)...")
        
        let exercises = parseCompleteExerciseList()
        
        print("🎯 Parsing-Ergebnisse:")
        print("  📊 Anzahl Übungen: \(exercises.count)")
        
        // Gruppiere nach Equipment-Type
        let byEquipment = Dictionary(grouping: exercises) { $0.equipmentType }
        for (equipment, exs) in byEquipment.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            print("  🏋️ \(equipment.rawValue): \(exs.count) Übungen")
        }
        
        // Gruppiere nach Schwierigkeitsgrad
        let byDifficulty = Dictionary(grouping: exercises) { $0.difficultyLevel }
        for (difficulty, exs) in byDifficulty.sorted(by: { $0.key.sortOrder < $1.key.sortOrder }) {
            print("  📊 \(difficulty.rawValue): \(exs.count) Übungen")
        }
        
        // Zeige Beispiele
        print("\n📋 Beispiel-Übungen:")
        for exercise in exercises.prefix(3) {
            print("  • \(exercise.name) (\(exercise.equipmentType.rawValue), \(exercise.difficultyLevel.rawValue))")
            print("    Muskelgruppen: \(exercise.muscleGroups.map { $0.rawValue }.joined(separator: ", "))")
        }
        
        print("\n✅ Test der vollständigen Liste abgeschlossen!")
        print("🎉 Alle \(exercises.count) Übungen erfolgreich geparst und bereit für App-Integration!")
    }
}