# Food-Recommendation Pipeline Map

**Probed:** app develop @ d72d43c9 (read-only worktree), live dev DB. **Date:** 2026-08-31.
**Companion register:** `runs/2026-08-31-food-recommendation-probe.md` (F-numbers cited here).

## Who computes what

```
client (macro_generation_service / brick_macro_service)
  └─▶ generate-macros-v4  ──────── targets (carbs/hydration/sodium engines)
        │                          + PRE-WORKOUT food selections (Algorithm C)
        ▼  response: macros + pre_run_selections
client (nutrition_plan_service)
  └─▶ generate-nutrition-plan-v3 ── the FOOD PLAN
        before: uses pre_run_selections VERBATIM if present (F-11),
                else re-runs Algorithm C (imported from v4) — same pools
        during: pinned personal formula → template solver → rule solver
                → closing pass (carb gap-fill + shortfalls)   [LP deleted]
        after:  pinned → template solver → LP fallback
        brick:  segments via during machinery; T1/T2 = template-0
                (60-min synthetic duration) → LP → greedy (F-25)
        then:   electrolyte↔water pairing (during/after at index level,
                before inside generateBeforePhaseV3)
        then:   validation vs targets — NON-FATAL, warnings only (F-3)
        then:   plan_generation_log ledger row (F-4)
offline client twin: OfflineMacroCalculator (targets) +
        client_plan/* solvers (during/after) — pre_run_selections: null,
        so any later v3 call RECOMPUTES before-phase (F-11)
```

## Algorithm C (pre-workout), inside v4
Pass 1 per sub-phase (meal/snack/top_up from hours_before): eligible templates
(diet/dislike/allergen, category + cross-phase food dedup) → `scoreFormula`
(servings = carb_target / per_serving, clamped to the row's [min,max] —
pin bypasses clamp) → `pickBestFormula` (carb+protein fit; sodium/fluid
deliberately NOT rewarded, #25) → optional stack. Pass 1.6 `trimSodiumOverage`
(add-ons only). Pass 2 `pickDrink` (drink pool = template_foods is_drink_pool).
Pass 3 `pickElectrolyte` — **pool EMPTY by ruling** (Lee 2026-08-06, sodium
SSOT v3): inert in prod (F-12). Fasted: returns [] only on
`meal_type === 'fasted'` — see F-8 for why v3's rebuild loses that flag.

## The faces, named (Xuan's #2)
1. **Pinned personal formula** — unconditional when in scope; carb-scaled;
   own fluid/sodium backfill (`pin-backfill.ts`).
2. **Pinned system template** — selector returns only pinned candidates;
   unrenderable pins downgrade honestly (`pinned_template_unrenderable`).
3. **Template solver (default-formula tier)** — the COMMON path since
   2026-07-29; ranked by selection_priority + preference.
4. **Rule solver** (during fallback) — same pool as tier 3 (post-3a3e3fdb).
5. **LP solver** — after-phase + brick transitions ONLY (deleted from during).
6. **Greedy** — brick transition last resort; client twin fallback.
Historic overwrite bugs in this chain are documented in-code (pin_decision
overwrite audit 2026-07-18, scenario-4, Chocolate-Milk-Solo) — the during path
is now disciplined; residual S2 risk sits in before-phase (explosion/reconcile/
substitution) and brick transitions.

## Where each suspected shape landed
| Shape | Verdict | F# |
|---|---|---|
| S1 twin divergence | LIVE: server-only 4-cap on supplements; baseline ×2 weight; gut-cap on electrolytes — Dart≠TS in `pickBestElectrolyte` | F-22 F-23 F-24 (+F-6 historical) |
| S2 face overwrite | during clean post-refactor; residual: before-phase layers, brick T1/T2, `pre_run_selections` dual-compute | F-2 F-11 F-25 |
| S3 standalone powder | pairing pass covers electrolyte-flagged items only; dry carb powders invisible; fl>15 rows self-satisfy | F-13 F-16 |
| S4 catalog data | as-prepared fluid on dry rows (tablet 475ml!), inconsistent dry/prepared conventions, live-confirmed | F-15 F-16 (F-14 downgraded) |
| S5 pickle juice | scoring arithmetic: sub-ceiling overshoot free, undershoot penalized, capsule penalty >2 — big-hit liquids win | F-17 |
| S6 sodium unfixed | pre-workout: electrolytes OFF by ruling (F-12). during: server 4-cap the Dart twin already removed (F-22); ≤2 sources/fill (F-18) | F-12 F-18 F-22 |
| P17 fasted foods | triple cause: v3 guard needs all-zero, meal_type rebuilt wrong, min_servings floor at 0 target | F-8 |
| P18 ×6.5 oatmeal | fluid = catalog as-prepared (F-15); ×6.5 exceeds today's max=3 — pin bypass or historical cap; sim decides | F-9 F-19 F-20 |
