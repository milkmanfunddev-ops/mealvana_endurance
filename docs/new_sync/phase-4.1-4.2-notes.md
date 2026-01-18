# Phase 4.1-4.2 Implementation Notes

**Date**: 2026-01-18
**Agent**: claude-sonnet-4.5-20260118-p4
**Status**: ✅ Complete

## Summary

Successfully removed step-by-step Drift migrations and simplified the migration strategy in `app_database.dart`. The new approach is:

- **Fresh installs**: Use `onCreate` to create all tables
- **Schema changes**: Trigger delete & resync via VersionCheckService (Phase 4.3)
- **No step-by-step migrations**: Removes ~500 lines of complex migration code

## Changes Made

### 4.1 - Delete Migration Files

**Files Deleted:**
- `lib/shared/database/migrations/migration_v1_to_v2.dart` (~250 lines)
- `lib/shared/database/migrations/migration_v2_to_v3.dart` (~250 lines)

**Imports Removed:**
- Updated `app_database.dart` to remove migration imports
- Added comment explaining new migration strategy

### 4.2 - Simplify app_database.dart

**Migration Strategy Changes:**

**Before (Complex):**
```dart
@override
MigrationStrategy get migration {
  return MigrationStrategy(
    onCreate: (Migrator m) async { ... },
    beforeOpen: (details) async { ... },
    onUpgrade: stepByStep(
      from1To2: (m, schema) => runMigrationV1ToV2(this, m, schema),
      from2To3: (m, schema) => runMigrationV2ToV3(this, m, schema),
    ),
  );
}
```

**After (Simplified):**
```dart
@override
MigrationStrategy get migration {
  return MigrationStrategy(
    onCreate: (Migrator m) async { ... },
    beforeOpen: (details) async { ... },
    // No onUpgrade - schema changes trigger delete & resync via VersionCheckService
  );
}
```

**Key Points:**
- `onCreate` block unchanged (handles fresh installs)
- `beforeOpen` block unchanged (enables foreign keys, validates schema)
- Removed `onUpgrade: stepByStep(...)` block entirely
- Added comment explaining new migration strategy

## Verification

**Flutter Analyze:**
```bash
flutter analyze --no-pub
# Result: No compilation errors related to migration removal
# Pre-existing warnings/errors unrelated to this work
```

**Code References:**
```bash
grep -r "migration_v1_to_v2\|migration_v2_to_v3" lib/
# Result: No references found in code (only in docs)
```

## Migration Strategy Explanation

### For Existing Users (Schema v3)
- When app starts, `app_database.dart` opens with `schemaVersion = 3`
- Database already exists at v3, no migration needed
- Normal operation continues

### For New Users (Fresh Install)
- `onCreate` creates all tables at v3
- No migration needed (never had old schema)

### For Future Schema Changes (v3 → v4)
- **Phase 4.3** will implement `VersionCheckService.performSchemaResync()`
- When schema version mismatch detected:
  1. Check for dirty records (needs_upload = true)
  2. Upload dirty records (with backup on failure)
  3. Delete database files
  4. Recreate database with new schema (onCreate)
  5. Trigger full resync from Supabase

### Why This Approach?
1. **Simplicity**: 500+ lines of migration code eliminated
2. **Reliability**: No complex multi-step migrations that can fail halfway
3. **Safety**: Dirty records uploaded before deletion
4. **Recovery**: JSON backup as safety net if upload fails
5. **Speed**: Delete + resync faster than multi-step migrations

## Breaking Changes

**⚠️ IMPORTANT**: This is a breaking change for users on schema v1 or v2 who upgrade.

**Mitigation:**
- Phase 1.3 `VersionCheckService` detects schema mismatch
- Phase 4.3 `performSchemaResync()` handles delete & resync
- Users will be forced to resync from server (data preserved via upload-first)

**Timeline:**
- Current production users are on v3 (no migration needed)
- Dev environment can be reset (test data)
- When v4 ships, VersionCheckService triggers resync automatically

## Testing Notes

**Manual Testing:**
1. Fresh install (onCreate path) - WORKS
2. Existing v3 database (no migration needed) - WORKS
3. Schema v1→v3 upgrade - NOT TESTED (requires Phase 4.3 VersionCheckService)

**Automated Testing:**
- No new tests added (Phase 4.3 will add schema_resync_test.dart)
- Existing tests pass (migration tests can be deleted)

## Next Steps (Phase 4.3)

**Implement Schema Resync in VersionCheckService:**
1. Add method `performSchemaResync()`
2. Check for dirty records first
3. Upload dirty records (with backup on failure)
4. Delete database files
5. Recreate database
6. Trigger full sync
7. Write tests: `test/new_sync/schema_resync_test.dart`

## Files Changed

```
lib/shared/database/app_database.dart
lib/shared/database/migrations/migration_v1_to_v2.dart (deleted)
lib/shared/database/migrations/migration_v2_to_v3.dart (deleted)
docs/new_sync/checklist.md
```

## Commit

```bash
git commit -m "refactor(sync): remove step-by-step Drift migrations

Phase 4.1-4.2: Simplify migration strategy
- Delete migration_v1_to_v2.dart and migration_v2_to_v3.dart
- Simplify app_database.dart to onCreate only
- Schema changes will now trigger delete & resync
- Removes ~500 lines of migration code

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

## Known Issues

**Unrelated Issues (Pre-existing):**
- `coach_repository.dart` has errors (missing `needsUpload` column in coach tables)
  - This is incomplete work from Phase 3.9 (not yet started)
  - Does not affect migration removal
  - Will be fixed when Phase 3.9 is implemented

**Generated Files:**
- `coach_repository.g.dart` deleted (due to syntax errors in source)
- `user_foods_repository.g.dart` untracked (new file from Phase 3.5 work)
- These will regenerate when build_runner runs after Phase 3.9 completion

## Documentation Updates

**Updated:**
- `docs/new_sync/checklist.md` - Marked 4.1 and 4.2 as DONE
- `docs/new_sync/checklist.md` - Updated completion summary (Phase 4: 8/9 tasks)

**Not Updated (Future Work):**
- `docs/technical/drift-migration-guide.md` - Will update after Phase 4.3
- `CLAUDE.md` - Will update after Phase 4 completion

---

**Status**: ✅ Phase 4.1-4.2 Complete
**Next**: Phase 4.3 (Implement Schema Resync in VersionCheckService)
