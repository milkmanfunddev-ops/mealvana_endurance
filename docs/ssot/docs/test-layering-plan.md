# QA test-layering plan — move testing off the simulator

**Goal:** put each invariant/spec on its **cheapest** test layer, so manual simulator driving shrinks
to *exploration only*. Companion to `spec/`, `DEVIATIONS.md`, and the `qa-smoke` skill.

## The three layers (cheapest → most expensive)

| Layer | What it is | Sees (visibility) | Cost | Where it runs |
|---|---|---|---|---|
| **L1 — Recipe tests** | Dart unit tests calling the calc engine directly (`OfflineMacroCalculator`) + Deno parity tests running the food-solver over athlete fixtures | The engine's exact numbers, no UI | ~free, seconds | every push (Deno) / merge gate (Dart) |
| **L2 — Robot diner** | Patrol flow tests: real app on a sim, log in, tap, **read the real widget values** (keys already exist) | Whatever a user sees, read precisely; proves the whole pipe | free per run, minutes | self-hosted M1 CI |
| **L3 — Manual** | An agent hand-driving the simulator | Pixels only, slowly | expensive (per screenshot) | ad-hoc |

**Rule of thumb:** pure math → L1. "Does the app *show/behave* right end-to-end" → L2. *Unknown* bug
hunting → L3. Never use L3 for regression — once a bug is known, it becomes an L1 or L2 guard.

## What already exists (don't rebuild)
- **L1 Dart:** `test/features/nutrition_plan/data/offline_macro_calculator_v4_parity_test.dart` asserts
  exact carb rates/bands and the **run gut-cap clamp to 70** — plus our `qa/conformance/` vectors (6
  fueling slices, green, local-only).
- **L1 Deno:** `supabase/functions/tests/parity/parity.test.ts` runs athlete fixtures through the
  solver and asserts foods hit targets within tolerance — **runs on every push** (`run-algorithm-tests.sh`).
- **L2 Patrol:** fully installed (`patrol 4.6.1`, iOS harness works); 17 flow tests incl.
  `activities_crud_flow_test.dart` (generates a plan) and `formula_pin_flow_test.dart` (pins a formula).
  *But* flows mostly assert "screen loaded," not the numbers, and **only the smoke test is in CI**
  (`release/*` only).

## The mapping — where each invariant goes

| Invariant / spec | Cheapest layer | Status | Action |
|---|---|---|---|
| **Fueling calc — all 6 slices** (pre/during carbs · hydration · sodium) | **L1 Dart** (engine direct) | ✅ mostly | Wire `qa/conformance` vectors in as an app-CI **merge gate** (today local-only) |
| **H7 gut cap** (run 70 / bike 120 / swim 0) | **L1 Dart** | ✅ run-70 asserted | Add explicit **bike-120** + **swim-0** asserts |
| **H6 in-range + gap-fill** (every macro ∈ [low,high]) | **L1 Deno** parity | 🟡 targets checked | Add explicit **range-bound + gap-fill-fired** assertions |
| **H4 fallback filtering** (no algo-chosen allergen violator) | **L1 Deno** | 🟡 | Scan every plan food vs the fixture athlete's allergies |
| **H5 stacking bands** (occasion set by window) | **L1** for the logic · **L2** for the display | 🟡 | Assert occasion set per window (≤30/30–90/≥90) |
| **H1 graceful degradation** (unmeetable → reported shortfall, no crash) | **L1 Deno** | ⬜ build | Fixture with an impossible target → assert shortfall emitted |
| **H8 input validation** (bad input → 400) | **L1** edge-fn/API test | ⬜ build | Assert 400, not a silent degraded plan |
| **H9 determinism** (targets stable; foods may vary) | **L1** | ⬜ build | Run identical input twice; assert targets identical |
| **H10 brick composition** (shared Before + per-seg During + T1/T2 + After) | **L1 Deno** structure | ⬜ build | Brick fixture → assert the section set |
| **S1–S5 soft** (liked foods, fewer items, near-midpoint…) | **L1 Deno** *scored* | ⬜ build | Report scores, not pass/fail |
| **H3 pin priority** (suitable pin → phase foods derive from it) | **L1 Deno** + **L2 Patrol** | 🟡 flow exists | Assert the pinned food actually appears in the plan |
| **H2 / D1 — pin safety warning (D-003)** | **L2 Patrol** (warning is a UI element) + L1 for the emit flag | ❌ warning not built | After Lee builds the warning, add a **failing-until-fixed** Patrol guard: pin an allergen formula → assert a warning shows |
| **D-004a brick fluids display** (oz vs ml) | **L2 Patrol / widget** (display-only) | ⬜ verify+guard | Assert brick macro-summary fluids render in **oz** |
| **D-004b brick During below-range** | **L1 Deno** | ⬜ verify | Assert brick sub-segment macros land in range (or a shortfall is reported) |
| **Unknown / novel bugs** | **L3 manual** | — | Keep for *exploration only*; log each run to `qa/runs/` |

## Sequencing (highest value first)
1. **Make the fueling vectors a real gate** — port `qa/conformance` into app CI so a spec break fails a
   PR (today they only run when we ask). *Biggest cost-saver: kills most manual fuel-number checking.*
2. **Extend the Deno parity test into an explicit H1–H10 harness** — it already runs every push; add the
   per-invariant assertions above. This is the "automated invariant harness" — it lives here, not in the sim.
3. **D-003 Patrol guard** — once the warning is built, a 1-flow Patrol test locks it in as a permanent
   regression guard (this is the *only* one that genuinely needs the UI/L2).
4. **Adjudicate D-004** via L1 (brick fixture) — confirms or clears the two brick candidates without a sim.

## Dependencies / gotchas
- **Athlete variety is free at L1** (fixtures are in-memory) — all 20 personas testable with no login.
  At **L2** only `avery@test.com` has credentials today; testing as Ravi et al. needs creds added.
- **CI reality:** Deno parity runs on every push; the Patrol suite (beyond smoke) and the fueling-vector
  gate are **not wired yet** — that wiring is the enabling work (Lee).
- Ties to Lee's live tasks: *"Build the Patrol smoke-test suite covering every flow"* (Doing) and
  *"Extend the nutrition-plan invariant matrix test with formula-kit pin states + wire into M1 CI"* (Ready to Test).
