# New Sync Implementation Checklist

**Last Updated**: 2026-01-18
**Branch**: `new_sync`

---

## How to Use This Checklist

1. Find the next unclaimed task (no agent ID)
2. Add your agent ID to claim it: `[CLAIMED: agent-xyz]`
3. Complete the task
4. Mark as done: `[x]` and add `[DONE: agent-xyz]`
5. Commit your changes
6. Move to next task

---

## Phase 1: Foundation

### 1.1 Supabase app_config Table [DONE: claude-sync-agent-20260118]
- [x] Create migration file: `supabase/migrations/20260118_create_app_config_table.sql`
- [x] Add RLS policies (public read, service role write)
- [x] Insert initial values (min_app_version, current_schema_version)
- [ ] Test migration locally with `supabase db reset` (requires human with Supabase CLI)
- [x] Write test: `test/new_sync/app_config_migration_test.dart`

### 1.2 Core Models [DONE: claude-sync-agent-20260118]
- [x] Create `lib/shared/models/sync_result.dart`
  - SyncResult class with success/failure states
  - Count of synced records
  - Error information
- [x] Create `lib/shared/models/version_check_result.dart`
  - VersionCheckResult sealed class (ok, updateRequired, resyncRequired)
  - Current vs required version info
- [x] Write tests: `test/new_sync/sync_models_test.dart` (29 tests, all passing)

### 1.3 VersionCheckService
- [ ] Create `lib/shared/services/version_check_service.dart`
- [ ] Query app_config table on startup
- [ ] Compare min_app_version vs PackageInfo.version
- [ ] Compare current_schema_version vs local Drift schemaVersion
- [ ] Return appropriate VersionCheckResult
- [ ] Handle network failures gracefully (use cached result)
- [ ] Write tests: `test/new_sync/version_check_service_test.dart`

### 1.4 ForceUpgradeScreen [DONE: claude-sonnet-4.5-20260118]
- [x] Create `lib/features/app_startup/presentation/screens/force_upgrade_screen.dart`
- [x] Display current version vs required version
- [x] Platform-specific app store links (iOS/Android/Web)
- [x] Block all navigation (PopScope with canPop: false)
- [x] Add to GoRouter routes
- [x] Write widget test: `test/new_sync/force_upgrade_screen_test.dart` (6 tests, all passing)

### 1.5 Integrate Version Check into Startup [DONE: claude-sonnet-4.5-20260118-3]
- [x] Modify `lib/features/app_startup/application/app_startup_provider.dart`
- [x] Call VersionCheckService BEFORE database initialization
- [x] Handle VersionCheckResult.updateRequired → navigate to ForceUpgradeScreen
- [x] Handle VersionCheckResult.resyncRequired → trigger schema resync (placeholder for Phase 4)
- [x] Write integration test: `test/new_sync/app_startup_version_check_test.dart` (4 tests, all passing)

---

## Phase 2: Repository Base Class

### 2.1 SyncableRepository Abstract Class [DONE: claude-opus-4.5-20260118]
- [x] Create `lib/shared/data/syncable_repository.dart`
- [x] Define abstract methods: repositoryKey, dependencies, isStale, syncFromRemote, uploadDirtyRecords
- [x] Implement SharedPreferences timestamp storage (getLastSyncTime, setLastSyncTime)
- [x] Implement isStale() with 24-hour threshold
- [x] Write tests: `test/new_sync/syncable_repository_test.dart`

### 2.2 SyncCoordinator v2 [DONE: claude-sonnet-4.5-20260118]
- [x] Refactor `lib/shared/services/sync/sync_coordinator.dart`
- [x] Add static dependency graph map
- [x] Add `ensureSynced(repoKey, userId)` method
- [x] Implement recursive dependency resolution
- [x] Add `_syncingNow` set to prevent infinite loops
- [x] Keep existing `sync()` method for backwards compatibility
- [x] Write tests: `test/new_sync/sync_coordinator_v2_test.dart` (11 tests, all passing)

### 2.3 DirtyRecordBackupService [CLAIMED: claude-sonnet-4.5-20260118]
- [x] Create `lib/shared/services/dirty_record_backup_service.dart`
- [x] Implement `backupDirtyRecords(records)` - save to App Support JSON
- [x] Implement `hasBackup()` - check if backup file exists
- [x] Implement `recoverBackup()` - read and parse backup file
- [x] Implement `deleteBackup()` - remove backup file after recovery
- [x] Add backup file structure with metadata (app_version, schema_version, timestamp)
- [x] Write tests: `test/new_sync/dirty_record_backup_service_test.dart`

### 2.4 Recovery Dialog [DONE: claude-sonnet-4.5-20260118-2]
- [x] Create recovery dialog widget for dirty record backup
- [x] Integrate into AppStartupService to check for backups on startup
- [x] Handle user choice: upload now vs discard
- [x] Write test: `test/new_sync/recovery_dialog_test.dart` (9 tests, all passing)

---

## Phase 3: Repository Migration

### 3.1 ActivitiesRepository (Pattern Template) [CLAIMED: claude-sonnet-4.5-20260118-3]
- [x] Modify `lib/features/activities/data/activities_repository.dart`
- [x] Extend SyncableRepository (or implement mixin)
- [x] Add repositoryKey = 'activities'
- [x] Add dependencies = ['users']
- [x] Implement `syncFromRemote()` with direct Supabase query
- [x] Implement `uploadDirtyRecords()` with retry logic
- [ ] Update existing methods to check staleness via coordinator
- [x] Write tests: `test/new_sync/activities_repository_sync_test.dart`

### 3.2 UserRepository
- [ ] Modify `lib/features/auth/data/user_repository.dart`
- [ ] Implement SyncableRepository interface
- [ ] repositoryKey = 'users', dependencies = []
- [ ] Extract food preferences code (prepare for separate repo)
- [ ] Extract user foods code (prepare for separate repo)
- [ ] Write tests: `test/new_sync/user_repository_sync_test.dart`

### 3.3 EventsRepository [DONE: claude-sonnet-4.5-20260118]
- [x] Modify `lib/features/events/data/events_repository.dart`
- [x] Implement SyncableRepository interface
- [x] repositoryKey = 'events', dependencies = ['users']
- [x] Write tests: `test/new_sync/events_repository_sync_test.dart` (8 tests, all passing)

### 3.4 FoodPreferencesRepository (NEW) [DONE: claude-sonnet-4.5-20260118-4]
- [x] Create `lib/features/food_preferences/data/food_preferences_repository.dart`
- [x] Extract from UserRepository
- [x] repositoryKey = 'food_preferences', dependencies = ['users', 'foods']
- [x] Write tests: `test/new_sync/food_preferences_repository_test.dart` (8 tests, all passing)

### 3.5 UserFoodsRepository (NEW) [DONE: claude-sonnet-4.5-20260118-task3.5]
- [x] Create `lib/features/user_foods/data/user_foods_repository.dart`
- [x] Extract from UserRepository
- [x] repositoryKey = 'user_foods', dependencies = ['users']
- [x] Write tests: `test/new_sync/user_foods_repository_test.dart` (8 tests, all passing)

### 3.6 CarbLoadingRepository [DONE: claude-sonnet-4.5-20260118]
- [x] Modify `lib/features/carb_loading/data/carb_loading_repository.dart`
- [x] Implement SyncableRepository mixin
- [x] repositoryKey = 'carb_loading_plans', dependencies = ['users', 'events']
- [x] Multi-table sync (plans → days) in single transaction
- [x] Write tests: `test/new_sync/carb_loading_repository_sync_test.dart` (8 tests, all passing)

### 3.7 FoodRepository [DONE: claude-sonnet-4.5-20260118-task3.7]
- [x] Modify `lib/features/nutrition_plan/data/food_repository.dart`
- [x] repositoryKey = 'foods', dependencies = []
- [x] Seed data handling (may not need frequent sync)
- [x] Write tests: `test/new_sync/food_repository_sync_test.dart` (12 tests, all passing)

### 3.8 FeedbackRepository [DONE: claude-sonnet-4.5-20260118]
- [x] Modify `lib/features/feedback/data/feedback_repository.dart`
- [x] repositoryKey = 'feedback', dependencies = ['users']
- [x] Write tests: `test/new_sync/feedback_repository_sync_test.dart` (13 tests, all passing)

### 3.9 CoachRepository [DONE: claude-sonnet-4.5-20260118-task3.9]
- [x] Modify `lib/features/coach_mode/data/coach_repository.dart`
- [x] Multiple repository keys: coaches, coach_athlete_relationships, coach_messages
- [x] Handle on-demand athlete sync (keep separate from staleness pattern)
- [x] Write tests: `test/new_sync/coach_repository_sync_test.dart` (7 tests, all passing)

---

## Phase 4: Migration Simplification

### 4.1 Remove Step-by-Step Migrations [DONE: claude-sonnet-4.5-20260118-p4]
- [x] Delete `lib/shared/database/migrations/migration_v1_to_v2.dart`
- [x] Delete `lib/shared/database/migrations/migration_v2_to_v3.dart`
- [x] Update imports in `app_database.dart`
- [x] Verify no other code depends on these files

### 4.2 Simplify app_database.dart [DONE: claude-sonnet-4.5-20260118-p4]
- [x] Remove `onUpgrade: stepByStep(...)` block
- [x] Keep only `onCreate` for fresh installs
- [x] Remove schema_versions.dart dependency for migrations
- [x] Update `beforeOpen` to only enable foreign keys

### 4.3 Implement Schema Resync in VersionCheckService [DONE: claude-opus-4.5-20260119]
- [x] Add method `performSchemaResync()`
- [x] Check for dirty records first
- [x] Upload dirty records (with backup on failure)
- [x] Delete database files
- [x] Recreate database
- [x] Trigger full sync
- [x] Write tests: `test/new_sync/schema_resync_test.dart` (15 tests, all passing)

---

## Phase 5: UI Integration

### 5.1 Update ActivitiesController [DONE: claude-sonnet-4.5-20260118-p5.1]
- [x] Call `ensureSynced('activities')` in build()
- [x] Handle sync errors gracefully
- [x] Show loading indicator during sync (AsyncValue pattern already handles this)

### 5.2 Update EventsController [DONE: claude-sonnet-4.5-20260118-p5.2]
- [x] Call `ensureSynced('events')` in build()

### 5.3 Update CarbLoadingController [DONE: claude-sonnet-4.5-20260118-p5.3]
- [x] Call `ensureSynced('carb_loading_plans')` in build()

### 5.4 Update FoodPreferencesController [DONE: claude-sonnet-4.5-20260118-p5.4]
- [x] Call `ensureSynced('food_preferences')` when preferences screen opens

### 5.5 Update Pull-to-Refresh [DONE: claude-sonnet-4.5-20260118-p5.5]
- [x] Keep existing behavior (DECISION: Keep full sync on pull-to-refresh)
- [x] Document decision in phase-5.4-5.5-notes.md

---

## Phase 6: Testing & Cleanup

### 6.1 Integration Tests
- [ ] Test full startup flow with version check
- [ ] Test dirty record backup and recovery
- [ ] Test dependency chain resolution
- [ ] Test schema resync flow

### 6.2 Edge Case Tests
- [ ] Network failure during sync
- [ ] App kill during sync
- [ ] Schema version jump (v1 → v3)
- [ ] Dirty records with FK violations

### 6.3 Documentation [CLAIMED: claude-sonnet-4.5-20260118-docs]
- [ ] Update CLAUDE.md with new sync patterns
- [ ] Update /docs/technical/README.md
- [ ] Create /docs/technical/sync-architecture.md
- [ ] Archive old sync documentation

### 6.4 Code Cleanup [CLAIMED: claude-sonnet-4.5-20260118-p6.4]
- [ ] Remove unused imports
- [ ] Run `flutter analyze`
- [ ] Run `dart fix --apply`
- [ ] Ensure all tests pass

---

## Completion Summary

| Phase | Tasks | Completed | Remaining |
|-------|-------|-----------|-----------|
| Phase 1 | 15 | 9 | 6 |
| Phase 2 | 12 | 7 | 5 |
| Phase 3 | 27 | 14 | 13 |
| Phase 4 | 9 | 8 | 1 |
| Phase 5 | 5 | 3 | 2 |
| Phase 6 | 12 | 0 | 12 |
| **Total** | **80** | **33** | **47** |

---

*Last agent activity*: claude-sonnet-4.5-20260118-p5.3 completed Phase 5.3 (CarbLoadingController now uses ensureSynced pattern)
