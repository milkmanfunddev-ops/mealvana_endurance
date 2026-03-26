# Database Guide (Repo Truth)

## Current State (Repo Truth)
- App uses local-first data architecture:
  - Local DB: Drift/SQLite in app runtime
  - Cloud DB: Supabase/PostgreSQL for sync + shared backend state
- Drift schema version in code is `6` (`AppDatabase.schemaVersion`).
- Drift table set in code currently includes 24 tables (declared in `app_database.dart`).
- Database connection is platform-specific:
  - Native: `connection_native.dart`
  - Web: `connection_web.dart` (Wasm database assets)
- Sync strategy is repository-level on-demand synchronization, not global startup sync.

## Source of Truth
- Schema version + table declarations: `lib/shared/database/app_database.dart`
- Table definitions: `lib/shared/database/tables/`
- DAOs: `lib/shared/database/daos/`
- Sync coordinator: `lib/shared/services/sync/sync_coordinator.dart`
- Version check + schema resync flow: `lib/shared/services/version_check_service.dart`
- Schema snapshots and SQL artifacts: `database_schemas/`

## Runbook / Commands
- Check schema version:
```bash
rg -n "int get schemaVersion" lib/shared/database/app_database.dart
```
- List table definition files:
```bash
find lib/shared/database/tables -maxdepth 1 -type f -name '*.dart' | sort
```
- Inspect schema snapshots:
```bash
find database_schemas -maxdepth 2 -type d | sort
```
- Run migration test suite:
```bash
flutter test test/migrations/v1_to_v2_migration_test.dart
```

## Verification Checklist
- Documented schema version matches `AppDatabase.schemaVersion`.
- Table counts/descriptions in docs are consistent with `app_database.dart` declarations.
- Sync docs do not claim startup-wide full sync behavior.
- Web database docs align with `connection_web.dart` implementation.

## Related Docs
- `/docs/technical/sync-architecture.md`
- `/docs/architecture/README.md`
- `/docs/web_mode/README.md`
- `/docs/deployment/README.md`

## Deprecated/Legacy Notes
- Older docs may reference previous schema versions, table counts, or migration strategies.
- Use `database_schemas/` artifacts and `app_database.dart` as canonical truth.
