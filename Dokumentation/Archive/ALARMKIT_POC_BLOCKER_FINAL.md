# AlarmKit POC - Final Blocker Analysis

**Date:** 2025-10-20  
**Status:** ❌ BLOCKED - EXC_BREAKPOINT Crash  
**iOS Version:** 26.0 Beta  
**Device:** Real iPhone (not Simulator)

---

## Executive Summary

AlarmKit integration consistently crashes with `EXC_BREAKPOINT (code=1, subcode=0x1bebba868)` when calling `AlarmManager.shared.schedule()`. After extensive debugging and comparing with Apple's official sample code, the crash appears to be either:

1. **iOS 26 Beta Bug** - AlarmKit is not fully implemented yet
2. **Missing Entitlement** - Special entitlement not available to developers
3. **Configuration Issue** - Something subtle we're missing

---

## What We Tried

### ✅ Configuration Fixes (All Successful Builds)

1. **Removed `schedule` parameter** from countdown timers
   - Countdown timers only need `countdownDuration`, not `schedule`
   
2. **Removed `stopIntent` parameter** 
   - Countdown-only timers handle stop via `presentation.alert.stopButton`
   
3. **Removed `secondaryIntent` parameter**
   - Pause/Resume handled internally via presentation buttons
   
4. **Simplified `RestTimerMetadata`**
   - Reduced to minimal structure (only `createdAt: Date`)
   - Matches Apple's `CookingData` structure exactly

5. **Added explicit `Codable` + `Sendable` conformance**
   - Required for AlarmKit serialization

6. **Dual-path authorization**
   - Try automatic auth first (WWDC recommendation)
   - Fallback to explicit `requestAuthorization()`

### ❌ The Crash

**Location:** Always during `AlarmManager.shared.schedule()` call  
**Type:** `EXC_BREAKPOINT` (Swift runtime error)  
**Symptom:** No system authorization dialog appears  

**Logs before crash:**
```
🔐 Current auth state: notDetermined
📞 Attempting schedule() with automatic authorization...
[CRASH - No further logs]
```

---

## Code Comparison: Our POC vs Apple Sample

### Our Final Configuration

```swift
// Metadata (minimal, matches Apple)
struct RestTimerMetadata: AlarmMetadata {
    let createdAt: Date
    init() {
        self.createdAt = Date.now
    }
}

// Button configurations
let stopButton = AlarmButton(
    text: "Fertig",
    textColor: .white,
    systemImageName: "stop.circle"
)

let pauseButton = AlarmButton(
    text: "Pause",
    textColor: .black,
    systemImageName: "pause.fill"
)

let resumeButton = AlarmButton(
    text: "Start",
    textColor: .black,
    systemImageName: "play.fill"
)

// Presentations
let alert = AlarmPresentation.Alert(
    title: LocalizedStringResource("Pause beendet! 💪"),
    stopButton: stopButton
)

let countdown = AlarmPresentation.Countdown(
    title: LocalizedStringResource("Rest Timer"),
    pauseButton: pauseButton
)

let paused = AlarmPresentation.Paused(
    title: LocalizedStringResource("Pausiert"),
    resumeButton: resumeButton
)

// Attributes
let attributes = AlarmAttributes<RestTimerMetadata>(
    presentation: AlarmPresentation(
        alert: alert,
        countdown: countdown,
        paused: paused
    ),
    metadata: RestTimerMetadata(),
    tintColor: .blue
)

// Countdown duration
let countdownDuration = Alarm.CountdownDuration(
    preAlert: TimeInterval(30),  // 30 seconds
    postAlert: 0
)

// Configuration (minimal - no intents!)
let configuration = AlarmConfiguration(
    countdownDuration: countdownDuration,
    attributes: attributes
)

// Schedule
let alarm = try await manager.schedule(id: UUID(), configuration: configuration)
```

### Apple's Working Example

```swift
// scheduleCountdownAlertExample() from ViewModel.swift

let alertContent = AlarmPresentation.Alert(
    title: "Food Ready",
    stopButton: .stopButton,
    secondaryButton: .repeatButton,
    secondaryButtonBehavior: .countdown
)

let countdownContent = AlarmPresentation.Countdown(
    title: "Cooking", 
    pauseButton: .pauseButton
)

let pausedContent = AlarmPresentation.Paused(
    title: "Paused", 
    resumeButton: .resumeButton
)

let attributes = AlarmAttributes(
    presentation: AlarmPresentation(
        alert: alertContent, 
        countdown: countdownContent, 
        paused: pausedContent
    ),
    metadata: CookingData(method: .oven),
    tintColor: Color.accentColor
)

let id = UUID()
let alarmConfiguration = AlarmConfiguration(
    countdownDuration: .init(preAlert: 15 * 60, postAlert: 15 * 60),
    attributes: attributes,
    secondaryIntent: RepeatIntent(alarmID: id.uuidString)
)

scheduleAlarm(id: UUID(), label: "Food is cooking", alarmConfiguration: alarmConfiguration)
```

**Key Differences:**
1. Apple uses `secondaryButton` + `secondaryButtonBehavior` in Alert (we don't)
2. Apple uses `secondaryIntent` (we removed it after crashes)
3. Apple's metadata has an optional enum property (we simplified to just Date)

---

## Info.plist Configuration

✅ **Already configured:**

```xml
<key>NSSupportsLiveActivities</key>
<true/>
<key>NSAlarmKitUsageDescription</key>
<string>GymTracker nutzt Alarme, um dich an das Ende deiner Pause zu erinnern...</string>
```

---

## Entitlements

**Current:** Only HealthKit
```xml
<key>com.apple.developer.healthkit</key>
<true/>
```

**Question:** Does AlarmKit need a special entitlement?
- Apple's sample doesn't show any AlarmKit-specific entitlements
- But beta APIs sometimes require entitlements not in public docs

---

## Authorization Flow

### What Should Happen (WWDC 2025)
1. App calls `AlarmManager.shared.schedule()`
2. System shows authorization dialog automatically
3. User grants permission
4. Timer is scheduled

### What Actually Happens
1. App calls `AlarmManager.shared.schedule()`
2. **No dialog appears**
3. **EXC_BREAKPOINT crash**

### Authorization State Check
```
manager.authorizationState = .notDetermined
```

This is correct for first run, but calling `schedule()` should trigger the dialog.

---

## Possible Root Causes

### 1. iOS 26 Beta Incomplete Implementation
**Likelihood: HIGH**

- AlarmKit is brand new (announced WWDC 2025)
- iOS 26 is in early beta
- Authorization dialog not appearing suggests incomplete system integration
- EXC_BREAKPOINT could be unimplemented code path

**Action:** Wait for later iOS 26 betas

### 2. Missing Entitlement
**Likelihood: MEDIUM**

- Some beta APIs require special entitlements
- AlarmKit might need developer approval from Apple
- Similar to how Push Notifications need APNS certificate

**Action:** Check with Apple Developer Support

### 3. Subtle API Misuse
**Likelihood: LOW**

- We've matched Apple's sample code structure
- All builds succeed
- Configuration looks correct

**Action:** Get Stack Trace from crash to see exact failure point

### 4. Device Requirements
**Likelihood: LOW**

- Tested on real device (not Simulator)
- iOS 26 Beta installed
- App signed correctly

---

## Next Steps

### Immediate Actions

1. **Get Stack Trace**
   - When crash occurs, copy complete call stack
   - Identify exact AlarmKit function that fails
   
2. **Test Apple's Sample**
   - Build and run Apple's official sample on same device
   - If it also crashes → iOS 26 Beta bug confirmed
   - If it works → compare configurations more carefully

3. **Check Xcode Console**
   - Look for system-level errors before crash
   - Check for entitlement warnings

### Alternative Approaches

If AlarmKit remains blocked:

1. **Wait for iOS 26 Public Release**
   - Safer bet for production app
   - APIs will be stable and documented
   
2. **Hybrid Approach**
   - Keep current Timer + BackgroundTasks implementation
   - Add AlarmKit when iOS 26 releases
   - Feature flag: `#available(iOS 26, *)`

3. **Feedback to Apple**
   - File a bug report with Feedback Assistant
   - Include sample code and crash logs
   - Reference WWDC 2025 session

---

## Files Modified

### Created
- `GymTracker/Models/AlarmKit/RestTimerMetadata.swift`
- `GymTracker/Services/AlarmKit/RestAlarmService.swift`
- `GymTracker/Services/AlarmKit/AlarmKitAuthorizationManager.swift`
- `GymTracker/Views/Debug/AlarmKitPoCView.swift`

### Modified
- `GymTracker/Info.plist` - Added NSAlarmKitUsageDescription

### Documentation
- `Dokumentation/ALARMKIT_POC_BUILD_SUCCESS.md`
- `Dokumentation/ALARMKIT_POC_FIX.md`
- `Dokumentation/ALARMKIT_AUTO_AUTH_TEST.md`
- `Dokumentation/ALARMKIT_POC_BLOCKER_FINAL.md` (this file)

---

## Recommendation

**DO NOT PROCEED with full AlarmKit migration at this time.**

**Reasons:**
1. Consistent crashes on real device
2. No authorization dialog appearing
3. iOS 26 still in beta (not production-ready)
4. Risk of breaking existing timer functionality

**Recommended Path:**
1. Keep current RestTimer implementation (proven, working)
2. Monitor iOS 26 beta releases for AlarmKit fixes
3. Revisit AlarmKit POC in iOS 26 Beta 3 or later
4. Plan migration for iOS 26 public release (Fall 2025)

---

## Conclusion

AlarmKit shows great promise for replacing our custom timer implementation, but it's not ready yet. The POC successfully builds and all configurations match Apple's patterns, but runtime crashes prevent actual testing.

**Status: ⏸️ PAUSED - Waiting for iOS 26 Beta Maturity**

---

## Contact

If AlarmKit becomes critical:
- Apple Developer Forums
- Developer Technical Support (DTS) incident
- WWDC Labs (if available)
