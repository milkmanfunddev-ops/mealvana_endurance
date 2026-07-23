# Testing Handbook (Repo Truth)

## 📌 Latest status ledger (2026-07, READ FIRST)
- **`coverage-status-2026-07.md`** — post-release/1.22.0 coverage push: layer-by-layer
  state, the Patrol flavor model (flavor-aware launcher + creds, prod CI workflow),
  the auto-discovery edge-fn runner, and the list of REAL bugs the suites currently
  expose (do not "fix" those tests). Supersedes the status claims in the 2026-06 docs
  below where they conflict.

## 📋 Current Strategy & Plan (2026-06, START HERE)
The authoritative, up-to-date testing docs (supersede the older `roadmap.md`,
`testing-strategy-2026.md`, `current_progress.md`, and the `phase_*` files):
- **`testing-strategy-comprehensive-2026.md`** — the canonical strategy (test pyramid, test types to add, Flutter web, Firebase Test Lab, CI, AI tooling, CodeRabbit + Sentry).
- **`testing-build-plan-2026.md`** — the sequenced execution plan + **Progress Log (what's done / live-E2E findings / what remains)**. ← *latest status lives here.*
- **`coverage-gaps-2026.md`** — grounded map of what is NOT yet tested (edge fns / Flutter services / widget / Patrol) + sequence to "test everything". ← *start here for new coverage.*
- **`test-recommendations-2026.md`** — prioritized next tests (P0s) per layer.
- **`BUGS_FOUND.md`** — bugs the suite has surfaced (all 17 from the 2026-06-25 sweep fixed).
- **`NEED_FROM_LEE.md`** — items that need a human (Sentry token, dev publishable key, etc.).
- **`testing-roadmap-2026.md`** — the Patrol + edge-fn coverage map.
- **`edge-function-test-plan-2026.md`** — the nutrition-engine unit-test plan (failure modes, real-catalog reality-check).

Current edge-fn suite: `supabase/functions/run-algorithm-tests.sh` (§1 = 15 deterministic groups; §2 = live E2E vs dev). Patrol flows: `integration_test/flows/`.

## Current State (Repo Truth)
- Flutter test suites live under `test/` with heavy coverage in:
  - `test/new_sync/`
  - `test/integration/flows/`
  - `test/features/`
  - `test/shared/`
- Migration and schema tests exist at `test/migrations/` and `test/generated_migrations/`.
- Edge-function TypeScript tests currently live under `supabase/functions/**` (Deno test files).
- CI test workflow is `.github/workflows/test.yml`.
- Current test files: **139 Dart** (`*_test.dart`, incl. `test/smoke_tests` 8 + `test/seeded_tests` 5 + `integration_test/flows`) and **53 Deno** (`*.test.ts`).

## Source of Truth
- Flutter tests: `test/`
- Edge function tests: `supabase/functions/**/*.test.ts`
- Algorithm test runner: `supabase/functions/run-algorithm-tests.sh`
- CI workflow: `.github/workflows/test.yml`
- Dev/Prod deploy workflows (also run tests):
  - `.github/workflows/deploy-dev.yml`
  - `.github/workflows/deploy-prod.yml`

## Runbook / Commands
- Run all Flutter tests:
```bash
flutter test
```
- Run sync-focused suites:
```bash
flutter test test/new_sync
```
- Run integration flow suites:
```bash
flutter test test/integration/flows
```
- Run migration tests:
```bash
flutter test test/migrations/v1_to_v2_migration_test.dart
```
- Run algorithm unit tests (Deno):
```bash
./supabase/functions/run-algorithm-tests.sh
```
- Run algorithm unit + E2E tests (requires env):
```bash
export SUPABASE_URL=https://<project-ref>.supabase.co
export SUPABASE_ANON_KEY=<anon-key>
./supabase/functions/run-algorithm-tests.sh --e2e
```
- Run a specific edge function integration test directly:
```bash
deno test --allow-net --allow-env supabase/functions/generate-macros-v4/index.test.ts
```

## Verification Checklist
- `flutter test` completes without failures.
- `flutter test test/new_sync` passes (sync architecture safety net).
- Nutrition algorithm tests pass via `run-algorithm-tests.sh`.
- Any changed edge-function logic has a matching `supabase/functions/**.test.ts` run.
- If deployment-related changes were made, confirm test workflow commands still match repository paths.

## Related Docs
- `/docs/technical/README.md`
- `/docs/deployment/README.md`
- `/docs/business_logic/README.md`
- `/docs/database/README.md`

## Deprecated/Legacy Notes
- Historical docs often reference `run-plan`, `generate-ai-nutrition-plan`, and `save-food-preferences`; current app code invokes a different set of functions (see `/docs/deployment/README.md`).
- `test/local_edge_functions/` is a compatibility harness for CI/deploy workflows.
  It delegates to `supabase/functions/run-algorithm-tests.sh`, where the real
  Deno edge-function tests live.
