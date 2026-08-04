# Mealvana Endurance — Full Testing Build Plan

**Created 2026-06-23 · Last updated 2026-06-24.** Companion to
`testing-strategy-comprehensive-2026.md` (the canonical strategy),
`testing-roadmap-2026.md` (the coverage map), and `edge-function-test-plan-2026.md`
(the nutrition-engine test detail). This is the **sequenced execution plan**.
Ordered by dependency and leverage; executed incrementally across sessions.

> **Jump to [Progress Log (2026-06-24)](#progress-log-2026-06-24)** for what's done,
> what the live E2E uncovered, and what remains. The phases below are the original
> plan with ✅/🟡 status annotations.

## 2026-06-25 — Strategy refocus (Lee)

This supersedes scope assumptions below. Direction from Lee:

1. **Nutrition-plan accuracy = formulas + pinned formulas ONLY.** That is the
   algorithm-correctness surface we test for "the numbers are right." Patrol +
   edge-fn/JS integration tests both assert the algorithm *respects the pinned
   formula* (system + personal-formula pins).
2. **Templates: test they FUNCTION, not their macro accuracy.** A template-driven
   plan should render/complete; we no longer chase macro bands for templates.
3. **Food preferences: OUT.** Allergies + dietary restrictions stay (they're
   separate). ✅ **DONE 2026-06-25:** food-prefs step removed from onboarding
   (`onboarding_pageview_screen.dart`), `getOnboardingProgress()` no longer gates
   on food prefs (`onboarding_service.dart`), settings "Food Likes & Dislikes"
   tile removed + hub relabeled "Diet, Allergies & Formulas"
   (`food_preferences_hub_screen.dart`, `settings_screen.dart`). Allergy
   compliance still matters for safety (task #24).
4. **Three test layers, all required:** local JS/Deno tests (run-algorithm-tests.sh
   §1) · edge-fn integration (parity + live E2E) · **a new widget-test smoke suite.**
5. **Patrol breadth:** the pinned-formula create→pin→generate→assert journey is
   the centerpiece; plus carb-loading, settings-change, and a smoke pass over
   **every screen** (incl. add-food / swap-food). Supplement with Flutter MCP
   screenshots on a booted sim.

### Built 2026-06-25
- **Widget smoke suite** — 8 files in `test/smoke_tests/`, 71 tests, ~70 screens, all green
  (harness `test/helpers/widget_test_harness.dart`). Found 16 bugs + 4 systemic
  patterns → `docs/test/BUGS_FOUND.md`.
- **Seeded content layer** — `test/seeded_tests/` (5 files, 91 tests + 1 crash-canary
  skip), asserting real VALUES not just render. Foundation: `pumpSeeded()` +
  in-memory Drift DB override + `test/helpers/fakes/fake_supabase_client.dart`
  (resolves the README Supabase-auth-mocking TODO). Confirmed bug #4 from the
  widget layer; found the SweatProfile unit-label bug + ActivityDetail title gap.
- **Patrol pinned-formula flow** — `integration_test/flows/formula_pin_flow_test.dart`
  **GREEN** on iPhone 17 Pro (pin → pinned-only filter → unpin lifecycle, 16 steps,
  36s). Proves the user-facing PIN PROCESS. The numeric "engine obeys the pin" half
  stays in the edge-fn parity layer (fixtures 07/08/34/35).
- **All 17 found bugs FIXED + verified** — full widget suite `+159 ~1` green (only
  BarcodeScanner skipped for camera), `flutter analyze lib/` clean. Includes the
  `MacroTargetsController` dispose fix (canary un-skipped), `ActivitiesListScreen`
  exception-dump fix, 7 overflows (re-gated at 390), 3 dead screens deleted, and the
  SweatProfile unit-label bug + regression test. `#12/#16` reclassified as a
  harness gap (ScreenUtilInit now in `wrapForTest`). Details: `BUGS_FOUND.md`.

### 2026-06-30 — coverage wave (10 parallel agents, ~1,180 new tests)
- **Edge functions:** ~20 previously-untested functions now covered (~730 Deno
  steps) — food/catalog, AI (gateway mocked), garmin+data-sync, user/weather/email.
  Wired into `run-algorithm-tests.sh` §1p–§1ac.
- **Flutter units:** coach_mode (116), calendar+carb_loading (121), meal_logging (92),
  integrations+auth (39) — features that had ~zero service coverage.
- **Widget content:** coach/calendar/carb + meal/weather/ai_coach (84).
- **Verified:** full Flutter suite `+1393 ~4` green, `analyze lib/` clean, Deno green.
- **Bugs found: ~21** (see `BUGS_FOUND.md`) — 2 HIGH dispose crashes (coach_chat FIXED;
  macro_targets fixed earlier), 2 security (`save-user-food` auth hole, committed
  Resend key), and the big one: **Calendar + CarbLoading screens render hardcoded
  MOCK data** (not wired to their controllers).

### 2026-06-30 — resume wave (after spend-limit reset)
- **Patrol `formula_create_pin_flow_test` GREEN on device** (36 steps, 29s): the full
  personal-formula lifecycle — auth → Formula Library → create → add food (swap-food)
  → save → pin → verify → unpin. Added missing `swap_food.*` ValueKeys + `figma_search_bar`
  `fieldKey` to prod (restored from develop). `fuel_timeline_flow_test` sentinel fixed
  (Journey 2 authored, device-verify pending).
- **Salvaged + repaired** the spend-limit-killed drafts: settings/credits/app_startup
  (82 tests) + template_scaling/fuel_timeline (49) + events/user_foods/templates CRUD.
- **More real bugs found & FIXED:** `UserProfile.copyWith` dropped 3 fields → settings
  DATA LOSS; startup analytics never fired; `EnergyBreakdownSheet` overflow (every
  4-digit-calorie user); all **6 edge-fn bugs** (incl. the `save-user-food` security
  hole); WeatherDetail invisible AppBar. + weather units (40).
- Full report + obsolete/combinable analysis: `TEST_STATUS_REPORT.md`.

### Coverage snapshot (2026-06-25) & gaps
- **Strong:** nutrition engine (`_shared/nutrition` — 12 Deno test files), `new_sync`
  repos (24), nutrition_plan + formula_kit Flutter units, widget smoke (159) + seeded.
- **WEAK / UNTESTED** (see `coverage-gaps-2026.md` for the full grounded map):
  ~24 of 33 edge functions have NO tests (get-foods, save-user-food, lookup-product,
  search-catalog, get-weather-forecast, analyze-meal-photo, describe-meal, ai-coach,
  jade-chat, the garmin-* family, create/delete/upsert-user, sync/upload-all-data);
  Flutter features coach_mode / calendar / carb_loading-logic / meal_logging /
  integrations-sync / auth-flows have little beyond smoke; Patrol covers only 3 flows.

### Widget-test smoke suite (NEW — every screen ≥1 test)
- **87 screens inventoried** (see per-screen widget-vs-Patrol verdicts in session notes).
- Infra exists: `test/helpers/responsive_test_harness.dart` (`pumpResponsiveScreen` +
  `expectNoRenderOverflow`), recording fakes under `test/helpers/fakes/`, Riverpod 3
  `AsyncNotifier` override patterns (model: `test/features/daily_macros/daily_macros_screen_layout_test.dart`).
- Plan: `test/smoke_tests/` with one file per feature-group; Tier-1 (pure-UI) +
  Tier-2 (provider-override) screens get widget smoke tests; Tier-3 (camera/auth/
  multi-screen nav: barcode scanner, photo capture, onboarding pageview, NewActivity)
  stay Patrol. Build `test/helpers/widget_test_harness.dart` + `mock_providers.dart`
  + `fakes/fake_supabase_client.dart` first.

## Guiding strategy
- **Two layers, different jobs.** Patrol proves a user *can do the thing* (UI,
  navigation, CRUD, values render). Direct edge-function tests prove *the numbers
  are right* (macro/hydration/sodium in range) — fast, deterministic, CI-cheap.
  Put the exhaustive input matrix in the direct layer; keep Patrol to one
  representative case per flow + a parity check.
- **Determinism is on our side.** All macro generation is formula-based (no LLM),
  so exact/range assertions are stable. "Generate Plan" = this engine.
- **Parametrize, don't duplicate.** One Patrol test body driven by a table of
  `(sport, distance, intensity)`; one direct-test harness driven by a scenario
  matrix. Adding a case = adding a row, not a file.
- **Reuse shared helpers.** Extract auth / form-fill / return-to-calendar /
  swipe-delete / range-assert once; every test builds on them.

---

## Phase 0 — Foundations & unblockers  *(do first; everything builds on these)*
- [ ] **Extract shared Patrol helpers** → `integration_test/helpers/patrol_flow_helpers.dart`:
  `ensureAuthenticated`, `fillField` (unfocus+scrollTo+enterText), `submitForm`
  (keyboard-dismiss+scrollTo+tap), `returnToHome` (multi-back unwind),
  `swipeToDelete`. Migrate events + activities tests onto them.
- [ ] **Fix Android birth-year picker deadlock** (`lib/shared/widgets/birth_year_picker.dart`)
  — disable magnifier under test OR expose a set-birthday path. Unblocks the
  ENTIRE Android fresh-user→CRUD chain.
- [ ] **Fix event-delete stale-detail bug** (`event_detail_screen.dart`
  `_showDeleteConfirmation`): pop the pushed route instead of/with `context.go('/main')`.
- [ ] **Wire all flows into CI** (`test_bundle.dart` / Codemagic) and confirm the
  per-PR Patrol set runs.
- [ ] Decide dev test account for `auth_flow_test.dart` (currently prod `test@test.com`).

## Phase 1 — Patrol UI CRUD breadth
- [ ] **Parametrize activities** → table-driven `(sport, distance, durationOrPace, intensity)`:
  running ✅ → add **cycling**, **swimming**, **brick/triathlon** (assert plan
  renders; macro stat non-empty). Keys exist: `activity_create.tab_biking/tab_swimming/tab_brick`, `brick.*`.
- [ ] **Activity edit/update**: `adjust_macros.edit_macros_button` → edit dialog
  (`edit_macros.save_button`), add foods (`plan_detail.<category>_add_food_button`),
  edit datetime (`activity_create.edit_datetime_button`). Assert persisted.
- [ ] **Settings CRUD**: profile/units/preferences change → persists across reload.
  (10 `settings.*` keys exist.)
- [~] ~~**Food preferences editing**~~ — **SKIP** (Lee, 2026-06-23: food-preferences feature is being phased out; don't test). Allergy compliance still matters (see task #24).
- [ ] **Macro-in-range (UI)**: read rendered macro stats on adjust-macros/plan-detail,
  assert > 0 and within sport band (light check; heavy matrix lives in Phase 3).

## Phase 2 — Patrol feature flows
- [ ] **Templates**: save a plan as template (`plan_detail.save_template_button`) →
  the "Use Template" path now appears → use it.
- [ ] **Formula Kit**: create/edit a personal formula, **pin** it, verify it surfaces
  in the plan (11 `formula_kit` keys + personal_formula pin path).
- [ ] **Weather**: assert create-form forecast fetch (`activity_create.view_forecast_link`,
  `temp_value` populates), humidity control adjusts.
- [ ] **Carb loading** (`event_details.create_carb_loading_button` → protocol), **race checklist**.
- [ ] **Daily Macros / meal logging / Mealvana AI** (logging methods, planned vs eaten, chat).
- [ ] **Integrations**: finish credentialed connect on **Android** (Garmin/FS/TP — iOS sandboxes OAuth).

## Phase 3 — Direct edge-function integration suite  *(verify the numbers)* — 🟡 MOSTLY DONE
Foundation: the Deno harness `supabase/functions/run-algorithm-tests.sh` (§1 deterministic, §2 live E2E). Reuse `assertWithinPercent`/`assertInRange` + `makeRealDev*` catalog builders from `test-utils.ts`.
- [ ] **Bump Python suite to v3/v4** → `test/integration/test_nutrition_plan_v3.py` (still on v2). *(Plus: ROTATE the committed service_role key in the v2 file.)*
- [x] ✅ **Activity-type × distance × duration matrix** — parity harness extended to drive rule/template/LP; **41 fixtures** across run/bike/swim/brick × every carb band × intensities × pins. Macro-engine ceilings/bands covered by `macro-bands.test.ts` (144-combo sweep).
- [ ] **Weather→hydration chain**: `get-weather-forecast` → feed temp/humidity into `generate-macros` → assert hydration scales. (Still only status-200 checked.)
- [ ] **Template-coverage-by-diet**: each diet → assert ≥1 valid food template in EVERY phase. *(Live E2E shows this IS a real gap — restrictive combos fail.)*
- [x] 🟡 **Formula-kit pin propagation** — parity fixtures 07/08/34/35 cover system + personal-formula pins; a dedicated live-pin integration test still TODO.
- [ ] **Custom overrides**: `override-utils.test.ts` exists (unit); an integration test that submits overrides → asserts plan respects them is TODO.
- [x] ✅ **Failure-mode unit tests** (NEW, beyond original plan): empty-pool, missing-component, macro-adherence, after-phase, LP-infeasibility, pre-workout-DB-failure (§1h–§1o).
- [x] ✅ **Catalog reality-check** (NEW): real dev catalog snapshot drives the parity/adherence tests.

## Phase 4 — Parity & CI gating  *(the leverage multiplier)*
- [ ] **Patrol↔edge parity**: the macros shown in Patrol plan-detail == the edge
  function's return for the same inputs, within tolerance.
- [ ] **CI matrix**:
  - Per-PR: deterministic Deno + Python smoke (gated on macro/plan/edge changes) +
    Patrol smoke + one CRUD.
  - Nightly: full Patrol matrix (iOS + Android via Firebase Test Lab) + full
    direct matrix + un-gated `dev_cloud_e2e` (`--tags e2e`).
- [ ] Surface results (badges / Codemagic dashboard).

---

## Execution notes
- Run Patrol on **iPhone 17 Pro / iOS 26** (booted) + Android emulator (after Phase 0 picker fix).
- Each Patrol iteration ≈ 1–10 min (build cached ~34 s; failures pay long timeouts).
- Direct edge-fn tests run in seconds — push the big matrices there.
- Known toolchain pins: `patrol 4.6.1 ↔ patrol_cli 4.4.0`, `test_directory: integration_test`, `--flavor dev`, creds via `--dart-define-from-file=secrets/integration_test.env`.

## Progress Log (2026-06-24)

### ✅ Done

**Patrol UI (integration_test/flows/)**
- Smoke, onboarding (iOS), email auth, integrations launch-boundary.
- **Events CRUD** — `events_crud_flow_test.dart`, full Create/Read/Update/Delete, 18 steps green (iPhone 17 Pro / iOS 26).
- **Activities CRUD (running)** — `activities_crud_flow_test.dart`, New-activity FAB → Generate Plan (real macro engine, no AI) → adjust-macros → create → read card → swipe-delete, 22 steps green.
- Added delete-dialog ValueKeys (`event_details.delete_confirm/cancel`, `activity_delete.confirm/cancel`).
- Reusable patterns learned: keyboard-overlay-on-submit (unfocus+scrollTo+tap), deep-stack unwind (multi-back), swipe-to-delete via `find.ancestor`+`Dismissible`, dev session persists across the Patrol install.

**Edge-function unit tests (`run-algorithm-tests.sh` §1 = 15 groups GREEN, deterministic, no DB)**
- §1h–§1l: empty-pool, missing-component, macro-adherence, after-phase, diet/allergy filtering.
- §1m LP-infeasibility · §1n macro bands/ceilings (144-combo sweep) · §1o pre-workout-DB-failure (→500).
- **Parity harness extended** to drive template + LP paths; **41 fixtures** (was 16) across athletes × distances/bands × run/bike/swim/brick × intensities × pins; min corpus 12→30.
- **Catalog reality-check**: dumped 92 dev `template_foods` → committed `__fixtures__/dev-food-catalog.json`; `makeRealDev*` builders; parity now uses real data. Reconciled `knownFailure`s: 3 were synthetic artifacts (RESOLVED), 2 confirmed real, 5 new real-catalog issues.
- Plan doc: `edge-function-test-plan-2026.md`.

**6 nutrition-plan bugs FIXED + verified (no regression in 78-case audit)**
- #2 silent empty phase (now emits shortfalls/warnings) · #3 short-target carb overshoot (≥15g) · #4 shortfall reporting decoupled from food-prefs · #5 after-phase warning propagation · #6 fluid-floor overshoot · #7 sodium fill. (#1 vegan/vegetarian filter intentionally **skipped** — food-prefs phasing out.)

**Live E2E vs dev (`run-algorithm-tests.sh --e2e`)**
- ✅ `generate-macros-v4` fully green (64 checks) — the macro **numbers** are correct in production.

**Observability / tooling**
- **CodeRabbit fixed** — deleted stray deprecated workflow; GitHub App reviews via `.coderabbit.yaml`.
- **Sentry P0 fixed** — uncaught handlers, release/dist tags, stale-version removed, Codemagic symbol-upload step, 27 edge functions wrapped (now 30/30). ⚠️ *Manual:* set `SENTRY_AUTH_TOKEN` in Codemagic + confirm `SENTRY_DSN` Supabase secrets.

### 🔴 Discovered by the live E2E — real production bugs (now have failing tests)
1. **After-phase recovery hydration/sodium severely under-delivered** across nearly all profiles — water **2–60%** of target (2% ultra, 5% very-heavy marathon, 10% heavy half, 31% avg male), sodium 29–73%. Root cause: after-phase uses canonical template portions, ignores `post_run` targets. → **task #23 (SEVERE)**.
2. **Stacked-allergy / vegan compliance broken** — single allergies pass, but multi-allergy / vegan+gluten / all-5 combos fail; a vegan plan contained Whey Protein Shake. Safety-relevant. → **task #24** (confirm scope: keep allergies, vegan deferred with food-prefs).
3. **Short during-carb target overshoot** confirmed live (12g→18.8g, 157%) — our fix #3 addresses it once deployed.
4. **Zero-carb swim gets no electrolytes** — confirmed in both unit (parity F27) and live E2E.
5. **Catalog scarcity**: only 7 foods with fluid ≥400ml (high-volume fluid genuinely scarce → ultra/after-phase water hard to hit); 30 with sodium ≥200mg (so synthetic sodium-gaps were artifacts).

### ▶ Remaining (priority order)
- **#23 FIX after-phase hydration/sodium** (severe, highest-impact correctness bug; failing E2E+unit test ready).
- **#24 FIX stacked-allergy compliance** (safety).
- **#25 Make parity harness deterministic** (real catalog introduced solver RNG non-determinism, masked as 5 knownFailures).
- **Phase 0** foundations: shared Patrol helpers, Android birth-year picker deadlock, event-delete stale-detail bug, wire Patrol into CI.
- **Phase 1/2** Patrol breadth: activity types (cycle/swim/brick), edit/update, settings, templates, formula-kit pinning, weather, carb loading, Daily Macros/Mealvana AI. *(Food-preferences editing flow — SKIP, phasing out.)*
- **Phase 3 remainder**: bump Python suite to v3/v4 (+ rotate the committed service_role key), weather→hydration chain, template-coverage-by-diet, override propagation.
- **Phase 4**: Patrol↔edge parity, CI gating (per-PR deterministic + smoke; nightly full matrix on Firebase Test Lab) — *the biggest long-term leverage; nothing is gated yet.*
- **Widget tests** (Tier 1: plan-state matrix, form validation, Planned/Eaten/Left table).
- **New test types**: `glados` property tests for macro formulas; `alchemist` golden tests; accessibility + perf/jank.
- **AI tooling**: Patrol MCP, `claude-code-action`, Codecov.

### Security
- ⚠️ `test/integration/test_nutrition_plan_v2.py` contains a committed **`service_role` key** — rotate it and move to env.

### Everything above is uncommitted on branch `feat/carbs-per-hour-summary`.
