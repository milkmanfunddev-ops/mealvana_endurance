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
- Flutter test suites live under `test/` — layout after the 2026-07-29 cleanup:
  - `test/features/` — per-feature unit + widget tests (the bulk of the suite)
  - `test/shared/` — cross-cutting services, DB/DAOs, Sentry, widgets
  - `test/new_sync/` — sync-architecture safety net (current despite the name)
  - `test/db_flows/` — in-memory provider/DB flow tests (formerly `test/integration/flows/`; untagged, runs in CI)
  - `test/smoke_tests/`, `test/seeded_tests/` — screen render sweep + seeded-value assertions
  - `test/migrations/`, `test/privacy/`, `test/app_startup` (folded into `test/features/app_startup/`)
  - `test/e2e/` — live dev-cloud tests, excluded by the `e2e` tag, run manually (its failures are documented real engine bugs)
  - `test/manual_live/` — live TrainingPeaks/Final Surge API contract checks, excluded by the `integration` tag, need hand-refreshed OAuth tokens (see its README)
  - `test/helpers/`, `test/fixtures/` — shared harnesses and payloads (imported by several suites; do not move)
- Archived (no longer analyzed or run): `_archived/test/generated_migrations/` (v1/v2 drift dumps vs live schema v15), `_archived/test/local_edge_functions/` (npm shim never wired into CI).
- Edge-function TypeScript tests live under `supabase/functions/**` (Deno test files); see `supabase/functions/TESTING.md`.

## Source of Truth
- Flutter tests: `test/` — CI runs `flutter test --exclude-tags="integration || e2e"` with NO path argument (pr-validation in `codemagic.yaml`), so the gate is exactly "whatever is in `test/`".
- Edge function tests: `supabase/functions/**/*.test.ts`
- Algorithm test runner: `supabase/functions/run-algorithm-tests.sh`
- CI: `codemagic.yaml` (pr-validation = analyze + format + unit tests + algorithm tests; `integration-tests*` = Patrol; `web-e2e` = non-gating web boot), mirrored by `.github/workflows/tests-selfhosted.yml`.

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
flutter test test/db_flows
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

## Seam tests: stored ≠ recomputed (rule, 2026-08-26)

A **seam** is any place where data that crossed a process boundary (the server twin, a
persisted row, a cached blob) meets a local recompute — e.g. the hydration check comparing the
plan's stored fluid band to `OfflineMacroCalculator`'s answer. Two rules, learned from the
BEFORE-card hydration check being "not clickable" on the first real device while 74 unit tests
were green:

1. **Feed the seam producer-shaped data, never the local engine's own output.** Tests that build
   the "stored" side with the same call the code recomputes with are equal by construction and
   cannot fail. Use a fixture that mirrors the producer (`serverPreRun()` in
   `test/features/nutrition_plan/pre_workout_before_card_fixtures.dart`: the server's lb→kg
   factor `0.453592` vs the device's `0.45359237`, and the wire's 3-decimal rounding). Make
   "stored ≠ recomputed" the default fixture, not a special case.
2. **Never `assert` on data that crossed a process boundary.** A debug `assert` inside a tap
   callback kills the Future silently — no red test, no console error, the button just "does
   nothing". Compare with a tolerance, log, and keep the stored value; put the invariant in a
   test instead.

And the harness rule that follows: **every controller write path gets one test through the real
notifier** (`ProviderContainer` + the seeded-controller pattern in
`test/features/nutrition_plan/presentation/providers/hydration_check_controller_test.dart`), not
only through a widget-test host that stands in for the controller. The host proves the widget
contract; the notifier test proves the lookups (weight, frozen lead time, tempC) and the save.

## Verification Checklist
- `flutter test` completes without failures.
- `flutter test test/new_sync` passes (sync architecture safety net).
- Nutrition algorithm tests pass via `run-algorithm-tests.sh`.
- Any changed edge-function logic has a matching `supabase/functions/**.test.ts` run.
- If deployment-related changes were made, confirm `codemagic.yaml` test steps still match repository paths.

## Related Docs
- `/docs/technical/README.md`
- `/docs/deployment/README.md`
- `/docs/business_logic/README.md`
- `/docs/database/README.md`

## Deprecated/Legacy Notes
- Historical docs often reference `run-plan`, `generate-ai-nutrition-plan`, and `save-food-preferences`; current app code invokes a different set of functions (see `/docs/deployment/README.md`).
- `_archived/test/local_edge_functions/` was an npm shim around
  `supabase/functions/run-algorithm-tests.sh`; it was never invoked by CI and is
  archived. The real Deno edge-function tests live under `supabase/functions/**`.
