# SSOT — Meal-Planning Calculations (Engine V)

**Status:** RECORDED v1 (Lee, 2026-09-03) — PROPOSED, awaiting Xuan's ratification.
**Source:** recorded from what the prototype (`mealplanning-prototype` @ `contract-v1` + the 2026-09-03 persona
mirror) and its edge-function twin (`mealvana_endurance` branch `mealplanning`,
`supabase/functions/_shared/vana/`) actually compute. Nothing here has been ruled on by Xuan; per the
governance rule every section states the **built** behaviour as the proposed contract and files what looks
wrong as a question, never as a silent edit.
**Code:** Engine V — the deterministic half of Vana. Three implementations exist and are contracted to be
MIRRORS, not forks (the "twin" rule, [`../agent/guardrails.md`](../agent/guardrails.md) H9):
**Scope:** every deterministic calculation the model is not allowed to make (see "What this family owns" below).

| Twin | Where | Runs |
|---|---|---|
| Prototype (TypeScript, Node) | `mealplanning-prototype/packages/web/src/{lib,server/vana}/` | web prototype, vitest |
| Edge (TypeScript, Deno) | `mealvana_endurance/supabase/functions/_shared/vana/` | `vana-chat` · `vana-action` · `vana-day-notes` |
| Client (Dart) | `mealvana_endurance/lib/features/meal_planning/{domain,application}/` | local-first recompute + cooking mode |

**What this family owns:** every number and every deterministic decision the model is *not allowed to make* —
the week's character, the athlete-context budget lines, day guidance, plan coverage, cooking sessions, the
shopping list, which opener a conversation gets, the meal glyph, cooking timers. **What it does not own:** the
daily macro targets (they come from the daily-macros engine, [`daily-targets.md`](daily-targets.md)), meal
*selection* ([`../selection/`](../selection/)), and anything the model phrases ([`../agent/`](../agent/)).

## Sections

| File | Owns | Executable vectors |
|---|---|---|
| [`daily-targets.md`](daily-targets.md) | how the week's targets are *consumed* and back-filled — never recomputed | — (contract only) |
| [`week-character.md`](week-character.md) | load score · character band · anchor session · race-week detection | `vectors/planning/week-character.json` (10) |
| [`athlete-context.md`](athlete-context.md) | the CONTEXT block: budget arithmetic, race-week carbs, holidays, recent session, season, memories | — (pending extraction, Q-AC1) |
| [`day-guidance.md`](day-guidance.md) | the day label decision table, the note copy, the dinner + snack pick | — (pending extraction, Q-DG1) |
| [`plan-coverage.md`](plan-coverage.md) | `coverage` — slots, covered, per-day macros; the `coverage_scope` denominator | `plan-coverage.json` (10) |
| [`cooking-sessions.md`](cooking-sessions.md) | `defaultSession`, the re-derive on toggle, session dates | `cooking-sessions.json` (9) |
| [`shopping-list.md`](shopping-list.md) | ingredient resolution → canonical names → aisles → aggregated quantities → pantry `have` | `shopping-list.json` (33) |
| [`opener-selection.md`](opener-selection.md) | which first turn a new planning conversation gets: plan · check-in · debrief | `opener-selection.json` (14) |
| [`meal-icon.md`](meal-icon.md) | the 23-key glyph classifier and the stored-key-wins rule | `meal-icon.json` (29) |
| [`cooking-timers.md`](cooking-timers.md) | timers parsed from step text; the clock format | `cooking-timers.json` (21) |
| [`season.json`](../../vectors/planning/season.json) | (no prose file — a static table; see `athlete-context.md` §SEASON) | `season.json` (4) |

Vector status vocabulary (same as the QA repo): `proposed` = derived from the recorded rule and verified against
the twins on 2026-09-03, becomes `ratified` when Xuan ratifies the section; `characterization` = pins an observed
behaviour that looks like a defect — a tripwire, never an endorsement; `expected-red` = the contract says X and a
named twin does not yet (listed in [`../../DEVIATIONS.md`](../../DEVIATIONS.md)).

## Cross-cutting rules

- **R1 — The model phrases; the engine decides.** Every value in this family is computed before the model runs
  and handed to it as text or as a tool result. The model never produces a number that is not in the context or
  a tool output ([`../agent/guardrails.md`](../agent/guardrails.md) H1).
- **R2 — Daily targets are consumed, never recomputed.** `carb_g / prot_g / fat_g / tdee / session_kcal` come
  from `daily_macro_targets`, filled by the deployed daily-macros function when missing. No formula in this
  family derives a macro target ([`daily-targets.md`](daily-targets.md)).
- **R3 — Dates are Sunday-start weeks in the athlete's local day.** `weekStartFor(iso)` = the Sunday on or
  before `iso`; cook-sun = week start. The anchor date is the client's local date (`anchor_date`, else derived
  from `timezone`, else UTC today).
- **R4 — Rounding is JS `Math.round` (halves toward +∞) at the boundary only.** Per-day macros round once when
  `coverage` is built; the Dart twin mirrors this explicitly (`_jsRound`). Intermediate sums are unrounded.
- **R5 — Twins are byte-identical where they can be.** `derive-week-character.ts`, `meal-icon.ts` and
  `grocery.ts` are copied verbatim between prototype and edge (only quote style differs). Where the twins have
  drifted it is a recorded deviation, not a choice (D-011 … D-014).

## Conformance

Runners: [`../../conformance/`](../../conformance/) — `run_edge.sh` (Deno, the edge twin), `run_prototype.sh`
(vitest, the prototype), `run_dart.sh` (flutter test, the client twin). Results on 2026-09-03: edge 109/109,
prototype 108/108 + 2 expected-red (D-011) + 1 skipped (edge-only), Dart — see `conformance/README.md`.
Explanation layer: the same numbers rendered on the Plan tab / plan bar / picker chips (design family) — the
engine-says-14-bar-says-13 drift is caught by the design conformance, not here.
