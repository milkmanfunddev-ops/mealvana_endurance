# App Architecture (Repo Truth)

## Current State (Repo Truth)
- Platform targets in repo: iOS, Android, and Web.
- Architecture style: Feature-Oriented Architecture (FOA).
- Layer direction: `presentation -> application -> domain <- data`.
- State management: Riverpod with generated providers and AsyncNotifier controllers.
- Local-first persistence: Drift database with schema version `6`.
- Remote backend: Supabase (PostgreSQL + Edge Functions), with on-demand repository sync.

## Source of Truth
- App entrypoints: `lib/main.dart`, `lib/main_web.dart`
- Startup flow: `lib/features/app_startup/` and `lib/shared/services/app_startup_service.dart`
- Database schema/version: `lib/shared/database/app_database.dart`
- Feature modules: `lib/features/`
- Sync coordinator: `lib/shared/services/sync/sync_coordinator.dart`
- External deps wiring: `lib/shared/services/app_external_deps.dart`

## Runbook / Commands
- Inspect feature modules:
```bash
find lib/features -maxdepth 1 -type d | sort
```
- Verify schema version:
```bash
rg -n "int get schemaVersion" lib/shared/database/app_database.dart
```
- Inspect active edge-function invocation points:
```bash
rg -n "functions\.invoke\(" lib -S
```

## Verification Checklist
- FOA layer boundaries are preserved in changed code.
- Startup initialization remains in startup flow (not direct DB setup in `main()`).
- Repository sync remains on-demand (`ensureSynced`/coordinator-driven).
- Architecture docs and deployment docs do not reference deprecated edge-function names as active.

## Related Docs
- `/docs/technical/README.md`
- `/docs/database/README.md`
- `/docs/deployment/README.md`
- `/docs/business_logic/README.md`

## Deprecated/Legacy Notes
- Older architecture narratives mention schema versions/table counts/function sets that no longer match current code.
- Keep historical context in `/docs/_archived/` and use this file for current architecture orientation.
