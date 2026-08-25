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
  versions, table lists, tier limits) — point at CLAUDE.md and `/docs` instead, and read the
  current code for specifics.
- Keep initialization invariant explicit: `main()` for non-recoverable setup, recoverable init in startup flow.
- Do not run `flutter build` as assistant execution.
- Run codegen after Riverpod/Drift annotation/schema changes.
- Run `/task-checker` after major changes and before commit.
- Run `/release-cut` whenever a dev or prod build is cut or pushed — it keeps the Notion cut card an
  honest manifest of what the build carries. A missed cut is what makes the whole board go stale.
- Run `/sprint-sync` after landing work that maps to a Sprint Task, to keep the swimlane right.
- Run `/design-sync` (user-invoked; Claude cannot launch it) after any change under `lib/theme/` or
  `lib/shared/widgets/kyle_design/`, and after a design ratification lands in `docs/ssot/spec/design/`.
  The Claude Design project is a sink regenerated from this repo — never hand-edit it. Authority map
  and promotion path: `docs/ssot/spec/design/source-authority.md`.
- Notion writes are scoped to Lee-owned cards. Never edit a card owned by Xuan; never set Status or
  Branch on the Feature Request / Bug Report boards — those belong to Xuan's worker. See
  `.claude/notion/boards.md`.

## Backend Deploys & Codemagic Cost Discipline
- Before ANY backend/deploy/schema/edge-function work, read
  `../ops/docs/supabase-deploy-playbook.md` — **§0 first** (current state + standing orders), then
  the agent brief `docs/ssot/intake/2026-08-19-phase-c-deploy-brief.md`. Ruling precedence there:
  ▶ Lee 08-20 > ▶ Lee 08-19 > older text > the brief.
- **Codemagic bills real minutes (free tier, ~9¢/min; no Pro plan). Pushing = spending.**
  Per `codemagic.yaml` (read it for current truth): a push to `develop` auto-cuts the dev iOS
  TestFlight build (put `[skip ci]` in the commit title for docs-only pushes — there is no changeset filter); a push to any `release/*` branch auto-cuts
  the release builds. Batch work into few pushes; never push `release/*` until the playbook's
  P1–P3 gates are green; never add or re-arm a Codemagic workflow without asking.
- **Codemagic never runs integration/Patrol tests** (Lee, 2026-08-20 — one develop-push run billed
  1h31m ≈ $9). The three `integration-tests*` workflows are trigger-disabled (`events: []`) in
  `codemagic.yaml`; leave them disabled. Integration tests run locally
  (`patrol test` / `run-algorithm-tests.sh --e2e`) or free on Lee's M1 mini — the self-hosted
  GitHub Actions workflow `.github/workflows/tests-selfhosted.yml`, which fires on every push/PR
  (`gh run list --workflow=tests-selfhosted.yml` to check; runner must be online).
- If a change doesn't need a cloud build to verify, verify it locally (flutter test, simulator,
  Deno/vector runners) instead of pushing to find out.
- `MACRO_DASHBOARD_ENABLED` is pending full removal (Lee, 2026-08-20: delete the flag from app
  code + the codemagic.yaml force-on). Don't add new hide-flags for dev features — dev is meant
  to be shipped visible and broken freely.

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
- Notion boards (IDs, release protocol, ownership boundary): `.claude/notion/boards.md`
- Saved multi-agent workflows (`bug-batch`, `sweep`, `daily-work` — run via the Workflow tool when Lee asks; `daily-work` is launched by the `/daily` skill): `.claude/workflows/`
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
