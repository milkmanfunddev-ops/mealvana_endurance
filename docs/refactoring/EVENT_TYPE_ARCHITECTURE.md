# Event Type Architecture - Unified ActivityType Enum

**Date**: 2025-11-14
**Status**: ✅ Complete
**Migration**: `20251114000001_use_activity_type_for_events.sql`

## Overview

We unified the event type and activity type representations to use a single shared `ActivityType` enum across both activities and events. This eliminates duplication and ensures consistency between the database and client code.

## Architecture Decision

### Problem
- Events and Activities were using different approaches for representing sport types
- Events had an old `EventType` enum that held **race distances** (5K, 10K, marathon) - confusing!
- No clear separation between **sport category** and **race distance**
- Database used `event_type` but client used `sportType` - inconsistent naming

### Solution
**Unified ActivityType enum** that supports both single-sport and multi-sport activities:

```dart
enum ActivityType {
  // Single-sport
  running,
  cycling,
  swimming,

  // Multi-sport
  triathlon,
  duathlon,
  multisport;
}
```

## Schema Changes

### Database (Postgres)

**Before:**
```sql
-- events table
event_type event_type_enum NOT NULL  -- Values: running, cycling, swimming, triathlon, duathlon, multisport
event_subtype event_subtype_enum      -- Values: marathon, 10k, 5k, etc.

-- activities table
activity_type text NOT NULL           -- Values: running, cycling, swimming
```

**After:**
```sql
-- events table
event_type activity_type_enum NOT NULL  -- Shared enum!
event_subtype event_subtype_enum        -- Race distances

-- activities table
activity_type activity_type_enum NOT NULL  -- Shared enum!
```

### Flutter Client (Drift)

**Drift tables use text columns** for flexibility (SQLite doesn't have enums), but values must match the PostgreSQL enum:

```dart
// lib/shared/database/tables/events_table.dart
TextColumn get eventType => text().named('event_type')();  // Maps to activity_type_enum in Postgres
TextColumn get eventSubtype => text().nullable().named('event_subtype')();
```

### Domain Model

**Event domain model** ([lib/features/events/domain/event.dart](../../lib/features/events/domain/event.dart)):

```dart
class Event {
  final ActivityType eventType;      // Sport category: running, cycling, swimming, triathlon, duathlon, multisport
  final String? eventSubtype;        // Race distance: 'marathon', 'half_marathon', '10k', '5k', etc.

  // Maps to database
  Map<String, dynamic> toJson() {
    return {
      'eventType': eventType.dbValue,  // Converts enum to string
      'eventSubtype': eventSubtype,
    };
  }
}
```

## Terminology Standardization

| Concept | Database Column | Domain Property | Enum Type | Values |
|---------|----------------|-----------------|-----------|--------|
| Sport Category | `event_type` | `eventType` | `ActivityType` | running, cycling, swimming, triathlon, duathlon, multisport |
| Race Distance | `event_subtype` | `eventSubtype` | `String?` (validated by Postgres enum) | marathon, half_marathon, 10k, 5k, sprint, olympic, etc. |

**Key Rule**: Use the same terminology as the production database!
- ✅ `eventType` (matches `event_type` column)
- ❌ `sportType` (confusing, not in database)

## Migration Path

### 1. SQL Migration
File: `supabase/migrations/20251114000001_use_activity_type_for_events.sql`

**Status**: ✅ Complete and idempotent

The migration handles all dependencies on `sport_enum` and `event_type_enum` before dropping them:

**Step 1**: Create shared `activity_type_enum` (if not exists)
**Step 2**: Migrate `events.event_type` from `event_type_enum` to `activity_type_enum`
**Step 3**: Drop old `event_type_enum`
**Step 4**: Migrate `activities.activity_type` from `sport_enum` to `activity_type_enum`
  - Also drops legacy `sport_type` column if it exists
**Step 5**: Migrate `foods.activity_types` array from `sport_enum[]` to `activity_type_enum[]`
**Step 6**: Migrate `user_foods.activity_types` array from `sport_enum[]` to `activity_type_enum[]`
**Step 7**: Drop old `sport_enum` (only after all dependencies removed)

Key implementation details:
- **Fully idempotent**: Safe to run multiple times, checks before each operation
- **Enum-to-enum casting**: Uses text as intermediate type (`::text::activity_type_enum`)
- **Array migration**: Uses `unnest()` to expand arrays, cast elements, then re-aggregate
- **Dependency order**: Removes all dependent columns before dropping enum types

### 2. Flutter Client Changes

**Updated Files:**
- `lib/shared/domain/activity_type.dart` - Extended enum to include multi-sport types
- `lib/features/events/domain/event.dart` - Renamed `sportType` → `eventType`
- `lib/features/events/data/events_repository.dart` - Updated all references
- `lib/features/events/application/events_service.dart` - Updated all references
- `lib/features/events/presentation/providers/events_controller.dart` - Updated all references
- `lib/features/events/presentation/screens/event_edit_screen.dart` - Updated all references
- `lib/features/events/presentation/screens/event_form_screen.dart` - Updated all references
- `lib/features/calendar/application/calendar_service.dart` - Updated all references
- `lib/features/calendar/presentation/providers/calendar_controller.dart` - Updated all references

## ActivityType Enum Features

```dart
enum ActivityType {
  running, cycling, swimming,      // Single-sport
  triathlon, duathlon, multisport; // Multi-sport

  /// Display name for UI
  String get displayName {
    switch (this) {
      case ActivityType.running: return 'Run';
      case ActivityType.cycling: return 'Ride';
      case ActivityType.swimming: return 'Swim';
      case ActivityType.triathlon: return 'Triathlon';
      case ActivityType.duathlon: return 'Duathlon';
      case ActivityType.multisport: return 'Multisport';
    }
  }

  /// Database-compatible value (matches Postgres activity_type_enum)
  String get dbValue => name; // 'running', 'cycling', etc.

  /// Check if single-sport or multi-sport
  bool get isSingleSport => this == running || this == cycling || this == swimming;
  bool get isMultiSport => this == triathlon || this == duathlon || this == multisport;
}
```

## Benefits

1. **Single Source of Truth**: One enum for both activities and events
2. **Database Consistency**: Client property names match database column names
3. **Type Safety**: Compile-time validation of sport types
4. **Future-Proof**: Easy to add new sport types (e.g., aquathlon, aquabike)
5. **Clear Separation**:
   - `eventType` = WHAT sport (running, triathlon, etc.)
   - `eventSubtype` = WHICH distance (marathon, 10k, etc.)

## Impact Analysis

**Analyzer Errors**:
- Before: 646 errors
- After: 634 errors
- **Fixed: 12 errors** related to EventType enum references

**Breaking Changes**:
- None for end users
- Backend: Production database requires migration before deploying client changes
- Client: Requires rebuild after updating enums

## Testing Checklist

- [x] SQL migration runs successfully in production
- [x] Migration is fully idempotent (can run multiple times safely)
- [x] All enum dependencies handled (events, activities, foods, user_foods)
- [ ] Verify events can be created with all ActivityType values
- [ ] Verify existing events migrate correctly
- [ ] Verify eventSubtype values are preserved
- [ ] Verify Activities continue to work (should not be affected)
- [ ] Verify sync service handles new schema correctly
- [ ] Run `flutter analyze` to verify client code compiles

## References

- **Migration SQL**: `supabase/migrations/20251114000001_use_activity_type_for_events.sql`
- **ActivityType Enum**: `lib/shared/domain/activity_type.dart`
- **Event Domain Model**: `lib/features/events/domain/event.dart`
- **Event Subtype Enum** (Postgres): See migration `20251113000001_fix_events_type_subtype.sql`

---

**Last Updated**: 2025-11-14
**Contributors**: Claude (AI Assistant), Lee Martin
