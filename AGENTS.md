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
- PostgREST upserts: never `onConflict` on columns backed by a partial unique index (fails with
  42P10) — use `onConflict: 'id'`. And `uploadDirtyRecords()` swallows exceptions into a silent
  `UploadResult.failed()` — always check the result.
- Skills, agents, and commands must not restate these rules or hardcode volatile facts (schema
  versions, table lists, tier limits) — point at AGENTS.md and `/docs` instead, and read the
  current code for specifics.
- Keep initialization invariant explicit: `main()` for non-recoverable setup, recoverable init in startup flow.
- Do not run `flutter build` as assistant execution.
- Run codegen after Riverpod/Drift annotation/schema changes.
- Run `/task-checker` after major changes and before commit.
- Run `/release-cut` whenever a dev or prod build is cut or pushed — it keeps the Notion cut card an
  honest manifest of what the build carries. A missed cut is what makes the whole board go stale.
- Run `/sprint-sync` after landing work that maps to a Sprint Task, to keep the swimlane right.
- Notion writes are scoped to Lee-owned cards. Never edit a card owned by Xuan; never set Status or
  Branch on the Feature Request / Bug Report boards — those belong to Xuan's worker. See
  `.Codex/notion/boards.md`.

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
- Docs index (core vs `features/` history vs `_archived/`): `/docs/README.md`
- **Nutrition SSOT (ratified specs + conformance vectors, synced from the QA repo): `/docs/ssot/`** — `PRE-WORKOUT-BUNDLE-DIGEST.md` first; `spec/` is normative, `.md` beats `.html`, `DEVIATIONS.md` holds the open register. Fuelling algorithm changes must go green against `docs/ssot/vectors/`.
- Notion boards (IDs, release protocol, ownership boundary): `.Codex/notion/boards.md`
- Saved multi-agent workflows (`bug-batch`, `sweep`, `daily-work` — run via the Workflow tool when Lee asks; `daily-work` is launched by the `/daily` skill): `.Codex/workflows/`
- Architecture overview: `/docs/architecture/README.md`
- Technical patterns and standards: `/docs/technical/README.md`
- FOA and UI/controller boundaries: `/docs/technical/foa-architecture.md`
- App initialization flow: `/docs/technical/andrea/andrea_initialization.txt`
- Sync architecture and staleness model: `/docs/technical/sync-architecture.md`
- Training-integration API reference (Garmin/TrainingPeaks/FinalSurge/VDOT: endpoints, fields, example payloads): `/docs/integration/api-exploration/README.md`
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
