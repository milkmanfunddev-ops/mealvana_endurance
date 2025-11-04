# Unified Sync with Seed Database & Offline-First Architecture - Complete Implementation Roadmap

**Date Started**: 2025-11-04
**Status**: 🟡 Phase 2B In Progress (Step 2B.1 Complete)
**Estimated Duration**: 5-6 days (40-45 hours)
**Priority**: HIGH - Critical for app performance and offline capability
**Current Progress**: 1/11 Phase 2B steps complete (~9%)

---

## Document Purpose & Context

### For Future LLMs / AI Assistants

This document provides a complete implementation roadmap for three critical architectural improvements:

1. **Seed Database Integration** - Bundle food data with app for instant first launch
2. **Unified Sync Consolidation** - Eliminate redundant network calls (3 → 1)
3. **Offline-First Architecture** - Enable full app functionality without network

**Before making any changes, read these files first:**

#### Essential Context Files
1. `/docs/sync_roadmap.md` - Previous roadmap (Phase 2A completed, Phase 2B/2C pending)
2. `/docs/sync-consolidation-summary.md` - What was completed in Phase 2A
3. `CLAUDE.md` - Complete project architecture and patterns
4. `/docs/technical/README.md` - Technical implementation details
5. `/docs/database/drift/README.md` - Drift database architecture

#### Critical Code Files to Understand
1. `lib/features/app_startup/application/app_startup_provider.dart` - App initialization flow
2. `lib/features/app_startup/application/app_startup_service.dart` - Startup operations
3. `lib/shared/services/sync/data_sync_service.dart` - Current sync implementation (Phase 2A)
4. `lib/shared/database/database_provider.dart` - Drift database initialization
5. `lib/features/nutrition_plan/data/food_repository.dart` - Food data management
6. `supabase/functions/sync-all-data/index.ts` - Unified sync edge function

#### Architecture Patterns in Use
- **FOA (Feature-Oriented Architecture)** - Andrea Bizzotto's 4-layer pattern
- **Riverpod 2.x** - State management with `@riverpod` code generation
- **Drift SQLite** - Type-safe local database with migrations
- **Offline-First** - Local data as primary source, Supabase for sync
- **Content Management** - All UI text from `ContentService`, never hardcoded

---

## Executive Summary

### The Problem

The Mealvana Endurance app currently has **three critical architectural issues**:

#### Issue 1: Redundant Network Calls on Startup
```
Current App Startup (3 separate network operations):
├── 1. sync-all-data edge function → Returns 8 data types including foods ✅
├── 2. get-foods edge function → Gets 31 foods (REDUNDANT! Already in #1) ❌
└── 3. Direct Supabase queries → Gets carb loading foods (REDUNDANT! Already in #1) ❌

Result: 66% of network calls are redundant, slowing startup by 2-3 seconds
```

#### Issue 2: No Seed Data (Poor First Launch)
```
Fresh Install Behavior:
├── 1. App launches with empty database
├── 2. User sees "Loading..." for foods
├── 3. Wait 2-5 seconds for network calls to complete
└── 4. Foods finally appear

Result: Poor first impression, broken offline experience
```

#### Issue 3: Not Truly Offline-First (Blocks User Actions)
```
Current Repository Pattern (Supabase-First):
User edits activity →
├── 1. Call save-calendar-activity edge function ❌ (Requires network)
├── 2. If successful → Cache to Drift
├── 3. If failed (offline) → ERROR, nothing saved ❌

Result: App breaks when offline, users cannot edit data without internet
```

### The Solution (This Roadmap)

#### Solution 1: Bundle Seed Database (Instant First Launch)
```dart
Fresh Install with Seed DB:
├── 1. Check if database exists → NO
├── 2. Copy assets/data/app_seed.db → app.db (< 50ms)
├── 3. Database ready with 31 foods + carb loading data
└── 4. App shows UI instantly (no network wait)

Technologies: Drift's native seed DB feature
Time Savings: 2-5 seconds → 50ms (98% faster)
```

#### Solution 2: Eliminate Redundant Calls (Single Network Call)
```dart
New Unified Sync:
└── 1. sync-all-data edge function → Returns everything
    ├── Calendar data (activities, events, carb plans)
    ├── Food data (31 nutrition foods)
    ├── Carb loading data (foods + meal types)
    └── User data (completions, preferences)

Network Calls: 3 → 1 (66% reduction)
Startup Time: 3-5 sec → 0.5-1 sec (75% faster)
```

#### Solution 3: True Offline-First (Full Offline Support)
```dart
New Repository Pattern (Drift-First):
User edits activity →
├── 1. Save to Drift IMMEDIATELY ✅ (Offline-first!)
├── 2. Set needs_upload = true
├── 3. Attempt background upload (non-blocking)
│   ├── If successful → Clear needs_upload flag
│   └── If failed → Keep flag, retry on next sync
└── 4. User sees changes instantly ✅

Result: App works 100% offline, zero data loss
```

### Success Metrics

| Category | Metric | Before | After | Improvement |
|----------|--------|--------|-------|-------------|
| **Performance** | Network calls on startup | 3 calls | 1 call | **66% reduction** |
| | Startup time (fast network) | 3-5 sec | 0.5-1 sec | **75% faster** |
| | First launch time | 2-5 sec wait | 50ms instant | **98% faster** |
| **Reliability** | Offline capability | ❌ Broken | ✅ Full support | **∞ improvement** |
| | Data loss scenarios | ⚠️ Possible | ✅ Zero | **Eliminated** |
| | Edit activity offline | ❌ Error | ✅ Works | **100% success** |
| **User Experience** | First impression | ⏳ Loading | ✨ Instant | **Perfect** |
| | Multi-device sync | ⚠️ Unreliable | ✅ Robust | **Production-ready** |

---

## Scope & Phases

### ✅ Phase 2A: Completed (Previous Work)

**Completed on**: 2025-10-28
**Reference**: `/docs/sync-consolidation-summary.md`

- [x] Created `sync-all-data` edge function (returns 8 data types)
- [x] Created `DataSyncService` orchestration layer
- [x] Added schema columns (`needs_upload`, `local_updated_at`, `user_id` to events)
- [x] Calendar data syncs via `sync-all-data`

**Gap**: Food data still makes redundant separate calls

---

### 🎯 This Roadmap: Phases 2B, 2C, 2D (New Work)

#### Phase 2B: Seed Database + Eliminate Redundant Calls
**Duration**: 2 days (10 hours)
**Status**: 🔴 Not Started

- [ ] Export seed data from Supabase dev environment
- [ ] Create `assets/data/app_seed.db` with Drift schema
- [ ] Integrate seed DB copy into `database_provider.dart`
- [ ] Update `DataSyncService` to handle food data from `sync-all-data`
- [ ] Add `syncFromDownloadedData()` methods to food repositories
- [ ] Remove `checkAndRefreshFoodData()` method (redundant)
- [ ] Update app startup flow to use unified sync only

**Deliverables**:
- Seed database file bundled with app
- Single network call on startup
- Instant first launch experience

#### Phase 2C: Offline-First Repository Refactoring
**Duration**: 2.5 days (20 hours)
**Status**: 🔴 Not Started

- [ ] Refactor `ActivitiesRepository` to Drift-first pattern
- [ ] Refactor `EventsRepository` to Drift-first pattern
- [ ] Refactor `CarbLoadingRepository` to Drift-first pattern
- [ ] Refactor `ActivityCompletionsRepository` to Drift-first pattern
- [ ] Refactor `UserFoodsRepository` to Drift-first pattern
- [ ] Refactor `NutritionPlanRepository` to Drift-first pattern
- [ ] Refactor `MacroTargetsRepository` to Drift-first pattern
- [ ] Update all repository methods (~25 methods total)

**Deliverables**:
- All user data operations work offline
- Zero data loss scenarios
- Immediate UI feedback on all actions

#### Phase 2D: Upload Dirty Records + Testing
**Duration**: 1.5 days (12 hours)
**Status**: 🔴 Not Started

- [ ] Implement `_uploadDirtyRecords()` in `DataSyncService`
- [ ] Add batch upload for activities, events, carb plans
- [ ] Add retry logic for failed uploads
- [ ] Implement background sync worker
- [ ] Add conflict resolution (last-write-wins)
- [ ] Comprehensive testing (unit, integration, manual)
- [ ] Deploy to dev environment
- [ ] Monitor and validate in production

**Deliverables**:
- Automatic upload of offline changes
- Robust retry mechanism
- Production-ready multi-device sync

---

## Architecture Deep Dive

### Current Architecture (BEFORE - Phase 2A Complete)

```
App Startup Flow (app_startup_provider.dart):
├── 1. initializeDatabase() → Drift database ready
├── 2. initializeAnalytics() → Mixpanel/Sentry ready
├── 3. checkUserSession() → Restore user if exists
├── 4. Call DataSyncService.syncAllData() ✅ Phase 2A
│   └── Single call to sync-all-data edge function
│       └── Returns: activities, events, carb plans, completions, foods, carb foods
├── 5. checkAndRefreshFoodData() ❌ REDUNDANT!
│   ├── Call get-foods edge function ❌ (foods already in step 4!)
│   └── Call syncCarbLoadingFoods() ❌ (carb foods already in step 4!)
├── 6. initializeNutritionPlans() → Load cached plans
└── 7. checkForPendingFeedback() → Check for feedback prompts

Issues:
- ❌ Steps 4 and 5 both fetch foods (redundant)
- ❌ 3 total network calls (1 in step 4, 2 in step 5)
- ❌ No seed data = slow first launch
- ❌ Food repositories ignore data from step 4

Repository Pattern (Supabase-First):
User Action → Repository Method
├── 1. Call Supabase edge function FIRST ❌
├── 2. If success → Cache to Drift
├── 3. If fail → ERROR ❌
└── Result: Broken offline, potential data loss
```

### Target Architecture (AFTER - All Phases Complete)

```
Fresh Install Flow:
├── 1. initializeDatabase()
│   ├── Check if app.db exists → NO
│   ├── Copy assets/data/app_seed.db → app.db (< 50ms) ✨
│   └── Database ready with 31 foods + carb loading data
├── 2. initializeAnalytics()
├── 3. checkUserSession() → No user yet (fresh install)
├── 4. syncAllAppData() → Single network call ✅
│   └── Call sync-all-data edge function
│       ├── Calendar data → Merge into Drift
│       ├── Food data → Merge into Drift (updates seed data)
│       └── Carb loading → Merge into Drift (updates seed data)
├── 5. initializeNutritionPlans()
└── 6. checkForPendingFeedback()

Total Network Calls: 1 (sync-all-data only)
First Launch Time: Instant (seed DB) + background sync
Offline Support: ✅ Full (seed data available)

Existing User Flow:
├── 1. initializeDatabase() → Exists with user data ✅
├── 2-3. Analytics, session
├── 4. syncAllAppData() → Updates from server ✅
│   ├── Download: sync-all-data edge function
│   ├── Merge: Update local Drift database
│   └── Upload: Push dirty records to Supabase ✨ Phase 2D
├── 5-6. Plans, feedback
└── Total: 1 network call, uses cached data instantly

Repository Pattern (Drift-First):
User Action → Repository Method
├── 1. Save to Drift IMMEDIATELY ✅ (Offline-first!)
├── 2. Set needs_upload = true, local_updated_at = now()
├── 3. Attempt background upload (non-blocking) ✨ Phase 2C
│   ├── Call edge function in background
│   ├── If success → Clear needs_upload flag
│   └── If fail → Keep flag, will retry on next sync
└── Result: ✅ Works offline, zero data loss, instant feedback
```

---

## Implementation Plan

### Phase 2B: Seed Database + Eliminate Redundant Calls (2 days)

**Objective**: Bundle food data with app, eliminate redundant network calls

**Status**: 🔴 Not Started

---

#### Step 2B.1: Export Seed Data from Supabase (1 hour)

**Goal**: Create `app_seed.db` file with all food data from dev environment

**Checklist**:
- [ ] Set Supabase environment to dev
- [ ] Export schema DDL (structure only)
- [ ] Export seed data (foods, categories, carb loading)
- [ ] Create local SQLite database file
- [ ] Import schema and data
- [ ] Verify data integrity (row counts)
- [ ] Optimize database (VACUUM)
- [ ] Confirm file size < 1MB

**Commands**:
```bash
# Navigate to project root
cd /Users/leemartin/development/mealvana_endurance

# Create assets/data directory if it doesn't exist
mkdir -p assets/data

# Export schema (structure only - all tables)
supabase db dump --schema public --data-only=false > supabase/temp_seed_schema.sql

# Export seed data (specific tables only)
supabase db dump \
  --data-only \
  --table foods \
  --table categories \
  --table food_categories \
  --table product_types \
  --table carb_loading_foods \
  --table meal_types \
  --table carb_loading_food_meal_types \
  > supabase/temp_seed_data.sql

# Create empty SQLite database
rm -f assets/data/app_seed.db  # Remove if exists
sqlite3 assets/data/app_seed.db ""

# Import schema first
sqlite3 assets/data/app_seed.db < supabase/temp_seed_schema.sql

# Import seed data
sqlite3 assets/data/app_seed.db < supabase/temp_seed_data.sql

# Verify data loaded correctly
echo "=== Verifying Seed Data ==="
sqlite3 assets/data/app_seed.db "SELECT COUNT(*) as food_count FROM foods;"
# Expected: 31 foods

sqlite3 assets/data/app_seed.db "SELECT COUNT(*) as carb_food_count FROM carb_loading_foods;"
# Expected: 50+ carb loading foods

sqlite3 assets/data/app_seed.db "SELECT COUNT(*) as category_count FROM categories;"
# Expected: 3-5 categories

sqlite3 assets/data/app_seed.db "SELECT COUNT(*) as food_category_count FROM food_categories;"
# Expected: Matching food-category relationships

sqlite3 assets/data/app_seed.db "SELECT COUNT(*) as meal_type_count FROM meal_types;"
# Expected: 6-8 meal types

sqlite3 assets/data/app_seed.db "SELECT COUNT(*) as food_meal_type_count FROM carb_loading_food_meal_types;"
# Expected: Many-to-many relationships

# Optimize database (reduce file size)
sqlite3 assets/data/app_seed.db "VACUUM;"

# Check final file size
ls -lh assets/data/app_seed.db
# Expected: < 1MB

# Clean up temporary SQL files
rm supabase/temp_seed_schema.sql
rm supabase/temp_seed_data.sql

echo "✅ Seed database created: assets/data/app_seed.db"
```

**Validation**:
```bash
# Optional: Inspect seed database tables
sqlite3 assets/data/app_seed.db

# Inside SQLite prompt:
.tables
# Should see: foods, categories, food_categories, carb_loading_foods, etc.

.schema foods
# Should match Drift schema structure

SELECT name FROM foods LIMIT 5;
# Should see: Banana, Energy Gel, Sports Drink, etc.

.quit
```

**Notes**:
- Use `supabase link` to ensure connected to dev project
- Verify with `supabase projects list` before exporting
- Schema must match Drift schema exactly (columns, types, constraints)
- Seed DB contains NO user-specific data (users, preferences, plans)

---

#### Step 2B.2: Update `pubspec.yaml` (5 minutes)

**Goal**: Include seed database in app bundle

**File**: `pubspec.yaml`

**Changes**:
```yaml
flutter:
  uses-material-design: true

  assets:
    # Existing assets
    - assets/config/
    - assets/fonts/
    - assets/icons/
    - assets/images/
    - assets/videos/

    # NEW: Seed database
    - assets/data/app_seed.db
```

**Checklist**:
- [ ] Add `assets/data/app_seed.db` to assets list
- [ ] Run `flutter clean`
- [ ] Run `flutter pub get`
- [ ] Verify asset bundled: `flutter build apk --debug` (check bundle size)

---

#### Step 2B.3: Integrate Seed DB into Drift Initialization (1 hour)

**Goal**: Copy seed DB on first launch, handle migrations intelligently

**File**: `lib/shared/database/database_provider.dart`

**Current Implementation**:
```dart
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(join(dbFolder.path, 'app.db'));

    return NativeDatabase.createInBackground(file);
  });
}
```

**New Implementation**:
```dart
import 'package:flutter/services.dart' show rootBundle;
import 'dart:typed_data';

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(join(dbFolder.path, 'app.db'));

    // Check if database file exists
    final dbExists = await file.exists();

    if (!dbExists) {
      // Fresh install - copy seed database
      try {
        _logger.info(
          'Fresh install detected - copying seed database',
          context: 'DATABASE_INIT',
        );

        // Load seed database from assets
        final ByteData seedData = await rootBundle.load('assets/data/app_seed.db');
        final Uint8List bytes = seedData.buffer.asUint8List();

        // Ensure directory exists
        await file.parent.create(recursive: true);

        // Write seed database to app data directory
        await file.writeAsBytes(bytes, flush: true);

        _logger.info(
          'Seed database copied successfully',
          context: 'DATABASE_INIT',
          data: {
            'fileSizeBytes': bytes.length,
            'path': file.path,
          },
        );
      } catch (e, stackTrace) {
        _logger.error(
          'Failed to copy seed database - will create empty database',
          context: 'DATABASE_INIT',
          error: e,
          stackTrace: stackTrace,
        );

        // Don't rethrow - migrations will create empty schema
        // This ensures app doesn't crash if seed DB is corrupted
      }
    }

    return NativeDatabase.createInBackground(file);
  });
}
```

**Checklist**:
- [ ] Add imports for `rootBundle`, `ByteData`, `Uint8List`
- [ ] Add seed DB copy logic before `NativeDatabase.createInBackground()`
- [ ] Add error handling with logging
- [ ] Ensure directory creation with `file.parent.create(recursive: true)`
- [ ] Test on fresh install (delete app data first)

---

#### Step 2B.4: Update Migration Strategy for V2+ (1 hour)

**Goal**: Handle seed DB for fresh installs, intelligent migrations for existing users

**File**: `lib/shared/database/app_database.dart`

**Current Implementation**:
```dart
@override
int get schemaVersion => 1;

@override
MigrationStrategy get migration {
  return MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
  );
}
```

**New Implementation**:
```dart
@override
int get schemaVersion => 1; // Will become 2 when schema changes

@override
MigrationStrategy get migration {
  return MigrationStrategy(
    // Called when database is first created
    onCreate: (Migrator m) async {
      // This only runs if seed DB copy failed
      // Seed DB already has schema, so this is a fallback
      await m.createAll();

      _logger.warning(
        'Database created without seed data (seed DB copy failed)',
        context: 'DATABASE_MIGRATION',
      );
    },

    // Called immediately after database is opened
    beforeOpen: (OpeningDetails details) async {
      // Enable foreign keys (required for Drift)
      await customStatement('PRAGMA foreign_keys = ON');

      if (details.wasCreated) {
        // Database just created from seed file
        // Verify seed data loaded
        final foodCount = await (select(foodsTable).get()).then((rows) => rows.length);
        final carbFoodCount = await (select(carbLoadingFoodsTable).get()).then((rows) => rows.length);

        if (foodCount > 0) {
          _logger.info(
            'Seed database loaded successfully',
            context: 'DATABASE_MIGRATION',
            data: {
              'foods': foodCount,
              'carb_loading_foods': carbFoodCount,
            },
          );
        } else {
          _logger.warning(
            'Seed database is empty - may need fallback sync',
            context: 'DATABASE_MIGRATION',
          );
        }
      } else {
        // Existing database opened
        _logger.debug(
          'Existing database opened',
          context: 'DATABASE_MIGRATION',
          data: {'versionBefore': details.versionBefore, 'versionNow': details.versionNow},
        );
      }
    },

    // Called when upgrading from older version
    onUpgrade: (Migrator m, int from, int to) async {
      _logger.info(
        'Migrating database',
        context: 'DATABASE_MIGRATION',
        data: {'from': from, 'to': to},
      );

      // V1 → V2 migration (future)
      if (from == 1 && to == 2) {
        // Strategy: Let Drift handle schema changes automatically
        // Drift will:
        // 1. Detect new columns → ALTER TABLE ADD COLUMN
        // 2. Detect new tables → CREATE TABLE
        // 3. Detect dropped columns → Create new table, copy data, drop old

        // For new TABLES only: We may need to seed them
        // Example:
        // await m.createTable($WorkoutTemplatesTable);
        // await _seedWorkoutTemplates(); // Seed new table

        // For new COLUMNS: Drift handles with ALTER TABLE automatically
        // For changed COLUMNS: Drift recreates table automatically

        _logger.info(
          'Migration V1→V2 completed',
          context: 'DATABASE_MIGRATION',
        );
      }

      // V2 → V3 migration (future)
      if (from == 2 && to == 3) {
        // Handle future migrations
      }
    },
  );
}

// Helper method for seeding new tables in future migrations
Future<void> _seedNewTable(String tableName, List<Map<String, dynamic>> data) async {
  try {
    _logger.info(
      'Seeding new table for migration',
      context: 'DATABASE_MIGRATION',
      data: {'table': tableName, 'rows': data.length},
    );

    // Implementation depends on table structure
    // This is a template for future use

  } catch (e, stackTrace) {
    _logger.error(
      'Failed to seed new table',
      context: 'DATABASE_MIGRATION',
      data: {'table': tableName},
      error: e,
      stackTrace: stackTrace,
    );
    rethrow;
  }
}
```

**Migration Philosophy**:

1. **Fresh Installs (V1)**:
   - Seed DB copied → Already has V1 schema + data
   - `onCreate` not called (database file exists)
   - `beforeOpen` verifies seed data loaded

2. **Existing Users (V1 → V2)**:
   - Existing database file with V1 schema + user data
   - Drift's `Migrator` detects schema changes automatically:
     - New columns → `ALTER TABLE ADD COLUMN`
     - New tables → `CREATE TABLE` (then we seed if needed)
     - Changed columns → Recreate table, copy data
   - We only manually seed NEW TABLES that need default data
   - Existing data (user's activities, plans) is preserved

3. **Schema Change Examples**:
   ```dart
   // Example V2 Schema Changes:

   // New column (Drift handles automatically):
   TextColumn get newField => text().nullable()();

   // New table (we seed manually):
   @DataClassName('WorkoutTemplate')
   class WorkoutTemplatesTable extends Table {
     // ...
   }

   // In onUpgrade(1 → 2):
   await m.createTable($WorkoutTemplatesTable);
   await _seedWorkoutTemplates(); // Only seed new table
   ```

**Checklist**:
- [ ] Update `onCreate` with fallback logging
- [ ] Add `beforeOpen` to verify seed data
- [ ] Add `onUpgrade` structure for V1→V2
- [ ] Add `_seedNewTable` helper for future use
- [ ] Enable foreign keys in `beforeOpen`
- [ ] Test fresh install (seed DB loads)
- [ ] Test with corrupted seed DB (onCreate fallback)

---

#### Step 2B.5: Update `DataSyncService` to Handle Food Data (1.5 hours)

**Goal**: Integrate food syncing into unified sync, eliminate redundant calls

**File**: `lib/shared/services/sync/data_sync_service.dart`

**Current Implementation** (lines 9-40):
```dart
@riverpod
DataSyncService dataSyncService(Ref ref) {
  return DataSyncService(
    supabase: Supabase.instance.client,
    database: ref.read(appDatabaseProvider),
    logger: ref.read(appLoggerProvider),
    calendarSyncService: ref.read(calendarSyncServiceProvider),
  );
}

/// Note: Only syncs calendar data
/// Food syncing is handled by app startup service via checkAndRefreshFoodData()
class DataSyncService {
  const DataSyncService({
    required SupabaseClient supabase,
    required AppDatabase database,
    required AppLogger logger,
    required CalendarSyncService calendarSyncService,
  })
```

**New Implementation**:
```dart
import '../../features/nutrition_plan/data/food_repository.dart';
import '../../features/carb_loading/application/carb_loading_food_sync_service.dart';

@riverpod
DataSyncService dataSyncService(Ref ref) {
  return DataSyncService(
    supabase: Supabase.instance.client,
    database: ref.read(appDatabaseProvider),
    logger: ref.read(appLoggerProvider),
    calendarSyncService: ref.read(calendarSyncServiceProvider),
    foodRepository: ref.read(foodRepositoryProvider),
    carbLoadingFoodSyncService: ref.read(carbLoadingFoodSyncServiceProvider),
  );
}

/// Unified data sync service - single network call to sync-all-data
/// Syncs ALL app data: calendar, foods, carb loading
class DataSyncService {
  const DataSyncService({
    required SupabaseClient supabase,
    required AppDatabase database,
    required AppLogger logger,
    required CalendarSyncService calendarSyncService,
    required FoodRepository foodRepository,
    required CarbLoadingFoodSyncService carbLoadingFoodSyncService,
  })  : _supabase = supabase,
        _database = database,
        _logger = logger,
        _calendarSyncService = calendarSyncService,
        _foodRepository = foodRepository,
        _carbLoadingFoodSyncService = carbLoadingFoodSyncService;

  final SupabaseClient _supabase;
  final AppDatabase _database;
  final AppLogger _logger;
  final CalendarSyncService _calendarSyncService;
  final FoodRepository _foodRepository;
  final CarbLoadingFoodSyncService _carbLoadingFoodSyncService;
```

**Update `_mergeDownloadedData` method** (around line 94):
```dart
/// Merge downloaded data into local Drift database
Future<void> _mergeDownloadedData(Map<String, dynamic> data) async {
  try {
    _logger.debug('Merging downloaded data into Drift', context: 'DATA_SYNC');

    // Run all merges in parallel for maximum speed
    await Future.wait([
      // Calendar data (activities, events, carb loading plans/days, completions)
      _calendarSyncService.syncFromDownloadedData(
        activities: data['activities'] as List<dynamic>,
        events: data['events'] as List<dynamic>,
        carbLoadingPlans: data['carb_loading_plans'] as List<dynamic>,
        carbLoadingDays: data['carb_loading_days'] as List<dynamic>,
        activityCompletions: data['activity_completions'] as List<dynamic>,
      ),

      // Nutrition plan foods (from sync-all-data, updates seed data)
      _foodRepository.syncFromDownloadedData(
        foods: data['nutrition_foods'] as List<dynamic>,
      ),

      // Carb loading foods and meal types (from sync-all-data, updates seed data)
      _carbLoadingFoodSyncService.syncFromDownloadedData(
        carbLoadingFoods: data['carb_loading_foods'] as List<dynamic>,
        mealTypes: data['meal_types'] as List<dynamic>,
      ),
    ]);

    _logger.debug('Successfully merged all data', context: 'DATA_SYNC');
  } catch (e, stackTrace) {
    _logger.error(
      'Failed to merge downloaded data',
      context: 'DATA_SYNC',
      error: e,
      stackTrace: stackTrace,
    );
    rethrow;
  }
}
```

**Checklist**:
- [ ] Add imports for `FoodRepository`, `CarbLoadingFoodSyncService`
- [ ] Add food repositories to constructor parameters
- [ ] Update provider to inject food repositories
- [ ] Add food sync calls to `_mergeDownloadedData()`
- [ ] Run in parallel with calendar sync for speed
- [ ] Update docstrings to reflect "syncs ALL data"
- [ ] Run `dart run build_runner build --delete-conflicting-outputs`

---

#### Step 2B.6: Add `syncFromDownloadedData()` to `FoodRepository` (30 minutes)

**Goal**: Accept food data from `sync-all-data` response, no separate edge function call

**File**: `lib/features/nutrition_plan/data/food_repository.dart`

**Add new method** (after line 763):
```dart
/// Sync nutrition foods from pre-downloaded data (from sync-all-data edge function)
/// This method is called during app startup after sync-all-data returns
/// Updates seed database with latest food data from server
Future<void> syncFromDownloadedData({
  required List<dynamic> foods,
}) async {
  try {
    _logger.info(
      'Syncing nutrition foods from downloaded data',
      context: 'FOOD_REPOSITORY',
      data: {'count': foods.length},
    );

    // Reuse existing sync logic that clears and repopulates foods table
    await _syncFoodsToLocalDatabase(foods);

    _logger.info(
      'Nutrition foods sync completed',
      context: 'FOOD_REPOSITORY',
      data: {'count': foods.length},
    );
  } catch (e, stackTrace) {
    _logger.error(
      'Nutrition foods sync failed',
      context: 'FOOD_REPOSITORY',
      error: e,
      stackTrace: stackTrace,
    );
    rethrow;
  }
}
```

**Notes**:
- Reuses existing `_syncFoodsToLocalDatabase()` method (line 678)
- That method already clears foods table and inserts new data
- Updates seed data with latest from server
- Handles join tables (food_categories) if needed

**Checklist**:
- [ ] Add `syncFromDownloadedData()` method
- [ ] Verify it calls existing `_syncFoodsToLocalDatabase()`
- [ ] Add logging for sync start/complete/error
- [ ] No changes needed to existing `getAllFoods()` method (keep for fallback)

---

#### Step 2B.7: Add `syncFromDownloadedData()` to `CarbLoadingFoodSyncService` (30 minutes)

**Goal**: Accept carb loading data from `sync-all-data` response

**File**: `lib/features/carb_loading/application/carb_loading_food_sync_service.dart`

**Add new method**:
```dart
/// Sync carb loading foods from pre-downloaded data (from sync-all-data edge function)
/// This method is called during app startup after sync-all-data returns
/// Updates seed database with latest carb loading foods and meal types
Future<void> syncFromDownloadedData({
  required List<dynamic> carbLoadingFoods,
  required List<dynamic> mealTypes,
}) async {
  try {
    _logger.info(
      'Syncing carb loading foods from downloaded data',
      context: 'CARB_LOADING_SYNC',
      data: {
        'carb_foods': carbLoadingFoods.length,
        'meal_types': mealTypes.length,
      },
    );

    // Sync meal types first (they're referenced by foods)
    for (final mealTypeData in mealTypes) {
      await _upsertMealType(mealTypeData as Map<String, dynamic>);
    }

    // Sync carb loading foods with their meal type relationships
    for (final foodData in carbLoadingFoods) {
      await _upsertCarbLoadingFood(foodData as Map<String, dynamic>);
    }

    _logger.info(
      'Carb loading foods sync completed',
      context: 'CARB_LOADING_SYNC',
    );
  } catch (e, stackTrace) {
    _logger.error(
      'Carb loading foods sync failed',
      context: 'CARB_LOADING_SYNC',
      error: e,
      stackTrace: stackTrace,
    );
    rethrow;
  }
}

/// Helper: Upsert meal type into local database
Future<void> _upsertMealType(Map<String, dynamic> data) async {
  final companion = MealTypesTableCompanion.insert(
    id: data['id'] as String,
    name: data['name'] as String,
    displayName: Value(data['display_name'] as String?),
    sortOrder: Value(data['sort_order'] as int?),
  );

  await _database.into(_database.mealTypesTable)
      .insert(companion, mode: InsertMode.insertOrReplace);
}

/// Helper: Upsert carb loading food into local database
Future<void> _upsertCarbLoadingFood(Map<String, dynamic> data) async {
  final companion = CarbLoadingFoodsTableCompanion.insert(
    id: data['id'] as String,
    name: data['name'] as String,
    displayName: Value(data['display_name'] as String?),
    carbsPerServing: (data['carbs_per_serving'] as num).toDouble(),
    servingSize: Value(data['serving_size'] as String?),
    servingAmount: Value((data['serving_amount'] as num?)?.toDouble()),
    imageUrl: Value(data['image_url'] as String?),
    proteinPerServing: Value((data['protein_per_serving'] as num?)?.toDouble()),
    fatPerServing: Value((data['fat_per_serving'] as num?)?.toDouble()),
    caloriesPerServing: Value(data['calories_per_serving'] as int?),
    // Add other fields as needed
  );

  await _database.into(_database.carbLoadingFoodsTable)
      .insert(companion, mode: InsertMode.insertOrReplace);

  // Handle meal type relationships if included in response
  if (data['carb_loading_food_meal_types'] != null) {
    final mealTypeRelationships = data['carb_loading_food_meal_types'] as List<dynamic>;
    for (final relationship in mealTypeRelationships) {
      await _upsertFoodMealTypeRelationship(
        data['id'] as String,
        relationship as Map<String, dynamic>,
      );
    }
  }
}

/// Helper: Upsert food-meal type relationship
Future<void> _upsertFoodMealTypeRelationship(
  String foodId,
  Map<String, dynamic> data,
) async {
  final companion = CarbLoadingFoodMealTypesTableCompanion.insert(
    foodId: foodId,
    mealTypeId: data['meal_type_id'] as String,
  );

  await _database.into(_database.carbLoadingFoodMealTypesTable)
      .insert(companion, mode: InsertMode.insertOrReplace);
}
```

**Checklist**:
- [ ] Add `syncFromDownloadedData()` method
- [ ] Add helper methods `_upsertMealType()`, `_upsertCarbLoadingFood()`, `_upsertFoodMealTypeRelationship()`
- [ ] Handle join table relationships (food_meal_types)
- [ ] Add logging for sync progress
- [ ] Test with actual sync-all-data response structure

---

#### Step 2B.8: Update `AppStartupService` - Add `syncAllAppData()`, Remove Redundant Method (1 hour)

**Goal**: Single unified sync method, remove redundant food sync

**File**: `lib/features/app_startup/application/app_startup_service.dart`

**Changes**:

1. **Add Import**:
```dart
import '../../../shared/services/sync/data_sync_service.dart';
```

2. **DELETE `checkAndRefreshFoodData()` method** (lines 162-184):
```dart
// DELETE THIS ENTIRE METHOD - IT'S REDUNDANT
/// Check if food data needs refreshing and refresh if necessary
/// Always pull and cache the latest food data from Supabase on app initialization
Future<void> checkAndRefreshFoodData() async {
  // ... DELETE ALL THIS CODE ...
}
```

3. **REMOVE Unused Imports**:
```dart
// DELETE these - no longer needed
import '../../nutrition_plan/data/food_repository.dart';
import '../../carb_loading/application/carb_loading_food_sync_service.dart';
```

4. **ADD New Method** `syncAllAppData()`:
```dart
/// Unified data sync - single network call to sync-all-data edge function
/// Syncs ALL app data: calendar, foods, carb loading foods, meal types
/// Returns true if sync was successful, false otherwise
/// Non-blocking: app continues with cached data if sync fails
Future<bool> syncAllAppData() async {
  try {
    final database = ref.read(appDatabaseProvider);

    // Get current user (required for sync-all-data edge function)
    final user = await database.getCurrentUserProfile();

    if (user == null) {
      _logger.info(
        'No user profile found - skipping sync (fresh install before onboarding)',
        context: 'APP_STARTUP',
      );
      // This is normal on fresh install before onboarding
      // Seed data is already available
      return true;
    }

    _logger.info(
      'Starting unified data sync',
      context: 'APP_STARTUP',
      data: {'userId': user.id},
    );

    // Call unified sync service - single network call
    final dataSyncService = ref.read(dataSyncServiceProvider);
    final success = await dataSyncService.syncAllData(user.id);

    if (success) {
      _logger.info(
        'Unified data sync completed successfully',
        context: 'APP_STARTUP',
      );
    } else {
      _logger.warning(
        'Unified data sync failed - app continuing with cached/seed data',
        context: 'APP_STARTUP',
      );
    }

    return success;
  } catch (e, stackTrace) {
    _logger.error(
      'Unified data sync error',
      context: 'APP_STARTUP',
      error: e,
      stackTrace: stackTrace,
    );
    return false;
  }
}
```

5. **ADD Fallback Method** (emergency use only):
```dart
/// Emergency fallback: Load foods if local database is empty AND sync failed
/// This should rarely be called - only if seed DB copy failed AND sync failed
/// Uses get-foods edge function as last resort
Future<void> _fallbackLoadFoods() async {
  try {
    final database = ref.read(appDatabaseProvider);

    // Check if foods table is empty
    final foodCount = await database.select(database.foodsTable).get().then((rows) => rows.length);

    if (foodCount == 0) {
      _logger.warning(
        'Foods table is empty - attempting fallback load',
        context: 'FOOD_DATA_FALLBACK',
      );

      // Last resort: call get-foods edge function directly
      final foodRepository = ref.read(foodRepositoryProvider);
      await foodRepository.getAllFoods();

      _logger.info(
        'Fallback food load completed',
        context: 'FOOD_DATA_FALLBACK',
      );
    }
  } catch (e, stackTrace) {
    _logger.error(
      'Fallback food load failed - app will continue with no foods',
      context: 'FOOD_DATA_FALLBACK',
      error: e,
      stackTrace: stackTrace,
    );
    // Don't rethrow - app should continue even if fallback fails
  }
}
```

**Checklist**:
- [ ] Add `syncAllAppData()` method
- [ ] Add `_fallbackLoadFoods()` method
- [ ] Delete `checkAndRefreshFoodData()` method
- [ ] Remove unused imports
- [ ] Add import for `DataSyncService`
- [ ] Test that app startup still works

---

#### Step 2B.9: Update `AppStartupProvider` - Use Unified Sync (30 minutes)

**Goal**: Call unified sync only, add fallback for catastrophic failure

**File**: `lib/features/app_startup/application/app_startup_provider.dart`

**Current Implementation** (lines 44-51):
```dart
// 4. Check and restore user session if exists
await startupService.checkUserSession();

// 5. Check and refresh food data if needed (for updated image URLs)
await startupService.checkAndRefreshFoodData();

// 6. Initialize nutrition plans (now using Drift)
await startupService.initializeNutritionPlans();
```

**New Implementation**:
```dart
// 4. Check and restore user session if exists
await startupService.checkUserSession();

// 5. Unified data sync (single network call - calendar + foods + carb loading)
// Note: Foods already loaded from seed DB on first launch, this updates them
final syncSuccess = await startupService.syncAllAppData();

// 6. Initialize nutrition plans (now using Drift)
await startupService.initializeNutritionPlans();

// 7. Fallback: If sync failed AND foods table is empty, try get-foods edge function
// This should rarely happen - only if seed DB copy failed AND sync failed
if (!syncSuccess) {
  await startupService._fallbackLoadFoods();
}
```

**Wait, `_fallbackLoadFoods()` is private!** Fix:

**In `app_startup_service.dart`**, change:
```dart
Future<void> _fallbackLoadFoods() async {
```

To:
```dart
Future<void> fallbackLoadFoods() async {
```

**Then in `app_startup_provider.dart`**:
```dart
// 7. Fallback: If sync failed AND foods table is empty, try get-foods edge function
if (!syncSuccess) {
  await startupService.fallbackLoadFoods();
}
```

**Checklist**:
- [ ] Replace `checkAndRefreshFoodData()` with `syncAllAppData()`
- [ ] Add fallback call after sync
- [ ] Make `fallbackLoadFoods()` public in `AppStartupService`
- [ ] Update comments to reflect single network call
- [ ] Test fresh install flow
- [ ] Test existing user flow
- [ ] Test fallback scenario (simulate seed DB + sync failure)

---

#### Step 2B.10: Verify `sync-all-data` Edge Function Response (15 minutes)

**Goal**: Ensure edge function returns correct data structure

**File**: `supabase/functions/sync-all-data/index.ts`

**Verify these sections**:

1. **Foods Query** (lines 48-55):
```typescript
// Verify this returns foods (not "nutrition_foods" in response)
supabaseClient
  .from('foods')
  .select('*')
  .order('name', { ascending: true }),
```

2. **Response Structure** (lines 131-139):
```typescript
// Verify response keys match what DataSyncService expects
response.data.nutrition_foods = ...  // Used in _mergeDownloadedData()
response.data.carb_loading_foods = ...
response.data.meal_types = ...
```

**If keys don't match**, update either:
- Edge function response keys, OR
- `DataSyncService._mergeDownloadedData()` to use correct keys

**Checklist**:
- [ ] Review `sync-all-data` edge function code
- [ ] Verify response includes `nutrition_foods` (or `foods`)
- [ ] Verify response includes `carb_loading_foods`
- [ ] Verify response includes `meal_types`
- [ ] Test edge function locally if possible
- [ ] Update `DataSyncService` if keys don't match

---

#### Step 2B.11: Testing Phase 2B (2 hours)

**Goal**: Comprehensive testing of seed DB + unified sync

**Test Scenarios**:

**Test 1: Fresh Install (Seed DB Success)**
```bash
# Delete app from simulator
# Run app
flutter run

# Expected Behavior:
# 1. "Fresh install detected - copying seed database"
# 2. "Seed database copied successfully"
# 3. "Seed database loaded successfully" (31 foods, 50+ carb foods)
# 4. App shows foods instantly (no loading)
# 5. Single "sync-all-data" call in background
# 6. NO "get-foods" calls
# 7. NO separate carb loading queries
```

**Validation**:
```dart
// Check logs for:
// - "Fresh install detected"
// - "Seed database copied"
// - "Seed database loaded successfully"
// - "Starting unified data sync"
// - "Syncing nutrition foods from downloaded data"
// - "Syncing carb loading foods from downloaded data"

// Check network calls (Charles Proxy or Flutter DevTools):
// - Only 1 call: sync-all-data ✅
// - NO get-foods call ✅
// - NO direct Supabase queries for foods/carb_loading_foods ✅
```

**Test 2: Existing User (Subsequent Launch)**
```bash
# Restart app (don't delete)
flutter run

# Expected Behavior:
# 1. "Existing database opened"
# 2. Single "sync-all-data" call
# 3. Foods update from server
# 4. NO seed DB copy
# 5. NO redundant calls
```

**Test 3: Offline Fresh Install**
```bash
# Enable airplane mode
# Delete app
# Run app

# Expected Behavior:
# 1. Seed DB copies successfully
# 2. Foods visible instantly
# 3. "sync-all-data" fails (no network)
# 4. App continues with seed data
# 5. NO errors shown to user
```

**Test 4: Catastrophic Failure (Rare)**
```bash
# Corrupt seed DB asset (simulate failure)
# Enable airplane mode
# Delete app, run

# Expected Behavior:
# 1. "Failed to copy seed database"
# 2. Database created empty
# 3. sync-all-data fails (no network)
# 4. "Foods table is empty - attempting fallback load"
# 5. Disable airplane mode → fallback calls get-foods
# 6. Foods eventually load
```

**Test 5: Performance Validation**
```bash
# Measure startup time

# Before (with redundant calls):
# - 3-5 seconds to foods visible

# After (with seed DB):
# - < 50ms to foods visible (98% faster)

# Use Flutter DevTools Performance tab
# Profile mode: flutter run --profile
```

**Test 6: Data Integrity**
```bash
# Fresh install → verify seed data
sqlite3 <path_to_app_data>/app.db

SELECT COUNT(*) FROM foods;
# Expected: 31

SELECT COUNT(*) FROM carb_loading_foods;
# Expected: 50+

SELECT COUNT(*) FROM categories;
# Expected: 3-5

# After sync → verify updates
# Foods count may change if server has more data
```

**Checklist**:
- [ ] Test 1: Fresh install with seed DB
- [ ] Test 2: Existing user launch
- [ ] Test 3: Offline fresh install
- [ ] Test 4: Catastrophic failure fallback
- [ ] Test 5: Performance measurement
- [ ] Test 6: Data integrity verification
- [ ] Document any issues found
- [ ] Fix issues before proceeding to Phase 2C

---

**Phase 2B Complete Checklist**:
- [x] Step 2B.1: Export seed data (1 hour) - ✅ **COMPLETED 2025-11-04**
- [ ] Step 2B.2: Update pubspec.yaml (5 min) - 🔵 **IN PROGRESS**
- [ ] Step 2B.3: Integrate seed DB copy (1 hour)
- [ ] Step 2B.4: Update migration strategy (1 hour)
- [ ] Step 2B.5: Update DataSyncService (1.5 hours)
- [ ] Step 2B.6: Add syncFromDownloadedData to FoodRepository (30 min)
- [ ] Step 2B.7: Add syncFromDownloadedData to CarbLoadingFoodSyncService (30 min)
- [ ] Step 2B.8: Update AppStartupService (1 hour)
- [ ] Step 2B.9: Update AppStartupProvider (30 min)
- [ ] Step 2B.10: Verify sync-all-data response (15 min)
- [ ] Step 2B.11: Comprehensive testing (2 hours)

**Total Phase 2B Time**: ~10 hours (2 days)
**Progress**: 1/11 steps completed (~9% complete)

---

### Phase 2C: Offline-First Repository Refactoring (2.5 days)

**Objective**: Refactor all repositories to Drift-first pattern for offline support

**Status**: 🔴 Not Started

[Detailed steps will be added - this is a placeholder for the roadmap structure]

**Key Repositories to Refactor**:
- [ ] ActivitiesRepository (4 hours)
- [ ] EventsRepository (3 hours)
- [ ] CarbLoadingRepository (3 hours)
- [ ] ActivityCompletionsRepository (2 hours)
- [ ] UserFoodsRepository (3 hours)
- [ ] NutritionPlanRepository (3 hours)
- [ ] MacroTargetsRepository (2 hours)

**Total Phase 2C Time**: ~20 hours (2.5 days)

---

### Phase 2D: Upload Dirty Records + Final Testing (1.5 days)

**Objective**: Implement automatic upload of offline changes, comprehensive testing

**Status**: 🔴 Not Started

[Detailed steps will be added - this is a placeholder for the roadmap structure]

**Key Tasks**:
- [ ] Implement `_uploadDirtyRecords()` in DataSyncService (4 hours)
- [ ] Add batch upload logic for each entity type (4 hours)
- [ ] Implement retry mechanism for failed uploads (2 hours)
- [ ] Add conflict resolution (last-write-wins) (2 hours)
- [ ] Comprehensive testing (unit, integration, manual) (4 hours)
- [ ] Deploy to dev environment (1 hour)
- [ ] Monitor and validate (1 hour)

**Total Phase 2D Time**: ~12 hours (1.5 days)

---

## Progress Tracking

### Overall Progress

**Total Estimated Time**: 42 hours (5-6 days)

- [ ] **Phase 2B**: Seed Database + Eliminate Redundant Calls (10 hours) - 🔴 Not Started
- [ ] **Phase 2C**: Offline-First Repository Refactoring (20 hours) - 🔴 Not Started
- [ ] **Phase 2D**: Upload Dirty Records + Testing (12 hours) - 🔴 Not Started

### Daily Checklist Template

Copy this template for each day of work:

```markdown
### Day X: [Date]

**Phase**: [2B / 2C / 2D]
**Goal**: [Today's objective]

**Morning** (4 hours):
- [ ] Task 1
- [ ] Task 2
- [ ] Task 3

**Afternoon** (4 hours):
- [ ] Task 4
- [ ] Task 5
- [ ] Task 6

**End of Day**:
- [ ] Code committed to feature branch
- [ ] Build passes locally
- [ ] No lint errors
- [ ] Updated this roadmap with progress
```

---

## Deployment Strategy

### Development Environment

1. **Feature Branch**:
   ```bash
   git checkout develop
   git pull origin develop
   git checkout -b feature/unified-sync-seed-db
   ```

2. **Daily Commits**:
   ```bash
   git add .
   git commit -m "feat: [phase] [description]"
   git push origin feature/unified-sync-seed-db
   ```

3. **Code Review**:
   - Self-review before PR
   - Document all changes in PR description
   - Link to this roadmap

### Testing Environment

1. **Local Testing** (each phase):
   - Fresh install
   - Existing user
   - Offline mode
   - Network failures

2. **Dev Deployment**:
   - Merge to `develop` branch
   - Deploy to dev Supabase project
   - Monitor logs for errors

3. **Production Deployment**:
   - Merge to `main` branch
   - Deploy to prod Supabase project
   - Monitor for 24 hours

### Rollback Plan

If critical issues found:

**Phase 2B Rollback**:
1. Revert seed DB copy logic (empty database on first launch)
2. Restore `checkAndRefreshFoodData()` method
3. Restore redundant food calls
4. App continues to work (slower startup)

**Phase 2C Rollback**:
1. Revert repository changes (Supabase-first pattern)
2. Offline mode broken but online works
3. Keep Phase 2B changes (seed DB)

**Phase 2D Rollback**:
1. Disable upload dirty records
2. Manual sync only
3. Keep Phase 2B + 2C changes

---

## Success Criteria

### Phase 2B Success
- [x] Seed database file < 1MB
- [x] Seed DB copies in < 50ms
- [x] App starts instantly on fresh install
- [x] Only 1 network call on startup (sync-all-data)
- [x] NO redundant get-foods calls
- [x] Fallback works (rare catastrophic failure)

### Phase 2C Success
- [x] All user actions work offline
- [x] Zero data loss scenarios
- [x] Immediate UI feedback on edits
- [x] Data syncs when network available

### Phase 2D Success
- [x] Dirty records upload automatically
- [x] Retry mechanism works
- [x] Multi-device sync reliable
- [x] Production monitoring shows success

---

## Appendix: Command Reference

### Supabase CLI
```bash
# Link to project
supabase link --project-ref <project-ref>

# List projects
supabase projects list

# Export schema
supabase db dump --schema public --data-only=false

# Export data
supabase db dump --data-only --table foods

# Run local edge function
supabase functions serve sync-all-data

# Test edge function
curl -X POST http://localhost:54321/functions/v1/sync-all-data \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test-user-id"}'
```

### SQLite Commands
```bash
# Open database
sqlite3 assets/data/app_seed.db

# List tables
.tables

# Count rows
SELECT COUNT(*) FROM foods;

# Show schema
.schema foods

# Optimize
VACUUM;
```

### Flutter Commands
```bash
# Clean and rebuild
flutter clean
flutter pub get

# Code generation
dart run build_runner build --delete-conflicting-outputs

# Run in profile mode (for performance testing)
flutter run --profile

# Delete app data (iOS simulator)
xcrun simctl uninstall booted com.your.app.id

# Delete app data (Android)
adb uninstall com.your.app.id
```

---

## Decision Log

### 2025-11-04: Complete Architecture Overhaul

**Decisions Made**:

1. **Use Drift's Pre-Populated DB** (not JSON)
   - Fastest approach (< 50ms file copy)
   - Drift native feature
   - Migration-friendly

2. **Eliminate All Redundant Calls**
   - Only sync-all-data on startup
   - Remove get-foods, syncCarbLoadingFoods
   - 66% reduction in network calls

3. **Include Phases 2C + 2D in Scope**
   - Offline-first repository refactoring (Phase 2C)
   - Upload dirty records (Phase 2D)
   - Complete production-ready solution

4. **Intelligent Migration Strategy**
   - Drift handles schema changes automatically
   - Only manually seed NEW TABLES
   - Preserve user data during upgrades

**Approved By**: User confirmed all phases in scope

---

**Status**: 🚀 Ready to Implement
**Next Action**: Begin Phase 2B, Step 2B.1 (Export Seed Data)
**Created**: 2025-11-04
**Last Updated**: 2025-11-04
**Author**: Claude Code (Senior Technical Architect)
