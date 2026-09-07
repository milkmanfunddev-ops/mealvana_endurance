> **DEFERRED 2026-09-03 (Xuan) — ruling postponed; the NARROW fix shipped ahead of it.** The fueling-window half is implemented (app `7418566f`) and recorded as `DEVIATIONS.md` D-018 `implemented-pending-ruling`; it sits in the intersection of options (a)/(b) so it cannot pre-empt this ruling. What still needs deciding: the lifetime of the OTHER form state (title / temperature / humidity flags) and whether values stay sticky.

type: ruling-request
bundle: food-recommendation@v1 (design slice create-flow / the PROPOSED create-activity-plan surface)

## Why this matters
Xuan hit it on-device 2026-09-03: a fueling window stepped once on tonight's run rides into
tomorrow's new activity, and because the manual flag latches, the ruled §3a defaults (incl.
Race Pace ⇒ 3 h) can never re-derive again for the rest of the app session. The engine-side rules
are implemented correctly; the state lifetime is what defeats them. Ops bug:
`../ops/data/bug-reports/2026-09-03-fueling-window-sticks-across-activities.md`.

## The question (Q-CA2, now live)
The sport input controllers are `keepAlive` singletons with **no reset path**. What is the ratified
lifetime of create-flow form state and of the `*ManuallySet` flags?

- **(a) Per-activity (recommended).** Opening the create flow for a NEW activity resets values and
  flags; "a manual change persists" (CF-1) means *within the activity being edited*. Editing an
  existing activity re-hydrates from that activity.
- **(b) Sticky per session, values only.** Keep the last-used values as convenience defaults but
  reset the `*ManuallySet` flags, so ruled defaults still re-derive when inputs change.
- **(c) Sticky entirely (today's behaviour).** Ratify as-is — the athlete's last choice is treated
  as a standing preference. (Would need the window to still re-clamp, else past-scheduled feedings
  return.)

## Scope note
The same shape applies to `activityTitleManuallySet`, `temperatureManuallySet`,
`humidityManuallySet` — a ruling should say whether they follow the same rule (recommended: yes,
one lifetime for all form state).

## Gates
The app fix's scope (which flags/values reset, and where the reset fires); CF-1's wording on manual
persistence; the PROPOSED `create-activity-plan.md` Q-CA2 row, which closes with this ruling.

## Suggested spec home
`spec/design/surfaces/create-flow-fueling-controls.md` (RATIFIED — post-ratification addition as
CF-9), cross-referenced from the create-activity-plan surface's Q-CA2.
