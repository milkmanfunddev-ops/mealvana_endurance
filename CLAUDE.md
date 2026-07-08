# Mealvana Endurance - AI Assistant Context

## Purpose
This is a routing guide for AI assistants in `mealvana_endurance`.
Keep this file concise. Detailed implementation guidance lives in `/docs`.

## Project Snapshot
- App: personalized endurance nutrition planning
- Stack: Flutter + Riverpod + Drift + Supabase
- Architecture: FOA (Andrea Bizzotto patterns)
- Platforms in repo: iOS, Android, Web

## Project Structure (High Level)
```text
mealvana_endurance/
├── lib/
│   ├── features/        # FOA feature modules
│   ├── shared/          # shared services, db, widgets, core wiring
│   ├── core/
│   ├── theme/
│   ├── main.dart
│   └── main_web.dart
├── supabase/
│   ├── functions/
│   └── migrations/
├── docs/
├── database_schemas/
├── test/
├── integration_test/
├── scripts/
└── web/
```

## Non-Negotiable Rules
- Enforce FOA layers: `presentation -> application -> domain <- data`.
- Keep UI screens UI-only (state, navigation, composition, validation).
- Put business logic in controllers/services (API calls, transforms, calculations, analytics).
- Controllers must use `@riverpod` + `AsyncNotifier` + `AsyncValue.guard()`.
- Do not hardcode user-facing strings when content/default systems exist.
- Use `MealvanaSnackbar`; do not use raw Flutter `SnackBar` directly.
- Preserve offline-first behavior with local-first writes and upload-state tracking.
- For coach-on-athlete writes that require immediate cross-user visibility, require remote server acknowledgment before success/navigation.
- Use repository-level on-demand sync (`ensureSynced`), not startup-wide sync-all.
- Keep initialization invariant explicit: `main()` for non-recoverable setup, recoverable init in startup flow.
- Do not run `flutter build` as assistant execution.
- Run codegen after Riverpod/Drift annotation/schema changes.
- Run `/task-checker` after major changes and before commit.

## App Initialization Pattern (Explicit)
- `main()` handles non-recoverable bootstrap (e.g., SDK initialization).
- Startup flow is managed by app startup widgets/providers/services.
- Drift DB initialization belongs in startup flow/provider path, not ad-hoc UI logic.
- Full reference: `/docs/technical/andrea/andrea_initialization.txt`

## Dev Simulator Login
`scripts/sim-dev-login.sh` signs the dev app into the booted iOS simulator using a login
stored in the macOS Keychain (service `mealvana-dev-login`). Prereqs: a booted simulator
and `idb`. See the script header for details.

## Docs Map
- Architecture overview: `/docs/architecture/README.md`
- Technical patterns and standards: `/docs/technical/README.md`
- FOA and UI/controller boundaries: `/docs/technical/foa-architecture.md`
- App initialization flow: `/docs/technical/andrea/andrea_initialization.txt`
- Sync architecture and staleness model: `/docs/technical/sync-architecture.md`
- Write consistency policy (offline-first vs remote-ack): `/docs/technical/write-consistency-policy.md`
- Content management system: `/docs/technical/content-management.md`
- Database architecture and schema docs: `/docs/database/README.md`
- Business logic and nutrition systems: `/docs/business_logic/README.md`
- Brick workouts: `/docs/brick/README.md`
- Testing strategy and commands: `/docs/test/README.md`
- Deployment hub (Supabase + Vercel): `/docs/deployment/README.md`
- Web mode details: `/docs/web_mode/README.md`
- Shorebird code push: `/docs/technical/shorebird-code-push.md`
- Sentry integration: `/docs/technical/sentry-integration.md`
- Responsiveness architecture: `/docs/technical/responsiveness.md`
