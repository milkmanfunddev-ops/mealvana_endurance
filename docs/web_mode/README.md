# Web Mode Guide (Repo Truth)

## Current State (Repo Truth)
- Web target is enabled and deployed via Vercel.
- Web entrypoint is `lib/main_web.dart`.
- Database on web uses Drift Wasm executor via `lib/shared/database/connection_web.dart`.
- Required web assets are present:
  - `web/sqlite3.wasm`
  - `web/drift_worker.js`
- Canonical build/deploy path is:
  - `vercel.json` -> `scripts/build_web.sh`

## Source of Truth
- `lib/main_web.dart`
- `lib/shared/database/app_database.dart`
- `lib/shared/database/connection_web.dart`
- `web/sqlite3.wasm`
- `web/drift_worker.js`
- `vercel.json`
- `scripts/build_web.sh`
- `pubspec.yaml`

## Runbook / Commands
- Run web app locally:
```bash
flutter run -d chrome -t lib/main_web.dart
```
- Local web build using project script (recommended):
```bash
./scripts/build_web.sh --local
```
- What the deployment build currently runs:
```bash
flutter build web --release --pwa-strategy=none -t lib/main_web.dart --dart-define-from-file=.dart_defines.json
```
- Confirm required web DB assets:
```bash
ls web/sqlite3.wasm web/drift_worker.js
```

## Verification Checklist
- `connection_web.dart` uses `WasmDatabase.open(...)` with `sqlite3.wasm` + `drift_worker.js`.
- `app_database.dart` uses conditional import for native vs web connection.
- `vercel.json` still points to `scripts/build_web.sh`.
- `scripts/build_web.sh` still builds `lib/main_web.dart` and outputs `build/web`.
- Vercel environment variables include required Supabase keys.

## Related Docs
- `/docs/deployment/README.md`
- `/docs/database/README.md`
- `/docs/technical/README.md`

## Deprecated/Legacy Notes
- Older docs mention `drift_web` package setup and `sqlite3_web` prerequisites; current implementation uses Drift Wasm connection in `connection_web.dart`.
- Older docs may describe `--wasm` as the canonical production build flag; current repo deployment path uses `scripts/build_web.sh` as source of truth.
