#!/usr/bin/env python3
import uuid
import re

pbxproj_path = "/Users/benkohler/Projekte/gym-app/GymBo.xcodeproj/project.pbxproj"

# Lese die pbxproj-Datei
with open(pbxproj_path, 'r') as f:
    content = f.read()

# Generiere eindeutige IDs
def generate_xcode_id():
    return ''.join(['{:02X}'.format(x) for x in uuid.uuid4().bytes[:12]])

filename = "WorkoutStoreServices.swift"
file_id = generate_xcode_id()
build_id = generate_xcode_id()

# PBXBuildFile entry
build_entry = f"\t\t{build_id} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_id} /* {filename} */; }};"

# PBXFileReference entry
file_entry = f"\t\t{file_id} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = \"<group>\"; }};"

# Sources entry
source_entry = f"\t\t\t\t{build_id} /* {filename} in Sources */,"

# Finde WorkoutStore.swift und füge dahinter ein
workout_store_build_pattern = r'(11E749052C9E4B9700AB1234 /\* WorkoutStore\.swift in Sources \*/ = \{isa = PBXBuildFile; fileRef = 11E749042C9E4B9700AB1234 /\* WorkoutStore\.swift \*/; \};)'
match = re.search(workout_store_build_pattern, content)
if match:
    insert_pos = match.end()
    content = content[:insert_pos] + "\n" + build_entry + content[insert_pos:]
    print("✅ PBXBuildFile entry hinzugefügt")

# Füge PBXFileReference ein
file_ref_pattern = r'(11E749042C9E4B9700AB1234 /\* WorkoutStore\.swift \*/ = \{isa = PBXFileReference; lastKnownFileType = sourcecode\.swift; path = WorkoutStore\.swift; sourceTree = "<group>"; \};)'
match = re.search(file_ref_pattern, content)
if match:
    insert_pos = match.end()
    content = content[:insert_pos] + "\n" + file_entry + content[insert_pos:]
    print("✅ PBXFileReference entry hinzugefügt")

# Füge Sources ein
sources_pattern = r'(11E749052C9E4B9700AB1234 /\* WorkoutStore\.swift in Sources \*/,)'
match = re.search(sources_pattern, content)
if match:
    insert_pos = match.end()
    content = content[:insert_pos] + "\n" + source_entry + content[insert_pos:]
    print("✅ Sources entry hinzugefügt")

# Füge zur ViewModels-Gruppe hinzu (in der Dateistruktur)
viewmodels_group_pattern = r'(11E749042C9E4B9700AB1234 /\* WorkoutStore\.swift \*/,)'
match = re.search(viewmodels_group_pattern, content)
if match:
    insert_pos = match.end()
    group_entry = f"\n\t\t\t\t{file_id} /* {filename} */,"
    content = content[:insert_pos] + group_entry + content[insert_pos:]
    print("✅ ViewModels group entry hinzugefügt")

# Schreibe zurück
with open(pbxproj_path, 'w') as f:
    f.write(content)

print(f"✅ {filename} zum Xcode-Projekt hinzugefügt")
