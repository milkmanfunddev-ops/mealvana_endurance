# HANDOFF — food-recommendation@v1 (tag c902ee6)

Standing implementation contract for the coding agent. Authority order: **the tagged specs** →
this handoff → the prototypes. Resolve `$APP_ROOT`/`$QA_ROOT` via `workspace.env`.

## What "done" means
`bundles/food-recommendation.yaml` `done_when`, verbatim: four slices green via
`qa/conformance/run_dart.sh`, the twin differential byte-equal on every vector (§8), and Xuan's
dev attestation of the ruled behaviour on a generated plan.

## Build order (dependency-sorted)
1. **Conformance arms first** (they do not exist — verified: `run_dart.sh` has zero
   `food-recommendation` arms). Both fueling slices carry `engine: null`; the harness must expose
   the SELECTION RESULT (which source, which servings, which window/tiers), not only macro totals,
   or the policy vectors cannot be asserted.
2. **Catalog v1.1 migration** — add `solvent_min_ml` (+ optional `solvent_max_ml`) to
   `template_foods`; backfill from label dilutions; dev + prod (catalogs are row-identical).
3. **Twin port** (§4, F-22/46/47) — one cap = the row's `max_servings_during`, symmetric
   overshoot, carryable-first with the 10 %-of-target tolerance, capsule-over-salt backfill; ship
   TS and Dart in ONE commit with a differential test.
4. **Window authority** (§3/§3a) — replace `recommendedHoursBefore` with the ratified table +
   early-start rule + clamp; CF-1/CF-2 UI states.
5. **Practicality** (§6) — 2× single-item cap, meal ≥2 components, container rows, per-sport form
   preference, solvent session-total constraint (selection paths only; pins untouched).
6. **Fasted retirement** (§7) — see the migration note in the watchlist; goldens retire in the
   same commit citing feeding-card/fuel-stat AMENDMENT A1.
7. **Ledger + funnel** (§10) — `before_path`/`after_path` columns + the `source` test-marker;
   `x-mealvana-test` header recorded by the function.
8. **Design slices** — write `conformance/design/create-flow-fueling-controls.yaml` and
   `formula-pin-surface.yaml` from the CF-/FP- rows, then implement to them.

## Reference renderings (candidates, not contracts)
`prototypes/create-activity-plan/v1.html` · `prototypes/formula-kit/v4.html` (both committed in
the prototypes repo). **Port prompt rule:** this is a port, not a redesign — exact values, static
fidelity by screenshot side-by-side. **Design-SSOT addendum:** the HTML holds static fidelity; the
ratified CF-/FP- rows hold state, gesture, copy and data contracts. Where they disagree, the spec
wins and the disagreement is a finding, not a judgement call.

## CONFLICT WATCHLIST (verified against develop @ 80230b59, not recalled)
| # | Finding | Evidence | What it forces |
|---|---|---|---|
| W-1 | **Update, not greenfield: no conformance target exists.** `run_dart.sh` has 0 arms for either fueling slice | grep count 0 | Arms are step 1, not an afterthought |
| W-2 | **`is_fasted` is a REQUIRED wire field** — v4 returns a 400 when it is absent (`generate-macros-v4/index.ts:83-84`). 15 TS files + 21 lib Dart files + 11 test files reference it | grep | Retirement must be **tolerate-and-ignore**: server accepts and drops the field for old clients; only then does the client stop sending it. Removing the validation and the client field in one release breaks every installed build |
| W-3 | **A DB migration pins the flag**: `test/migrations/is_fasted_v14_migration_test.dart` | file exists | Decide deliberately: drop the column, or keep it dormant. Do not delete the migration test blindly |
| W-4 | **Fasted goldens exist** — `fuelstat_fasted.png` + the before-card golden/gesture suites | file listing | Retire them in the SAME commit as the code, message citing feeding-card/fuel-stat AMENDMENT A1 (updating a golden is a ratification act) |
| W-5 | **Twin pair**, five known divergences | `client_during_phase_solver.dart` ⇄ `_shared/nutrition/during-utils.ts` | §8: one commit, both engines, differential test. A one-sided fix is a defect by contract |
| W-6 | **`DEFAULT_PAIRING_VOLUME_ML = 250` has a test asserting it** (`electrolyte-water-pairing.test.ts:141` asserts `>= 250`) | grep | The per-product solvent minimum SUPERSEDES the flat constant; that assertion must move to the column, keeping 250 as the undeclared-row fallback |
| W-7 | **Ledger has `during_path` only** (`plan-generation-log.ts:26,83`) | grep | §10 needs before/after paths + `source`; the funnel's step-2/step-3 split reads `pin_decision.used_pin` — keep emitting it |
| W-8 | **Coach insight is NOT in scope** (FP-9) — it appears in the pin prototype's authoring screen | manifest excludes | Do not build it. Do not let it into a golden |
| W-9 | **A 41-fixture corpus parity suite already exists** — `supabase/functions/tests/parity/` (`01-light-easy-run.json` … incl. `07-pinned-during-system-template`, `08-personal-formula-during`), asserting plan-vs-target at a **15 % end-to-end tolerance** | file listing + `parity.test.ts:101` | This is the closest thing to a selection test today. **Reuse it, don't fork it:** the new conformance arm should feed these fixtures where they fit, and the ruled policies (§4 source choice, §6 practicality) tighten what it asserts. A second, parallel corpus is how the two drift |
| W-10 | **`recommendedHoursBefore` has FOUR call sites, not one** — `meal_type.dart` (definition) + running, **brick**, **swimming** input controllers | grep | §3a retires it for ALL sports. The current function carries sport-specific windows (run 0.25–3.5 h, bike 0.25–3.0, swim 0.5–2.5) that the ratified table does not name — **the table's session classes are sport-neutral, so the implementation must map every sport's controller onto it.** Brick calls it with `defaultIntensity` and no duration in one path (`brick_input_controller.dart`) — that path has no §3a class until the leg total exists. **This is a gap worth a ruling if the mapping is not obvious at implementation time; do not invent per-sport windows silently** |

## PRODUCER / CONSUMER INVENTORY
| Field | Producers | Shapes actually written | Existing consumers + resolution | New consumer's rule |
|---|---|---|---|---|
| `template_foods.solvent_min_ml` | **NEW** — catalog migration (this bundle) | null for non-concentrated rows; ml from label dilution for mixes/tablets | none yet | Selection paths: session plain water ≥ Σ solvent minima. **Undeclared/null ⇒ fall back to `DEFAULT_PAIRING_VOLUME_ML` (250)** — never treat null as 0, that silently removes the pairing |
| `template_foods.max_servings_during` | catalog (existing) | integers 0–15; **0 means "not offered in this phase"** | TS `getServingCandidates` (raw range, no gut adjust) · Dart `_maxServingsForGut` (gut-adjusted) — **these already disagree (F-24)** | §4.2: ONE rule, both engines — the row's value, gut-adjusted identically. Divergence here is the bug this ruling closes |
| `pin_decision.used_pin` / `.ephemeral` | v3 during/after + v4 before | `used_pin:true` also emitted for EPHEMERAL default formulas (F-31) | banner UI (renders pin rows) · ledger | Funnel step-2 vs step-3 **must gate on `ephemeral`**, and FP-2 says an ephemeral decision renders NO pin row. Reading `used_pin` alone reproduces F-31 |
| `is_fasted` | client create-flow | bool, REQUIRED on the v4 wire | v4 validation + target engines + FC-4 rendering + Drift column + migration test | Retired: server tolerates-and-ignores during migration, then the field goes. See W-2/W-3 |
| `generation_path` | v3 per phase | `personal_formula`/`template`/`rule`/`empty`/`brick`/`swimming` | ledger `during_path` only | §10 funnel maps path × pin_decision → step 1–4; before/after paths must start being recorded |
| `hours_before` | client (`recommendedHoursBefore`, being retired) | double hours; **unclamped today** (F-38: feedings scheduled in the past) | v4 tier activation + v3 before-phase | §3a table default + clamp to time-until-start. **Seam test required:** stored-vs-recomputed built the PRODUCER's way (client minutes → /60.0 double), not by round-tripping the engine's own output |

**Late additions (recon deepened 2026-09-03 after the first pass):** W-9 and W-10 came from the
two checks that were thin in the first sweep — shared parity fixtures (2) and adjacent call sites
(5). Both are now verified; W-10 in particular is a scope fact the build order must respect.

**Seam-test rule (repo precedent, `app/docs/test/README.md` §"Seam tests: stored ≠ recomputed"):**
every row above whose value crosses a process boundary needs a test whose stored side is built the
way the producer builds it — producer constants and wire rounding included. A hard `assert` on such
data is a finding, not a safeguard: require tolerance + log.

## Deferred ledger
No `bundles/food-recommendation.deferred.md` exists yet — this is v1. Items this bundle RESOLVES
from the previous ledger (`bundles/pre-workout-macros.deferred.md`): **P10** (composition runner,
built here) · **P11/P17 + D-001** (close by fasted removal) · **P13** (fluid overcount — the C1
zeros shipped in brick-transition; band discipline now ruled in §5/§6) · **P18** (portion sanity —
§6(a) 2× cap + the pin-clamp ruling). Items it CARRIES: P1–P9, P12, P14–P16 (before-card interim
defaults and copy gaps, unchanged by this bundle).

## Baseline to beat (re-run is part of "done")
`bench/BASELINE-2026-09-03.md` — 30 frozen scenarios through the real dev edge functions,
captured BEFORE any of this work. **Of the 23 scenarios where the single-sport cascade ran:
step 3 = 82.6 %, step 4 = 17.4 %** (the four failing shapes are named: 45-min easy run, 30-min
shakeout, 60-min bike, 5-h bike — both duration extremes lack a fitting during template).

When the slices are green, **re-run `scripts/run-bench.sh dev post-implementation` and report the
delta against that file.** Success = step-4 share below 17.4 % with no scenario regressing 3→4.
Do NOT edit `bench/scenarios.json` — a changed corpus makes the comparison meaningless.
Two harness findings you inherit: `generation_path` is never sent on the wire (read it from
`plan_generation_log`), and brick during-segments are not path-recorded at all (§10's ledger
migration should fix that, or brick coverage stays unmeasurable).

## Exploratory
`.claude/skills/sim-explore/references/charter-food-recommendation.md` (shipped with this bundle)
— walk it after the first dev build.
