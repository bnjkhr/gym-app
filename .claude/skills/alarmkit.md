---
name: alarmkit
description: Comprehensive guidance for working with Apple's AlarmKit framework to create, manage, and present alarms on Apple devices
---

# AlarmKit Skill

## Overview

This skill provides comprehensive guidance for working with Apple's **AlarmKit** framework. AlarmKit enables developers to create, manage, and present alarms on Apple devices, including scheduling, displaying, and interacting with alarms both in apps and on the lock screen.

## When to Use This Skill

Use this skill when:
- Creating or scheduling alarms in iOS/macOS applications
- Managing alarm lifecycles and states
- Implementing alarm UI presentations
- Working with alarm metadata and attributes
- Handling alarm interactions and buttons
- Debugging AlarmKit-related issues

## Core Components

### 1. AlarmManager (class)

The central API for alarm management and control.

**Primary responsibilities:**
- Managing alarm lifecycle
- Scheduling and canceling alarms
- Controlling alarm states

**Usage context:**
- Use `AlarmManager` as the entry point for all alarm operations
- Instantiate once and reuse throughout the application
- Handle alarm permissions and authorization through this class

### 2. Alarm (struct)

Defines the properties and functionality of an individual alarm.

**Key characteristics:**
- Immutable struct containing alarm configuration
- Includes time, recurrence, and sound settings
- Represents a single scheduled alarm instance

**Best practices:**
- Create new `Alarm` instances for each scheduled alarm
- Store alarm identifiers for future reference and updates
- Use value semantics for alarm data

### 3. AlarmButton (struct)

Provides properties for alarm interaction buttons.

**Purpose:**
- Define custom actions for alarm interactions
- Configure button appearance and behavior
- Handle user responses to alarm notifications

**Implementation notes:**
- Used in conjunction with `AlarmPresentation`
- Can represent actions like "Snooze", "Dismiss", or custom actions
- Follow Human Interface Guidelines for button design

### 4. AlarmPresentation (struct)

Describes the preparation and display of an alarm at the UI level.

**Responsibilities:**
- Define alarm visual appearance
- Configure notification content
- Set up interactive elements

**Usage:**
- Required component of `AlarmAttributes`
- Customizes how alarms appear to users
- Works with Live Activities for dynamic updates

### 5. AlarmPresentationState (struct)

Represents the presentation state of an alarm.

**State management:**
- Tracks current alarm display status
- Updates dynamically during alarm lifecycle
- Used for Live Activities state updates

**Common states:**
- Scheduled
- Ringing
- Snoozed
- Dismissed

### 6. AlarmAttributes (struct)

Contains all information necessary for alarm UI.

**Structure:**
```swift
let attributes = AlarmAttributes(
    presentation: presentation,
    metadata: metadata,
    tintColor: .white
)
```

**Properties:**
- `tintColor: Color` – Tint color for the UI
- `presentation: AlarmPresentation` – Content for the UI
- `metadata: Metadata?` – Optional additional data
- `typealias ContentState` – Describes concrete alarm content

**Initialization:**
```swift
init(presentation: AlarmPresentation, metadata: Metadata?, tintColor: Color)
```

**Encoding/Decoding:**
- `init(from: Decoder) throws`
- `func encode(to: Encoder) throws`

**Protocol conformances:**
- `ActivityAttributes`
- `Decodable`
- `Encodable`
- `Sendable`
- `SendableMetatype`

**Best practices:**
- Always provide meaningful `presentation` data
- Use `metadata` for app-specific data that needs to persist
- Choose `tintColor` that matches your app's design system
- Ensure all data is `Sendable` for thread safety

### 7. AlarmMetadata (protocol)

Provides additional metadata for alarms.

**Purpose:**
- Pass custom information to alarm UI
- Extend alarm functionality with app-specific data
- Can be implemented as empty if no additional data needed

**Implementation:**
```swift
struct MyAlarmMetadata: AlarmMetadata {
    let customField: String
    // Add any custom properties needed
}

// Or empty implementation:
struct EmptyAlarmMetadata: AlarmMetadata {}
```

**Protocol requirements:**
Inherits from:
- `Decodable`
- `Encodable`
- `Equatable`
- `Hashable`
- `Sendable`
- `SendableMetatype`

**Guidelines:**
- Keep metadata lightweight and serializable
- Use value types (structs) for metadata
- Ensure all properties conform to required protocols
- Document custom metadata fields clearly

## Implementation Workflow

### Basic Alarm Creation

1. **Create AlarmMetadata** (if needed):
   ```swift
   struct MyMetadata: AlarmMetadata {
       let label: String
   }
   ```

2. **Configure AlarmPresentation**:
   ```swift
   let presentation = AlarmPresentation(
       // Configure presentation details
   )
   ```

3. **Create AlarmAttributes**:
   ```swift
   let attributes = AlarmAttributes(
       presentation: presentation,
       metadata: MyMetadata(label: "Morning Alarm"),
       tintColor: .blue
   )
   ```

4. **Schedule with AlarmManager**:
   ```swift
   let alarm = Alarm(/* configuration */)
   alarmManager.schedule(alarm, attributes: attributes)
   ```

## Common Patterns

### Pattern 1: Simple Alarm
For basic alarms without custom metadata:
- Use empty `AlarmMetadata` implementation
- Provide minimal `AlarmPresentation`
- Schedule through `AlarmManager`

### Pattern 2: Rich Alarm with Metadata
For alarms requiring custom data:
- Define custom `AlarmMetadata` struct
- Include all necessary app-specific information
- Ensure metadata is properly encoded/decoded

### Pattern 3: Interactive Alarms
For alarms with custom actions:
- Configure `AlarmButton` instances
- Define button actions and handlers
- Integrate with `AlarmPresentation`

## Error Handling

When working with AlarmKit:
- Handle encoding/decoding errors gracefully
- Check alarm scheduling permissions
- Validate alarm times and recurrence rules
- Provide user feedback for failure cases

## Thread Safety

AlarmKit components marked as `Sendable`:
- Can be safely passed across concurrency boundaries
- Use with Swift Concurrency (async/await)
- No additional synchronization needed for these types

## Testing Considerations

When testing AlarmKit integration:
- Mock `AlarmManager` for unit tests
- Test alarm state transitions
- Verify metadata encoding/decoding
- Test UI presentation configurations
- Validate button action handlers

## Performance Tips

- Reuse `AlarmManager` instances
- Keep metadata lightweight
- Avoid heavy computations in alarm handlers
- Use efficient data structures for metadata
- Profile alarm scheduling performance

## Debugging

Common debugging steps:
1. Verify alarm permissions are granted
2. Check alarm scheduling time validity
3. Inspect metadata serialization
4. Validate presentation configuration
5. Review system logs for AlarmKit errors

## Related Apple Frameworks

AlarmKit integrates with:
- **ActivityKit**: For Live Activities integration
- **UserNotifications**: For notification delivery
- **SwiftUI**: For UI presentation
- **Combine**: For reactive updates (if applicable)

## Documentation References

- Official Apple Developer Documentation: https://developer.apple.com/documentation/AlarmKit
- Human Interface Guidelines for Alarms
- ActivityKit integration guides

## Version Notes

This skill is based on the current AlarmKit documentation. Always check the official Apple Developer Documentation for the latest updates and API changes.

## Summary

AlarmKit provides a comprehensive system for alarm management on Apple platforms. The framework's key strengths are:
- Clear separation of concerns (manager, data, presentation)
- Strong type safety with Swift protocols
- Integration with modern Apple frameworks
- Support for custom metadata and rich presentations

When implementing alarms, start with `AlarmManager`, define your data structures (`Alarm`, `AlarmMetadata`), configure presentation (`AlarmAttributes`, `AlarmPresentation`), and handle user interactions (`AlarmButton`).
