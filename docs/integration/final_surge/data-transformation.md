# Final Surge Data Transformation Guide

**Last Updated**: December 17, 2025
**Status**: Design Complete - Ready for Implementation
**Related**: [Notes](./notes.md) | [Technical Architecture](./technical-architecture.md)

---

## Overview

This document provides detailed field-by-field mapping for transforming Final Surge API data into Mealvana's database schema. It includes unit conversions, parsing logic, and example transformations with real data.

---

## Field-by-Field Mapping

### Complete Mapping Table

| Final Surge Field | Type | Mealvana Field | Type | Transformation Logic | Required |
|------------------|------|----------------|------|---------------------|----------|
| `WorkoutURL` | string | `provider_workout_url` | TEXT | Direct copy | ✅ Yes |
| `WorkoutURL` (parsed) | string | `provider_workout_id` | TEXT | Extract `s` query parameter | ✅ Yes |
| `WorkoutDate` | ISO 8601 | `scheduled_date` | DATE | Parse to Date object | ✅ Yes |
| `WorkoutTime` | "HH:MM:SS" | `scheduled_time` | TIME | Parse to Time object | ❌ No |
| `WorkoutTypeName` | string | `sport_type` | TEXT | Map "Run"→"running", "Bike"→"cycling", "Swim"→"swimming" | ✅ Yes |
| `WorkoutIcon` | int (1-11) | `sport_type` | TEXT | Map via icon number (1=running, 2=cycling, 3=swimming) | ✅ Yes |
| `WorkoutSubTypeName` | string | `intensity` | TEXT | Intelligent mapping to easy/moderate/hard/race | ❌ No |
| `WorkoutTitle` | string | `title` | TEXT | Direct copy (optional truncate to 255 chars) | ❌ No |
| `WorkoutDescription` | string | `notes` | TEXT | Direct copy | ❌ No |
| `PlannedDistance` | float | `distance_miles` | REAL | Convert km→miles if needed | ❌ No |
| `PlannedDistanceType` | "mi" or "km" | N/A | N/A | Used for conversion only | N/A |
| `PlannedTime` | int (seconds) | `estimated_duration_minutes` | INTEGER | Convert seconds→minutes | ❌ No |
| `PlannedPace` | "5:40-5:55" | `pace_target` | REAL | Parse range, store midpoint as decimal minutes per mile | ❌ No |
| `PlannedPaceType` | "min/mi" or "min/km" | N/A | N/A | Used for conversion only | N/A |
| `WorkoutCompleted` | boolean | `is_completed` | BOOLEAN | Direct copy | ✅ Yes |
| `HasStructuredWorkout` | boolean | N/A | N/A | Future: Flag for fetching structured workout data | N/A |
| `StructuredWorkoutURLs` | object | N/A | N/A | Future: Store json_fs_v1 URL for interval parsing | N/A |
| N/A | N/A | `synced_from_provider` | TEXT | Set to "final_surge" | ✅ Yes |
| N/A | N/A | `last_synced_at` | TIMESTAMPTZ | Set to current timestamp | ✅ Yes |

---

## Unit Conversion Functions

### 1. Distance Conversion

**Input:** `PlannedDistance` (float) + `PlannedDistanceType` (string)
**Output:** `distance_miles` (float)

```dart
double convertToMiles(double distance, String distanceType) {
  if (distanceType.toLowerCase() == 'km') {
    return distance * 0.621371; // km to miles
  }
  return distance; // Already in miles
}
```

**Examples:**
```dart
convertToMiles(10.0, 'mi')   // → 10.0 miles
convertToMiles(16.09, 'km')  // → 10.0 miles
convertToMiles(42.2, 'km')   // → 26.22 miles (marathon)
```

---

### 2. Duration Conversion

**Input:** `PlannedTime` (int, seconds)
**Output:** `estimated_duration_minutes` (int)

```dart
int convertToMinutes(int seconds) {
  return (seconds / 60).round();
}
```

**Examples:**
```dart
convertToMinutes(1800)   // → 30 minutes
convertToMinutes(3600)   // → 60 minutes
convertToMinutes(5400)   // → 90 minutes
```

---

### 3. Pace Parsing & Conversion

**Input:** `PlannedPace` (string, e.g., "5:40-5:55") + `PlannedPaceType` (string)
**Output:** `pace_target` (float, decimal minutes per mile)

```dart
double? parsePaceToDecimalMinutes(String? paceStr, String? paceType) {
  if (paceStr == null || paceStr.isEmpty) return null;

  // Remove pace type suffix if present (e.g., "5:40 min/mi" → "5:40")
  final cleanPace = paceStr.replaceAll(RegExp(r'\s*(min/mi|min/km)'), '').trim();

  // Handle range (e.g., "5:40-5:55")
  if (cleanPace.contains('-')) {
    final parts = cleanPace.split('-');
    final min = _parseMinutesSeconds(parts[0]);
    final max = _parseMinutesSeconds(parts[1]);
    if (min == null || max == null) return null;

    // Calculate midpoint
    final midpoint = (min + max) / 2;

    // Convert km pace to mile pace if needed
    if (paceType?.toLowerCase().contains('km') == true) {
      return midpoint * 0.621371; // Slower pace in min/mile
    }
    return midpoint;
  }

  // Single pace value (e.g., "5:40")
  final pace = _parseMinutesSeconds(cleanPace);
  if (pace == null) return null;

  // Convert km pace to mile pace if needed
  if (paceType?.toLowerCase().contains('km') == true) {
    return pace * 0.621371;
  }
  return pace;
}

/// Parse "5:40" → 5.6667 (decimal minutes)
double? _parseMinutesSeconds(String timeStr) {
  final parts = timeStr.split(':');
  if (parts.length != 2) return null;

  final minutes = int.tryParse(parts[0]);
  final seconds = int.tryParse(parts[1]);
  if (minutes == null || seconds == null) return null;

  return minutes + (seconds / 60.0);
}
```

**Examples:**
```dart
parsePaceToDecimalMinutes("5:40-5:55", "min/mi")  // → 5.7917 (midpoint of 5:40 and 5:55)
parsePaceToDecimalMinutes("7:30", "min/mi")       // → 7.5
parsePaceToDecimalMinutes("4:30", "min/km")       // → 7.24 min/mile (converted)
parsePaceToDecimalMinutes(null, "min/mi")         // → null
```

---

### 4. Cycling Speed Calculation

**Input:** `PlannedDistance` (float) + `PlannedTime` (int, seconds) + `PlannedDistanceType` (string)
**Output:** `speed_mph` (float) or `speed_kph` (float)

```dart
double? calculateSpeed(double? distance, int? time, String? distanceType) {
  if (distance == null || time == null || time == 0) return null;

  // Convert to hours
  final hours = time / 3600.0;

  // Speed = distance / time
  final speed = distance / hours;

  // Return in same units as distance
  return speed; // mph if distance is miles, kph if kilometers
}
```

**Examples:**
```dart
calculateSpeed(50.0, 7200, 'mi')   // → 25.0 mph (50 miles in 2 hours)
calculateSpeed(80.0, 7200, 'km')   // → 40.0 kph (80 km in 2 hours)
```

---

### 5. Swimming Pace Calculation

**Input:** `PlannedDistance` (float) + `PlannedTime` (int, seconds) + `PlannedDistanceType` (string)
**Output:** `pace_per_100m` (float, seconds per 100 meters)

```dart
double? calculateSwimmingPace(double? distance, int? time, String? distanceType) {
  if (distance == null || time == null || distance == 0) return null;

  // Convert distance to meters
  double distanceMeters;
  if (distanceType?.toLowerCase() == 'mi') {
    distanceMeters = distance * 1609.34; // miles to meters
  } else {
    distanceMeters = distance * 1000.0; // km to meters
  }

  // Calculate seconds per 100m
  final pacePerMeter = time / distanceMeters;
  return pacePerMeter * 100.0;
}
```

**Examples:**
```dart
calculateSwimmingPace(1.0, 1800, 'mi')   // → 111.8 sec/100m (30 min mile swim)
calculateSwimmingPace(2.0, 1800, 'km')   // → 90.0 sec/100m (30 min for 2km)
```

---

## Intensity Inference Logic

### Intensity Mapping Algorithm

```dart
String inferIntensity(String? workoutSubTypeName, String? workoutTitle, String? workoutDescription) {
  // Combine all text fields for analysis
  final searchText = [
    workoutSubTypeName?.toLowerCase() ?? '',
    workoutTitle?.toLowerCase() ?? '',
    workoutDescription?.toLowerCase() ?? '',
  ].join(' ');

  // Priority 1: Race intensity
  if (searchText.contains('race') ||
      searchText.contains('event') ||
      searchText.contains('marathon') ||
      searchText.contains('half marathon') ||
      searchText.contains('10k') ||
      searchText.contains('5k')) {
    return 'race';
  }

  // Priority 2: Hard intensity
  if (searchText.contains('tempo') ||
      searchText.contains('threshold') ||
      searchText.contains('interval') ||
      searchText.contains('speed work') ||
      searchText.contains('fartlek') ||
      searchText.contains('hill repeats')) {
    return 'hard';
  }

  // Priority 3: Moderate intensity
  if (searchText.contains('steady') ||
      searchText.contains('aerobic') ||
      searchText.contains('marathon pace') ||
      searchText.contains('mp') ||
      searchText.contains('endurance')) {
    return 'moderate';
  }

  // Default: Easy intensity
  return 'easy';
}
```

### Keyword-Based Classification

| Intensity | Keywords (case-insensitive) |
|-----------|----------------------------|
| **race** | race, event, marathon, half marathon, 10k, 5k, triathlon, target time |
| **hard** | tempo, threshold, intervals, speed work, fartlek, hill repeats, VO2 max, anaerobic |
| **moderate** | steady state, aerobic, marathon pace, MP, endurance, sustained, tempo-ish |
| **easy** | recovery, easy, base, long run, warmup, cooldown, jog, light |

---

## Sport Type Mapping

### Icon-Based Mapping

```dart
String? mapSportTypeFromIcon(int workoutIcon) {
  switch (workoutIcon) {
    case 1: return 'running';
    case 2: return 'cycling';
    case 3: return 'swimming';
    case 11: return null; // Walk - SKIP for now (or map to 'running' with easy intensity)
    default: return null; // Unsupported - SKIP import
  }
}
```

### Name-Based Mapping (Fallback)

```dart
String? mapSportTypeFromName(String? workoutTypeName) {
  if (workoutTypeName == null) return null;

  final normalized = workoutTypeName.toLowerCase();

  if (normalized.contains('run')) return 'running';
  if (normalized.contains('bike') || normalized.contains('cycle')) return 'cycling';
  if (normalized.contains('swim')) return 'swimming';

  return null; // Unsupported
}
```

---

## External ID Extraction

### WorkoutURL Parsing

**URL Format:**
```
https://log.finalsurge.com/WorkoutDetails?s=<WORKOUT_ID>&id=<SECONDARY_ID>
```

**Extraction Function:**
```dart
String extractWorkoutId(String? workoutUrl) {
  if (workoutUrl == null || workoutUrl.isEmpty) {
    return ''; // Return empty string for null safety
  }

  try {
    final uri = Uri.parse(workoutUrl);

    // Primary: Extract 's' parameter (most reliable)
    final workoutId = uri.queryParameters['s'];
    if (workoutId != null && workoutId.isNotEmpty) {
      return workoutId;
    }

    // Fallback: Extract 'id' parameter
    final secondaryId = uri.queryParameters['id'];
    return secondaryId ?? '';
  } catch (e) {
    // Handle parse errors gracefully
    _logger.warning('Failed to parse WorkoutURL: $workoutUrl', error: e);
    return '';
  }
}
```

**Examples:**
```dart
extractWorkoutId("https://log.finalsurge.com/WorkoutDetails?s=abc123")
// → "abc123"

extractWorkoutId("https://log.finalsurge.com/WorkoutDetails?s=abc123&id=xyz789")
// → "abc123"

extractWorkoutId("https://log.finalsurge.com/WorkoutDetails?id=xyz789")
// → "xyz789"

extractWorkoutId(null)
// → ""
```

---

## Example Transformations

### Example 1: Running Workout

**Final Surge API Response:**
```json
{
  "WorkoutURL": "https://log.finalsurge.com/WorkoutDetails?s=workout123",
  "WorkoutDate": "2025-01-20T00:00:00",
  "WorkoutTime": "06:00:00",
  "WorkoutTypeName": "Run",
  "WorkoutIcon": 1,
  "WorkoutSubTypeName": "Tempo Run",
  "WorkoutTitle": "10 Mile Tempo",
  "WorkoutDescription": "10-15 minute warm-up, then 6 miles at tempo pace (6:30-6:45 min/mile), followed by 10 minute cool-down",
  "PlannedDistance": 10.0,
  "PlannedDistanceType": "mi",
  "PlannedTime": 4200,
  "PlannedPace": "6:30-6:45",
  "PlannedPaceType": "min/mi",
  "WorkoutCompleted": false
}
```

**Mealvana Activity Record:**
```dart
Activity(
  id: '<generated_uuid>',
  userId: '<user_id>',
  sportType: 'running',
  scheduledDate: DateTime(2025, 1, 20),
  scheduledTime: TimeOfDay(hour: 6, minute: 0),
  distanceMiles: 10.0,
  estimatedDurationMinutes: 70, // 4200 seconds / 60
  paceTarget: 6.625, // Midpoint of 6:30 (6.5) and 6:45 (6.75)
  intensity: 'hard', // Inferred from "Tempo Run"
  title: '10 Mile Tempo',
  notes: '10-15 minute warm-up, then 6 miles at tempo pace (6:30-6:45 min/mile), followed by 10 minute cool-down',
  isCompleted: false,
  syncedFromProvider: 'final_surge',
  providerWorkoutId: 'workout123',
  providerWorkoutUrl: 'https://log.finalsurge.com/WorkoutDetails?s=workout123',
  lastSyncedAt: DateTime.now(),
)
```

---

### Example 2: Cycling Workout

**Final Surge API Response:**
```json
{
  "WorkoutURL": "https://log.finalsurge.com/WorkoutDetails?s=bike456",
  "WorkoutDate": "2025-01-22T00:00:00",
  "WorkoutTime": null,
  "WorkoutTypeName": "Bike",
  "WorkoutIcon": 2,
  "WorkoutSubTypeName": "Endurance Ride",
  "WorkoutTitle": "50 Mile Long Ride",
  "WorkoutDescription": "Steady aerobic pace on flat route",
  "PlannedDistance": 50.0,
  "PlannedDistanceType": "mi",
  "PlannedTime": 9000,
  "PlannedPace": null,
  "PlannedPaceType": null,
  "WorkoutCompleted": false
}
```

**Mealvana Activity Record:**
```dart
Activity(
  id: '<generated_uuid>',
  userId: '<user_id>',
  sportType: 'cycling',
  scheduledDate: DateTime(2025, 1, 22),
  scheduledTime: null, // No time specified
  distanceMiles: 50.0,
  estimatedDurationMinutes: 150, // 9000 seconds / 60
  speedMph: 20.0, // 50 miles / 2.5 hours
  intensity: 'moderate', // Inferred from "Endurance Ride" + "Steady aerobic"
  title: '50 Mile Long Ride',
  notes: 'Steady aerobic pace on flat route',
  isCompleted: false,
  syncedFromProvider: 'final_surge',
  providerWorkoutId: 'bike456',
  providerWorkoutUrl: 'https://log.finalsurge.com/WorkoutDetails?s=bike456',
  lastSyncedAt: DateTime.now(),
)
```

---

### Example 3: Swimming Workout

**Final Surge API Response:**
```json
{
  "WorkoutURL": "https://log.finalsurge.com/WorkoutDetails?s=swim789",
  "WorkoutDate": "2025-01-24T00:00:00",
  "WorkoutTime": "17:30:00",
  "WorkoutTypeName": "Swim",
  "WorkoutIcon": 3,
  "WorkoutSubTypeName": "Intervals",
  "WorkoutTitle": "3000m Interval Swim",
  "WorkoutDescription": "8x400m @ threshold pace with 30 sec rest",
  "PlannedDistance": 3.0,
  "PlannedDistanceType": "km",
  "PlannedTime": 2700,
  "PlannedPace": null,
  "PlannedPaceType": null,
  "WorkoutCompleted": true
}
```

**Mealvana Activity Record:**
```dart
Activity(
  id: '<generated_uuid>',
  userId: '<user_id>',
  sportType: 'swimming',
  scheduledDate: DateTime(2025, 1, 24),
  scheduledTime: TimeOfDay(hour: 17, minute: 30),
  distanceMiles: 1.864, // 3.0 km * 0.621371
  estimatedDurationMinutes: 45, // 2700 seconds / 60
  pacePerHundredMeters: 90.0, // 2700 sec / 3000m * 100
  intensity: 'hard', // Inferred from "Intervals" + "threshold pace"
  title: '3000m Interval Swim',
  notes: '8x400m @ threshold pace with 30 sec rest',
  isCompleted: true, // User completed this workout
  syncedFromProvider: 'final_surge',
  providerWorkoutId: 'swim789',
  providerWorkoutUrl: 'https://log.finalsurge.com/WorkoutDetails?s=swim789',
  lastSyncedAt: DateTime.now(),
)
```

---

### Example 4: Workout with Missing Data

**Final Surge API Response:**
```json
{
  "WorkoutURL": "https://log.finalsurge.com/WorkoutDetails?s=run999",
  "WorkoutDate": "2025-01-26T00:00:00",
  "WorkoutTime": null,
  "WorkoutTypeName": "Run",
  "WorkoutIcon": 1,
  "WorkoutSubTypeName": null,
  "WorkoutTitle": "Easy Recovery Run",
  "WorkoutDescription": null,
  "PlannedDistance": null,
  "PlannedDistanceType": null,
  "PlannedTime": null,
  "PlannedPace": null,
  "PlannedPaceType": null,
  "WorkoutCompleted": false
}
```

**Mealvana Activity Record:**
```dart
Activity(
  id: '<generated_uuid>',
  userId: '<user_id>',
  sportType: 'running',
  scheduledDate: DateTime(2025, 1, 26),
  scheduledTime: null, // No time specified
  distanceMiles: null, // No distance planned
  estimatedDurationMinutes: null, // No duration planned
  paceTarget: null, // No pace planned
  intensity: 'easy', // Inferred from "Easy Recovery Run" in title
  title: 'Easy Recovery Run',
  notes: null,
  isCompleted: false,
  syncedFromProvider: 'final_surge',
  providerWorkoutId: 'run999',
  providerWorkoutUrl: 'https://log.finalsurge.com/WorkoutDetails?s=run999',
  lastSyncedAt: DateTime.now(),
)
```

**Decision:** Import workout with partial data. User can fill in details later in Mealvana.

---

## Edge Cases & Handling

### 1. Invalid WorkoutURL

**Scenario:** `WorkoutURL` is null or malformed

**Handling:**
```dart
if (workoutUrl == null || workoutUrl.isEmpty) {
  // Skip import - can't deduplicate without ID
  _logger.warning('Skipping workout with missing WorkoutURL');
  continue;
}

final workoutId = extractWorkoutId(workoutUrl);
if (workoutId.isEmpty) {
  // Skip import - can't extract ID
  _logger.warning('Skipping workout - unable to extract ID from URL: $workoutUrl');
  continue;
}
```

---

### 2. Unsupported Sport Type

**Scenario:** `WorkoutIcon` = 4 (Cross Training) or 5 (Strength Training)

**Handling:**
```dart
final sportType = mapSportTypeFromIcon(workout.workoutIcon);
if (sportType == null) {
  // Skip import - unsupported sport
  _logger.info('Skipping unsupported sport type: ${workout.workoutTypeName}');
  continue;
}
```

---

### 3. Distance Unit Mismatch

**Scenario:** `PlannedDistanceType` is not "mi" or "km"

**Handling:**
```dart
String normalizeDistanceType(String? distanceType) {
  if (distanceType == null) return 'mi'; // Default to miles

  final normalized = distanceType.toLowerCase().trim();

  if (normalized.contains('km') || normalized == 'k') return 'km';
  if (normalized.contains('mi') || normalized == 'm') return 'mi';

  // Unknown type - log warning and default to miles
  _logger.warning('Unknown distance type: $distanceType, defaulting to miles');
  return 'mi';
}
```

---

### 4. Pace Parsing Errors

**Scenario:** `PlannedPace` = "fast" or "sub-6" (non-standard format)

**Handling:**
```dart
double? parsePaceToDecimalMinutes(String? paceStr, String? paceType) {
  // ... parsing logic ...

  // If parsing fails, return null
  if (pace == null) {
    _logger.warning('Unable to parse pace: $paceStr');
    return null; // Store null in pace_target
  }

  return pace;
}
```

**Result:** Import workout without pace data. User can add pace manually.

---

### 5. Completed vs Upcoming Workouts

**Scenario:** `WorkoutCompleted` = true, but workout is in future

**Handling:**
```dart
// Import both completed and upcoming workouts
final activity = Activity(
  // ... other fields ...
  isCompleted: workout.workoutCompleted,
);

// UI will show completed badge if true
// Don't send reminders for completed workouts
```

---

## Testing Data Transformations

### Unit Test Examples

```dart
group('Data Transformation Tests', () {
  test('converts kilometers to miles', () {
    expect(convertToMiles(10.0, 'km'), closeTo(6.21, 0.01));
    expect(convertToMiles(42.2, 'km'), closeTo(26.22, 0.01));
  });

  test('parses pace range and calculates midpoint', () {
    expect(parsePaceToDecimalMinutes("5:40-5:55", "min/mi"), closeTo(5.79, 0.01));
    expect(parsePaceToDecimalMinutes("7:00", "min/mi"), closeTo(7.0, 0.01));
  });

  test('infers intensity from workout subtype', () {
    expect(inferIntensity('Tempo Run', null, null), 'hard');
    expect(inferIntensity('Long Run', null, null), 'easy');
    expect(inferIntensity('Race', null, null), 'race');
  });

  test('extracts workout ID from URL', () {
    expect(
      extractWorkoutId('https://log.finalsurge.com/WorkoutDetails?s=abc123'),
      'abc123',
    );
  });

  test('maps sport type from icon', () {
    expect(mapSportTypeFromIcon(1), 'running');
    expect(mapSportTypeFromIcon(2), 'cycling');
    expect(mapSportTypeFromIcon(3), 'swimming');
    expect(mapSportTypeFromIcon(4), null); // Cross Training - skip
  });
});
```

---

## References

- [Final Surge API Documentation](./Final-Surge-Partner-API-Uploads.pdf)
- [Notes: Data Mapping Section](./notes.md#16-data-mapping--schema-decisions)
- [Technical Architecture](./technical-architecture.md)
- [Mealvana Database Schema](../database/README.md)

---

*Last updated: December 17, 2025*
