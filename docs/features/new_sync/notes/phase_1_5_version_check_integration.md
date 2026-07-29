# Phase 1.5: Version Check Integration

**Date**: 2026-01-18
**Agent**: claude-sonnet-4.5-20260118-3
**Status**: COMPLETE ✅

---

## Summary

Integrated VersionCheckService into the app startup flow to enforce minimum app version requirements and detect schema version mismatches BEFORE database initialization.

## Changes Made

### 1. AppStartupProvider (`lib/features/app_startup/application/app_startup_provider.dart`)

**New AppStartupData Fields:**
- `forceUpgradeRequired: bool` - Indicates app version is too low
- `currentVersion: String?` - Current app version
- `requiredVersion: String?` - Minimum required version
- `resyncRequired: bool` - Indicates schema version mismatch
- `localSchemaVersion: int?` - Local Drift schema version
- `remoteSchemaVersion: int?` - Remote schema version from app_config

**New Startup Flow:**
```dart
1. Call VersionCheckService.checkVersion() FIRST (before database init)
2. Handle VersionCheckResult:
   - updateRequired → Return AppStartupData with forceUpgradeRequired=true
   - resyncRequired → Return AppStartupData with resyncRequired=true (placeholder for Phase 4)
   - ok → Continue with normal startup (database init, etc.)
```

**Key Design Decision:**
- Version check happens BEFORE database initialization to prevent incompatible app versions from accessing the database
- If version check network call fails, VersionCheckService returns cached result (graceful degradation)
- Database initialization is SKIPPED when force upgrade or resync is required

### 2. App Router (`lib/shared/core/app_router.dart`)

**New Redirect Logic:**
```dart
redirect: (context, state) {
  // Allow navigation to force-upgrade route always
  if (state.uri.path == '/force-upgrade') return null;

  // Check app startup state
  appStartupState.whenData((data) {
    // CRITICAL: Force upgrade required - block all other navigation
    if (data.forceUpgradeRequired) return '/force-upgrade';

    // CRITICAL: Schema resync required - block all other navigation
    if (data.resyncRequired) return '/welcome'; // Temporary until Phase 4

    // ... existing logic
  });
}
```

**Force Upgrade Route Builder:**
- Reads version info from `appStartupProvider` state
- Falls back to `extra` data for testing/direct navigation
- Passes `currentVersion` and `requiredVersion` to ForceUpgradeScreen

### 3. Integration Tests (`test/new_sync/app_startup_version_check_test.dart`)

**Tests (4 total, all passing):**
1. ✅ `proceeds with normal startup when version check passes`
   - Verifies VersionCheckService is called
   - Verifies database initialization happens
   - Verifies normal AppStartupData is returned
2. ✅ `returns force upgrade state when app version is too low`
   - Verifies forceUpgradeRequired=true
   - Verifies version data is populated
   - Verifies database initialization is SKIPPED
3. ✅ `returns resync state when schema version mismatch detected`
   - Verifies resyncRequired=true
   - Verifies schema version data is populated
   - Verifies database initialization is SKIPPED
4. ✅ `handles version check network failure gracefully`
   - Verifies app starts normally with cached ok result
   - Demonstrates graceful degradation

## Technical Notes

### Dependency Injection Pattern
All tests use proper Riverpod provider overrides:
- `versionCheckServiceProvider` → MockVersionCheckService
- `appStartupServiceProvider` → MockAppStartupService
- `appExternalDepsProvider` → Mock dependencies
- `appDatabaseProvider` → MockAppDatabase (only for tests that need it)

### Error Handling
- Version check failures are caught by VersionCheckService
- Cached results are used when network fails
- If no cached result, returns `VersionCheckResult.ok()` to allow app startup

### Navigation Blocking
- ForceUpgradeScreen has `PopScope(canPop: false)` to prevent back navigation
- App router blocks all navigation except `/force-upgrade` when force upgrade required
- Schema resync currently redirects to `/welcome` (Phase 4 will implement proper resync flow)

## Integration with Existing Code

### No Breaking Changes
- Existing startup flow is unchanged when version check passes
- All existing tests continue to pass
- Code generation updated successfully

### New Dependencies
- Added `version_check_service.dart` import to app_startup_provider
- Added `version_check_result.dart` import
- Added `database_provider.dart` import to app_router (for provider override in tests)

## Next Steps (Phase 4)

1. Replace placeholder resync handling with actual schema resync logic
2. Implement `performSchemaResync()` in VersionCheckService:
   - Check for dirty records
   - Upload dirty records (with backup on failure)
   - Delete database files
   - Recreate database with new schema
   - Trigger full sync
3. Create dedicated resync screen (instead of redirecting to /welcome)

## Files Modified

```
lib/features/app_startup/application/app_startup_provider.dart
lib/shared/core/app_router.dart
docs/features/new_sync/checklist.md
```

## Files Created

```
test/new_sync/app_startup_version_check_test.dart
docs/features/new_sync/notes/phase_1_5_version_check_integration.md
```

## Test Results

```
✅ All 4 tests passing
✅ flutter analyze clean
✅ Code generation successful
```

## Timeline

- **Start**: 2026-01-18 (Task claimed)
- **End**: 2026-01-18 (All tests passing)
- **Duration**: ~1 hour

---

*Phase 1.5 is COMPLETE. Phase 1 is now 9/15 tasks complete (60%).*
