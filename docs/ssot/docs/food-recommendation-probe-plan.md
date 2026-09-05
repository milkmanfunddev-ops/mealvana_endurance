# Food-Recommendation Probe Plan

**Branch:** `qa/food-recommendation` · **Written:** 2026-08-31 · **Status:** PROPOSED (Xuan reviews before the probing session starts)

The exploration phase for the food-recommendation ratification. Inputs: the three deferred
defects (P13 · P17 · P18, `bundles/pre-workout-macros.deferred.md`), the un-run
food-composition bundle (P10), and Xuan's six suspected failure shapes (2026-08-31, below).
Output: a findings register + intake ruling-requests that feed the ratification. **Nothing
found here edits an SSOT** — implementation is not authorization.

## Code map (recon 2026-08-31)

Server engine + selector (`$APP_ROOT/supabase/functions/`):
- `generate-macros-v4/` — `pre-workout.ts`, `pre-workout-scoring.ts`, `ingredient-pools.ts`,
  `brick-workout.ts`, `single-sport.ts`, `types.ts` + a large test suite (pinned, pickdrink,
  pickelectrolyte, sodium-scoring, fallback-foods, liked-bonus, matrix …)
- `_shared/nutrition/` — the during/post pipeline and its **faces**: `pins.ts`,
  `personal-formula-pins.ts`, `pin-backfill.ts` (pinned face) → `during-template-solver.ts`
  (template face) → `during-rule-solver.ts` (rule face) → `during-gap-fill.ts`,
  `lp-solver.ts`, `target-seeking.ts` (linear/fallback face) · `electrolyte-water-pairing.ts` ·
  `phase-target-reconcile.ts` · `food-queries.ts`, `template-food-queries.ts` (catalog access) ·
  `templates/`, `sport-configs/`
- `generate-nutrition-plan-v3/` — **legacy generator still in the tree**; is it still called?

Client twin (`$APP_ROOT/lib/features/nutrition_plan/`):
- `application/client_plan/` — `client_plan_service.dart`, `client_during_phase_solver.dart`,
  `client_greedy_solver.dart`, `client_food_pool_service.dart`, `electrolyte_water_pairing.dart`
- `data/offline_macro_calculator.dart`, `data/food_repository.dart`

Catalog: DB tables reached through `food-queries.ts` / `template-food-queries.ts` (fixtures in
`__fixtures__` are mocks, not the data). The data audit must hit the real dev DB.

Prior intake already pointing here: `intake/2026-08-22-engineering-ssot-twin-computations.md`
(shape 1 pre-filed), `intake/2026-08-22-data-ssot-producer-shapes.md`.

## The six suspected failure shapes (Xuan, 2026-08-31)

| # | Shape | Prior evidence |
|---|-------|----------------|
| S1 | Twin engines (edge TS vs client Dart) deviate | intake 2026-08-22 twin-computations |
| S2 | Face-selection spaghetti: a face's result computed then dumped / correct answer overwritten by a later face | — (suspected) |
| S3 | Drink mix recommended standalone as a carb source (nobody chews powder); must be paired with water | electrolyte-water-pairing exists but scope unknown |
| S4 | Catalog data errors: dry oatmeal carries fluid (P18's 44 oz), drink mix carries fluid | P13 · P18 |
| S5 | Pickle juice picked as electrolyte over easier-to-carry tablets/capsules | observed on dev |
| S6 | Sodium shortfalls never fixed by scaling electrolyte-capsule count, though that scaling is trivial | observed repeatedly on dev |

Plus the carried defects: **P13** (delivered fluid busts band; H6 ruling), **P17** (fasted gets
carbs; D-001 ruling), **P18** (×6.5 oatmeal; portion caps), **P10** (87 composition vectors,
no runner).

## Phases

### Phase 0 — Ground truth setup (short)
- App repo is currently on `fix/activity-update-preserves-device-fields`; probing runs against
  **develop** (read-only checkout or worktree — never disturb Xuan's working branch without asking).
- Confirm which edge functions the dev build actually calls (v4 vs the legacy v3 — grep the
  client's invocation sites). If v3 is still reachable, that alone is a finding.
- Boot the sim with the current dev build; verify a seeded QA athlete logs in and generates a plan.
- Open `runs/2026-08-31-food-recommendation-probe.md` as the running findings register:
  every finding gets an F-number, evidence path (screenshot / code cite / query output), and a
  suspected-shape tag S1–S6 / P13 / P17 / P18 / NEW.

### Phase 1 — Pipeline map (static; anchors everything else)
Read the selection pipeline end-to-end and produce **one diagram-grade map**: for pre-workout
and during-workout separately — entry point → pin lookup → template face → rule face →
LP/greedy fallback → pairing → reconcile → response; and the client twin's path when offline.
Specifically hunt S2 while mapping:
- results computed then unused (a solver runs, its return is shadowed or reassigned),
- faces that can run twice with the later, worse answer winning,
- error paths that silently fall through to a cruder face,
- `phase-target-reconcile.ts` / `during-gap-fill.ts` overwriting a face's already-correct rows.
Deliverable: `docs/food-recommendation-pipeline-map.md` + S2 candidates filed as findings with
exact file:line cites. The map is also the skeleton the eventual SSOT spec will ratify.

### Phase 2 — Catalog data audit (S4; fast, high yield)
Pull the real food catalog from the dev DB (via `food-queries.ts`'s tables) and run mechanical
sanity rules over every row:
- dry/powder items (`oatmeal`, drink mixes, chews?) with `fluid > 0`;
- fluid-per-serving physically implausible vs serving mass/size;
- items with no portion cap where tier-seeking can scale ×N absurdly (P18's ×6.5 class);
- sodium/carb densities that would let one item dominate scoring (S5's pickle-juice class);
- form/consumption-type field: does the schema even *have* "requires water" / "not standalone"
  (S3)? If not, that's a spec-add finding, not a data fix.
Deliverable: a findings table per offending row + a proposed catalog-correction intake file.

### Phase 3 — Twin-engine differential (S1)
- Static diff of the twin pairs first (`electrolyte-water-pairing.ts` ↔
  `electrolyte_water_pairing.dart`, during solvers ↔ `client_during_phase_solver.dart`,
  greedy ↔ LP) — divergent constants/branches found by reading are cheap.
- Then a small differential harness (conformance-runner pattern): one shared input file →
  run the Dart solver (`dart run`, same trick as `conformance/run_dart.sh`) and the TS solver
  (deno test-fake-supabase pattern with the *real* catalog rows from Phase 2) → diff row-by-row.
- Matrix: sports × durations (30/60/90/240) × diets (incl. fasted) × pinned/unpinned.
Deliverable: divergence table; each divergence is a finding — which engine matches the ratified
target math decides which one is *wrong*.

### Phase 4 — Selection-quality probes (S3 · S5 · S6, targeted static + unit-level)
- **S3:** where is "drink mix ⇒ pair with water" enforced? Read `electrolyte-water-pairing.ts`
  scope (electrolytes only? or all powders?) and `pre-workout-pickdrink.test.ts`. Construct a
  case where drink mix is the sole carb row.
- **S5:** read `pre-workout-scoring.ts` + `pre-workout-sodium-scoring.test.ts`: what does the
  score reward? If portability/form is absent from the score, pickle juice winning is
  *by design of the current score* — that's a ruling-request (add form preference), not a bug fix.
- **S6:** find where electrolyte quantity is chosen: can the solver scale capsule count at all,
  or is quantity fixed at 1 and sodium shortfall then eaten by gap-fill/reconcile? Check
  integer-quantization and any per-item max. If capsules are scalable in code but never scaled
  in output, that's an S2-style dead path — trace it.
Deliverable: per-shape verdict — *bug* (code contradicts its own intent) vs *ruling-needed*
(code does what it says, and what it says was never ratified).

### Phase 5 — Simulator probing session (long; the "eyes" pass)
sim-explore-style charter against the dev build, seeded QA athletes:
1. **Reproduce the knowns:** P13 (240-min plan fluid), P17 (fasted plan snack), P18 (meal-tier
   oatmeal) — screenshot each on the current build so the register has fresh evidence.
2. **Sibling hunt, steered by Phases 2–4:** every suspicious catalog row and scoring quirk gets
   a targeted on-screen reproduction attempt (does the absurdity actually surface in a plan?).
3. **Matrix free-play:** sports × durations × diets/allergies × liked/disliked × pinned formula
   vs none; for each generated plan record every recommendation row (item, portion, ×N scale,
   carb/sodium/fluid) into the register and check: rows sum into the band? any powder standalone?
   any ×N > plausible? sodium shortfall with capsules available? drawer number == engine number?
4. **Twin check on-device:** airplane-mode / offline plan generation vs online for the same
   athlete+workout — a visible S1 divergence.
Findings → register → intake ruling-requests (one per defect family, per `intake/README.md`).

### Exit criteria
- Pipeline map written; every S1–S6 shape has a verdict (confirmed-bug / ruling-needed /
  not-reproducible) with evidence.
- P13 · P17 · P18 reproduced (or noted changed) on current dev.
- Catalog audit table complete; every offending row listed.
- Intake files staged for the ruling desk; characterization vectors *only* where we must pin
  observed behavior as a tripwire.
- **No SSOT edits, no vector oracles from code, no tags, no merges** — this branch ends at the
  ruling desk, and the ratified spec + spec-to-vectors + ship-bundle come after Xuan rules.

## Order & why
Static before sim (Phases 1–4 before 5) because the sim session is expensive and the static
passes tell it exactly where to aim; catalog audit early because P13/P18 already prove data
errors reach the screen and each bad row predicts a reproducible on-screen defect.
