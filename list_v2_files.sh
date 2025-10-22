#!/bin/bash

echo "========================================="
echo "V2 Clean Architecture Files"
echo "Diese Files müssen zu Xcode hinzugefügt werden"
echo "========================================="
echo ""

echo "📁 DOMAIN LAYER (Sprint 1.2)"
echo "----------------------------"
find GymTracker/Domain -name "*.swift" -type f | sort

echo ""
echo "📁 DATA LAYER (Sprint 1.3)"
echo "----------------------------"
find GymTracker/Data -name "*.swift" -type f | sort

echo ""
echo "📁 PRESENTATION LAYER (Sprint 1.4)"
echo "----------------------------"
find GymTracker/Presentation/Stores -name "*.swift" -type f | sort

echo ""
echo "📁 INFRASTRUCTURE LAYER"
echo "----------------------------"
find GymTracker/Infrastructure/DI -name "*.swift" -type f | sort

echo ""
echo "========================================="
echo "Total Files:"
echo "========================================="
echo "Domain:        $(find GymTracker/Domain -name "*.swift" -type f | wc -l | xargs)"
echo "Data:          $(find GymTracker/Data -name "*.swift" -type f | wc -l | xargs)"
echo "Presentation:  $(find GymTracker/Presentation/Stores -name "*.swift" -type f | wc -l | xargs)"
echo "Infrastructure: $(find GymTracker/Infrastructure/DI -name "*.swift" -type f | wc -l | xargs)"
echo ""
echo "GESAMT: $(find GymTracker/{Domain,Data,Presentation/Stores,Infrastructure/DI} -name "*.swift" -type f 2>/dev/null | wc -l | xargs) Files"
echo ""
echo "========================================="
echo "Nächste Schritte:"
echo "========================================="
echo "1. Öffne Xcode: open GymBo.xcodeproj"
echo "2. Right-Click auf 'GymTracker' Group"
echo "3. Wähle 'Add Files to GymBo...'"
echo "4. Wähle alle oben gelisteten Ordner"
echo "5. Aktiviere Target 'GymTracker'"
echo "6. Build: Cmd + B"
echo ""
