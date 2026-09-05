> **RESOLVED 2026-09-03 → RULED same day (Xuan, in-session): targets steps 1+2 ≥ 60%, step 3 ≈ 40%, ANY step-4 = defect signal; folded as food-recommendation.md §10; ledger columns ride the bundle; terminology fixed to "step" (not face/phase)**

type: ruling-request
bundle: (food-recommendation bundle — telemetry slice)

## Why this matters
More than a third of real prod plans (38% of 177, Jul–Sep ledger) resolve their during-phase at
face 4 (the rule solver) — the regime that produces the banana-during-a-run class of picks. Nobody
currently watches this number, so quality regressions in the selection cascade are invisible.

## The proposal (Xuan, 2026-09-03, in-session)
Ratify a **face-resolution funnel** as the selection-quality metric, tracked over time:
- Per phase (before / during / after / transitions): % of plans resolved at face 1 (personal
  formula) / 2 (pinned template) / 3 (default template) / 4 (rule / LP / greedy), from the
  engine's existing `generation_path` + `logFormulaCascade` telemetry.
- Fallthrough-reason histogram (why face 3 didn't render: no_template_candidates,
  pinned_template_unrenderable, …).
- Practicality tripwires: count of rows violating the ruled §6 constraints (mega-rows, >2×
  single-item scaling, solvent shortfall) — should be 0 post-implementation.
- Baseline (prod, 177 plans): during = 46% face 3, 38% face 4, 6% face 1. Proposed target:
  face-4 share < 10% for during after this bundle's improvements land.

## Implementation shape
`plan_generation_log` gains before/after path columns (during_path exists) — rides the bundle's
migration; `qa/scripts/query-ledger.sh funnel [env]` computes the funnel from the ledger (added
2026-09-03); weekly cadence; optionally mirrored to Mixpanel via ops later.

## Gates
Where the metric definition lives (proposal: food-recommendation.md §10 post-ratification
addition), the face-4 target value, and the ledger schema addition.

## Suggested spec home
`spec/fueling/food-recommendation.md` §10 "Selection-quality telemetry" (post-ratification
addition once ruled).

> **Producer note 2026-09-03 (ledger-growth investigation, Xuan's ask):** the 177→663 prod jump
> was NOT humans and NOT a brick launch — 484 rows landed in ONE UTC hour (09-02 01:xx ≈ Sep 1
> evening PT), 99% <10 s apart, one target-signature ×222: the brick-ship verification ran
> `run-algorithm-tests.sh --e2e` (`during-invariant-remote-e2e.test.ts`) against the freshly
> deployed PROD edge functions, and v3 writes a ledger row on every call. Consequences folded
> into the telemetry contract: (1) the funnel must EXCLUDE test traffic — the bundle's ledger
> migration adds a `source` flag (e2e suites send an `x-mealvana-test` marker the function
> records; interim: burst-window exclusion); (2) clean HUMAN prod baseline (179 rows): of
> step-resolvable plans — steps 1+2 = 6.8% (target ≥60), step 3 = 51.6%, step 4 = 41.6%.
