# Mealvana Endurance - AI Assistant Context

Routing guide for agents in this repo. Keep it short; detail lives in `/docs`.

## Snapshot
- Personalized endurance nutrition planning. Flutter + Riverpod + Drift + Supabase. iOS, Android, Web.
- Architecture: FOA (Andrea Bizzotto): `lib/features/<feature>/{presentation,application,domain,data}`,
  shared services and widgets in `lib/shared/`, tokens in `lib/theme/`. Backend in `supabase/`.
- Nutrition truth comes from the QA repo (`../mealvana_endurance_qa`), mirrored verbatim into
  `docs/ssot/`. Never edit `docs/ssot/` here; change it in the QA repo and re-sync.

## Non-negotiable rules
- FOA layers: `presentation -> application -> domain <- data`. Screens are UI-only; business
  logic lives in controllers and services. Controllers are `@riverpod` + `AsyncNotifier` +
  `AsyncValue.guard()`. Run codegen after Riverpod or Drift annotation/schema changes.
- No hardcoded user-facing strings where the content system exists. Use `MealvanaSnackbar`, never
  raw `SnackBar`.
- Offline-first: local write first with upload-state tracking; repository-level `ensureSynced`,
  never startup sync-all. Coach-on-athlete writes that must be visible cross-user wait for the
  remote ack before reporting success.
- PostgREST upserts never `onConflict` on a partial-unique-index column (42P10); use
  `onConflict: 'id'`. `uploadDirtyRecords()` swallows failures into `UploadResult.failed()`;
  always check the result.
- Design-bearing widgets are implemented once in `lib/shared/widgets/kyle_design/` under their
  spec name (`docs/ssot/spec/design/components/<name>.md`), header comment citing spec path and
  version. Features compose them, never redefine them. One token registry (`lib/theme/kyle_design/`):
  no `Color(0x…)` literals or Material `Colors.*` for brand semantics outside `lib/theme/`.
  Run `/design-sync` after changes under `lib/theme/`, `kyle_design/`, or `docs/ssot/spec/design/`.
- Fuelling algorithm changes must go green against `docs/ssot/vectors/`. Seam tests feed
  producer-shaped data, never the local engine's own output; every controller write path gets one
  test through the real notifier (`docs/test/README.md`, Seam tests).
- `main()` does non-recoverable bootstrap only; recoverable init (Drift, etc.) goes in the startup
  flow (`docs/technical/andrea/andrea_initialization.txt`).
- Don't add hide-flags for dev features; dev ships visible and broken freely.
- Skills and agents added to `.claude/` must not restate these rules or hardcode volatile facts;
  point here and at `/docs` and read the current code.

## Deploys and CI cost
- Before any backend, schema, or edge-function work read `docs/deployment/supabase-deploy-playbook.md`
  (ordering, `app_config` window, function versioning) and the status header of the current bundle
  runbook it lists. Newest ruling wins.
- Prod `app_config` is written only at Xuan's explicit direction, in default permission mode, after
  a read-only check (playbook §7).
- Codemagic bills real minutes; pushing is spending. A push to `develop` auto-cuts the dev iOS
  build (`[skip ci]` in the title for docs-only pushes); a push to `release/*` cuts release builds
  and must wait for the playbook §8 gates. Batch pushes. Never add or re-arm a Codemagic workflow
  without asking. Codemagic never runs Patrol or integration tests; those run locally or on the
  self-hosted runner (`.github/workflows/tests-selfhosted.yml`). Verify locally before pushing.
- Never run `flutter build` as assistant execution.

## Dev simulator login
`scripts/sim-dev-login.sh` signs the dev app into the booted simulator using the Keychain entry
`mealvana-dev-login` (needs `idb`).

## Docs map
- Index of everything, incl. `features/` history and `_archived/`: `docs/README.md`
- **Nutrition SSOT** (specs, vectors, conformance, deviations): `docs/ssot/`, start at
  `PRE-WORKOUT-BUNDLE-DIGEST.md`; `.md` beats `.html`
- Architecture and patterns: `docs/architecture/`, `docs/technical/` (FOA, sync, write
  consistency, content management, responsiveness, Shorebird, Sentry)
- Database and schema dumps: `docs/database/`, `docs/dev_schema.txt`, `docs/prod_schema.txt`
- Business logic and nutrition systems: `docs/business_logic/`, brick workouts `docs/brick/`
- Meal planning (Vana): research base `docs/new_mealplanning/`, build phases
  `docs/implement_mealplanning/`; Kroger integration `docs/kroger/`
- Macro screens and Kyle design work: `docs/kyle/`
- Training integrations (Garmin, TrainingPeaks, FinalSurge, VDOT): `docs/integration/`
- Testing strategy and commands: `docs/test/`
- Deployment, CI/CD, flavors, release checklist: `docs/deployment/`, `docs/ci-cd/`,
  `docs/flavors/`, `docs/release/`
- Web mode: `docs/web_mode/`; privacy and requirements: `docs/privacy/`, `docs/requirements/`
- Retired project skills, agents, commands, workflows (not loaded): `.claude/archive/`

## Agent skills

### Issue tracker

Local markdown: one directory per feature under `.scratch/`, spec plus numbered
issue files. See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical roles, each label string equal to its name. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `CONTEXT.md` at the root plus `docs/adr/`. See `docs/agents/domain.md`.
