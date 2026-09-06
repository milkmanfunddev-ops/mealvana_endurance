type: ruling-request
bundle: daily-macros-dashboard@v3 (brick session pricing — narrows the composite-types half of 2026-08-20-session-cost-unknown-activity-types.md)

## Why this matters
Bricks are the core multisport object and until 2026-09-04 no side priced them from their legs:
the engine fed F4 the whole brick as RUNNING over the summed duration while display surfaces
priced it at the interim conservative strength rate — Xuan's device showed a 9,486-kcal intake
target beside a 1,980-kcal projected burn for the same two bricks (ops bug
`ops/data/bug-reports/2026-09-04-brick-priced-as-one-conservative-session.md`). A per-leg
interim is now implemented app-side at Xuan's direction; this file is the deferred ratification
it runs ahead of.

## What shipped (implemented-pending-ruling, app repo 2026-09-04)
`brick_session_legs.dart`: a brick with segment metadata decomposes into one session per leg —
each leg at its own already-ratified F4 rate (running 11 / cycling 9 / swimming 7, quadratic;
unknown leg sport → `engineSport` mapping) over its own duration through the shared
`SessionInputResolver` ladder. Both consumers use the one decomposition: the engine feed
(`DailyMacroService._sessionsFromActivityRow`) and the dashboard
(`MacroDashboardAssembler._sessionKcal`), so targets and display reconcile by construction.
Deliberately conservative sub-choices, each an open question below:
- every leg inherits the PARENT session's zone distribution (IF);
- expanded legs carry NO `activity_id`, so per-session Garmin completion never attaches to them;
- the brick-level TSS rides on the first leg only;
- a brick with absent/unparseable segments falls back to the previous single-session pricing;
- transitions (T1/T2) price as nothing.
Nothing new is invented — rates, RMS IF derivation, and duration ladder are the ratified ones;
only the decomposition itself is interim. Pinned by
`test/features/daily_macros/brick_session_expansion_test.dart`,
`test/features/activities/domain/brick_session_legs_test.dart`, and the brick group in
`test/contracts/session_pricing_producer_consumer_test.dart`.

## The questions
1. **Decomposition (the headline):** is a brick's session demand (F4 kcal and F5 carb demand)
   the plain sum of its legs, each at its own sport's rate over its own duration? (The shipped
   interim says yes for kcal; F5 carb demand still sees whatever the engine derives from the
   expanded sessions — confirm that is the intent.)
2. **Per-leg IF:** brick segments carry an `intensity` string (easy/moderate/hard/race) but the
   session row carries ONE zone distribution. Should each leg derive its own IF from segment
   intensity (needs a ratified intensity→distribution mapping), or keep inheriting the parent's?
3. **Measured whole-brick allocation:** when Garmin reports ONE ActiveKilocalories for the whole
   brick, how does it reconcile against N formula legs on a retrospective recalc — replace the
   summed formula total with the measured total (recommended), prorate across legs by formula
   share, or attach to nothing (the shipped interim, which currently leaves retrospective bricks
   on pure formula)?
4. **Transition cost:** do T1/T2 price as 0 (shipped), or as strength-rate minutes when segment
   metadata carries transition durations?
5. **Metadata-less bricks:** confirm the fallback (interim conservative single session) or rule
   a better degenerate shape (e.g. whole duration at the dominant-leg rate).

## Recommendation
1: yes, ratify the sum-of-legs decomposition (it uses only already-ratified quantities).
2: parent-IF inheritance until a segment-intensity mapping is worth ratifying on its own.
3: measured total replaces the formula sum for the brick as one unit.
4: zero until evidence says otherwise. 5: keep the conservative fallback.

## Suggested spec home
`session-demand.md` — a "composite sessions" clause under F4 (cross-referenced from F5), plus
vector rows: one multi-leg brick (run/bike/run) with per-leg expecteds and the summed total,
one metadata-less brick, one measured-brick retrospective case. Supersedes the composite-types
half of `2026-08-20-session-cost-unknown-activity-types.md` for BRICK specifically (tri/du/
multisport imports and the mobility classes remain open there).

## Gates
QA: vector rows above; DEVIATIONS.md entry for the app-side implemented-pending-ruling state.
App: fold the ruling back into `brick_session_legs.dart` / `_sessionsFromActivityRow` (questions
2–4 may change them); the TS engine (`calculate-daily-macros-v6/formulas/session.ts`) needs no
change for question 1 (expansion is client-side) but questions 2–3 may touch `resolve.ts`.
