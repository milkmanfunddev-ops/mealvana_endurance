# Production Events Schema Fix
*Date: 2025-11-13*

## Issue

The production `events` table had `event_type` and `event_subtype` fields with values that were semantically backwards:

**Production (Incorrect)**:
```sql
event_type text not null
  constraint event_type_check
    check (event_type = ANY (ARRAY [
      'marathon'::text,      -- These are race distances
      'half_marathon'::text,
      '10k'::text,
      '5k'::text,
      'ultra_50k'::text,
      'ultra_50m'::text,
      'ultra_100k'::text,
      'ultra_100m'::text,
      'custom'::text
    ])),
event_subtype text  -- No constraint, unclear purpose
```

**Correct Schema**:
```sql
event_type text not null  -- Sport category: running, cycling, swimming, triathlon, duathlon, multisport
event_subtype text        -- Race distance: marathon, half_marathon, 10k, 5k, ultra_50k, ultra_50m, ultra_100k, ultra_100m, custom
```

## Root Cause

The production database was created with the wrong constraint on `event_type`. Race distances were stored in `event_type` when they should have been in `event_subtype`, and there was no constraint on what sport category the event was for.

This made it impossible to differentiate between:
- A 10K running race
- A 10K cycling race
- A 10K open water swim

All would have just been stored as `event_type: '10k'` with no sport category information.

## Solution

### 1. Production Migration

Created migration: `supabase/migrations/20251113000001_fix_events_type_subtype.sql`

**What it does**:
1. Creates enum types:
   - `event_type_enum`: running, cycling, swimming, triathlon, duathlon, multisport
   - `event_subtype_enum`: All race distances across all sports (50+ values including 5k, 10k, marathon, sprint, olympic, half_ironman, ironman, century, gran_fondo, etc.)
2. Adds temporary enum columns
3. Swaps the values:
   - Current `event_type` (race distance text) → new `event_subtype` (enum)
   - Sets new `event_type` to 'running' (enum) since all existing events are running events
4. Drops old constraint and text columns
5. Renames temp columns to original names
6. Makes `event_type` NOT NULL (required field)
7. Updates column comments for clarity

**Benefits of using enums**:
- Database-level validation of allowed values
- Better query performance
- Clear schema documentation
- Type safety at the database level

### 2. Drift Schema Update

Updated `lib/shared/database/tables/events_table.dart`:

**Before** (matched production bug):
```dart
List<String> get customConstraints => [
  "CHECK (event_type IN ('marathon', 'half_marathon', '10k', '5k', ...))",
];
```

**After** (removed constraints - production uses enums):
```dart
List<String> get customConstraints => [
  // Note: event_type and event_subtype use enums in production (event_type_enum, event_subtype_enum)
  // Drift uses text columns locally but production enforces valid values via enum types
  'CHECK (carb_loading_days IS NULL OR carb_loading_days IN (1, 2, 3, 7))',
];
```

**Why remove constraints?**
- Production database enforces valid values via enum types
- Drift doesn't support enum types (uses text columns)
- No need to duplicate validation in Drift constraints
- Client code already validates via EventSubtype class

### 3. Client Code Status

**Good news**: The client code was already correct!

- ✅ **Event domain model**: Already uses `ActivityType sportType` and `String? eventSubtype`
- ✅ **toJson() mapping**: Already maps `sportType.dbValue` to `'eventType'` field correctly
- ✅ **Repository parsing**: `_parseActivityType()` already handles sport categories ('running', 'cycling', 'swimming', etc.)
- ✅ **Service layer**: Already uses `ActivityType sportType` parameter
- ✅ **Controller layer**: Already uses `ActivityType sportType` parameter

**No client code changes needed** - the bug was only in the production database schema!

## Impact

### Before Migration
- ❌ Events table only supported running events (no way to specify cycling/swimming/multisport)
- ❌ Race distance stored in wrong field
- ❌ Client code and database schema were misaligned
- ❌ Impossible to query events by sport type

### After Migration
- ✅ Events table supports all sport types (running, cycling, swimming, triathlon, duathlon, multisport)
- ✅ Race distance stored in correct field (`event_subtype`)
- ✅ Sport category stored in correct field (`event_type`)
- ✅ Client code and database schema are aligned
- ✅ Can query events by sport type: `SELECT * FROM events WHERE event_type = 'cycling'`
- ✅ Can query events by distance: `SELECT * FROM events WHERE event_subtype = 'marathon'`

## Deployment Steps

1. **Run migration on production**:
   ```bash
   # Apply the migration
   supabase db push
   ```

2. **Verify data migration**:
   ```sql
   -- Check that all events now have correct event_type (should all be 'running' initially)
   SELECT event_type, event_subtype, event_name, COUNT(*)
   FROM events
   GROUP BY event_type, event_subtype, event_name;
   ```

3. **Update any manually created events**:
   ```sql
   -- If any events should be cycling/swimming/multisport, update them manually:
   UPDATE events
   SET event_type = 'cycling'
   WHERE event_name ILIKE '%cycling%' OR event_name ILIKE '%bike%';

   UPDATE events
   SET event_type = 'swimming'
   WHERE event_name ILIKE '%swim%';
   ```

4. **Verify constraints**:
   ```sql
   -- This should work:
   INSERT INTO events (event_type, event_subtype, ...)
   VALUES ('running', 'marathon', ...);

   -- This should fail:
   INSERT INTO events (event_type, event_subtype, ...)
   VALUES ('marathon', 'running', ...);  -- Backwards - should fail!
   ```

## Benefits

1. **Multi-sport support**: Can now properly track cycling, swimming, triathlon, duathlon, and multisport events
2. **Semantic clarity**: Field names now match their actual purpose
3. **Query flexibility**: Can filter by sport type OR race distance independently
4. **Client code alignment**: Database now matches what the client code expected all along
5. **Future-proof**: Easy to add new race distances or sport types as needed

## References

- Migration file: `supabase/migrations/20251113000001_fix_events_type_subtype.sql`
- Drift schema: `lib/shared/database/tables/events_table.dart`
- Event domain model: `lib/features/events/domain/event.dart`
- Events repository: `lib/features/events/data/events_repository.dart`
