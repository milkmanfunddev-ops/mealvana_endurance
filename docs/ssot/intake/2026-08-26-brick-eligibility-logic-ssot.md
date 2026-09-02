> **RESOLVED 2026-08-31 → spec/domain/brick.md v1 (ruling applied on qa/brick-transition-nutrition; Q-BR1/Q-BR2 remain open there)**

type: ruling-request
bundle: (none yet — proposes a new spec family)
raised: 2026-08-26 (app side, while resurrecting the brick flow on the macro dashboard)

# Brick eligibility is unratified logic — where should this kind of truth live?

## Why this matters
The brick flow ("link 2+ workouts on a day into one brick session") has been lost in two consecutive
surface migrations (Activities → Fuel Timeline, app bug 3a6e3fdb; Fuel Timeline → Macro Dashboard,
app `adeb1e38`). Both times for the same reason: **no spec anywhere says the affordance must exist
or when it is offered**, so each port faithfully omitted it. The app has now re-carried the Fuel
Timeline design onto the dashboard as a *candidate* (see the class doc on
`lib/features/macro_dashboard/presentation/screens/macro_dashboard_screen.dart`) so a design
session can ratify from the real thing. That leaves the *condition* itself unowned.

## What the code currently does (characterization — NOT a proposal)
`lib/features/activities/domain/brick_eligibility.dart` + `brick_selection_controller.dart`:
- A workout is brick-eligible iff sport ∈ {swim, bike, run} and it is not already a brick.
- The Brick pill is offered iff the day's workouts, in timeline order, contain a run of **2+
  positionally adjacent** eligible workouts spanning **≥ 2 distinct sports**. A meal between two
  workouts does not break adjacency; an ineligible workout (strength, "other", an existing brick)
  does.
- Pickable legs are exactly the rows inside such a run; min 2, max 3 legs; duplicate sports are
  rejected at create time; leg order = pick order, `Swap` reverses it.
- Nothing distinguishes planned / done / skipped / verified legs, or past / future days.
None of this was ever ratified. It is *observed*, so per the QA governance rule it belongs in a
characterization vector, not in the spec text.

## The categorization question
This is neither design truth (a screenshot cannot hold "adjacent", and it is not a hue or a gesture
outcome) nor calculation truth (no formula, no band). It is a **domain rule**: what a brick *is*,
and when the action is *offered*. Today the taxonomy has only `spec/<engine>/` (math) and
`spec/design/` (behavior + meaning of components/surfaces). `spec/design/` *could* hold it as a
surface suppression row, but that would mean the definition of a brick is owned by the dashboard
surface — the same rule would have to be restated on every surface that offers bricks (dashboard,
calendar, coach view), which is exactly the drift pattern the design SSOT was built to stop.

### Proposal: a third family, `spec/domain/`
```
spec/domain/README.md                 what a domain rule is; lifecycle = same as the others
spec/domain/brick.md                  definition · eligibility · leg rules · what a brick is not
vectors/domain/brick-eligibility.json input = ordered day (sport, status, isBrick) → offered? · candidate ids
conformance/domain/brick_eligibility_conformance_test.dart
                                      feeds vectors to hasAdjacentBrickCandidates / canCreateBrick
```
- Ratification lifecycle, status lines, `DEVIATIONS.md` use — identical to the other families.
- Vectors are the executable truth (same as fueling): a ruling is a vector flip, not a prose edit.
- `spec/design/surfaces/macro-dashboard.md` then cites `spec/domain/brick.md` for *when* the pill
  shows, and owns only *how* it shows (pill placement, pick mode, tile) — the way workout-card
  cites generate-plan for its numbers instead of restating them.
- The nutrition side stays where it is: H10 in `spec/recommendation/generate-plan.md`, the brick
  penalty in `spec/fueling/during-workout-carbs.md`, the deferred hydration slice. `brick.md`
  links to them; it does not absorb them.

Alternative considered: `spec/design/components/brick.md` carrying the gate as a suppression row.
Rejected for the reason above (definition owned by a surface). Alternative: fold into
`spec/daily-macros/session-demand.md` as "session composition". Rejected: that file is math.

## Rulings received so far (Lee, 2026-08-26 — app implemented on
`feature/brick-on-macro-dashboard`; recorded here pending the spec fold)
- **1 Adjacency — WITHDRAWN.** Any swim / bike / run on the day may be linked, whatever lies
  between them on the dashboard. `hasBrickCandidates` = 2+ eligible workouts on the day, 2+ sports.
- **8 Order — pick order.** Leg order is the order the athlete taps them; it need not match the
  dashboard order. `Swap` reverses it.
- **2 Same-sport pairs — ALLOWED** (second iteration, same day, after Lee hit the block on-sim with
  run + run + ride). The sport set is the ONLY filter: swim / bike / run, not already a brick.
  `canCreateBrick` no longer rejects duplicate sports; `hasBrickCandidates` = 2+ eligible on the day.
- **Delete brick = return to the ungrouped state.** Found on-sim: deleting a brick tombstoned the
  brick row and left its legs `archivedForBrick` (invisible). Both surfaces now route "Delete
  brick" through `ungroupBrick` (legs restored, brick + plan removed). Belongs in `brick.md`
  under "what happens to the legs".
- Max 3 legs (item 4) was NOT changed — still characterization, still open below. (The nutrition
  side models T1/T2 only — `generate-plan.md` H10 — so a 4th leg needs a math ruling too.)

## Conditions that need a ruling (each becomes a vector)
1. **Adjacency vs any-two-on-day.** Must the legs be consecutive on the day, or may any two eligible
   workouts on the day be linked (e.g. swim 06:00 · strength 12:00 · run 18:00)?
2. **Same-sport pairs.** Two runs — never a brick (current), or allowed (double-run day)?
3. **Sport set.** Swim/bike/run only, or is strength/other ever a leg?
4. **Leg count.** Max 3 (current) — ratify or lift?
5. **Leg state.** May a DONE_CONFIRMED / DONE_VERIFIED / SKIPPED leg be linked? (Current: yes,
   silently — the skipped case is almost certainly wrong.) May a brick be formed on a past day?
   A future day?
6. **Existing brick as a leg.** A brick next to a third workout — ungroupable-then-relink only, or
   direct extension?
7. **Time gap.** Is there a maximum gap between legs (T1/T2 assume minutes, not hours)? Does a gap
   above it make the pair ineligible, or merely change the nutrition (H10) treatment?
8. **Order.** Pick order = leg order (current) vs chronological order forced.

## Asked of the SSOT owner
- Rule on the family (`spec/domain/` or otherwise), then on 1–8.
- Until ruled, the app carries the characterization above and cites this intake.

## Found while making the fueling page follow the ruled brick (2026-08-26, app side)
Same-sport / any-order legs expose two server-side issues in the brick maths. Neither is fixed on
`feature/brick-on-macro-dashboard` (edge-function work goes through the deploy playbook); logged
here because both need a ruling, not just a patch.

- **Transition naming is inconsistent between functions — pre-existing.** `generate-macros-v4`
  (`brick-workout.ts`) names a transition by sport pair (swim→bike = `T1`, bike→run = `T2`, else
  `T{i+1}`), while `generate-nutrition-plan-v3` (`brick-handler.ts`) and the app mapper look
  transitions up as positional `T{i+1}`. A plain **bike→run** brick therefore emits a lone `T2`
  that the plan function never finds, and falls to the zero-default transition targets. With
  repeats allowed, sport-pair names also **collide** (bike→run→bike = `T2`,`T2`;
  bike→swim→bike = `T1`,`T1`) and the keyed map keeps only the last. Run→bike→run happens to
  be safe. **Ruling needed:** is a transition's *identity* positional (`T{i+1}`) with the sport
  pair as a label, or is `T1`/`T2` a triathlon-specific meaning? H10 in `generate-plan.md` says
  "T1/T2 transition fuel" without defining it for non-triathlon orders.
- **Run→bike redistribution double-counts with two run legs.** `calculateBrickHydration` loops
  every running leg and re-reads the bike leg's already-raised rate, so a 2-run brick adds the
  shortfall to the bike twice. Also `hydrationByOrder` / `segmentRates` are keyed by the
  client-supplied `order` with no uniqueness check server-side. Belongs in
  `during-workout-hydration.md`'s deferred "multi-segment tri" slice.
- **Brick penalty (×0.8 run-after-bike)** in `during-workout-carbs.md:46` is applied per
  adjacent pair in the loop, so run→bike→run penalises only the second run. That matches the
  ratified wording ("run-after-bike"); noting it so the vector for a 3-leg brick asserts it.
