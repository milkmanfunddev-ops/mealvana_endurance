type: ruling-request
bundle:

## Why this matters
`Activity` persists `distanceMiles`, `durationMinutes`, `paceTargetMinutesPerMile` as three independent columns with no invariant. Two live defects are the same root cause: the Critical stale-45m bug (editor corrected duration, plan generation consumed the stale one) and the Garmin import that updates avg speed but not distance/duration. A ratified invariant makes both classes of bug detectable at write time instead of on the plan screen.

## The question (R4)
What relationship must hold among the persisted distance / duration / speed-pace, which one is the source of truth for the engines, and who is responsible for re-deriving dependents on write?

## Options
1. **Duration is the engine SOT; `distance ÷ speed` (or `distance × pace`) must reconcile to it within rounding tolerance on every write; any writer (editor, Garmin/Runna import, plan generation) that changes one field re-derives the dependents (recommended).** Cheap to check; makes an impossible triple unrepresentable.
2. Persist only two (distance + speed/pace), derive duration on read. Cleanest but touches storage + every reader; larger migration.
3. Keep three independent columns; enforce consistency only in the editor UI. Leaves import and generation free to diverge — status quo failure mode.

## What is already ruled (and what isn't)
- Engines take `duration_hr` as given (`generate-plan.md`, `session-demand.md`); nothing says where it comes from or that it must agree with distance/pace.

## Suggested spec home
`spec/activity/editor-inputs.md` §invariant, plus a conformance vector family (`vectors/activity/…`) that asserts the reconciliation on the editor's save payload and on import.

## Gates
Correct scoping of the stale-45m bug fix (Lee) — with this ruled, his fix is "make the invariant hold", not "find the second variable"; the Garmin avg-speed bug; item 06.
