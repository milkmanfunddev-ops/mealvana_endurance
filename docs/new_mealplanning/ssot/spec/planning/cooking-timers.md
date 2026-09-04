# SSOT — Cooking Timers

**Status: RECORDED v1 (Lee, 2026-09-03) — PROPOSED, awaiting Xuan.**
**Engine:** Dart `CookingStepTimers.findDurations(text)` / `clock(seconds)`
(`lib/features/meal_planning/domain/cooking_step_timers.dart`) — a port of `findDurations` / `clock` in the
prototype's `routes/food.cook_.$id.tsx`, which are **not exported** (D-13: TS arm pending extraction).
**Consumers:** cooking mode — the "Start N timer" chips under a step; the running-timer clock.

## Constants

```
RE           = /(\d+(?:\.\d+)?)\s*(?:(?:–|—|-|to)\s*(\d+(?:\.\d+)?)\s*)?(seconds?|secs?|minutes?|mins?|hours?|hrs?)\b/gi
UNIT_SECONDS = { sec 1, second 1, min 60, minute 60, hr 3600, hour 3600 }
MIN_SECONDS  = 5            # anything shorter is not a cookable timer
MAX_SECONDS  = 12 h         # anything longer is not a timer either
MAX_QUANTITY = 600          # "601 hours" is a parse error before the seconds test
MAX_PER_STEP = 3
```

## The algorithm

```
for each match: unit = singularised (secs→sec, mins→min, hrs→hr); hi = upper bound of a range, else the number
  skip if hi ≤ 0 or hi > 600; seconds = round(hi × UNIT_SECONDS[unit]); skip unless 5 ≤ seconds ≤ 43200
  keep { label: matched text trimmed, seconds, index: match offset }
dedupe by seconds (first occurrence wins); take the first 3
clock(s): s = max(0, round(s)); h ? "h:mm:ss" : "m:ss"
```

**A range takes its upper bound** — "better to check early than to walk away from an under-timer" (prototype
comment). Timers survive step changes, can run concurrently, pause/resume/cancel; the alarm is a WebAudio triple
blip + vibrate on web and a local notification + vibration on Flutter (open decision 4 in
`../../../implement_mealplanning/README.md`). Those behaviours are design contracts
([`../design/components/cooking-mode.md`](../design/components/cooking-mode.md)), not calculation.

## Invariants

1. A number without a time unit is never a timer (`no-unit-no-timer`, `number-before-degrees-then-minutes`).
2. Bounds are inclusive at 5 s and 12 h.
3. Order is text order; duplicates collapse to the first label.
4. `clock` never renders a negative.

## Conformance

Vectors: `vectors/planning/cooking-timers.json` (21: 15 `findDurations`, 6 `clock`). Dart 21/21 (2026-09-03,
after correcting a hand-counted index in the vector — the engine was right). TS arm: **pending extraction** of
`findDurations` into `lib/vana/` so the prototype runner can cover it (D-13).
