# Test Recommendations — Patrol / Widget / Local / Edge-fn Integration

Companion to `testing-build-plan-2026.md`. Forward-looking, prioritized list of
the tests worth building next, by layer. Reflects the 2026-06-25 refocus:
**formulas + pinned formulas are the accuracy surface; templates are
function-only; food-preferences is out.** P0 = highest leverage.

---

## 1. Patrol (real-device UI / end-to-end)

Patrol proves a user *can do the thing*. Keep one representative case per flow.

- **P0 — Personal-formula create → pin → generate.** Extend the new
  `formula_pin_flow_test.dart`: tap "New" in a phase, fill `formula_kit.editor_name`,
  add foods via `formula_kit.editor_add_food` (reuses the swap-food page), save,
  pin the personal card, then create a matching activity → Generate Plan → assert
  the plan's During section shows the formula's food. This is the *full* product
  loop (the current flow covers pin/unpin of a system formula only).
- **P0 — Carb-loading protocol.** From an event: `event_details.create_carb_loading_button`
  → pick a protocol → assert the day-by-day plan renders + persists across reload.
- **P1 — Settings change persists.** Change a unit/profile value → kill & relaunch
  (Patrol's `$.native`) → assert it stuck. Covers the offline-first write path.
- **P1 — Templates function (not accuracy).** Save a plan as a template
  (`plan_detail.save_template_button`) → "Use Template" appears → use it → plan
  renders. Asserts the path works; no macro-band assertions.
- **P1 — Weather → hydration.** `activity_create.view_forecast_link` populates
  `temp_value`; assert humidity control changes the plan's fluid target.
- **P2 — Credentialed integration connect** (Garmin/FS/TP) — **Android only**
  (iOS sandboxes OAuth); creds in `secrets/integration_test.env`.
- **Phase-0 unblockers that gate the above:** extract shared Patrol helpers
  (`_ensureAuthenticated`/`_fillField`/`_returnToCalendar` are copy-pasted across
  flow files); fix the **Android birth-year picker deadlock** (blocks the whole
  Android fresh-user→CRUD chain).

## 2. Widget (fast, no device)

Two tiers exist: smoke (`test/smoke_tests/`, renders) + seeded (`test/seeded_tests/`,
values). Next:

- **P0 — Form-validation matrix.** We have EventForm + ManualLog; add the rest:
  user-profile (age/weight bounds), sweat-profile, nutrition-targets overrides,
  formula editor (empty name / no foods → Save disabled). Validation logic is where
  bugs hide and it's trivial to widget-test.
- **P0 — Plan-state matrix for plan-detail / adjust-macros.** Seed
  loading / empty / populated / error states and assert each renders correctly
  (after the `MacroTargetsController` fix unblocks AdjustMacros).
- **P1 — Multi-size responsive pass.** Re-run the smoke suite at `kSmokeSizes`
  (320 / 390 / 834) with overflow enforced everywhere — turns the suite into a
  responsive regression gate (it already found 7 overflows at 390 alone).
- **P1 — DB-backed seeded tests.** Use `pumpSeeded(database: AppDatabase.memory()..seed)`
  to drive screens that read Drift directly (calendar, activities list) with real rows.
- **P2 — Golden tests** (`alchemist`) for the high-traffic cards (daily-total card,
  macro comparison, fuel-timeline rows) — lock visual regressions.
- **P2 — Accessibility** (`flutter_test` `meetsGuideline`): tap-target size, contrast,
  text-scaling on the primary flows.

## 3. Local edge-function unit tests (Deno, deterministic — `run-algorithm-tests.sh §1`)

Pure-function tests over the nutrition engine; no DB, fast, CI-cheap. This is the
layer that proves **"the algorithm obeys the formula."**

- **P0 — Pinned-formula honored, explicit assertions.** The parity fixtures
  (07/08/34/35) exercise pin paths, but extend them into *direct* assertions:
  given a personal during-formula pin scoped to (activity, duration), the solver's
  output FoodResults == the formula's components scaled to the carb target
  (`personalFormulaToFoodResults` / `carbScaleFactor`). One test per phase
  (before/during/after) × scoped vs unscoped (null activities/durations = any).
- **P0 — Pin overrides everything.** Assert a pin is honored even when the food
  violates diet/allergy filters (the "pin bypass" behavior in §1l) AND when the
  template solver would otherwise pick differently — i.e. pin short-circuits the
  solver (early-return path in during-phase.ts:392).
- **P0 — pin-backfill correctness.** After a pin renders, fluid/sodium shortfalls
  are topped up (`backfillPinnedFluidsAndSodium`): assert water rounds UP (never
  under-delivers) and sodium uses tablets-before-drinks ordering.
- **P1 — Make the parity harness deterministic** (#25): the real-catalog snapshot
  introduced solver RNG non-determinism masked as 5 known-failures. Seed the RNG
  or sort candidates deterministically so the suite is stable in CI.
- **P1 — Template = function-only.** For each diet, assert a template-driven plan
  *completes with ≥1 food per phase* (no macro-band assertions, per the refocus).
- **P1 — Before-phase personal-formula honoring** is NOT yet wired on the edge path
  (only client fallback, see `pins.ts:38`). Add a failing test that documents the
  gap, then wire it.

## 4. Edge-function integration tests (live, against dev — `--e2e` / Python)

End-to-end through the deployed function; proves wiring + real catalog behavior.

- **P0 — Live pinned-formula round-trip.** Seed a personal formula + pin via the
  REST API, call `generate-nutrition-plan-v3` for a matching activity, assert the
  response's during foods are the formula's. The deterministic layer proves the
  math; this proves the *fetch-pins → apply* wiring (`fetchUserPinnedTemplateIds`).
- **P0 — Land the two open engine bugs with their failing E2E tests:**
  **after-phase hydration/sodium under-delivery (#23)** and **stacked-allergy /
  vegan compliance (#24)** — both have failing tests ready in the parity/E2E layer.
- **P1 — Weather→hydration chain.** `get-weather-forecast` → feed temp/humidity into
  `generate-macros` → assert hydration scales (currently only status-200 checked).
- **P1 — Bump the Python suite v2→v3/v4** (`test/integration/test_nutrition_plan_v2.py`
  is still on v2; the hardcoded key is already env-ified).
- **P1 — Override propagation.** Submit custom `NutritionTargetOverrides` →
  assert the plan respects them (an `override-utils.test.ts` unit exists; add the
  integration assertion).
- **P2 — Sentry-on-error.** Force an edge-fn failure (bad payload) → assert it's
  reported (30/30 functions are wrapped; verify the dark path actually fires).

---

## Cross-cutting: CI gating (the multiplier — nothing is gated yet)

- **Per-PR:** `flutter test test/smoke_tests test/seeded_tests` + `run-algorithm-tests.sh`
  (deterministic §1) + Python smoke, gated on macro/plan/edge changes + Patrol smoke.
- **Nightly:** full Patrol matrix (iOS + Android via Firebase Test Lab) + live `--e2e`.
- **Guardrails for the systemic bugs found:** a lint/check for screenutil-without-init
  and for deep-`../` imports, so they can't reappear.
