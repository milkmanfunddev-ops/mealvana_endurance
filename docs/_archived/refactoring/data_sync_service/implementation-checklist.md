# DataSyncService Refactoring - Implementation Checklist

**Start Date**: TBD
**Target Completion**: 2-2.5 weeks
**Status**: Ready to Begin

---

## Pre-Implementation

### Setup
- [ ] Create feature branch: `refactor/data-sync-service`
- [ ] Read all refactoring documentation
- [ ] Backup current `data_sync_service.dart` (copy to `.backup` file)
- [ ] Ensure all existing tests pass before starting
- [ ] Run `flutter pub run build_runner build` to ensure clean state

### Baseline Tests
- [ ] Run full test suite: `flutter test`
- [ ] Document current test results (passing count)
- [ ] Identify integration tests that cover sync functionality
- [ ] Note any flaky tests to monitor during refactoring

---

## Phase 1: Quick Wins

**Target Duration**: 1-2 days
**Goal**: Extract utilities and self-contained services

### Phase 1.1: TypeConverters Utility ✅

- [ ] Create directory: `lib/shared/services/sync/utils/`
- [ ] Create file: `type_converters.dart`
- [ ] Copy implementation from refactoring-plan.md
- [ ] Add missing imports (Gender, GutTrainingLevel enums)
- [ ] Test manually in Dart console or write unit tests
- [ ] **No code generation needed** (no Riverpod annotations)

**Testing**:
```bash
# Create test file: test/shared/services/sync/utils/type_converters_test.dart
flutter test test/shared/services/sync/utils/type_converters_test.dart
```

**Validation**:
- [ ] All static methods return expected types
- [ ] Null handling works correctly
- [ ] DateTime parsing handles multiple formats
- [ ] Boolean conversion handles int/String/bool

---

### Phase 1.2: SyncErrorHandler Utility ✅

- [ ] Create file: `lib/shared/services/sync/utils/sync_error_handler.dart`
- [ ] Copy implementation from refactoring-plan.md
- [ ] Add imports (AppLogger, Riverpod)
- [ ] Run code generation: `flutter pub run build_runner build --delete-conflicting-outputs`
- [ ] Verify `.g.dart` file created

**Testing**:
```bash
# Create test file: test/shared/services/sync/utils/sync_error_handler_test.dart
flutter test test/shared/services/sync/utils/sync_error_handler_test.dart
```

**Validation**:
- [ ] Provider compiles successfully
- [ ] Error logging works
- [ ] Default values work
- [ ] Rethrow works as expected

---

### Phase 1.3: DataIntegrityService ✅

- [ ] Create file: `lib/shared/services/sync/data_integrity_service.dart`
- [ ] Copy implementation from refactoring-plan.md
- [ ] Add all necessary imports
- [ ] Run code generation: `flutter pub run build_runner build --delete-conflicting-outputs`
- [ ] Verify `.g.dart` file created

**Testing**:
```bash
# Create test file: test/shared/services/sync/data_integrity_service_test.dart
flutter test test/shared/services/sync/data_integrity_service_test.dart
```

**Test Cases**:
- [ ] Duplicate detection works
- [ ] Most recent record is kept
- [ ] Older records are deleted
- [ ] User profile duplicates handled
- [ ] No duplicates case handled gracefully

**Integration with DataSyncService**:
- [ ] Add `DataIntegrityService` to DataSyncService constructor
- [ ] Replace `_cleanDuplicatesFromDrift` call with `_dataIntegrity.cleanAllDuplicates(userId)`
- [ ] Comment out old methods (keep for reference):
  - `_cleanDuplicatesFromDrift`
  - `_cleanTableDuplicates`
  - `_cleanUserProfilesDuplicates`
- [ ] Run tests to ensure sync still works

---

### Phase 1.4: EntityJsonConverter ✅

- [ ] Create directory: `lib/shared/services/sync/converters/`
- [ ] Create file: `entity_json_converter.dart`
- [ ] Copy implementation from refactoring-plan.md
- [ ] Add imports for domain models
- [ ] **No code generation needed** (pure utility class)

**Testing**:
```bash
# Create test file: test/shared/services/sync/converters/entity_json_converter_test.dart
flutter test test/shared/services/sync/converters/entity_json_converter_test.dart
```

**Test Cases**:
- [ ] Activity → JSON conversion includes all fields
- [ ] Event → JSON conversion includes all fields
- [ ] DateTime fields converted to ISO8601
- [ ] Null fields handled correctly

**Integration with DataSyncService**:
- [ ] Replace inline `_activityToJson` calls with `EntityJsonConverter.activityToJson`
- [ ] Replace inline `_eventToJson` calls with `EntityJsonConverter.eventToJson`
- [ ] Replace inline `_carbLoadingPlanToJson` calls
- [ ] Replace inline `_carbLoadingDayToJson` calls
- [ ] Replace inline `_featureSurveyToJson` calls
- [ ] Comment out old `*ToJson` methods
- [ ] Run tests

---

### Phase 1: Checkpoint ✓

**Before proceeding to Phase 2**:
- [ ] All Phase 1 files created and compiling
- [ ] Code generation completed successfully
- [ ] Unit tests written and passing for new utilities
- [ ] Integration with DataSyncService successful
- [ ] All existing tests still passing
- [ ] Git commit: `refactor(sync): Phase 1 - Extract utilities (~795 lines)`

---

## Phase 2: Entity Services

**Target Duration**: 3-4 days
**Goal**: Extract entity-specific sync logic into specialized services

### Phase 2.1: CalendarSyncService ✅

- [ ] Create directory: `lib/features/calendar/data/`
- [ ] Create file: `calendar_sync_service.dart`
- [ ] Copy implementation from refactoring-plan.md
- [ ] Add all imports (Activity, Event, Companion classes)
- [ ] Run code generation: `flutter pub run build_runner build --delete-conflicting-outputs`

**Methods to Implement**:
- [ ] `downloadActivities(String userId)`
- [ ] `downloadEvents(String userId)`
- [ ] `upsertActivity(Map<String, dynamic> data, String userId)`
- [ ] `upsertEvent(Map<String, dynamic> data, String userId)`
- [ ] `collectDirtyRecords(String userId)`
- [ ] `clearUploadFlags(String userId)`

**Testing**:
```bash
flutter test test/features/calendar/data/calendar_sync_service_test.dart
```

**Test Cases**:
- [ ] Download activities from Supabase
- [ ] Upsert activity preserves dirty records
- [ ] Upsert activity checks timestamps
- [ ] Event FK validation works
- [ ] Dirty record collection works
- [ ] Upload flags cleared correctly

**Integration with DataSyncService**:
- [ ] Add `CalendarSyncService` to DataSyncService constructor
- [ ] Replace `_downloadActivities` call with `_calendarSync.downloadActivities(userId)`
- [ ] Replace `_downloadEvents` call with `_calendarSync.downloadEvents(userId)`
- [ ] Replace `_upsertActivity` call with `_calendarSync.upsertActivity(...)`
- [ ] Replace `_upsertEvent` call with `_calendarSync.upsertEvent(...)`
- [ ] Comment out old methods
- [ ] Run tests

---

### Phase 2.2: CarbLoadingSyncService ✅

- [ ] Create file: `lib/features/carb_loading/data/carb_loading_sync_service.dart`
- [ ] Implement similar to CalendarSyncService
- [ ] Run code generation

**Methods to Implement**:
- [ ] `downloadPlansAndDays(String userId)`
- [ ] `upsertPlan(Map<String, dynamic> data, String userId)`
- [ ] `upsertDay(Map<String, dynamic> data)`
- [ ] `collectDirtyRecords(String userId)`
- [ ] `clearUploadFlags(String userId)`

**Special Handling**:
- [ ] Handle `local_updated_at` instead of `updated_at`
- [ ] Update linked event when syncing plan
- [ ] Handle plan → days FK relationship

**Testing**:
```bash
flutter test test/features/carb_loading/data/carb_loading_sync_service_test.dart
```

**Integration with DataSyncService**:
- [ ] Add to constructor
- [ ] Replace download/upsert calls
- [ ] Comment out old methods
- [ ] Run tests

---

### Phase 2.3: CoachDataSyncService ✅

- [ ] Create file: `lib/features/coach_mode/data/coach_sync_service.dart`
- [ ] Implement all coach-related sync methods
- [ ] Run code generation

**Methods to Implement**:
- [ ] `syncCoachRecord(Map<String, dynamic> data)`
- [ ] `syncCoachAthleteRelationships(List<dynamic> data)`
- [ ] `syncCoachMessages(List<dynamic> data)`
- [ ] `syncAthleteEvents(List<dynamic> data)`
- [ ] `syncAthleteActivities(List<dynamic> data)`
- [ ] `syncAthleteProfiles(List<dynamic> data)`
- [ ] `syncAthleteCarbLoadingPlans(List<dynamic> data)`
- [ ] `collectDirtyRecords(String coachId)`
- [ ] `clearUploadFlags(String coachId)`

**Special Handling**:
- [ ] Conditional sync (only if user is approved coach)
- [ ] Limited athlete profile fields
- [ ] Relationship status handling

**Testing**:
```bash
flutter test test/features/coach_mode/data/coach_sync_service_test.dart
```

**Integration with DataSyncService**:
- [ ] Add to constructor
- [ ] Replace all `_syncCoach*` method calls
- [ ] Consider using `CoachRepository` (currently unused)
- [ ] Comment out old methods
- [ ] Run tests

---

### Phase 2.4: UserProfileSyncService ✅

- [ ] Create file: `lib/features/auth/data/user_profile_sync_service.dart`
- [ ] Implement user profile and food preferences sync
- [ ] Run code generation

**Methods to Implement**:
- [ ] `syncUserProfile(String userId)` - Main entry point
- [ ] `_fetchRemoteProfile(String userId)`
- [ ] `_saveRemoteProfileLocally(Map<String, dynamic> data, String userId)`
- [ ] `uploadUserProfile(String userId)`
- [ ] `syncFoodPreferences(Map<String, dynamic> data, String userId)`
- [ ] `uploadFoodPreferences(String userId)`
- [ ] `collectDirtyRecords(String userId)`
- [ ] `clearUploadFlags(String userId)`

**Special Handling**:
- [ ] Multi-device support
- [ ] Sign-back-in flow
- [ ] Dev/prod schema differences
- [ ] JSONB + normalized table for food preferences

**Testing**:
```bash
flutter test test/features/auth/data/user_profile_sync_service_test.dart
```

**Test Cases**:
- [ ] Fetch remote profile works
- [ ] Multi-device login fetches from Supabase
- [ ] Sign-back-in refreshes profile
- [ ] Food preferences merge correctly
- [ ] Empty server response preserved local data

**Integration with DataSyncService**:
- [ ] Add to constructor
- [ ] Replace `syncUsers` call with `_userProfileSync.syncUserProfile(userId)`
- [ ] Replace `_saveRemoteUserProfile` call
- [ ] Replace `_uploadUserProfile` call
- [ ] Replace `_uploadFoodPreferences` call
- [ ] Replace `_syncFoodPreferencesFromEdgeFunction` call
- [ ] Comment out old methods
- [ ] Run tests

---

### Phase 2: Checkpoint ✓

**Before proceeding to Phase 3**:
- [ ] All 4 entity services created and compiling
- [ ] Code generation completed for all services
- [ ] Unit tests written for each service
- [ ] Integration with DataSyncService successful
- [ ] All existing tests still passing
- [ ] Commented out replaced methods (keep for reference)
- [ ] Git commit: `refactor(sync): Phase 2 - Extract entity services (~1,550 lines)`

---

## Phase 3: Core Refactoring

**Target Duration**: 2-3 days
**Goal**: Create upload orchestrator and simplify main service

### Phase 3.1: UploadOrchestratorService ✅

- [ ] Create file: `lib/shared/services/sync/upload_orchestrator_service.dart`
- [ ] Copy implementation from refactoring-plan.md
- [ ] Add imports for all entity services
- [ ] Run code generation

**Methods to Implement**:
- [ ] `uploadAllDirtyRecords(String userId)`
- [ ] `_uploadViaEdgeFunction(String userId, Map<String, dynamic> payload)`
- [ ] `_countRecords(Map<String, dynamic> payload)`

**Logic**:
1. Collect dirty records from all entity services
2. Call edge function with consolidated payload
3. Clear upload flags on success

**Testing**:
```bash
flutter test test/shared/services/sync/upload_orchestrator_service_test.dart
```

**Test Cases**:
- [ ] Collects from all services
- [ ] Edge function called with correct payload
- [ ] Flags cleared on success
- [ ] Flags not cleared on failure
- [ ] Empty payload handled

**Integration with DataSyncService**:
- [ ] Add to constructor
- [ ] Replace `uploadDirtyRecords` call with `_uploadOrchestrator.uploadAllDirtyRecords(userId)`
- [ ] Comment out old `uploadDirtyRecords` method (178 lines)
- [ ] Comment out `_clearNeedsUploadFlag` method
- [ ] Run tests

---

### Phase 3.2: Simplify Main DataSyncService ✅

**Goal**: Reduce to ~400 lines of orchestration logic only

**Steps**:
- [ ] Open `data_sync_service.dart`
- [ ] Add all new service imports (Phase 1 & 2 utilities/services)
- [ ] Update constructor to inject all services
- [ ] Update provider to wire up all dependencies

**Replace Method Calls**:
- [ ] `syncUsers` → `_userProfileSync.syncUserProfile(userId)`
- [ ] `uploadDirtyRecords` → `_uploadOrchestrator.uploadAllDirtyRecords(userId)`
- [ ] `_cleanDuplicatesFromDrift` → `_dataIntegrity.cleanAllDuplicates(userId)`
- [ ] `_downloadActivities` → `_calendarSync.downloadActivities(userId)`
- [ ] `_downloadEvents` → `_calendarSync.downloadEvents(userId)`
- [ ] `_downloadCarbLoadingPlans` → `_carbLoadingSync.downloadPlansAndDays(userId)`
- [ ] `_upsertActivity` → `_calendarSync.upsertActivity(...)`
- [ ] `_upsertEvent` → `_calendarSync.upsertEvent(...)`
- [ ] `_upsertCarbLoadingPlan` → `_carbLoadingSync.upsertPlan(...)`
- [ ] `_upsertCarbLoadingDay` → `_carbLoadingSync.upsertDay(...)`
- [ ] All coach sync methods → `_coachSync.*(...)`
- [ ] JSON conversions → `EntityJsonConverter.*(...)`
- [ ] Type conversions → `TypeConverters.*(...)`

**Keep These Methods** (core orchestration):
- [ ] `syncAllData(String userId)` - Main entry point
- [ ] `_tryEdgeFunctionSync(...)` - Edge function flow
- [ ] `_syncDataFromEdgeFunction(...)` - Process edge response
- [ ] `_clientSideDownload(...)` - Fallback flow
- [ ] `needsFullSync(...)` - Sync detection
- [ ] `_invalidateCalendarProviders()` - UI refresh
- [ ] Static utility methods (for backward compatibility)

**Delete/Comment Out**:
- [ ] Comment out all replaced methods with `// DEPRECATED - moved to [ServiceName]`
- [ ] Comment out all DEPRECATED methods (already not called)
- [ ] Consider deleting DEPRECATED methods if confident

**Code Generation**:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

**Validation**:
- [ ] Main file reduced to ~400-500 lines
- [ ] All imports resolved
- [ ] Code generation successful
- [ ] No compilation errors

---

### Phase 3.3: Final Testing ✅

**Unit Tests**:
```bash
flutter test test/shared/services/sync/
flutter test test/features/calendar/data/
flutter test test/features/carb_loading/data/
flutter test test/features/coach_mode/data/
flutter test test/features/auth/data/
```

**Integration Tests**:
```bash
flutter test test/integration/sync/
```

**Manual Testing Checklist**:
- [ ] Create new activity in app
- [ ] Mark `needs_upload = true`
- [ ] Trigger sync
- [ ] Verify activity uploaded to Supabase
- [ ] Verify `needs_upload = false` after sync
- [ ] Delete local DB
- [ ] Trigger sync (download)
- [ ] Verify activity downloaded from Supabase
- [ ] Test multi-device: sign in on new device
- [ ] Verify profile fetched from Supabase
- [ ] Test sign-out/sign-in flow
- [ ] Verify profile refreshed

**Edge Cases**:
- [ ] Edge function timeout (30 sec)
- [ ] Client-side fallback works
- [ ] Dirty records preserved during download
- [ ] Duplicate cleanup before upload
- [ ] FK violations prevented

---

### Phase 3: Checkpoint ✓

**Final Validation**:
- [ ] Main DataSyncService ~400-500 lines
- [ ] All functionality preserved
- [ ] All tests passing
- [ ] No regressions in sync behavior
- [ ] Code generation successful
- [ ] Manual testing complete
- [ ] Git commit: `refactor(sync): Phase 3 - Upload orchestrator and simplified core (~300 lines + major simplification)`

---

## Post-Implementation

### Cleanup

- [ ] Review all `// DEPRECATED` comments
- [ ] Decide: keep for reference or delete
- [ ] Update CLAUDE.md if sync architecture changed
- [ ] Update docs/technical/README.md
- [ ] Update architecture diagrams

### Documentation

- [ ] Update sync service documentation
- [ ] Document new service boundaries
- [ ] Create migration guide for future entity additions
- [ ] Update testing documentation

### Code Review Preparation

- [ ] Squash commits if needed (or keep separate commits per phase)
- [ ] Write comprehensive PR description
- [ ] Include before/after metrics (lines, complexity)
- [ ] Include testing results
- [ ] Include manual testing checklist

### Merge Strategy

**Option 1: Merge all at once**
- Single large PR with all 3 phases
- Easier to review as complete refactoring
- Higher risk if issues found

**Option 2: Merge per phase**
- 3 separate PRs (Phase 1 → Phase 2 → Phase 3)
- Easier to review incrementally
- Can rollback individual phases
- **Recommended approach**

---

## Success Criteria Validation

- [ ] Main service <500 lines (target: ~400)
- [ ] Code duplication eliminated (~980 lines saved)
- [ ] 6 specialized services created
- [ ] 3 utility classes created
- [ ] Test coverage ≥90% on new code
- [ ] All integration tests passing
- [ ] No sync regressions
- [ ] CI/CD pipeline green

---

## Rollback Procedures

### If Phase 1 Issues Found
```bash
git revert <phase-1-commit-hash>
flutter pub run build_runner build --delete-conflicting-outputs
flutter test
```

### If Phase 2 Issues Found
```bash
git revert <phase-2-commit-hash>
flutter pub run build_runner build --delete-conflicting-outputs
flutter test
```

### If Phase 3 Issues Found
```bash
git revert <phase-3-commit-hash>
flutter pub run build_runner build --delete-conflicting-outputs
flutter test
```

### Nuclear Option (Revert All)
```bash
git checkout main
git branch -D refactor/data-sync-service
# Start over or abandon refactoring
```

---

## Timeline Tracking

| Phase | Estimated | Actual | Status |
|-------|-----------|--------|--------|
| Phase 1.1 | 2 hours | - | Not Started |
| Phase 1.2 | 2 hours | - | Not Started |
| Phase 1.3 | 3 hours | - | Not Started |
| Phase 1.4 | 2 hours | - | Not Started |
| **Phase 1 Total** | **1-2 days** | **-** | **Not Started** |
| Phase 2.1 | 4 hours | - | Not Started |
| Phase 2.2 | 3 hours | - | Not Started |
| Phase 2.3 | 3 hours | - | Not Started |
| Phase 2.4 | 4 hours | - | Not Started |
| **Phase 2 Total** | **3-4 days** | **-** | **Not Started** |
| Phase 3.1 | 3 hours | - | Not Started |
| Phase 3.2 | 4 hours | - | Not Started |
| Phase 3.3 | 1 day (testing) | - | Not Started |
| **Phase 3 Total** | **2-3 days** | **-** | **Not Started** |
| **TOTAL** | **6-9 days** | **-** | **Not Started** |

---

## Notes & Issues Log

### Phase 1 Issues
- [ ] None yet

### Phase 2 Issues
- [ ] None yet

### Phase 3 Issues
- [ ] None yet

### Lessons Learned
- [ ] Document any unexpected challenges
- [ ] Document any shortcuts taken
- [ ] Document any deviations from plan

---

**Status**: Ready to begin. Start with Phase 1.1 (TypeConverters).
