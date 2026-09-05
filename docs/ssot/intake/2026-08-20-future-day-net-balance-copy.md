type: ruling-request
bundle: daily-macros-dashboard@v3

## Why this matters
The dashboard's headline figure speaks intraday urgency language on days that have not begun; until ruled, the display consumer has no contract for what a future day's net-balance card should say, and the current rendering reads as a command to eat toward tomorrow's workout today.

## The question
What does the NET BALANCE card show, and which copy register applies, when the selected day is in the FUTURE?

## Observed (dev build 1.23.1, 2026-08-20 /sim-explore)
Selecting tomorrow (Aug 21, one planned workout) shows `−2,115 kcal · "deficit — time to eat"` — the full-day projected deficit with the intraday band copy. Adding tomorrow's workout deepened it to −2,157. Screenshot: session scratchpad explore/18-day21.png.

## What is already ruled (and where it is silent)
- `spec/daily-macros/intraday-display.md` defines net balance and the SS2 band-copy register for the CURRENT day ("so far" semantics; suppression rules name `pre_override` only). It does not name future days.
- `conformance/design/macro-dashboard.gestures.yaml` `band_copy_matches_register` pins band strings against the intraday vectors — again current-day.
- Past days render historical record (Q-016 spirit). Future days: nothing.

## Options
1. **Projection register:** future days show `*_by_days_end` projections with distinct copy (e.g. "projected deficit — plan your fueling"), never the intraday urgency strings.
2. **Suppress the figure:** future days show targets only (no net balance) until the day starts.
3. **Status quo:** the intraday register applies verbatim to any selected day; document that "time to eat" can refer to a future day.

## Recommendation
Option 1 — the number is already a projection there; only the register is missing. Small copy table, one spec addition.

## Suggested spec home
`spec/daily-macros/intraday-display.md` (SS2 band-copy register: a future-day column or a projection register), cross-referenced from `spec/design/surfaces/macro-dashboard.md`.

## Gates
Display-consumer copy branch + one gestures-manifest assertion (`band_copy_matches_register` gains a future-day negative half). No engine change.
