# Database Guide (Repo Truth)

## Current State (Repo Truth)
- App uses local-first data architecture:
  - Local DB: Drift/SQLite in app runtime
  - Cloud DB: Supabase/PostgreSQL for sync + shared backend state
- Drift schema version: read `schemaVersion` in `lib/shared/database/app_database.dart`
  (never a number from this file). Its doc comment carries the per-version changelog;
  the `onUpgrade` ladder is idempotent (`addColumn` / `ensureTable` guards) because web
  replays steps. Latest addition: `user_entitlements` (v19) — a read-only local cache of the
  user's Pro subscription row, written server-side by the `revenuecat-webhook`
  (`supabase/migrations/20260902080000_user_entitlements.sql`; see
  `docs/implement_mealplanning/04-entitlement.md`). It is not a `SyncableRepository`.
- Drift tables are the `tables:` list in `app_database.dart`; snapshots per version live in
  `database_schemas/drift_schemas/drift_schema_v<N>.json`
  (`dart run drift_dev schema dump lib/shared/database/app_database.dart database_schemas/drift_schemas/`).
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
