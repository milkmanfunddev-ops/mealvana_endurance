# Test Coverage Status — July 2026 (release/1.22.0 push)

Snapshot of where automated coverage stands after the 2026-07-21/22 coverage push,
what each layer covers, how it runs in CI, and what remains. Companion to
`testing-strategy-comprehensive-2026.md` (strategy) — this file is the *status ledger*.
Update it when a layer materially changes; stale claims here are worse than no claims.

## The layers at a glance

| Layer | Where | Size | CI gate | State |
|---|---|---|---|---|
| Unit + widget (Flutter) | `test/` | ~225 files | `pr-validation` (release/* PRs + develop pushes) | Green |
| Screen smoke (render/overflow) | `test/smoke_tests/` | 88/88 non-archived screens | same | Green |
| Edge-function local (Deno) | `supabase/functions/**/*.test.ts` | 77 discovered / 71 run / 1 quarantined / 5 remote | same (`run-algorithm-tests.sh`) | Green |
| Edge-function remote e2e (Deno) | same, `--e2e` flag | 5 files vs deployed dev | manual only | 2/5 pass — dev deploy lags HEAD |
| Cloud e2e (Dart, dev backend) | `test/e2e/dev_cloud_e2e_test.dart` | 13 tests | excluded (`e2e` tag) — bug-finder, run manually | 8/13 — 5 fails are REAL engine bugs (below) |
| Patrol integration (iOS sim) | `integration_test/flows/` | 17 flows + smoke | `integration-tests` (dev, release/* PRs), `integration-tests-prod` (prod backend, release/* pushes) | see per-flow table |
| Web e2e (boot smoke) | `scripts/run_web_e2e.sh` | 1 boot walk | `web-e2e` (non-gating) | unchanged |

## Patrol: flavor model (NEW — read before touching flows)

- Every flow boots via `integration_test/helpers/flow_launcher.dart` → `launchApp()`,
  which picks `main_prod` vs `main_dev` from `TestConfig.isProd` (driven by the
  `SUPABASE_URL` in whichever `--dart-define-from-file` env file the run passes).
  **Never import `main_dev.dart` in a flow** — that was the old pattern and it made
  `--flavor prod` runs silently test the dev backend.
- Credentials are flavor-aware: `TestConfig.loginEmail/loginPassword` pick the dev or
  prod pair from `secrets/integration_test.env` (`INTEGRATION_TEST_*` = dev,
  `INTEGRATION_TEST_PROD_*` = prod). Same file is mirrored in the Codemagic
  `INTEGRATION_TEST_ENV` secure var — **in both `mealvana_dev` and `mealvana_prod`
  groups**; update both when it changes.
- Shared login walk: `ensureAuthenticated($)` in `flow_launcher.dart` (session reuse →
  email login → sentinel `bottom_nav.timeline_tab`). Flows self-skip with
  `noAuthSkipMessage()` when unauthenticated.
- Prod runs use the prod tester account and create/delete uniquely-named rows under it.
  Flows that would spend AI money (`jade_chat`) self-skip on prod via `TestConfig.isProd`.

### Patrol flow inventory

| Flow | Covers | Notes |
|---|---|---|
| auth | welcome → email login → tabs shell | uses flavor creds |
| onboarding_signup | full anonymous onboarding → signup | creates fresh user |
| google_login | Google OAuth | Android only, iOS self-skips |
| events_crud | event create/edit/delete + DB-visible outcomes | strong assertions |
| activities_crud | activity → macro gen → plan create → delete | was hanging; fix in flows refactor |
| formula_pin | pin/unpin library formula | was hanging; fix in flows refactor |
| formula_create_pin | personal formula create + swap-food search + pin | |
| fuel_timeline | filter pills + toggles | weak (controls-exist), data-agnostic by design |
| meal_card_interaction | manual meal log → edit → swipe-delete | was hanging; fix in flows refactor |
| integrations_connect | FS/TP/Garmin OAuth launch boundary | no credential entry on iOS |
| settings_persist | body-comp weight persists across nav | data-integrity guard |
| settings_sweep (NEW) | 8 settings screens crash-sweep | landmark asserts per screen |
| meal_log_build (NEW) | build-a-meal via search → log → delete | no AI needed |
| learn (NEW) | Learn tab → lesson → player | skips if catalog empty |
| event_checklist_carbload (NEW) | race-day checklist + carb-load protocol screens | cleans up its event |
| jade_chat (NEW) | send message → assistant reply arrives | dev only; skips if entry gated off |
| paywall_render (NEW) | /pro renders pricing | never taps buy |

### Still uncovered by Patrol (accepted gaps, revisit post-1.22)
Password reset; meal-log AI paths (photo/describe — camera + AI spend); barcode scan
(camera impossible on sim); coach mode end-to-end (needs a second, coach-role account);
weather detail; recipes; share-plan; privacy-consent screen (region-gated); force-upgrade.

## Edge functions

- `run-algorithm-tests.sh` now **auto-discovers** every `*.test.ts` (was: hand-list that
  silently orphaned ~57 of ~90 files). Prints found/run/quarantined counts and fails on
  mismatch. New test files are picked up with zero script edits.
- Remote tests (filename `*e2e*`/`*integration*` or reads `SUPABASE_ANON_KEY`) run only
  under `--e2e`, which now **fails hard** when SUPABASE_URL/ANON_KEY are missing.
- `revenuecat-webhook` (money path) has its first tests: auth, event types, grant
  amounts, idempotency (23505 → 200), malformed bodies.
- Quarantined (1): `generate-macros-v4/pre-workout-matrix.test.ts` — top-up windows
  deliver ~55g vs a 39g ceiling for 3 athlete profiles. Needs domain review (stale
  2026-05-05 expectations vs real over-delivery), not a mechanical fix.

## Known REAL bugs the suites currently expose (do not "fix" the tests)

1. **Before-phase adherence misses its own contract** (`MACRO_CONSTRAINT_RANGES`
   0.9–1.1): protein 81% (50kg/5K) and 122% (70kg/10mi); carbs 112% (90kg/HM) and
   89% (65kg/marathon). `test/e2e/dev_cloud_e2e_test.dart` strict cases.
2. **After-phase shortfall declaration is non-deterministic**: 80kg cyclist case
   delivers 51–60% of the 96g carb target; some runs declare the shortfall via
   `plan.after_shortfalls`, some stay silent. The before phase has **no shortfall
   channel at all**. Silent under-delivery breaks the honest-shortfall contract.
3. **Pre-workout top-up over-delivery** — the quarantined matrix test above.
4. **`DataSyncService` download-side silent failure**: if every entity download fails
   it still returns `true` and stamps `last_sync_timestamp`. Pinned by a canary test in
   `test/new_sync/data_sync_service_test.dart` (invert it when fixed).
5. **`/pro` is unreachable** — route exists, zero UI callers. Paywall can't be seen by
   users. (`paywall_render_flow_test.dart` documents this.)
6. Jade's coach banner isn't mounted anywhere in `lib/`; Jade is only reachable through
   the feature-gated route.
7. `FoodPreferencesV2Screen`: zero callers in `lib/` (likely dead code) + repeats the
   business-logic-in-initState FOA violation.
8. **Dev-deployed edge fns lag HEAD**: `--e2e` fails for calculate-daily-macros /
   generate-macros-v4 / generate-nutrition-plan-v3 against dev. Redeploy dev to clear.

## CI wiring (Codemagic is source of truth)

- `pr-validation`: analyze + format + unit + Deno local — release/* PRs **and every
  develop push** (added 2026-07-21).
- `integration-tests`: full Patrol suite, dev flavor — release/* PRs.
- `integration-tests-prod` (NEW): full Patrol suite, **prod flavor against the prod
  backend** — push to release/* + manual. Uses `mealvana_prod` group (has its own
  `INTEGRATION_TEST_ENV` copy).
- `integration-test-quick`: manual single-flow run (`TEST_FLOW` var).
- GitHub self-hosted M1 workflow mirrors the gates; patrol_cli pinned 4.4.0 there
  (unpinned CLI refuses patrol 4.6.1).

## Remaining work (priority order)

1. Confirm the 3 previously-hanging flows are green on CI (fix pattern: noSettle taps +
   manual poll loops instead of settles around Fuel-Timeline `Dismissible`s).
2. First live `integration-tests-prod` run — validates the prod credential path E2E.
3. Fix engine bugs #1–#3 above, then un-quarantine the matrix test and watch the strict
   e2e cases go green (they are the regression net for that work).
4. Redeploy dev edge fns; then consider promoting `--e2e` to a non-gating CI step.
5. Coach-mode Patrol coverage (needs dedicated coach test account on dev + prod).
6. Add a dedicated QA prod account (current prod tester is Lee's real email with a weak
   password — fine for now, rotate once QA account exists).
7. Golden-test coverage is thin (2 widgets); expand for the highest-churn cards.
