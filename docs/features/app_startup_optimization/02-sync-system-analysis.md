# Sync System Deep Dive

> **Last Updated**: December 2024
> **Primary File**: `lib/shared/services/sync/data_sync_service.dart` (1,135 lines)

## Table of Contents

1. [Sync Architecture Overview](#sync-architecture-overview)
2. [What Data Gets Synced](#what-data-gets-synced)
3. [Sync Direction](#sync-direction)
4. [Dirty Flag Pattern](#dirty-flag-pattern)
5. [Conflict Resolution](#conflict-resolution)
6. [Edge Function](#edge-function)
7. [Error Handling](#error-handling)
8. [ID Generation & Rekey](#id-generation--rekey)
9. [Sync Triggers](#sync-triggers)
10. [Performance Characteristics](#performance-characteristics)

---

## Sync Architecture Overview

Mealvana Endurance implements a **hybrid sync architecture** combining:

| Component | Purpose |
|-----------|---------|
| Edge Function (Primary) | Single `sync-all-data` endpoint for fast bulk downloads |
| Client-Side Fallback | Direct Supabase queries when edge function fails/times out |
| Dirty Flag Tracking | Offline-first with `needs_upload` flags for pending changes |
| Timestamp-Based Incremental Sync | Reduces bandwidth by only fetching changed records |

### High-Level Flow

```
syncAllData()
    ↓
┌─────────────────────────────────────────────────────┐
│ PHASE 0: syncUsers()                                │
│ (FK violation prevention - CRITICAL)                │
└──────────────────────────┬──────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────┐
│ PHASE 1: _uploadDirtyRecords()                      │
│ (Upload FIRST - prevents data loss)                 │
│ • Activities, Events                                │
│ • Carb Loading Plans, Carb Loading Days             │
│ • User Foods, Feedback, Feature Survey Responses    │
└──────────────────────────┬──────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────┐
│ PHASE 2: _tryEdgeFunctionSync()                     │
│ (Fast parallel download - 30s timeout)              │
└──────────┬──────────────────────────────┬───────────┘
           │                              │
      Success                        Timeout/Fail
           │                              │
           ↓                              ↓
┌─────────────────┐          ┌─────────────────────────┐
│ Extract & Merge │          │ PHASE 3: Client-Side    │
│ Data            │          │ Direct Queries          │
└────────┬────────┘          └────────────┬────────────┘
         │                                │
         └────────────┬───────────────────┘
                      ↓
         ┌─────────────────────────┐
         │ Update Local Drift DB   │
         │ (Upsert with conflict   │
         │  resolution)            │
         └────────────┬────────────┘
                      ↓
         ┌─────────────────────────┐
         │ Save Last Sync          │
         │ Timestamp               │
         └────────────┬────────────┘
                      ↓
         ┌─────────────────────────┐
         │ Return success/failure  │
         │ (Non-blocking)          │
         └─────────────────────────┘
```

---

## What Data Gets Synced

### Downloaded from Supabase → Local Drift DB

| Table | Type | Records | Update Frequency | Incremental |
|-------|------|---------|------------------|-------------|
| `users` | User profile | 1 per user | Every sync | Yes (critical) |
| `foods` | Reference data | ~300 records | Every sync | Yes (via `updated_at`) |
| `carb_loading_foods` | Reference data | ~150 records | Every sync | Yes (via `updated_at`) |
| `activities` | User data | Variable | Every sync | Yes (via `updated_at`) |
| `events` | User data | Variable | Every sync | Yes (via `updated_at`) |
| `carb_loading_plans` | User data | Variable | Every sync | Yes (via `local_updated_at`) |
| `carb_loading_days` | User data | Variable | Every sync | Yes (via `local_updated_at`) |

**Total synced tables**: **7 tables**

### Uploaded from Local Drift DB → Supabase

Tables with `needs_upload` dirty flag:

| Table | Upload Trigger | Conflict Resolution |
|-------|----------------|---------------------|
| `activities` | User creates/modifies activity | Server ID rekey if needed |
| `events` | User creates/modifies event | Direct upsert |
| `carb_loading_plans` | User generates plan | Server ID rekey if needed |
| `carb_loading_days` | User logs meal/progress | Server ID rekey if needed |
| `user_foods` | User scans barcode/creates food | Direct upsert |
| `feedback` | User submits feedback | Direct upsert |
| `feature_survey_responses` | User votes on features | Direct upsert |

**Total tracked tables**: **7 tables**

### Not Synced (Local-Only)

| Table | Reason |
|-------|--------|
| `macro_targets` | Calculated data, regenerated on demand |
| `workout_notes` | Deprecated (embedded in activities now) |
| `weather_forecasts` | Cache table with 1-24hr expiry |
| `nutrition_plan_selections` | Temporary selections during plan generation |

---

## Sync Direction

### Bidirectional Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    SYNC FLOW DIAGRAM                         │
└─────────────────────────────────────────────────────────────┘

APP STARTUP TRIGGER:
├─ STEP 0: User Profile Sync (CRITICAL - prevents FK violations)
│   └─ Upload: Local user → Supabase users table
│
├─ STEP 1: Upload Dirty Records (CRITICAL - prevents data loss)
│   ├─ Query: SELECT * WHERE needs_upload = true
│   ├─ Upload: activities, events, carb_loading_plans, carb_loading_days
│   ├─ Upload: user_foods, feedback, feature_survey_responses
│   └─ Clear: Set needs_upload = false on success
│
├─ STEP 2: Download from Edge Function (Primary Strategy)
│   ├─ Call: sync-all-data edge function with optional last_sync_timestamp
│   ├─ Timeout: 30 seconds
│   ├─ Returns: All 7 tables in single JSON response
│   └─ Merge: Upsert to local Drift database (timestamp-based)
│
└─ STEP 3: Client-Side Fallback (if edge function fails/times out)
    ├─ Phase A: Download reference data (parallel)
    │   ├─ foods: SELECT * FROM foods
    │   └─ carb_loading_foods: SELECT * FROM carb_loading_foods
    └─ Phase B: Download user data (parallel)
        ├─ activities: SELECT * WHERE user_id = ? AND deleted_at IS NULL
        ├─ events: SELECT * WHERE user_id = ?
        ├─ carb_loading_plans: SELECT * WHERE user_id = ?
        └─ carb_loading_days: SELECT * WITH JOIN ON user_id
```

### Key Principles

| Principle | Implementation |
|-----------|----------------|
| Upload First | Local changes pushed BEFORE downloading to prevent overwrites |
| User Profile Priority | User record synced first to avoid FK violations |
| Hybrid Strategy | Edge function for speed, direct queries for reliability |
| Non-Blocking | App continues with cached data if sync fails |

---

## Dirty Flag Pattern

### Schema Design

Tables with sync tracking columns:

```sql
-- Example: activities table
CREATE TABLE activities (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT NOT NULL,
  -- ... other columns
  needs_upload BOOLEAN DEFAULT 0,      -- Dirty flag (Drift-only)
  local_updated_at DATETIME,           -- Client timestamp (Drift-only)
  updated_at DATETIME NOT NULL         -- Server timestamp
);
```

### Setting Dirty Flag

**When**: Any local modification (create, update, delete)

```dart
// In repositories when user modifies data
await db.into(db.activitiesTable).insert(
  ActivitiesTableCompanion.insert(
    title: 'Morning Run',
    needsUpload: const Value(true),  // ✅ Mark for upload
    localUpdatedAt: Value(DateTime.now()),
    updatedAt: DateTime.now(),
  ),
);
```

### Clearing Dirty Flag

**When**: After successful upload to Supabase

```dart
// In DataSyncService after successful upload
await (_database.update(_database.activitiesTable)
  ..where((tbl) => tbl.id.equals(serverId)))
  .write(const ActivitiesTableCompanion(
    needsUpload: Value(false),
  ));
```

### Query Patterns

```dart
// Type-safe Drift queries for tables with needsUpload in schema
final dirtyActivities = await (_database.select(_database.activitiesTable)
      ..where((tbl) => tbl.needsUpload.equals(true)))
    .get();

// Raw SQL for tables with dynamically-added columns
final dirtyUserFoods = await _database
    .customSelect('SELECT * FROM user_foods WHERE needs_upload = 1')
    .get();
```

---

## Conflict Resolution

### Download Conflicts (Server → Local)

**Rule**: Server data wins IF server timestamp is newer AND local record is clean

```dart
// In _upsertActivity() method
// CRITICAL: Preserve local data if it has pending changes (needsUpload = true)
if (existingActivity != null && (existingActivity.needsUpload ?? false)) {
  return; // Keep local version with pending changes
}

// Only overwrite if server is newer
if (existingActivity == null || existingActivity.updatedAt.isBefore(supabaseUpdatedAt)) {
  await _database.into(_database.activitiesTable)
    .insert(companion, mode: InsertMode.insertOrReplace);
}
```

### Resolution Matrix

| Scenario | Local State | Server State | Resolution |
|----------|-------------|--------------|------------|
| New record created locally | `needs_upload=true` | Doesn't exist | ✅ Keep local, upload on next sync |
| User modified locally | `needs_upload=true` | Older timestamp | ✅ Keep local, upload overwrites server |
| Server has newer version | `needs_upload=false` | Newer timestamp | ✅ Server wins, local overwritten |
| Both modified (rare) | `needs_upload=true` | Newer timestamp | ✅ **Local wins** (dirty flag protection) |

### Upload Conflicts (Local → Server)

**Rule**: Server auto-generates IDs, client updates with new ID

```dart
// Try UPDATE first, fallback to INSERT if record doesn't exist
try {
  updateResponse = await _supabase
    .from('activities')
    .update(payload)
    .eq('id', activity.id)
    .eq('user_id', userId)
    .select('id')
    .maybeSingle();
} catch (e) {
  // Activity doesn't exist on server, will INSERT
}

int serverId;
if (updateResponse != null && updateResponse['id'] != null) {
  serverId = updateResponse['id'] as int; // Existing record
} else {
  // INSERT and get server-generated ID
  insertResponse = await _supabase.from('activities').insert(payload).select('id').single();
  serverId = insertResponse['id'] as int;
}

// Re-key locally if server ID differs
if (serverId != activity.id) {
  await _rekeyActivityLocally(activity.id, serverId);
}
```

---

## Edge Function

**File**: `supabase/functions/sync-all-data/index.ts` (159 lines)

### Purpose

Bundle 7 parallel Supabase queries into a single HTTP request for efficiency.

### Request Format

```typescript
{
  user_id: string;
  last_sync_timestamp?: string; // ISO8601 for incremental sync
}
```

### Response Format

```typescript
{
  user_profile: UserProfile | null;
  nutrition_foods: Food[];
  carb_loading_foods: CarbLoadingFood[];
  activities: Activity[];
  events: Event[];
  carb_loading_plans: CarbLoadingPlan[];
  carb_loading_days: CarbLoadingDay[];
}
```

### Incremental Sync Support

```typescript
const { user_id, last_sync_timestamp } = await req.json();

const addFilter = (query) => {
  if (last_sync_timestamp) {
    return query.gt('updated_at', last_sync_timestamp);  // Only fetch changed records
  }
  return query;  // Full sync on first run
};

// Apply to all queries
addFilter(supabaseClient.from('foods').select('*')),
addFilter(supabaseClient.from('activities').select('*').eq('user_id', user_id)),
```

### Timeout Handling

```dart
// In DataSyncService
final response = await _supabase.functions.invoke('sync-all-data', body: {...})
  .timeout(Duration(seconds: 30), onTimeout: () {
    throw TimeoutException('Edge function timed out after 30 seconds');
  });
```

---

## Error Handling

### Graceful Degradation

```dart
Future<bool> syncAllData(String userId) async {
  try {
    // STEP 0: CRITICAL - User profile MUST succeed
    await syncUsers(userId);  // Throws on failure

    // STEP 1: CRITICAL - Upload dirty records FIRST
    await _uploadDirtyRecords(userId);  // Individual failures logged but not fatal

    // STEP 2: Try edge function (fast path)
    final edgeFunctionSuccess = await _tryEdgeFunctionSync(userId, lastSyncTimestamp);

    if (edgeFunctionSuccess) {
      return true; // ✅ Happy path
    }

    // STEP 3: Fallback to client-side (slow path)
    await _clientSideDownload(userId);

    return true; // ✅ Fallback succeeded
  } catch (e, stackTrace) {
    _logger.error(
      'Sync failed - app continuing with cached data',  // ✅ Non-blocking error
      context: 'DATA_SYNC',
      error: e,
      stackTrace: stackTrace,
    );
    return false; // ❌ Sync failed, but app continues
  }
}
```

### Error Categories

| Error Type | Severity | Handling | User Impact |
|------------|----------|----------|-------------|
| User profile sync fails | **FATAL** | Re-throw, stop sync | App shows retry screen |
| Edge function timeout | **Warning** | Fallback to client-side | Sync takes 2-5s longer |
| Individual table download fails | **Warning** | Log error, continue | Stale data for that table |
| Individual record upload fails | **Warning** | Leave `needs_upload=true`, retry next sync | Record stays pending |
| Network offline | **Info** | Return false, app continues | User sees cached data |

### Upload Failure Handling

```dart
Future<void> _uploadActivity(String userId, Activity activity) async {
  try {
    // Try UPDATE/INSERT logic...

    // ✅ Success: Clear dirty flag
    await (_database.update(_database.activitiesTable)
      ..where((tbl) => tbl.id.equals(serverId)))
      .write(const ActivitiesTableCompanion(needsUpload: Value(false)));

  } catch (e, stackTrace) {
    // ❌ Failure: Log but don't throw
    _logger.error('Failed to upload activity ${activity.id}',
      context: 'DATA_SYNC',
      error: e,
      stackTrace: stackTrace
    );
    // Record stays marked as needs_upload=true, will retry on next sync
  }
}
```

---

## ID Generation & Rekey

### Activities: Server-Generated IDs

**Pattern**: Local creates with auto-increment, server provides permanent ID

```dart
// Step 1: Create locally with auto-increment ID
final localId = await _database.into(_database.activitiesTable).insert(companion);

// Step 2: Upload to server (no ID in payload)
final insertResponse = await _supabase
    .from('activities')
    .insert(payload)  // No 'id' field
    .select('id')
    .single();
final serverId = insertResponse['id'] as int;

// Step 3: Rekey local ID to match server
if (serverId != localId) {
  await _replaceActivityIdLocal(localId, serverId);
}
```

### Rekey Implementation (Transaction)

```dart
Future<void> _replaceActivityIdLocal(int oldId, int newId) async {
  await _database.transaction(() async {
    // Update foreign keys first (events reference activities)
    await _database.customStatement(
      'UPDATE events SET activity_id = ? WHERE activity_id = ?',
      [newId, oldId],
    );

    // Update primary key
    await _database.customStatement(
      'UPDATE activities SET id = ? WHERE id = ?',
      [newId, oldId],
    );
  });
}
```

### User Foods: UUID (No Rekey)

```dart
// Client generates UUID - no rekey needed
final foodId = _uuid.v4();
```

**Advantage**: Client-generated UUIDs avoid rekey complexity entirely.

---

## Sync Triggers

### Current Triggers

| Trigger | Location | When |
|---------|----------|------|
| App Startup | `app_startup_service.dart` | Every app launch |
| Auth State Change | `auth_service.dart` | Sign in/out |

### Missing Triggers (Gaps)

| Trigger | Status | Impact |
|---------|--------|--------|
| App Resume (foreground) | ❌ Not implemented | Stale data after long background |
| Pull-to-Refresh | ❌ Not implemented | User can't manually refresh |
| Manual "Sync Now" button | ❌ Not implemented | No user control |
| Background sync (WorkManager) | ❌ Not implemented | Data not uploaded if app closed |
| After data modification | ❌ Not implemented | Changes wait for next app start |

---

## Performance Characteristics

### Current State

| Metric | Value |
|--------|-------|
| Sync Duration (cellular) | 3-5 seconds |
| Bandwidth per sync | ~500KB (ALL foods downloaded) |
| Network Requests | 1 edge function call + individual uploads |

### With Incremental Sync (Future)

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Sync Duration | 3-5s | <1s | 70% faster |
| Bandwidth | 500KB | ~50KB | 90% reduction |
| FK Violations | Common | Zero | Eliminated |

### Sync Metadata Storage

```dart
// Last sync timestamp tracked per user (SharedPreferences)
final lastSyncTimestamp = prefs.getString('last_sync_timestamp_$userId');

// Updated after successful sync
await prefs.setString('last_sync_timestamp_$userId', DateTime.now().toIso8601String());
```

---

## Summary Table

| Aspect | Implementation |
|--------|----------------|
| **Data Synced** | 7 tables (users, foods, carb_loading_foods, activities, events, carb_loading_plans, carb_loading_days) |
| **Direction** | Bidirectional (upload dirty records, download all changes) |
| **Conflict Resolution** | Last-write-wins with dirty flag protection (local always wins if `needs_upload=true`) |
| **Tables Tracked** | 7 tables with `needs_upload` column |
| **Incremental Sync** | Yes (timestamp-based via `updated_at` and `last_sync_timestamp`) |
| **Primary Strategy** | Edge function `sync-all-data` (single HTTP call, 30s timeout) |
| **Fallback Strategy** | Direct Supabase client queries (6 parallel downloads) |
| **Error Handling** | Graceful degradation (app continues with cached data) |
| **Retry Mechanism** | Manual (retry on next app startup, no automatic backoff) |
| **Trigger** | App startup only (no pull-to-refresh or manual sync) |
| **User Visibility** | None (sync happens silently, no UI feedback) |
| **Performance** | <1s incremental sync, 3-5s full sync, 90% bandwidth reduction potential |
