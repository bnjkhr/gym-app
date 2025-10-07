#!/usr/bin/env python3
import uuid
import re

# Liste der neuen Service-Dateien
new_files = [
    "WorkoutStoreCoordinator.swift",
    "CacheService.swift",
    "ExerciseRepository.swift",
    "HealthKitIntegrationService.swift",
    "HeartRateTrackingService.swift",
    "LastUsedMetricsService.swift",
    "RestTimerService.swift",
    "SessionService.swift",
    "UserProfileService.swift",
    "WorkoutRepository.swift"
]

pbxproj_path = "/Users/benkohler/Projekte/gym-app/GymBo.xcodeproj/project.pbxproj"

# Lese die pbxproj-Datei
with open(pbxproj_path, 'r') as f:
    content = f.read()

# Generiere eindeutige IDs für jede Datei (im Xcode-Format: 24 Zeichen Hex)
def generate_xcode_id():
    return ''.join(['{:02X}'.format(x) for x in uuid.uuid4().bytes[:12]])

# Finde die Stelle wo WorkoutStore.swift definiert ist
workout_store_pattern = r'(11E749052C9E4B9700AB1234 /\* WorkoutStore\.swift in Sources \*/ = \{isa = PBXBuildFile; fileRef = 11E749042C9E4B9700AB1234 /\* WorkoutStore\.swift \*/; \};)'

# Erstelle neue Einträge
build_file_entries = []
file_ref_entries = []
sources_entries = []

for filename in new_files:
    file_id = generate_xcode_id()
    build_id = generate_xcode_id()

    # PBXBuildFile entry
    build_entry = f"\t\t{build_id} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_id} /* {filename} */; }};"
    build_file_entries.append(build_entry)

    # PBXFileReference entry
    file_entry = f"\t\t{file_id} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = \"<group>\"; }};"
    file_ref_entries.append(file_entry)

    # Sources entry
    source_entry = f"\t\t\t\t{build_id} /* {filename} in Sources */,"
    sources_entries.append(source_entry)

# Füge PBXBuildFile-Einträge nach WorkoutStore ein
match = re.search(workout_store_pattern, content)
if match:
    insert_pos = match.end()
    build_entries_str = "\n" + "\n".join(build_file_entries)
    content = content[:insert_pos] + build_entries_str + content[insert_pos:]
    print("✅ PBXBuildFile entries hinzugefügt")
else:
    print("⚠️  WorkoutStore.swift nicht gefunden")

# Füge PBXFileReference-Einträge hinzu
file_ref_pattern = r'(11E749042C9E4B9700AB1234 /\* WorkoutStore\.swift \*/ = \{isa = PBXFileReference; lastKnownFileType = sourcecode\.swift; path = WorkoutStore\.swift; sourceTree = "<group>"; \};)'
match = re.search(file_ref_pattern, content)
if match:
    insert_pos = match.end()
    file_entries_str = "\n" + "\n".join(file_ref_entries)
    content = content[:insert_pos] + file_entries_str + content[insert_pos:]
    print("✅ PBXFileReference entries hinzugefügt")

# Füge Sources-Einträge hinzu
sources_pattern = r'(11E749052C9E4B9700AB1234 /\* WorkoutStore\.swift in Sources \*/,)'
match = re.search(sources_pattern, content)
if match:
    insert_pos = match.end()
    sources_entries_str = "\n" + "\n".join(sources_entries)
    content = content[:insert_pos] + sources_entries_str + content[insert_pos:]
    print("✅ Sources entries hinzugefügt")

# Schreibe die modifizierte pbxproj zurück
with open(pbxproj_path, 'w') as f:
    f.write(content)

print(f"✅ {len(new_files)} Dateien zum Xcode-Projekt hinzugefügt")
