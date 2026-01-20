# Brick Workout Schema Changes

## Overview

This document details all database schema changes required to support brick workouts in Mealvana Endurance. Changes are needed in both the local Drift SQLite database and the Supabase PostgreSQL backend.

## Current State

### Activity Type Enum

**Drift (Local SQLite):**
```dart
// Current CHECK constraint in activities_table.dart
CHECK (activity_type IN ('running', 'cycling', 'swimming'))
```

**Supabase (Dev & Prod):**
```sql
-- Current enum
CREATE TYPE activity_type_enum AS ENUM (
  'running',
  'cycling',
  'swimming',
  'triathlon',
  'duathlon',
  'multisport'
);
```

**Issue:** Drift is more restrictive than Supabase. Need to align and add `brick` type.

## Required Changes

### 1. Activity Type Enum Updates

#### Supabase Migration

```sql
-- Add 'brick' to existing enum
ALTER TYPE activity_type_enum ADD VALUE 'brick';
```

#### Drift Migration (Schema Version v3)

```dart
// lib/shared/database/tables/activities_table.dart

// Update CHECK constraint to include brick
class ActivitiesTable extends Table {
  // ... existing columns ...

  TextColumn get activityType => text().check(
    activityType.isIn([
      'running', 'cycling', 'swimming',
      'triathlon', 'duathlon', 'multisport',
      'brick'  // NEW
    ])
  )();
}
```

### 2. New Columns for Activities Table

#### Supabase Migration

```sql
-- Add brick_metadata column for storing segment information
ALTER TABLE activities
ADD COLUMN brick_metadata JSONB DEFAULT NULL;

-- Add brick_id column for linking archived activities to their brick
ALTER TABLE activities
ADD COLUMN brick_id UUID DEFAULT NULL REFERENCES activities(id) ON DELETE SET NULL;

-- Add index for querying brick-related activities
CREATE INDEX idx_activities_brick_id ON activities(brick_id) WHERE brick_id IS NOT NULL;

-- Add index for querying brick activities
CREATE INDEX idx_activities_brick_type ON activities(activity_type) WHERE activity_type = 'brick';
```

#### Drift Migration

```dart
// In activities_table.dart

// Brick metadata stored as JSON text
TextColumn get brickMetadata => text().nullable()();

// Reference to parent brick (for archived originals)
TextColumn get brickId => text().nullable()();
```

### 3. Activity Status Enum Update

Add new status for archived activities that are part of a brick:

#### Supabase Migration

```sql
-- Add 'archived_for_brick' status
ALTER TYPE activity_status_enum ADD VALUE 'archived_for_brick';
```

#### Drift Update

```dart
// Update status CHECK constraint
TextColumn get status => text().check(
  status.isIn([
    'draft', 'planned', 'inProgress', 'completed', 'skipped',
    'archived_for_brick'  // NEW
  ])
).withDefault(const Constant('planned'))();
```

### 4. Brick Metadata JSON Schema

The `brick_metadata` column stores structured data about the brick workout:

```typescript
interface BrickMetadata {
  // Ordered list of sports in this brick
  segment_order: ('swimming' | 'cycling' | 'running')[];

  // Detailed segment information
  segments: BrickSegment[];

  // Original activity IDs (for ungrouping)
  original_activity_ids: string[] | null;

  // Whether created from existing activities
  created_from_existing: boolean;

  // Total calculated duration (sum of all segments)
  total_duration_minutes: number;
}

interface BrickSegment {
  // Sport type for this segment
  sport: 'swimming' | 'cycling' | 'running';

  // Position in the brick (1-based)
  order: number;

  // Duration of this segment
  duration_minutes: number;

  // Intensity level for this segment
  intensity: 'easy' | 'moderate' | 'hard' | 'race';

  // Sport-specific fields (only relevant ones populated)

  // Swimming
  distance_meters?: number;
  pace_per_100m_seconds?: number;
  pool_or_open_water?: 'pool' | 'open_water';
  water_temp_c?: number;

  // Cycling
  distance_miles?: number;
  speed_mph?: number;
  terrain?: 'flat' | 'rolling' | 'hilly';
  indoor_outdoor?: 'indoor' | 'outdoor';
  elevation_gain_ft?: number;

  // Running
  distance_miles?: number;
  pace_minutes_per_mile?: number;
}
```

**Example brick_metadata value:**

```json
{
  "segment_order": ["swimming", "running"],
  "segments": [
    {
      "sport": "swimming",
      "order": 1,
      "duration_minutes": 40,
      "intensity": "moderate",
      "distance_meters": 2000,
      "pace_per_100m_seconds": 120,
      "pool_or_open_water": "pool"
    },
    {
      "sport": "running",
      "order": 2,
      "duration_minutes": 55,
      "intensity": "moderate",
      "distance_miles": 6.2,
      "pace_minutes_per_mile": 8.5
    }
  ],
  "original_activity_ids": ["uuid-1", "uuid-2"],
  "created_from_existing": true,
  "total_duration_minutes": 95
}
```

## Shared Domain Model Updates

### ActivityType Enum

```dart
// lib/shared/domain/activity_type.dart

enum ActivityType {
  running,
  cycling,
  swimming,
  triathlon,
  duathlon,
  multisport,
  brick,  // NEW
}

extension ActivityTypeExtension on ActivityType {
  String get displayName {
    switch (this) {
      case ActivityType.running: return 'Run';
      case ActivityType.cycling: return 'Ride';
      case ActivityType.swimming: return 'Swim';
      case ActivityType.triathlon: return 'Triathlon';
      case ActivityType.duathlon: return 'Duathlon';
      case ActivityType.multisport: return 'Multisport';
      case ActivityType.brick: return 'Brick';  // NEW
    }
  }

  String get dbValue {
    switch (this) {
      case ActivityType.running: return 'running';
      case ActivityType.cycling: return 'cycling';
      case ActivityType.swimming: return 'swimming';
      case ActivityType.triathlon: return 'triathlon';
      case ActivityType.duathlon: return 'duathlon';
      case ActivityType.multisport: return 'multisport';
      case ActivityType.brick: return 'brick';  // NEW
    }
  }

  bool get isBrick => this == ActivityType.brick;  // NEW

  bool get isSingleSport =>
    this == ActivityType.running ||
    this == ActivityType.cycling ||
    this == ActivityType.swimming;

  bool get isMultiSport =>
    this == ActivityType.triathlon ||
    this == ActivityType.duathlon ||
    this == ActivityType.multisport ||
    this == ActivityType.brick;  // UPDATED
}
```

### Activity Domain Model

```dart
// lib/features/activities/domain/activity.dart

class Activity {
  // ... existing fields ...

  // NEW: Brick-specific fields
  final BrickMetadata? brickMetadata;
  final String? brickId;  // For archived activities

  // Helper getters for brick activities
  bool get isBrick => activityType == ActivityType.brick;

  List<BrickSegment>? get brickSegments => brickMetadata?.segments;

  String get brickDisplayName {
    if (!isBrick || brickMetadata == null) return '';
    final sports = brickMetadata!.segmentOrder
        .map((s) => s.substring(0, 1).toUpperCase() + s.substring(1))
        .join('/');
    return '$sports Brick';
  }
}
```

### BrickMetadata Domain Model

```dart
// lib/features/activities/domain/brick_metadata.dart (NEW FILE)

import 'package:freezed_annotation/freezed_annotation.dart';

part 'brick_metadata.freezed.dart';
part 'brick_metadata.g.dart';

@freezed
class BrickMetadata with _$BrickMetadata {
  const factory BrickMetadata({
    required List<String> segmentOrder,
    required List<BrickSegment> segments,
    List<String>? originalActivityIds,
    required bool createdFromExisting,
    required int totalDurationMinutes,
  }) = _BrickMetadata;

  factory BrickMetadata.fromJson(Map<String, dynamic> json) =>
      _$BrickMetadataFromJson(json);
}

@freezed
class BrickSegment with _$BrickSegment {
  const factory BrickSegment({
    required String sport,
    required int order,
    required int durationMinutes,
    required String intensity,

    // Swimming fields
    double? distanceMeters,
    int? pacePer100mSeconds,
    String? poolOrOpenWater,
    double? waterTempC,

    // Cycling fields
    double? distanceMiles,
    double? speedMph,
    String? terrain,
    String? indoorOutdoor,
    int? elevationGainFt,

    // Running fields (shares distanceMiles)
    double? paceMinutesPerMile,
  }) = _BrickSegment;

  factory BrickSegment.fromJson(Map<String, dynamic> json) =>
      _$BrickSegmentFromJson(json);
}
```

## Migration Strategy

### Phase 1: Supabase Schema Update

1. **Development Environment:**
   ```sql
   -- Run in Supabase SQL Editor (Dev)
   ALTER TYPE activity_type_enum ADD VALUE 'brick';
   ALTER TYPE activity_status_enum ADD VALUE 'archived_for_brick';

   ALTER TABLE activities
   ADD COLUMN brick_metadata JSONB DEFAULT NULL,
   ADD COLUMN brick_id UUID DEFAULT NULL REFERENCES activities(id) ON DELETE SET NULL;

   CREATE INDEX idx_activities_brick_id ON activities(brick_id) WHERE brick_id IS NOT NULL;
   CREATE INDEX idx_activities_brick_type ON activities(activity_type) WHERE activity_type = 'brick';
   ```

2. **Production Environment:**
   - Same SQL after dev testing complete

### Phase 2: Drift Schema Migration

1. **Bump schema version to v3:**
   ```dart
   // lib/shared/database/app_database.dart
   @DriftDatabase(...)
   class AppDatabase extends _$AppDatabase {
     @override
     int get schemaVersion => 3;  // Was 2

     @override
     MigrationStrategy get migration => MigrationStrategy(
       onCreate: (Migrator m) async {
         await m.createAll();
       },
       onUpgrade: (Migrator m, int from, int to) async {
         if (from < 3) {
           // Add brick support columns
           await m.addColumn(activities, activities.brickMetadata);
           await m.addColumn(activities, activities.brickId);
         }
       },
     );
   }
   ```

2. **Generate schema snapshot:**
   ```bash
   dart run drift_dev schema dump lib/shared/database/app_database.dart database_schemas/v3/
   ```

### Phase 3: Domain Model Updates

1. Update `ActivityType` enum
2. Create `BrickMetadata` and `BrickSegment` domain models
3. Update `Activity` domain model
4. Run code generation:
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

## Backward Compatibility

### Existing Activities
- No changes needed - existing activities continue to work
- `brick_metadata` and `brick_id` columns are nullable

### App Updates
- Older app versions will simply not see/create brick activities
- Supabase queries should handle `activity_type = 'brick'` gracefully

### Sync Considerations
- Bricks sync as single activity records
- `brick_metadata` JSON travels with the activity
- Archived original activities have `status = 'archived_for_brick'` and won't appear in normal queries

## Database Queries

### Get all brick activities for a user

```sql
SELECT * FROM activities
WHERE user_id = $1
AND activity_type = 'brick'
AND status != 'archived_for_brick'
ORDER BY scheduled_date_time DESC;
```

### Get archived activities for a brick

```sql
SELECT * FROM activities
WHERE brick_id = $1
AND status = 'archived_for_brick';
```

### Ungroup a brick (restore originals)

```sql
-- Start transaction
BEGIN;

-- Restore original activities
UPDATE activities
SET status = 'planned', brick_id = NULL
WHERE brick_id = $1 AND status = 'archived_for_brick';

-- Delete the brick
DELETE FROM activities WHERE id = $1;

COMMIT;
```

## Testing Considerations

1. **Migration Tests:**
   - Test upgrade from v2 to v3
   - Verify existing data integrity
   - Test rollback scenario

2. **CRUD Tests:**
   - Create brick activity
   - Read brick with segments
   - Update brick segments
   - Delete brick (cascade to archived originals)

3. **Sync Tests:**
   - Upload brick to Supabase
   - Download brick from Supabase
   - Dirty record handling for bricks

## Related Files to Update

| File | Change |
|------|--------|
| `lib/shared/domain/activity_type.dart` | Add `brick` enum value |
| `lib/shared/database/tables/activities_table.dart` | Add new columns |
| `lib/shared/database/app_database.dart` | Bump version, add migration |
| `lib/features/activities/domain/activity.dart` | Add brick fields |
| `lib/features/activities/domain/brick_metadata.dart` | NEW FILE |
| `lib/features/activities/data/activities_repository.dart` | Add brick queries |
| `supabase/migrations/YYYYMMDD_add_brick_support.sql` | Supabase migration |
