# DataSyncService Code Analysis

**Date**: 2026-01-09
**File**: `lib/shared/services/sync/data_sync_service.dart`
**Total Lines**: 2,508
**Analysis Method**: 4 specialized code research agents

---

## Table of Contents

1. [File Statistics](#file-statistics)
2. [Method Inventory](#method-inventory)
3. [Code Duplication Analysis](#code-duplication-analysis)
4. [Dependency Analysis](#dependency-analysis)
5. [Sync Pattern Analysis](#sync-pattern-analysis)
6. [Natural Refactoring Boundaries](#natural-refactoring-boundaries)

---

## File Statistics

### Overview
- **Total Lines**: 2,508
- **Total Methods**: 52 (public + private)
- **Public Methods**: 4
- **Private Methods**: 48
- **Static Methods**: 3
- **Average Method Length**: 48.2 lines
- **Median Method Length**: 39 lines
- **File Size**: ~86 KB

### Complexity Metrics
- **Methods Over 100 Lines**: 4 (critical complexity)
- **Methods 50-100 Lines**: 14 (moderate complexity)
- **Methods Under 50 Lines**: 34
- **Code Duplication**: ~980 lines (39%)

---

## Method Inventory

### 1. Utility/Helper Methods (7 methods, avg 8.6 lines)

| Method | Lines | Range | Purpose |
|--------|-------|-------|---------|
| `_toStringId` | 6 | 60-65 | Convert dynamic ID to String |
| `_toRequiredStringId` | 7 | 68-74 | Convert required ID with null check |
| `_toBool` | 9 | 78-86 | Convert dynamic bool |
| `_intToIso8601` | 10 | 94-103 | Convert SQLite timestamp to ISO8601 |
| `_parseGenderString` | 9 | 295-303 | Parse gender string to enum |
| `_parseGutTrainingString` | 13 | 308-320 | Parse gut training level |
| `_parsePgArray` | 6 | 2442-2447 | Parse PostgreSQL array |

---

### 2. Core Sync Orchestration (4 methods, avg 54 lines)

| Method | Lines | Range | Purpose |
|--------|-------|-------|---------|
| **`syncAllData`** | **40** | **108-147** | Main entry point |
| **`syncUsers`** | **90** | **158-243** | User profile sync (prevents FK violations) |
| `_saveRemoteUserProfile` | 44 | 248-292 | Save remote user to local |
| `needsFullSync` | 42 | 2457-2497 | Detect if full sync needed |

---

### 3. Edge Function Sync (2 methods, avg 84.5 lines)

| Method | Lines | Range | Purpose |
|--------|-------|-------|---------|
| `_tryEdgeFunctionSync` | 45 | 325-369 | Try edge function with timeout |
| **`_syncDataFromEdgeFunction`** | **124** | **372-495** | Process edge function response ⚠️ |

---

### 4. Client-Side Download (6 methods, avg 25.2 lines)

| Method | Lines | Range | Purpose |
|--------|-------|-------|---------|
| `_clientSideDownload` | 22 | 498-520 | Fallback orchestrator |
| `_downloadFoods` | 18 | 523-539 | Download nutrition foods |
| `_downloadCarbLoadingFoods` | 20 | 542-560 | Download carb foods |
| `_downloadActivities` | 28 | 563-589 | Download activities |
| `_downloadEvents` | 24 | 592-615 | Download events |
| `_downloadCarbLoadingPlans` | 39 | 618-654 | Download plans + days |

---

### 5. Upsert Methods (5 methods, avg 64.4 lines)

| Method | Lines | Range | Purpose |
|--------|-------|-------|---------|
| **`_upsertActivity`** | **66** | **656-721** | Upsert activity |
| **`_upsertEvent`** | **67** | **723-789** | Upsert event |
| **`_upsertCarbLoadingPlan`** | **66** | **791-857** | Upsert carb plan |
| `_upsertCarbLoadingDay` | 53 | 859-912 | Upsert carb day |
| `_syncFoodPreferencesFromEdgeFunction` | 70 | 916-985 | Sync food preferences |

---

### 6. Coach Mode Sync (7 methods, avg 40 lines)

| Method | Lines | Range | Purpose |
|--------|-------|-------|---------|
| `_syncCoachRecord` | 62 | 989-1050 | Sync coach record |
| `_syncCoachAthleteRelationships` | 64 | 1053-1116 | Sync relationships |
| `_syncCoachMessages` | 48 | 1119-1165 | Sync messages |
| `_syncAthleteEvents` | 20 | 1168-1188 | Sync athlete events |
| `_syncAthleteActivities` | 20 | 1191-1210 | Sync athlete activities |
| `_syncAthleteProfiles` | 46 | 1213-1258 | Sync athlete profiles |
| `_syncAthleteCarbLoadingPlans` | 20 | 1261-1281 | Sync athlete carb plans |

---

### 7. Upload Orchestration (2 methods, avg 90.5 lines)

| Method | Lines | Range | Purpose |
|--------|-------|-------|---------|
| **`uploadDirtyRecords`** | **178** | **1287-1464** | Upload via edge function ⚠️⚠️⚠️ |
| `_uploadDirtyRecords` | 3 | 1827-1829 | Deprecated wrapper |

---

### 8. Duplicate Cleaning (3 methods, avg 95.7 lines)

| Method | Lines | Range | Purpose |
|--------|-------|-------|---------|
| **`_cleanDuplicatesFromDrift`** | **67** | **1469-1535** | Clean all duplicates |
| **`_cleanTableDuplicates`** | **110** | **1539-1647** | Clean specific table ⚠️⚠️ |
| **`_cleanUserProfilesDuplicates`** | **110** | **1654-1763** | Clean user duplicates ⚠️⚠️ |

---

### 9. Upload Flag Management (1 method)

| Method | Lines | Range | Purpose |
|--------|-------|-------|---------|
| **`_clearNeedsUploadFlag`** | **60** | **1766-1824** | Clear upload flags |

---

### 10. DEPRECATED Methods (10 methods, avg 35.8 lines)

**Status**: Kept for reference, not called in production

| Method | Lines | Range | Purpose |
|--------|-------|-------|---------|
| `_uploadActivity` | 76 | 1833-1908 | Upload single activity |
| `_rekeyActivityLocally` | 12 | 1910-1921 | Re-key activity FKs |
| `_uploadEvent` | 44 | 1925-1968 | Upload single event |
| `_uploadCarbLoadingPlan` | 53 | 1972-2024 | Upload single plan |
| `_uploadCarbLoadingDay` | 57 | 2028-2084 | Upload single day |
| `_rekeyPlanLocally` | 11 | 2089-2100 | Re-key plan FKs |
| `_rekeyDayLocally` | 11 | 2102-2113 | Re-key day FKs |
| `_uploadUserFoodRow` | 47 | 2245-2291 | Upload user food |
| `_uploadFeedbackRow` | 30 | 2297-2327 | Upload feedback |
| `_uploadFeatureSurveyRow` | 17 | 2331-2347 | Upload survey |

**Recommendation**: Remove after Phase 3 implementation is validated

---

### 11. JSON Conversion (5 methods, avg 23.4 lines)

| Method | Lines | Range | Purpose |
|--------|-------|-------|---------|
| `_activityToJson` | 33 | 2116-2148 | Convert Activity to JSON |
| `_eventToJson` | 28 | 2151-2178 | Convert Event to JSON |
| `_carbLoadingPlanToJson` | 17 | 2181-2197 | Convert Plan to JSON |
| `_featureSurveyToJson` | 17 | 2201-2217 | Convert Survey to JSON |
| `_carbLoadingDayToJson` | 22 | 2220-2241 | Convert Day to JSON |

---

### 12. User Profile Upload (2 methods, avg 43 lines)

| Method | Lines | Range | Purpose |
|--------|-------|-------|---------|
| `_uploadUserProfile` | 50 | 2351-2401 | Upload user profile |
| `_uploadFoodPreferences` | 36 | 2405-2440 | Upload food preferences |

---

### 13. UI Invalidation (1 method)

| Method | Lines | Range | Purpose |
|--------|-------|-------|---------|
| `_invalidateCalendarProviders` | 5 | 2503-2507 | Refresh UI after sync |

---

## Code Duplication Analysis

### Summary Statistics

| Pattern Type | Occurrences | Lines | Priority |
|--------------|-------------|-------|----------|
| DateTime parsing | ~35 | ~140 | HIGH |
| Companion builders | 7 | ~250 | HIGH |
| Error handling | ~20 | ~180 | MEDIUM |
| Entity-to-JSON | 4 | ~100 | MEDIUM |
| Duplicate cleanup | 2 | ~150 | MEDIUM |
| Clear upload flag | 7 | ~60 | LOW |
| Rekeying | 3 | ~40 | LOW |
| Coach sync loops | 3 | ~60 | LOW |

**Total Duplication**: ~980 lines (39% of file)

---

### 1. DateTime Parsing Pattern (HIGH PRIORITY)

**Occurrences**: ~35 times across multiple methods

**Pattern**:
```dart
// Repeated everywhere:
Value(
  data['field_name'] != null
      ? DateTime.parse(data['field_name'] as String)
      : null,
)

// Or:
coachData['created_at'] != null
    ? DateTime.parse(coachData['created_at'] as String)
    : DateTime.now()
```

**Examples**:
- Lines 274-277, 1010-1014, 1016-1020, 1021-1025
- Lines 1067-1070, 1071-1075, 1076-1080, 1081-1085
- Lines 1086-1090, 1091-1095, 1135-1139, 1140-1144

**Recommended Fix**:
```dart
DateTime? parseOptionalDateTime(dynamic value, {DateTime? defaultValue}) {
  if (value == null) return defaultValue;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return defaultValue;
}
```

**Lines Saved**: ~140 lines

---

### 2. Companion Builder Pattern (HIGH PRIORITY)

**Occurrences**: 7 entity types

**Pattern**: Each upsert method follows identical structure:
1. Extract ID from data
2. Query existing record
3. Compare timestamps
4. Build companion object
5. Insert or replace
6. Error handling

**Examples**:
- `_upsertActivity` (lines 674-711): Activity companion
- `_upsertEvent` (lines 745-778): Event companion
- `_upsertCarbLoadingPlan` (lines 808-830): Carb plan companion
- `_upsertCarbLoadingDay` (lines 875-902): Carb day companion
- `_syncCoachRecord` (lines 1001-1030): Coach companion
- `_syncCoachAthleteRelationships` (lines 1060-1101): Relationship companion
- `_syncCoachMessages` (lines 1126-1150): Message companion

**Recommended Fix**: Create generic upsert handler (see Phase 4 in refactoring plan)

**Lines Saved**: ~250 lines

---

### 3. Error Handling Pattern (MEDIUM PRIORITY)

**Occurrences**: ~20 try-catch blocks with identical structure

**Pattern**:
```dart
} catch (e, stackTrace) {
  _logger.error(
    'Failed to upsert [entity]',
    context: '[CONTEXT]',
    error: e,
    stackTrace: stackTrace,
    data: {'[entity]Id': data['id']},
  );
}
```

**Examples**:
- Lines 712-720 (activity error)
- Lines 780-788 (event error)
- Lines 848-856 (carb plan error)
- Lines 903-911 (carb day error)
- Lines 1041-1049 (coach record error)
- Lines 1107-1115 (relationship error)
- Lines 1156-1164 (message error)

**Recommended Fix**:
```dart
Future<T?> withErrorLogging<T>(
  String operation,
  String context,
  Future<T> Function() action,
  {Map<String, dynamic>? metadata}
) async {
  try {
    return await action();
  } catch (e, stackTrace) {
    _logger.error(operation, context: context, error: e, stackTrace: stackTrace, data: metadata);
    return null;
  }
}
```

**Lines Saved**: ~180 lines

---

### 4. Entity-to-JSON Conversion (MEDIUM PRIORITY)

**Occurrences**: 4 entity types

**Pattern**: Manual field mapping for every entity

**Examples**:
- `_activityToJson` (lines 2116-2148): 30 field mappings
- `_eventToJson` (lines 2151-2178): 21 field mappings
- `_carbLoadingPlanToJson` (lines 2181-2197): 14 field mappings
- `_carbLoadingDayToJson` (lines 2220-2241): 17 field mappings

**Recommended Fix**: Extract to `EntityJsonConverter` utility class

**Lines Saved**: ~100 lines

---

### 5. Duplicate Cleanup Logic (MEDIUM PRIORITY)

**Occurrences**: 2 methods with 95% identical code

**Methods**:
- `_cleanTableDuplicates` (lines 1539-1647): Generic table cleanup
- `_cleanUserProfilesDuplicates` (lines 1654-1763): User-specific cleanup

**Pattern**: Both follow identical logic:
1. Find duplicates via GROUP BY COUNT(*)
2. Order by timestamp DESC
3. Keep first record
4. Delete rest by rowid

**Recommended Fix**: Consolidate into single parameterized method

**Lines Saved**: ~150 lines (one method eliminated, other simplified)

---

### 6. Clear Upload Flag Pattern (LOW PRIORITY)

**Occurrences**: 7 table updates in switch statement

**Location**: `_clearNeedsUploadFlag` (lines 1766-1824)

**Pattern**:
```dart
case 'activities':
  await _database.customStatement(
    'UPDATE activities SET needs_upload = 0 WHERE user_id = ? AND needs_upload = 1',
    [userId],
  );
```

**Repeated 7 times** with only table name changing.

**Recommended Fix**: Table-agnostic parameterized method

**Lines Saved**: ~60 lines

---

### 7. Rekeying Pattern (LOW PRIORITY)

**Occurrences**: 3 methods with identical structure

**Examples**:
- `_rekeyActivityLocally` (lines 1910-1921)
- `_rekeyPlanLocally` (lines 2089-2100)
- `_rekeyDayLocally` (lines 2102-2113)

**Pattern**: Transaction-based UPDATE for ID changes

**Recommended Fix**: Generic rekey method

**Lines Saved**: ~40 lines

---

## Dependency Analysis

### Injected Dependencies (7 total)

```dart
final Ref _ref;                                    // Riverpod reference
final SupabaseClient _supabase;                    // Remote database
final AppDatabase _database;                       // Local Drift database
final AppLogger _logger;                           // Logging service
final FoodRepository _foodRepository;              // Nutrition foods
final CarbLoadingFoodSyncService _carbLoadingFoodSyncService;
final CoachRepository _coachRepository;            // ⚠️ UNUSED
```

---

### Dependency Usage Patterns

#### `_ref` (Riverpod Reference) - 6 usages
- Lines 111, 359, 2469: Reading `sharedPreferencesProvider` for last sync timestamp
- Lines 2504-2506: Invalidating calendar providers after sync

**Purpose**: State management and provider access

---

#### `_supabase` (SupabaseClient) - 11 usages
- Line 172: Fetch remote user profile
- Line 230: Upsert user profile to Supabase
- Line 327: Call `sync-all-data` edge function
- Lines 525, 544, 565, 594, 620: Client-side downloads (fallback)
- Line 1404: Call `upload-all-data` edge function
- Lines 2254, 2299, 2333, 2382, 2426: Deprecated uploads

**Purpose**: All remote data operations

---

#### `_database` (AppDatabase) - 100+ usages
- **User operations** (lines 162-284): fetch, save, upsert
- **Activity operations** (lines 661-713): upsert, rekey
- **Event operations** (lines 726-781): upsert with FK validation
- **Carb loading** (lines 794-904): plans/days upsert
- **Food preferences** (lines 959-977): sync from edge function
- **Coach data** (lines 1029-1273): 7 coach-related tables
- **Dirty records** (lines 1299-1456): query records needing upload
- **Duplicate cleanup** (lines 1561-1755): detect and remove duplicates
- **Custom SQL** (80+ instances): transactions, updates, deletes

**Purpose**: ALL local storage operations

---

#### `_logger` (AppLogger) - 40+ usages
- Error handling in all catch blocks
- Warnings for duplicates, missing data, schema issues
- Info logs for successful syncs, record counts

**Purpose**: Observability and debugging

---

#### `_foodRepository` (FoodRepository) - 2 usages
- Line 377: Sync nutrition foods from edge function response
- Line 529: Sync nutrition foods from client-side download

**Purpose**: Delegate food parsing/syncing

---

#### `_carbLoadingFoodSyncService` - 2 usages
- Line 383: Sync carb loading foods from edge function
- Line 548: Sync carb loading foods from client-side download

**Purpose**: Delegate carb loading food parsing/syncing

---

#### `_coachRepository` (CoachRepository) - 0 usages ⚠️

**UNUSED DEPENDENCY** - Injected but never called

**Recommendation**: Either remove or refactor coach sync to use it

---

### Coupling Analysis

#### 🔴 CRITICAL: Monolithic Database Operations
- **Problem**: 100+ direct calls to `_database` scattered across 2,500 lines
- **Impact**: Schema changes require touching this massive file
- **Coupling**: Tightly coupled to table structure, column names, FK relationships

#### 🔴 CRITICAL: Mixed Concerns
- **Example**: `_syncDataFromEdgeFunction()` (lines 372-496)
  - Parses edge function response
  - Syncs 9 different entity types
  - Calls 9 different sync methods
  - 125 lines of orchestration logic
- **Impact**: Can't test individual sync concerns in isolation

#### 🟡 HIGH: Direct SQL Coupling
- 20+ instances of `_database.customStatement()` with raw SQL
- **Examples**:
  - Line 1561: Complex duplicate detection query
  - Lines 1770-1810: Multiple UPDATE statements
  - Line 1912: FK update with raw SQL
- **Impact**: SQL dialect locked to SQLite, can't swap implementations

#### 🟡 HIGH: Edge Function Response Structure
- Methods assume specific JSON structure from edge functions
- No validation or schema versioning
- **Impact**: Breaking changes in edge function require code changes here

#### 🟠 MEDIUM: Calendar Provider Coupling
- Lines 2504-2506: Direct invalidation of calendar providers
- **Problem**: Sync service shouldn't know about UI-layer providers
- **Better**: Emit events that UI layer listens to

---

## Sync Pattern Analysis

### Entities Being Synced

**User Data**:
- `users` (user profiles)
- `food_preferences` (normalized table)

**Activity/Training Data**:
- `activities` (workouts/training)
- `events` (races, competitions)

**Nutrition Data**:
- `foods` (nutrition_foods - reference)
- `carb_loading_foods` (reference)
- `carb_loading_plans`
- `carb_loading_days`
- `user_foods` (custom)

**Feedback/Survey**:
- `feedback`
- `feature_survey_responses`

**Coach Mode**:
- `coaches`
- `coach_athlete_relationships`
- `coach_messages`
- Athlete data: `athlete_events`, `athlete_activities`, `athlete_profiles`, `athlete_carb_loading_plans`

---

### Common Sync Patterns

#### Pattern A: Upsert with Timestamp Check
```dart
// 1. Get existing record
final existing = await (_database.select(table)
  ..where((tbl) => tbl.id.equals(id)))
  .getSingleOrNull();

// 2. Compare timestamps
final remoteTime = DateTime.parse(data['updated_at']);

// 3. Only update if newer or doesn't exist
if (existing == null || existing.updatedAt.isBefore(remoteTime)) {
  final companion = TableCompanion.insert(...);
  await _database.into(table).insert(
    companion,
    mode: InsertMode.insertOrReplace
  );
}
```

**Used for**: Activities, Events, Carb Plans/Days, Coach Records

---

#### Pattern B: Preserve Dirty Records
```dart
// CRITICAL: Never overwrite local changes pending upload
if (existingActivity != null && (existingActivity.needsUpload ?? false)) {
  return; // Keep local version
}
```

**Used in**: `_upsertActivity()` (line 669)
**Purpose**: Prevents data loss by preserving user edits

---

#### Pattern C: Timestamp-Based Sync
```dart
// Use local_updated_at for client tables
final remoteUpdatedAt = DateTime.parse(data['local_updated_at']);
final shouldUpsert = existing == null ||
  (remoteUpdatedAt != null && remoteUpdatedAt.isAfter(existing.localUpdatedAt));
```

**Used for**: Carb loading plans and days

---

### Upload vs Download

#### Upload Flow
1. **Collect dirty records** (`needs_upload = true`)
2. **Convert to JSON** (entity-specific converters)
3. **Call edge function** (`upload-all-data`)
4. **Clear flags** on success

**Implementation**: `uploadDirtyRecords()` (lines 1287-1464)

---

#### Download Flow

**Strategy 1: Edge Function (Preferred)**
- Single call: `sync-all-data`
- Returns all entities in one response
- 30-second timeout
- Implemented in `_tryEdgeFunctionSync()` (lines 325-369)

**Strategy 2: Client-Side Fallback**
- Multiple parallel queries to Supabase
- 2 minutes timeout per call
- Implemented in `_clientSideDownload()` (lines 498-520)

---

### Edge Function vs Client-Side

| Aspect | Edge Function | Client-Side |
|--------|--------------|-------------|
| **Network Calls** | 1 (all data) | 5+ (per entity) |
| **Data Format** | Pre-joined | Raw tables |
| **Timeout** | 30 seconds | 2 min per call |
| **Fallback** | Yes → client-side | No fallback |
| **Performance** | Fast | Slower but reliable |

---

## Natural Refactoring Boundaries

Based on method groupings and dependency usage:

### Group 1: Edge Function Handler (~450 lines)
**Methods**:
- `_tryEdgeFunctionSync` (45 lines)
- `_syncDataFromEdgeFunction` (124 lines)
- All `_sync*` coach methods (7 methods, ~280 lines)

**New Class**: `EdgeFunctionSyncHandler`

---

### Group 2: Duplicate Cleaner (~290 lines)
**Methods**:
- `_cleanDuplicatesFromDrift` (67 lines)
- `_cleanTableDuplicates` (110 lines)
- `_cleanUserProfilesDuplicates` (110 lines)

**New Class**: `DataIntegrityService`

---

### Group 3: Upload Coordinator (~325 lines)
**Methods**:
- `uploadDirtyRecords` (178 lines)
- `_clearNeedsUploadFlag` (60 lines)
- `_uploadUserProfile` (50 lines)
- `_uploadFoodPreferences` (36 lines)

**New Class**: `UploadOrchestratorService`

---

### Group 4: Client Download Handler (~150 lines)
**Methods**:
- `_clientSideDownload` (22 lines)
- `_downloadFoods` (18 lines)
- `_downloadCarbLoadingFoods` (20 lines)
- `_downloadActivities` (28 lines)
- `_downloadEvents` (24 lines)
- `_downloadCarbLoadingPlans` (39 lines)

**New Class**: `ClientSideDownloadHandler`

---

### Group 5: Upsert Handler (~320 lines)
**Methods**:
- `_upsertActivity` (66 lines)
- `_upsertEvent` (67 lines)
- `_upsertCarbLoadingPlan` (66 lines)
- `_upsertCarbLoadingDay` (53 lines)
- `_syncFoodPreferencesFromEdgeFunction` (70 lines)

**New Class**: `LocalDatabaseUpsertHandler`

---

### Group 6: JSON Converter (~115 lines)
**Methods**:
- All 5 `*ToJson` methods

**New Class**: `EntityJsonConverter`

---

### Group 7: User Sync Handler (~155 lines)
**Methods**:
- `syncUsers` (90 lines)
- `_saveRemoteUserProfile` (44 lines)
- `_parseGenderString` (9 lines)
- `_parseGutTrainingString` (13 lines)

**New Class**: `UserProfileSyncService`

---

## Recommendations

### Immediate Actions (Phase 1)
1. Extract duplicate cleaning → `DataIntegrityService`
2. Extract JSON converters → `EntityJsonConverter`
3. Create utilities → `TypeConverters`, `SyncErrorHandler`

**Expected Reduction**: ~795 lines

---

### Medium-Term (Phase 2)
4. Break up entity sync logic into specialized services
5. Extract user profile sync
6. Extract calendar sync (activities/events)
7. Extract carb loading sync
8. Extract coach data sync

**Expected Reduction**: ~1,550 lines

---

### Long-Term (Phase 3)
9. Create upload orchestrator
10. Simplify main `DataSyncService` to orchestration only

**Target**: Main service ~400 lines (down from 2,508)

---

**Target After Full Refactoring**:
- Main service: ~400 lines
- 6-7 extracted services: ~1,650 lines
- 3 utility classes: ~250 lines
- DEPRECATED removal: -360 lines
- **Net result**: More maintainable, testable, clear separation of concerns
