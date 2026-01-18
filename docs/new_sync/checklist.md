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

### 1.2 Core Models [CLAIMED: claude-sync-agent-20260118]
- [ ] Create `lib/shared/models/sync_result.dart`
  - SyncResult class with success/failure states
  - Count of synced records
  - Error information
- [ ] Create `lib/shared/models/version_check_result.dart`
  - VersionCheckResult enum (ok, updateRequired, resyncRequired)
  - Current vs required version info
- [ ] Write tests: `test/new_sync/models_test.dart`

### 1.3 VersionCheckService
- [ ] Create `lib/shared/services/version_check_service.dart`
- [ ] Query app_config table on startup
- [ ] Compare min_app_version vs PackageInfo.version
- [ ] Compare current_schema_version vs local Drift schemaVersion
- [ ] Return appropriate VersionCheckResult
- [ ] Handle network failures gracefully (use cached result)
- [ ] Write tests: `test/new_sync/version_check_service_test.dart`

### 1.4 ForceUpgradeScreen
- [ ] Create `lib/features/app_startup/presentation/screens/force_upgrade_screen.dart`
- [ ] Display current version vs required version
- [ ] Platform-specific app store links (iOS/Android)
- [ ] Block all navigation (no back button)
- [ ] Add to GoRouter routes
- [ ] Write widget test: `test/new_sync/force_upgrade_screen_test.dart`

### 1.5 Integrate Version Check into Startup
- [ ] Modify `lib/features/app_startup/application/app_startup_provider.dart`
- [ ] Call VersionCheckService BEFORE database initialization
- [ ] Handle VersionCheckResult.updateRequired → navigate to ForceUpgradeScreen
- [ ] Handle VersionCheckResult.resyncRequired → trigger schema resync
- [ ] Write integration test: `test/new_sync/app_startup_version_check_test.dart`

---

## Phase 2: Repository Base Class

### 2.1 SyncableRepository Abstract Class [CLAIMED: claude-opus-4.5-20260118]
- [ ] Create `lib/shared/data/syncable_repository.dart`
- [ ] Define abstract methods: repositoryKey, dependencies, isStale, syncFromRemote, uploadDirtyRecords
- [ ] Implement SharedPreferences timestamp storage (getLastSyncTime, setLastSyncTime)
- [ ] Implement isStale() with 24-hour threshold
- [ ] Write tests: `test/new_sync/syncable_repository_test.dart`

### 2.2 SyncCoordinator v2
- [ ] Refactor `lib/shared/services/sync/sync_coordinator.dart`
- [ ] Add static dependency graph map
- [ ] Add `ensureSynced(repoKey, userId)` method
- [ ] Implement recursive dependency resolution
- [ ] Add `_syncingNow` set to prevent infinite loops
- [ ] Keep existing `sync()` method for backwards compatibility
- [ ] Write tests: `test/new_sync/sync_coordinator_v2_test.dart`

### 2.3 DirtyRecordBackupService [CLAIMED: claude-sonnet-4.5-20260118]
- [ ] Create `lib/shared/services/dirty_record_backup_service.dart`
- [ ] Implement `backupDirtyRecords(records)` - save to App Support JSON
- [ ] Implement `hasBackup()` - check if backup file exists
- [ ] Implement `recoverBackup()` - read and parse backup file
- [ ] Implement `deleteBackup()` - remove backup file after recovery
- [ ] Add backup file structure with metadata (app_version, schema_version, timestamp)
- [ ] Write tests: `test/new_sync/dirty_record_backup_service_test.dart`

### 2.4 Recovery Dialog
- [ ] Create recovery dialog widget for dirty record backup
- [ ] Integrate into AppStartupService to check for backups on startup
- [ ] Handle user choice: upload now vs discard
- [ ] Write test: `test/new_sync/recovery_dialog_test.dart`

---

## Phase 3: Repository Migration

### 3.1 ActivitiesRepository (Pattern Template)
- [ ] Modify `lib/features/activities/data/activities_repository.dart`
- [ ] Extend SyncableRepository (or implement mixin)
- [ ] Add repositoryKey = 'activities'
- [ ] Add dependencies = ['users']
- [ ] Implement `syncFromRemote()` with direct Supabase query
- [ ] Implement `uploadDirtyRecords()` with retry logic
- [ ] Update existing methods to check staleness via coordinator
- [ ] Write tests: `test/new_sync/activities_repository_sync_test.dart`

### 3.2 UserRepository
- [ ] Modify `lib/features/auth/data/user_repository.dart`
- [ ] Implement SyncableRepository interface
- [ ] repositoryKey = 'users', dependencies = []
- [ ] Extract food preferences code (prepare for separate repo)
- [ ] Extract user foods code (prepare for separate repo)
- [ ] Write tests: `test/new_sync/user_repository_sync_test.dart`

### 3.3 EventsRepository
- [ ] Modify `lib/features/events/data/events_repository.dart`
- [ ] Implement SyncableRepository interface
- [ ] repositoryKey = 'events', dependencies = ['users']
- [ ] Write tests: `test/new_sync/events_repository_sync_test.dart`

### 3.4 FoodPreferencesRepository (NEW)
- [ ] Create `lib/features/food_preferences/data/food_preferences_repository.dart`
- [ ] Extract from UserRepository
- [ ] repositoryKey = 'food_preferences', dependencies = ['users', 'foods']
- [ ] Write tests: `test/new_sync/food_preferences_repository_test.dart`

### 3.5 UserFoodsRepository (NEW)
- [ ] Create `lib/features/user_foods/data/user_foods_repository.dart`
- [ ] Extract from UserRepository
- [ ] repositoryKey = 'user_foods', dependencies = ['users']
- [ ] Write tests: `test/new_sync/user_foods_repository_test.dart`

### 3.6 CarbLoadingRepository
- [ ] Modify `lib/features/carb_loading/data/carb_loading_repository.dart`
- [ ] Split into multiple repository keys or handle as group
- [ ] carb_loading_plans: dependencies = ['users', 'events']
- [ ] carb_loading_days: dependencies = ['carb_loading_plans']
- [ ] Write tests: `test/new_sync/carb_loading_repository_sync_test.dart`

### 3.7 FoodRepository
- [ ] Modify `lib/features/nutrition_plan/data/food_repository.dart`
- [ ] repositoryKey = 'foods', dependencies = []
- [ ] Seed data handling (may not need frequent sync)
- [ ] Write tests: `test/new_sync/food_repository_sync_test.dart`

### 3.8 FeedbackRepository
- [ ] Modify `lib/features/feedback/data/feedback_repository.dart`
- [ ] repositoryKey = 'feedback', dependencies = ['users']
- [ ] Write tests: `test/new_sync/feedback_repository_sync_test.dart`

### 3.9 CoachRepository
- [ ] Modify `lib/features/coach_mode/data/coach_repository.dart`
- [ ] Multiple repository keys: coaches, coach_athlete_relationships, coach_messages
- [ ] Handle on-demand athlete sync (keep separate from staleness pattern)
- [ ] Write tests: `test/new_sync/coach_repository_sync_test.dart`

---

## Phase 4: Migration Simplification

### 4.1 Remove Step-by-Step Migrations
- [ ] Delete `lib/shared/database/migrations/migration_v1_to_v2.dart`
- [ ] Delete `lib/shared/database/migrations/migration_v2_to_v3.dart`
- [ ] Update imports in `app_database.dart`
- [ ] Verify no other code depends on these files

### 4.2 Simplify app_database.dart
- [ ] Remove `onUpgrade: stepByStep(...)` block
- [ ] Keep only `onCreate` for fresh installs
- [ ] Remove schema_versions.dart dependency for migrations
- [ ] Update `beforeOpen` to only enable foreign keys

### 4.3 Implement Schema Resync in VersionCheckService
- [ ] Add method `performSchemaResync()`
- [ ] Check for dirty records first
- [ ] Upload dirty records (with backup on failure)
- [ ] Delete database files
- [ ] Recreate database
- [ ] Trigger full sync
- [ ] Write tests: `test/new_sync/schema_resync_test.dart`

---

## Phase 5: UI Integration

### 5.1 Update ActivitiesController
- [ ] Call `ensureSynced('activities')` in build()
- [ ] Handle sync errors gracefully
- [ ] Show loading indicator during sync

### 5.2 Update EventsController
- [ ] Call `ensureSynced('events')` in build()

### 5.3 Update CarbLoadingController
- [ ] Call `ensureSynced('carb_loading_plans')` in build()

### 5.4 Update FoodPreferencesController
- [ ] Call `ensureSynced('food_preferences')` when preferences screen opens

### 5.5 Update Pull-to-Refresh
- [ ] Keep existing behavior OR
- [ ] Convert to repository-level refresh

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

### 6.3 Documentation
- [ ] Update CLAUDE.md with new sync patterns
- [ ] Update /docs/technical/README.md
- [ ] Archive old sync documentation

### 6.4 Code Cleanup
- [ ] Remove unused imports
- [ ] Run `flutter analyze`
- [ ] Run `dart fix --apply`
- [ ] Ensure all tests pass

---

## Completion Summary

| Phase | Tasks | Completed | Remaining |
|-------|-------|-----------|-----------|
| Phase 1 | 15 | 4 | 11 |
| Phase 2 | 12 | 0 | 12 |
| Phase 3 | 27 | 0 | 27 |
| Phase 4 | 9 | 0 | 9 |
| Phase 5 | 5 | 0 | 5 |
| Phase 6 | 12 | 0 | 12 |
| **Total** | **80** | **4** | **76** |

---

*Last agent activity*: claude-sync-agent-20260118 completed Phase 1.1 (app_config table migration)
