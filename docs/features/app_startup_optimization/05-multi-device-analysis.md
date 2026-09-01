# Multi-Device & Realtime Analysis

> **Last Updated**: December 2024
> **Status**: Critical gaps identified for multi-device support

## Table of Contents

1. [Current Multi-Device State](#current-multi-device-state)
2. [User Identification Architecture](#user-identification-architecture)
3. [Conflict Detection Analysis](#conflict-detection-analysis)
4. [Supabase Realtime Status](#supabase-realtime-status)
5. [Timestamp Handling](#timestamp-handling)
6. [Data Merging Logic](#data-merging-logic)
7. [User Switching Scenarios](#user-switching-scenarios)
8. [Row Level Security](#row-level-security)
9. [Critical Gaps](#critical-gaps)
10. [Recommended Improvements](#recommended-improvements)

---

## Current Multi-Device State

### Summary

| Aspect | Status | Risk Level |
|--------|--------|------------|
| Same user on multiple devices | ✅ Supported | Low |
| Concurrent edit detection | ❌ Not implemented | High |
| Real-time sync | ❌ Not implemented | High |
| Conflict resolution UI | ❌ Not implemented | Medium |
| Clock skew protection | ❌ Not implemented | Medium |

### What Works Today

- User can sign in on multiple devices
- Data syncs on app startup
- Dirty flag protects local changes during download
- Upload-first prevents most data loss

### What Doesn't Work

- Changes on Device B don't appear on Device A until restart
- Simultaneous edits can silently overwrite each other
- No notification when data changes on another device
- No way for user to resolve conflicts

---

## User Identification Architecture

### Current Implementation

**File**: `lib/features/auth/data/user_repository.dart`

```dart
// Primary: Supabase Auth UUID (auth.uid())
// Fallback: Local cached user profile ID
// Legacy: device_id (being phased out but still present)
```

### Evolution of User ID

| Phase | Identifier | Status |
|-------|------------|--------|
| Original | `device_id` | Legacy, still in schema |
| Current | `user_id` (Supabase Auth UUID) | Primary |
| Both point to | Same UUID value | For backward compatibility |

### How Multi-Device Auth Works

1. **First Device**: User creates anonymous session → gets UUID
2. **Second Device**: User signs in with OAuth → same UUID restored
3. **Data Association**: Both devices use same `user_id` for queries

```dart
// From app_startup_service.dart
final existingSession = _supabase.auth.currentSession;
if (existingSession == null) {
  await _supabase.auth.signInAnonymously();
}
// Session UUID becomes user_id for all data
```

---

## Conflict Detection Analysis

### Current Approach: Last-Write-Wins with Dirty Flag

**File**: `lib/shared/services/sync/data_sync_service.dart` lines 440-444

```dart
// CRITICAL: Preserve local data if it has pending changes
if (existingActivity != null && (existingActivity.needsUpload ?? false)) {
  return; // Keep local version - PHONE IS SOURCE OF TRUTH
}

// Only overwrite if server is newer
if (existingActivity == null || existingActivity.updatedAt.isBefore(supabaseUpdatedAt)) {
  // Update from server
}
```

### Conflict Scenarios

#### Scenario 1: Sequential Edits (Works)

```
Timeline:
T1: Device A edits → uploads → needsUpload = false
T2: Device B opens app → downloads Device A's changes
T3: Device B edits → uploads
Result: ✅ Both changes preserved (sequential)
```

#### Scenario 2: Concurrent Edits (FAILS)

```
Timeline:
T1: Device A edits activity (offline)     needsUpload = true
T2: Device B edits same activity (online) → uploads immediately
T3: Device A goes online → uploads
T4: Device A's upload overwrites Device B's changes
Result: ❌ Device B's changes SILENTLY LOST
```

#### Scenario 3: Race During Sync (Partially Protected)

```
Timeline:
T1: Device A has dirty record (needsUpload = true)
T2: Device A starts sync, downloads server data
T3: Server has newer version of same record
T4: Dirty flag check → skip overwrite
Result: ✅ Local changes protected
```

### Why Current Approach Fails for Multi-Device

| Issue | Description |
|-------|-------------|
| No version tracking | Can't detect concurrent modifications |
| No conflict UI | Users never know conflicts occurred |
| Silent overwrites | Last upload wins, no warning |
| Clock dependency | Relies on device time being correct |

---

## Supabase Realtime Status

### Current State: NOT IMPLEMENTED

**Evidence**: Searched entire codebase for realtime patterns

| Pattern | Found | Location |
|---------|-------|----------|
| `.stream()` | ❌ No | - |
| `supabase.channel()` | ❌ No | - |
| `onPostgresChanges` | ❌ No | - |
| WebSocket setup | ❌ No | - |

### Impact of Missing Realtime

| Scenario | Current Behavior | Ideal Behavior |
|----------|------------------|----------------|
| Edit on Device B | Device A sees nothing | Device A sees change instantly |
| Collaborative use | Must restart to see updates | Live updates |
| Coach-athlete sync | Manual refresh required | Automatic sync |

### Why Realtime Matters

For your stated goals:
- **Multi-device support**: Essential for live sync
- **Future coach features**: Required for collaboration
- **User trust**: "Why don't I see my changes?"

---

## Timestamp Handling

### Current Implementation

**File**: `lib/shared/services/sync/data_sync_service.dart` lines 56-65

```dart
String? _intToIso8601(dynamic value) {
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value).toIso8601String();
  }
  // handles DateTime objects too
}
```

### Timestamp Columns

| Column | Purpose | Set By |
|--------|---------|--------|
| `created_at` | Immutable creation time | Client on create |
| `updated_at` | Modified timestamp | Client on every change |
| `local_updated_at` | Drift-only tracking | Client (Drift tables only) |

### Issues Identified

| Issue | Risk | Mitigation |
|-------|------|------------|
| No timezone normalization | Medium | Relies on OS clock |
| No NTP sync checks | Medium | Could have wrong time |
| Millisecond precision only | Low | Same-ms conflicts possible |
| No logical clocks | High | Can't guarantee ordering |

### Clock Skew Problem

```
Scenario:
- Device A clock is 5 minutes behind
- Device B clock is correct
- Device A edits at actual 10:00 (thinks it's 9:55)
- Device B edits at actual 10:01
- Device A uploads with timestamp 9:55
- Device B uploads with timestamp 10:01
- Last-write-wins picks Device B (10:01 > 9:55)
- But Device A actually edited AFTER Device B's change!
```

---

## Data Merging Logic

### Upload Phase: SOLID

```dart
// Lines 669-749: Upload dirty records FIRST
await _uploadDirtyRecords(userId);  // Step 1
await _downloadActivities(userId);  // Step 2
```

**Strength**: Upload before download prevents local data loss

### Download/Merge Phase: NEEDS IMPROVEMENT

```dart
// Lines 431-494: Merge logic
if (existingActivity != null && (existingActivity.needsUpload ?? false)) {
  return; // Skip - local data has priority
}

if (existingActivity == null || existingActivity.updatedAt.isBefore(supabaseUpdatedAt)) {
  // Replace ENTIRE record
  await _database.into(_database.activitiesTable)
    .insert(companion, mode: InsertMode.insertOrReplace);
}
```

### Merge Limitations

| Limitation | Impact |
|------------|--------|
| No field-level merging | Replaces entire record |
| No three-way merge | Can't detect divergent changes |
| Silent overwrites | If local `needsUpload=false`, overwritten |
| Race condition window | Between check and insert |

### Example: Lost Changes

```
Device A edits: nutrition_plan_data (JSON field)
Device B edits: completion_notes (text field)

Both should be merged, but:
- Last upload wins
- Entire record replaced
- One set of changes lost
```

---

## User Switching Scenarios

### Scenario A: Sign In on New Device

**Flow**: `lib/features/auth/data/user_repository.dart` lines 464-487

```dart
1. Supabase Auth creates/restores session
2. fetchAndSaveRemoteProfile(userId) downloads profile
3. fetchAndCacheRemoteFoodPreferences(userId) downloads preferences
4. syncUserFoodsFromSupabase(userId) downloads custom foods
5. DataSyncService downloads activities/events
```

**Status**: ✅ Works well - new device gets full data

### Scenario B: Anonymous → OAuth Account Linking

**Flow**: `lib/features/auth/data/user_repository.dart` lines 663-734

```dart
1. migrateAnonymousUserData() called
2. Supabase data migrated (events, activities, food_preferences, user_foods)
3. Delete anonymous user from Supabase
4. Create/update OAuth user with anonymous user's data
5. Local database updated with new user_id
```

**Issues**:
- **Destructive merge**: Deletes OAuth user's existing data first
- **No conflict resolution**: Can't merge two accounts with overlapping data
- **Unique constraint prevention**: Deletes OAuth data before migrating

### Scenario C: device_id → user_id Transition

**Current State**: Hybrid system

```sql
-- Both columns point to same UUID
users(
  id UUID PRIMARY KEY,     -- Supabase Auth UUID
  device_id TEXT,          -- Legacy, same value as id
)
```

**Implementation**:
```dart
final userData = {
  'id': userId,           // Supabase Auth UUID
  'device_id': userId,    // Same value for backward compat
}
```

**Status**: ✅ Smooth transition completed

---

## Row Level Security

### Current State: DEVELOPMENT MODE (INSECURE)

**Documentation**: `docs/features/startup_auth_roadmap/RLS_DEFERRAL.md`

```sql
-- Current (Development) - INSECURE
CREATE POLICY "Users can read own data" ON users
  FOR SELECT USING (true);  -- ANY user can read ALL data

-- Required (Production)
CREATE POLICY "Users can only read own profile" ON users
  FOR SELECT USING (auth.uid() = id);
```

### Impact on Multi-Device

| Aspect | Current | After RLS |
|--------|---------|-----------|
| Cross-user access | ⚠️ Possible (dev only) | ✅ Blocked |
| Same user, multiple devices | ✅ Works | ✅ Works (same auth.uid()) |
| Security | ❌ Insecure | ✅ Secure |

### Before Production

Must implement proper RLS:
```sql
-- Activities: User can only access own activities
CREATE POLICY "Users access own activities" ON activities
  FOR ALL USING (auth.uid() = user_id);

-- Apply to all user-data tables
```

---

## Critical Gaps

### Gap 1: No Real-Time Sync (HIGH PRIORITY)

| Impact | Description |
|--------|-------------|
| UX | Changes on Device B invisible to Device A |
| Trust | Users think data didn't save |
| Effort | Medium (1-2 weeks) |

### Gap 2: No Conflict Resolution UI (MEDIUM PRIORITY)

| Impact | Description |
|--------|-------------|
| Data loss | Silent overwrites |
| User confusion | "Where did my changes go?" |
| Effort | High (2-3 weeks) |

### Gap 3: No Clock Skew Protection (MEDIUM PRIORITY)

| Impact | Description |
|--------|-------------|
| Correctness | Wrong device's changes win |
| Edge case | Rare but possible |
| Effort | Medium (1-2 weeks) |

### Gap 4: No Field-Level Merge (LOW PRIORITY)

| Impact | Description |
|--------|-------------|
| Granularity | Entire records overwritten |
| Complexity | Very high to implement |
| Effort | Very High (4+ weeks) |

### Gap 5: Weak Concurrent Edit Detection (HIGH PRIORITY)

| Impact | Description |
|--------|-------------|
| Data loss | Last-write-wins silently |
| Fixable | Add version column |
| Effort | Low (3-5 days) |

---

## Recommended Improvements

### Phase 1: Conflict Detection (1 week)

**Add version column to synced tables**:

```sql
ALTER TABLE activities ADD COLUMN version INTEGER DEFAULT 1;
ALTER TABLE events ADD COLUMN version INTEGER DEFAULT 1;
ALTER TABLE carb_loading_plans ADD COLUMN version INTEGER DEFAULT 1;
```

**Update upload logic**:

```dart
// Optimistic locking
final result = await supabase.from('activities')
  .update({...data, version: localVersion + 1})
  .eq('id', id)
  .eq('version', localVersion)  // Only succeeds if version matches
  .select()
  .maybeSingle();

if (result == null) {
  // Version mismatch = CONFLICT
  final serverVersion = await fetchServerActivity(id);
  throw SyncConflictException(local: localActivity, server: serverVersion);
}
```

### Phase 2: Realtime Sync (2 weeks)

**Subscribe to user's data changes**:

```dart
final channel = supabase
  .channel('user-data-$userId')
  .onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: 'activities',
    filter: PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'user_id',
      value: userId,
    ),
    callback: (payload) => _handleRemoteChange(payload),
  )
  .subscribe();
```

**Handle incoming changes**:

```dart
void _handleRemoteChange(PostgresChangePayload payload) {
  switch (payload.eventType) {
    case PostgresChangeEvent.insert:
    case PostgresChangeEvent.update:
      // Check for conflicts before applying
      _mergeRemoteChange(payload.newRecord);
      break;
    case PostgresChangeEvent.delete:
      _deleteLocally(payload.oldRecord['id']);
      break;
  }

  // Refresh UI
  ref.invalidate(activitiesControllerProvider);
}
```

### Phase 3: Clock Skew Protection (1 week)

**Get server time with each sync**:

```dart
// Add server time endpoint or use existing response
final serverTime = await supabase.rpc('get_server_time');
final clockSkew = serverTime.difference(DateTime.now());

// Store and apply to all timestamps
final adjustedTime = DateTime.now().add(clockSkew);
```

### Phase 4: Conflict Resolution UI (2 weeks)

**Show conflict dialog when detected**:

```dart
class ConflictResolutionDialog extends StatelessWidget {
  final Activity localVersion;
  final Activity serverVersion;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Sync Conflict'),
      content: Column(
        children: [
          Text('This activity was modified on another device.'),
          Text('Your version: ${localVersion.updatedAt}'),
          Text('Other version: ${serverVersion.updatedAt}'),
          // Show field-by-field diff
          DiffView(local: localVersion, server: serverVersion),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, ConflictResolution.keepLocal),
          child: Text('Keep My Changes'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, ConflictResolution.keepServer),
          child: Text('Use Other Device'),
        ),
      ],
    );
  }
}
```

---

## Implementation Priority

| Phase | Effort | Impact | Priority |
|-------|--------|--------|----------|
| Conflict Detection (version column) | 3-5 days | High | P1 |
| Realtime Sync | 2 weeks | High | P1 |
| Clock Skew Protection | 1 week | Medium | P2 |
| Conflict Resolution UI | 2 weeks | Medium | P2 |
| Field-Level Merge | 4+ weeks | Low | P3 |

### Recommended Order

1. **Version column** (quick win, enables detection)
2. **Realtime sync** (biggest UX improvement)
3. **Conflict UI** (handles detected conflicts)
4. **Clock skew** (edge case protection)
5. **Field merge** (future enhancement)
