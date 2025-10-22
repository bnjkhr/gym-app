#!/bin/bash

echo "========================================="
echo "V2 Clean Architecture - Setup Verification"
echo "========================================="
echo ""

echo "✓ Checking File System..."
echo ""

# Check V1 renamed files
if [ -f "GymTracker/Models/WorkoutSessionV1.swift" ]; then
    echo "  ✅ WorkoutSessionV1.swift exists"
else
    echo "  ❌ WorkoutSessionV1.swift NOT FOUND"
fi

if [ ! -f "GymTracker/Models/WorkoutSession.swift" ]; then
    echo "  ✅ Old WorkoutSession.swift removed"
else
    echo "  ⚠️  Old WorkoutSession.swift still exists!"
fi

# Check V2 files exist
echo ""
echo "✓ Checking V2 Domain Layer..."
if [ -f "GymTracker/Domain/Entities/WorkoutSession.swift" ]; then
    echo "  ✅ V2 WorkoutSession.swift (Domain) exists"
else
    echo "  ❌ V2 WorkoutSession.swift NOT FOUND"
fi

echo ""
echo "✓ Checking V2 Data Layer..."
if [ -f "GymTracker/Data/Entities/WorkoutSessionEntity.swift" ]; then
    echo "  ✅ V2 WorkoutSessionEntity.swift (Data) exists"
else
    echo "  ❌ V2 WorkoutSessionEntity.swift NOT FOUND"
fi

echo ""
echo "✓ Checking V2 Presentation Layer..."
if [ -f "GymTracker/Presentation/Stores/SessionStore.swift" ]; then
    echo "  ✅ SessionStore.swift exists"
else
    echo "  ❌ SessionStore.swift NOT FOUND"
fi

echo ""
echo "✓ Checking Xcode Project References..."
echo ""

V1_REF_COUNT=$(grep -c "WorkoutSessionV1.swift" GymBo.xcodeproj/project.pbxproj)
V2_REF_COUNT=$(grep -c "AD7947272EA92D72001A1128.*WorkoutSession.swift" GymBo.xcodeproj/project.pbxproj)
OLD_REF_COUNT=$(grep -c "437AAE525E254351A9FB4A60571D1D51.*WorkoutSession.swift[^V]" GymBo.xcodeproj/project.pbxproj)

echo "  V1 (WorkoutSessionV1.swift) references: $V1_REF_COUNT"
echo "  V2 (Domain/WorkoutSession.swift) references: $V2_REF_COUNT"
echo "  Old (incorrect) references: $OLD_REF_COUNT"

if [ "$OLD_REF_COUNT" -eq 0 ] && [ "$V1_REF_COUNT" -gt 0 ] && [ "$V2_REF_COUNT" -gt 0 ]; then
    echo "  ✅ Xcode project references are correct!"
else
    echo "  ⚠️  Some references may need fixing"
fi

echo ""
echo "========================================="
echo "Summary"
echo "========================================="
echo ""
echo "Ready to build? Run in Xcode:"
echo "  1. Clean Build Folder: Cmd + Shift + K"
echo "  2. Build: Cmd + B"
echo ""
echo "Expected result: ✅ BUILD SUCCEEDED"
echo ""
