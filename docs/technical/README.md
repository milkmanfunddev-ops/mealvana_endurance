# Technical Guide (Repo Truth)

## Current State (Repo Truth)
- Core app architecture follows FOA with clear layering:
  - `presentation -> application -> domain <- data`
- State management pattern is Riverpod `@riverpod` + `AsyncNotifier`.
- Local storage is Drift, with platform-specific database connection files:
  - native: `connection_native.dart`
  - web: `connection_web.dart`
- Startup flow is centralized through app startup providers/widgets, not direct DB init in `main()`.

## Source of Truth
- FOA rules: `/docs/technical/foa-architecture.md`
- App startup pattern: `/docs/technical/andrea/andrea_initialization.txt`
- Sync architecture: `/docs/technical/sync-architecture.md`
- Content management: `/docs/technical/content-management.md`
- Database implementation: `lib/shared/database/`
- App startup implementation: `lib/features/app_startup/` + `lib/shared/services/app_startup_service.dart`

## Runbook / Commands
- Riverpod/Drift codegen:
```bash
dart run build_runner build --delete-conflicting-outputs
```
- Static analysis:
```bash
flutter analyze
```
- Full test pass:
```bash
flutter test
```
- Quick FOA compliance spot-check:
```bash
rg -n "class .*Controller|@riverpod|AsyncNotifier|StateNotifier" lib/features -S
```

## Verification Checklist
- Controllers use `@riverpod` and AsyncNotifier patterns.
- UI screens do not contain edge-function calls or heavy business logic.
- Content-facing UI text is sourced through content/defaults, not ad-hoc literals.
- Startup flow keeps recoverable initialization in startup services/providers.

## Related Docs
- `/docs/architecture/README.md`
- `/docs/database/README.md`
- `/docs/deployment/README.md`
- `/docs/test/README.md`

## Deprecated/Legacy Notes
- Older technical docs may reference legacy function names and stale deployment commands.
- Use `/docs/deployment/README.md` and current workflows/scripts for deployment truth.
