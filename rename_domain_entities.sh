#!/bin/bash

echo "Renaming V2 Domain Entities to Domain* prefix..."
echo ""

# V2 Files (Domain, Data, Presentation, Infrastructure)
V2_FILES=$(find GymTracker/{Domain,Data,Presentation,Infrastructure} -name "*.swift" 2>/dev/null)

# Replace patterns
# Note: Order matters! Replace longer names first to avoid partial matches

for file in $V2_FILES; do
    if [ -f "$file" ]; then
        echo "Processing: $file"
        
        # Replace WorkoutSession (but not WorkoutSessionEntity)
        sed -i '' 's/\bWorkoutSession\b/DomainWorkoutSession/g' "$file"
        
        # Replace SessionExercise (but not SessionExerciseEntity)  
        sed -i '' 's/\bSessionExercise\b/DomainSessionExercise/g' "$file"
        
        # Replace SessionSet (but not SessionSetEntity)
        sed -i '' 's/\bSessionSet\b/DomainSessionSet/g' "$file"
    fi
done

echo ""
echo "✅ Done! All V2 Domain entities renamed with 'Domain' prefix"
