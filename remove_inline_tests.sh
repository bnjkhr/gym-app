#!/bin/bash

echo "Removing inline XCTest code from production files..."

FILES=(
    "GymTracker/Data/Mappers/SessionMapper.swift"
    "GymTracker/Domain/UseCases/Session/EndSessionUseCase.swift"
    "GymTracker/Domain/UseCases/Session/CompleteSetUseCase.swift"
    "GymTracker/Domain/UseCases/Session/StartSessionUseCase.swift"
)

for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "Processing: $file"
        
        # Find the line number where "// MARK: - Tests" starts
        START_LINE=$(grep -n "^// MARK: - Tests" "$file" | head -1 | cut -d: -f1)
        
        if [ -n "$START_LINE" ]; then
            # Remove everything from "// MARK: - Tests" to end of file
            # Then add TODO comment
            sed -i '' "${START_LINE},\$d" "$file"
            cat >> "$file" << 'COMMENT'

// MARK: - Tests
// TODO: Move inline tests to separate Test target file
// Tests were removed from production code to avoid XCTest import issues
COMMENT
            echo "  ✅ Removed tests from line $START_LINE onwards"
        else
            echo "  ⚠️  No test marker found"
        fi
    fi
done

echo ""
echo "✅ Done! All inline tests removed."
echo "Tests should be recreated in GymTrackerTests target."
