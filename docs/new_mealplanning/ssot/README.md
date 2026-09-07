# Meal-Planning SSOT — Vana and the Food tab

The single source of truth for what the meal-planning feature **is supposed to do**, in the same shape and
spirit as the nutrition SSOT in `docs/ssot/` (mirrored from `mealvana_endurance_qa`): one file per section ·
rule / algorithm / constants / invariants / worked examples · an explicit deviation register · an open-questions
register · executable vectors · conformance runners that feed the vectors to the real code.

Two things differ from the QA repo, deliberately stated up front:

1. **It is app-side authored.** Lee recorded it from what was built (the prototype `mealplanning-prototype` at
   `contract-v1` + its edge-function and Dart twins on `mealplanning`, as of 2026-09-03) and from Xuan's own
   artifacts (`spec/intent/`). Nothing has been ratified by Xuan. Every spec is **RECORDED v1 → PROPOSED**.
2. **Implementation is still not authorization.** Recording what the code does is the *record* step (PLAN.md
   Phase 1 step 2 in the QA repo's vocabulary), not the ratify step. Where the code does something that looks
   wrong it is filed as a `characterization` vector plus a Q-item, never blessed. Where Xuan's intent and the
   build disagree it is in `DEVIATIONS.md` (D-001 … D-010 — old single/double-digit IDs, see the old→new map at
   its top) with the ⚖️ interim call that shipped.

Created 2026-09-02 (intent spec + deviations); restructured into families with vectors and runners 2026-09-03;
normalized to the QA repo's header/rule/conformance shape and folded in the 2026-09-03 evening's code changes
(question-first opener, intro-card removal, picker tap/tick split, Browse-meals-from-chat) 2026-09-04 —
[`PLAN.md`](PLAN.md) Phase 2.

## Layout

```
ssot/
  README.md                 this file — layout, families, governance, status
  OPEN-QUESTIONS.md         the Q register: Xuan's Q-1..7 (intent) + everything the record surfaced
  DEVIATIONS.md             intent-vs-build (D-001..010) and twin/code deviations (D-011..019), plus D-020+
  spec/
    intent/                 Xuan's design intent, sourced per claim — the stage-0 distillation
    planning/               Engine V: the deterministic calculations (week character, coverage, sessions,
                            shopping list, opener, icon, timers, day guidance, context, targets)
    selection/              which meals may be offered: the search_meals contract + suggestion rules
    domain/                 what a meal / plan / memory / conversation IS and when an action is offered
    agent/                  the model contract: guardrails, voice registers, tools, wire protocol
    design/                 tokens (meaning), components, surfaces — screenshot-test discipline
  vectors/<family>/*.json   the executable SSOT: input → expected, with status and a why per vector
  conformance/              run_edge.sh (Deno) · run_prototype.sh (vitest) · run_dart.sh (flutter) · run_all.sh
```

## Families and status (2026-09-04)

| Family | Sections | Vectors | Status |
|---|---|---|---|
| [`spec/intent/`](spec/intent/vana-mealplanning-chatbot.md) | 1 | — | PROPOSED (synthesised from Xuan's artifacts 2026-09-02); Q-1..7 carry ⚖️ interim calls |
| [`spec/planning/`](spec/planning/README.md) | 10 (+ season table) | 130 | RECORDED v1 — edge 109/109 · prototype 108 + 2 expected-red (D-011) + 1 skipped · Dart 60/60 |
| [`spec/selection/`](spec/selection/meal-search.md) | 2 | 15 | RECORDED v1 — prototype 15/15 (edge modules import `npm:ai`; deno arm skips) |
| [`spec/domain/`](spec/domain/README.md) | 4 | — | RECORDED v1 — DB-shaped truth; contract fixtures + seam tests, no pure vectors |
| [`spec/agent/`](spec/agent/README.md) | 4 | 5 | RECORDED v1 — `scripts/vana-eval` is the executable form (13 conversations, green last run) |
| [`spec/design/`](spec/design/README.md) | tokens + 8 components + 6 surfaces | — | RECORDED v1 — no renderings ratified, no manifests yet (Q-DS1); two app-authored component specs cited |

## Governance

- **Authority order for *intent*:** [`spec/intent/`](spec/intent/vana-mealplanning-chatbot.md) §Authority
  (AI Scenarios > the 2026-06-17 scope decision > MealBuddy brief > meeting positions > interview synthesis).
- **Authority order for *build truth*:** the edge twin (`_shared/vana/`) is ahead of the prototype since
  2026-09-03 and is treated as authoritative where they differ; the prototype is the reference implementation of
  `contract-v1` and the design's reference rendering; the Dart client is derived. Drift between twins is a
  deviation (D-011 … D-018), never a choice.
- **Amendments:** a ruling from Xuan is quoted, dated and folded in place (the `intraday-display.md` §4b
  pattern); a contract change to `contract-v1` types is versioned in three places at once
  (`../implement_mealplanning/02-contract.md`). Open questions live in `OPEN-QUESTIONS.md`; nobody resolves one
  by implementer judgment without marking it ⚖️.
- **Specs and vectors never move to make code pass.** A red arm is a finding: fix the twin, or file a Q.
- **The screenshot test governs `spec/design/`:** anything a screenshot can hold is left to the renderings.

## A conformance-run caveat

`scripts/vana-eval/` and `scripts/vana-eval/lifecycle.ts` run against dev using the same account
`scripts/sim-dev-login.sh` signs into the simulator (the account stored in macOS Keychain service
`mealvana-dev-login`) — the standing eval account. Running the eval and then poking around dev in the
simulator (or vice versa) share plans, conversations and memories on that one account; an eval run leaves
plans/debriefs behind that a manual walkthrough will see, and a manual session's picks can desync an eval
expecting a clean slate. Treat that account as shared, noisy state, not a clean fixture — the eval scripts bill
real AI spend too, so both run "by hand," never in CI.

## The loop

Bug found → write it as a failing vector here first → fix the twin → the vector is a permanent guard. Red means
raise, on every side.

## Related

- `../README.md` — the research base this feature was built from; `../walkthrough.md` (the scripted turns);
  `../plan-tab-v2.md`; `../vana-chatbot-update-plan.md` (the ⚖️ interpretive calls and the eight phases);
  `../recipe-directions-and-cooking-mode.md`.
- `../../implement_mealplanning/` — the app-integration phases; `02-contract.md` is the frozen wire contract.
- `docs/ssot/` — the fueling / daily-macros SSOT (Engine A/B); race-day fueling stays deterministic and outside
  Vana (`spec/agent/guardrails.md` H10).
- QA repo precedents this mirrors: `spec/fueling/pre-workout-carbs.md` (calculation), `spec/domain/brick.md`
  (domain), `spec/recommendation/generate-plan.md` (invariant contract), `spec/design/*` (screenshot test).
