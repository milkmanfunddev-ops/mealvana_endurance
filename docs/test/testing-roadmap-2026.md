# Mealvana Endurance — Testing Roadmap (2026-06-23)

Two complementary layers. **Patrol** drives the real app UI on a device (flows,
navigation, CRUD, that values render). **Direct integration tests** call the
Supabase edge functions over HTTP and assert numeric macro/hydration values are
in range — runnable independently of Patrol, fast, CI-friendly. Both are needed:
Patrol proves the user can do the thing; direct tests prove the numbers are right.

Macro generation is **deterministic** (formula-based — ISSN/Jeukendrup/Baker, no
LLM), so exact/range assertions are safe. "Generate Plan" in the app is this
engine, NOT Mealvana AI/AI.

---

## Layer 1 — Patrol UI flows (`integration_test/flows/`)

Run on iPhone 17 Pro / iOS 26 (the documented-working Patrol-on-iOS config) and
Android emulator. Session persists across installs, so CRUD tests reuse the warm
login (email-login fallback only fires on a clean install).

### Done / green
- `patrol_smoke_test.dart` — toolchain (iOS + Android)
- `onboarding_signup_flow_test.dart` — onboarding → new user → calendar (iOS; Android blocked by birth-year picker)
- `auth_flow_test.dart` — email login (uses prod test@test.com)
- `integrations_connect_flow_test.dart` — provider connect launch boundary
- **`events_crud_flow_test.dart`** ✅ — full event Create/Read/Update/Delete
- **`activities_crud_flow_test.dart`** ✅ — running activity create (Generate Plan → real macro engine) → read card → swipe-delete

### Reusable patterns (learned)
- **Keyboard overlay:** Patrol `enterText` leaves the soft keyboard up, covering
  bottom submit buttons → tap fails "not hit-testable". Fix:
  `FocusManager.instance.primaryFocus?.unfocus(); await $.pump(ms:400); await $(key).scrollTo().tap();`
- **Swipe-to-delete:** find the row via `find.ancestor(of: find.text(name), matching: find.byType(Dismissible))`, `tester.drag(row, Offset(-500,0))`, then confirm.
- Generate Plan calls the macro edge function — allow ~60s `waitUntilVisible` on the adjust-macros screen.

### TODO — Patrol coverage gaps (one focused test per aspect)
- [ ] **Activity types:** cycling, swimming, **brick/triathlon** create+plan (each has different macro ceilings: run 70 g/hr, bike 120, swim 0).
- [ ] **Distance/intensity sweep:** short vs long, easy vs threshold — assert plan renders and macro stats are non-empty & sane.
- [ ] **Weather:** assert the create form fetches a forecast (`activity_create.view_forecast_link` / `temp_value` populate) and humidity control works; assert hot/cold changes hydration.
- [ ] **Activity edit/update:** edit macros (`adjust_macros.edit_macros_button` → dialog), add foods (`plan_detail.<category>_add_food_button`), edit datetime.
- [ ] **Macro-in-range (UI):** read the rendered macro stats on adjust-macros/plan-detail and assert > 0 and within sport band.
- [ ] **Settings CRUD:** profile/units/preferences changes persist.
- [ ] **Food preferences editing** (post-onboarding).
- [ ] **Templates:** save a plan as template, then "Use Template" path (only appears once a template exists).
- [ ] **Formula Kit:** create/edit a personal formula, pin it, verify it surfaces.
- [ ] **Carb loading**, **race checklist**, **Daily Macros / meal logging / Mealvana AI**.
- [ ] **Android:** fix the birth-year `CupertinoPicker` deadlock (gates the whole Android fresh-user→CRUD chain).

---

## Layer 2 — Direct edge-function integration tests (runnable without Patrol)

Assert the **numbers**: macro/hydration/sodium targets returned by the edge
functions are within an acceptable range, across diets, distances, intensities,
activity types, and weather. These already exist in part — extend, don't restart.

### What exists
- `test/integration/test_nutrition_plan_v2.py` (601 LOC, 20 scenarios) — generate-macros-v3 → generate-nutrition-plan-v2; ranges: **carbs 70–130%, fluids 50–150%, sodium 30–200%**. Manual, dev. **Running-only.**
- `test/integration/test_nutrition_plan_v2.sh` — curl subset (deprecate in favor of Python).
- `test/e2e/dev_cloud_e2e_test.dart` (1121 LOC) — get-foods, generate-macros (gut-training bands), search-events, **get-weather-forecast** (status+fields only). `@Tags(['e2e'])` → excluded by default.
- `supabase/functions/run-algorithm-tests.sh` + 6600+ LOC Deno `.test.ts` — algorithm-audit (78 cases ±5%), lp-solver, pre-workout scoring/pins, sweat-hydration. Local, not CI.
- `generate-macros-v4/*.test.ts` (3000+ LOC, ±5%, sport ceilings). Unit hydration parity in `test/features/nutrition_plan/data/offline_macro_calculator_hydration_test.dart` (±5%).

### TODO — direct-integration gaps
- [ ] **Bump Python suite to v3/v4** (`generate-nutrition-plan-v3`, `generate-macros-v4`); rename `test_nutrition_plan_v3.py`.
- [ ] **Activity-type matrix:** running/cycling/swimming/brick × distances × durations — assert macros respect sport ceilings & bands.
- [ ] **Weather→hydration chain:** call `get-weather-forecast` → feed temp/humidity into `generate-macros` → assert hydration scales within range (the gap `dev_cloud_e2e` only checks status 200).
- [ ] **Template-coverage-by-diet:** for each diet, assert ≥1 valid food template in every phase (pre/during/after/top-up) so restrictive diets don't silently yield empty phases.
- [ ] **Formula-kit pins:** create pin → call plan-v3 with pinned IDs → assert the pin is used in the output.
- [ ] **Custom overrides:** submit override carbs/sodium → assert plan respects them.
- [ ] **Patrol↔edge parity:** the macros shown in the Patrol plan-detail should match (within tolerance) the macros the edge function returns for the same inputs.

### Foundation choice
- **Deno harness** (`run-algorithm-tests.sh`) is the richest base for algorithm/value tests — extend with `weather-integration.test.ts`, `activity-types.test.ts`, `template-coverage.test.ts`, `formula-kit-pins.test.ts`.
- **Python** stays for HTTP smoke/diet-matrix scenarios.
- Reuse helpers: `generate-macros-v4/index.test.ts` `assertWithinPercent`/`assertInRange`.

---

## Layer 3 — CI gating (currently MISSING for all integration tests)
- [ ] GitHub Actions / Codemagic job: run Deno algorithm tests + Python smoke on PR (skip if no macro/plan/edge changes).
- [ ] Decide which Patrol flows run per-PR (fast: smoke + one CRUD) vs nightly (full matrix, both platforms → Firebase Test Lab).
- [ ] Un-gate `dev_cloud_e2e_test.dart` into a scheduled `--tags e2e` run.

---

## Known app bugs surfaced by testing
- **Event delete leaves a stale detail screen:** `event_detail_screen.dart` `_showDeleteConfirmation` calls `context.go('/main')` but the detail route is pushed on top of the shell, so it does NOT pop — user is stranded on the deleted event's detail. Fix: pop the pushed route.
- Delete-confirm dialogs were label-only; added keys: `event_details.delete_confirm/delete_cancel`, `activity_delete.confirm_button/cancel_button`.
