#!/bin/bash

echo "Updating V1 WorkoutSessionEntity references..."

# Liste aller V1 Files (nicht V2!)
V1_FILES=(
    "GymTracker/ViewModels/WorkoutStore.swift"
    "GymTracker/Views/StatisticsView.swift"
    "GymTracker/Views/WorkoutsView.swift"
    "GymTracker/Views/SessionDetailView.swift"
    "GymTracker/Views/Components/WeeklySetsCard.swift"
    "GymTracker/Views/Components/SmartTipsCard.swift"
    "GymTracker/Views/Components/MuscleDistributionCard.swift"
    "GymTracker/Views/Components/WeekComparisonCard.swift"
    "GymTracker/Views/Components/ProgressionScoreCard.swift"
    "GymTracker/Views/Components/RecoveryCard.swift"
    "GymTracker/BackupManager.swift"
    "GymTracker/BackupView.swift"
    "GymTracker/Views/Components/Statistics/RecentActivityView.swift"
    "GymTracker/Views/Components/Statistics/CalendarSessionsView.swift"
    "GymTracker/Views/WorkoutDetailView.swift"
    "GymTracker/Views/Components/Home/WorkoutsHomeView.swift"
    "GymTracker/Views/Components/Statistics/DayStripView.swift"
    "GymTracker/Services/WorkoutAnalyticsService.swift"
    "GymTracker/GymTrackerApp.swift"
    "GymTracker/DataManager.swift"
    "GymTracker/Models/WeekComparison.swift"
    "GymTracker/Workout+SwiftDataMapping.swift"
    "GymTracker/Models/ProgressionScore.swift"
    "GymTracker/Models/RecoveryIndex.swift"
    "GymTracker/Services/LastUsedMetricsService.swift"
)

# Backup erstellen
echo "Creating backup..."
tar -czf v1_files_backup_$(date +%Y%m%d_%H%M%S).tar.gz "${V1_FILES[@]}" 2>/dev/null

# Replace WorkoutSessionEntity mit WorkoutSessionEntityV1
for file in "${V1_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "Processing: $file"
        sed -i '' 's/: WorkoutSessionEntity/: WorkoutSessionEntityV1/g' "$file"
        sed -i '' 's/<WorkoutSessionEntity>/<WorkoutSessionEntityV1>/g' "$file"
        sed -i '' 's/(WorkoutSessionEntity)/(WorkoutSessionEntityV1)/g' "$file"
        sed -i '' 's/\[WorkoutSessionEntity\]/[WorkoutSessionEntityV1]/g' "$file"
        sed -i '' 's/ WorkoutSessionEntity / WorkoutSessionEntityV1 /g' "$file"
    fi
done

echo "✅ Done! Check git diff to verify changes."
