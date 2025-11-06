# Sport Type Handling Analysis - Mealvana Endurance

## Issue Summary
The app has mixed sport type handling across different screens. Some screens use hardcoded running icons/pace for all activities, while others properly support cycling and swimming with sport-specific metrics.

## Domain Models

### Shared Domain (`/lib/shared/domain/activity_type.dart`)
- Central `ActivityType` enum with running, cycling, swimming
- Includes helpful methods:
  - `displayName` - Returns "Run", "Ride", "Swim"
  - `iconName` - Returns 'directions_run', 'directions_bike', 'pool'

### Activities Feature (`/lib/features/activities/domain/activity.dart`)
- Complete model with sport-specific properties:
  - **Shared**: `distanceMiles`, `durationMinutes`, `paceTargetMinutesPerMile`, `intensityLevel`
  - **Cycling**: `cyclingSpeedMph`, `cyclingTerrain`, `cyclingIndoorOutdoor`, `cyclingElevationGainFt`, `cyclingSessionGoal`
  - **Swimming**: `swimmingPacePer100mSeconds`, `swimmingPoolOrOpenWater`, `swimmingWaterTempC`
  - Has extension methods: `isRunning`, `isCycling`, `isSwimming`, `formattedPace`

### Calendar Feature (`/lib/features/calendar/domain/activity.dart`)
- Older model that only has:
  - `paceTargetMinutesPerMile` (running-only)
  - Missing: cycling speed, swimming pace metrics
  - Uses same enum structure as activities feature but missing sport-specific properties

## Screens & Their Issues

### 1. Activities List Screen (`/lib/features/calendar/presentation/screens/activities_list_screen.dart`)
**Issues:**
- Line 740: Hardcoded `Icons.directions_run` icon (ignores sport type)
- Lines 1053-1093: `_formatActivityDetails()` method has some sport handling:
  - Properly differentiates swimming (converts to meters, shows pace per 100m)
  - But cycling and running treated the same (both show miles + pace per mile)
  - Does NOT show cycling speed in mph
  - Does NOT show swimming time in formatted pace

**Should Support:**
- Running: "5 mi • 45m • 9:00/mi"
- Cycling: "10 mi • 45m • 13.3 mph" (NOT pace/mile)
- Swimming: "1600m • 30m • 1:52/100m" (NOT pace/mile)

### 2. Activity Detail Screen (`/lib/features/nutrition_plan/presentation/screens/activity_detail_screen.dart`)
**Issues:**
- Line 340: Hardcoded `Icons.directions_run` icon
- Line 347: Shows "miles at pace pace" for all activities
- Line 517: Text says "Run scheduled for..." (hardcoded activity type text)
- All text assumes running activity

**Should Support:**
- Different icons based on sport type
- Cycling: "miles at X mph"
- Swimming: "X meters, pace per 100m"
- Dynamic text: "Run/Ride/Swim scheduled for..."

### 3. Activity Card Widget (`/lib/features/activities/presentation/widgets/activity_card.dart`)
**Status: CORRECT**
- Lines 226-235: `_getActivityIcon()` properly handles all sport types
- Lines 187-223: `_formatActivityDetails()` properly handles:
  - Running: miles + pace per mile
  - Cycling: miles + speed in mph
  - Swimming: meters + pace per 100m

## Database Schema Note
Both Activity models have similar fields but calendar feature model is simpler and lacks cycling/swimming properties. They appear to be separate domain models (one in activities feature, one in calendar feature).

## Property Differences Across Models

| Property | Activities Model | Calendar Model |
|----------|------------------|-----------------|
| `cyclingSpeedMph` | ✓ Yes | ✗ No |
| `swimmingPacePer100mSeconds` | ✓ Yes | ✗ No |
| Sport-specific fields | ✓ Complete | ✗ Missing |
| `paceTargetMinutesPerMile` | ✓ Yes | ✓ Yes |
| `activityType` | ✓ ActivityType | ✓ ActivityType |

## Fix Priorities
1. **High**: Update activities_list_screen.dart icon and pace formatting
2. **High**: Update activity_detail_screen.dart icons, text, and formatting
3. **Medium**: Consider unifying the two Activity models or adding missing fields to calendar model
4. **Medium**: Ensure all screens use ActivityType enum methods (displayName, iconName) instead of hardcoding

## Existing Good Patterns to Copy From
- `ActivityCard` widget in activities feature - use this as reference for proper sport type handling
- `ActivityType.displayName` and `ActivityType.iconName` methods - use these instead of hardcoding
- Extension methods on Activity - can add similar extensions for pace formatting by sport type