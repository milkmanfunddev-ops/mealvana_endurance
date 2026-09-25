> **RESOLVED 2026-09-25 → morning interview (Xuan): OPTION 1 plan-authoritative override ruled as direction; rebalance spec pass + mini-interview next; own bundle loading-day-macros-coupling**
type: ruling-request
bundle: cross-cutting (carb-loading release-1 × daily-macros)

# Loading-day carb target: the protocol and the daily-macro engine disagree

Raised by Xuan at the carb-loading interview close (2026-09-24): "there will be a gap between
the carb target on the carb load dashboard and the carb recommendation on the meal intake page…
the daily macros do consider carb load, but I'm pretty sure that number doesn't exactly match."
**Premise verified — the mismatch is structural, not rounding:**

- `spec/daily-macros/multi-day-context.md` Formula 8 (`preLoadOverride`, ratified): carb floor
  `max(current, 9.0 × kg)` ONLY when `tomorrow_is_race` (or tss > 200) — i.e., day −1 only.
- `spec/fueling/carb-loading.md` (ratified at interview 2026-09-24): Classic 8/8/10, Quick 9/11,
  1-Day 11 g·kg⁻¹ per day, athlete-editable per day.
- Consequence @ 68 kg: days −3/−2 have NO loading floor at all (regular-day carbs vs 544 g on the
  dashboard); day −1 shows 612 g vs 680/748. Protein/fat/kcal never rebalance around a
  2,200–3,000 kcal carb load (`fat_mod = 0.85` RACE_WEEK records the intent, uncoupled from any
  plan). Same day, two ratified numbers — the exact engine ⇄ explanation drift class QA exists
  to catch, but here it is SSOT ⇄ SSOT.

## The question
On a day inside a created carb-loading plan, what does the daily-macro calculation emit?

## Options
1. **Plan-authoritative override** *(shape Xuan's remarks point at)*: daily-macros carb target :=
   the plan day's stored `carbTargetGrams` (incl. athlete edits); protein holds its ratified
   g/kg; fat/kcal recompute around the load (fat floor needs choosing — the 0.85 note is the
   seed). One number on every surface. Costs: a daily-macros contract change → next bundle
   version for that family; fat/kcal formulas need ratifying.
2. **Floor alignment only**: extend Formula 8 to floor every loading day at its protocol rate
   (`max` semantics preserved). Cheaper; but `max` lets a higher regular-day target exceed the
   plan, and protein/fat/kcal still don't rebalance — the two numbers merely converge, not unify.
3. **Two numbers + precedence display rule**: dashboard wins on loading days; meal page renders
   the plan number with a provenance marker. No engine change; institutionalizes the split.

## What it gates
Release-1 coherence (Xuan flagged the on-screen gap as live); daily-macros vectors for loading
days; the meal-intake page's carb recommendation on days −3..−1.

## Suggested home
`spec/daily-macros/multi-day-context.md` (Formula 8 amendment or a new loading-day section) +
cross-ref from `spec/fueling/carb-loading.md` §4. Ratifier: Xuan. NOT ruled at the 2026-09-24
interview — deliberately filed (tangent-spawns-policy rule); Xuan chooses interview vs desk and
which bundle carries it.
