# Design SSOT — Component: Cooking Mode

**Status: RECORDED v1 (Lee, 2026-09-03) — PROPOSED, awaiting Xuan.** Prototype `routes/food.cook_.$id.tsx`;
Dart `cooking_mode_screen.dart` + `cooking_session_controller.dart`. Reference for the feature set: the old
Mealvana consumer app's cooking mode (`../../../recipe-directions-and-cooking-mode.md` §4).
**Numbers authority:** `../../planning/cooking-timers.md`.

## State model

```
phase    ∈ { overview, cooking, done }
step     : index into methodSteps
ticked   : {step}                                  # steps marked done
timers   : RunningTimer[] {label, stepIndex, endsAt, remaining, paused, done}
wakeLock : held iff phase == cooking (re-acquired on visibility change)
```

## Contracts

| # | Contract |
|---|---|
| CM-1 | **Overview → one big step per screen → done.** Overview shows image (with licence credit — M-5), ingredients, and the "AI-written steps" badge when `directions.origin == ai_generated` (M-4). |
| CM-2 | **Navigation is swipe, oversized left/right tap zones, on-screen Back/Next and arrow keys.** No wave-to-advance on web (no proximity API); the Flutter port may restore it. |
| CM-3 | **Timers come from the step text** (one chip per parsed duration, ≤ 3, "Start N timer"); several may run at once; they survive step changes; pause / resume / cancel. |
| CM-4 | **The alarm is audible without an asset:** three rising blips (WebAudio, armed on the Start tap because iOS suspends the context) + vibration on web; local notification + vibration on Flutter (open decision 4). |
| CM-5 | **The screen stays awake while cooking** and quietly degrades where the API is missing. |
| CM-6 | **Done asks for the thumb** (`set_meal_feedback` — M-7); the same thumb again clears it. |
| CM-7 | **Tap zones must never swallow the timer chips** — the step content sits above the zones (prototype gotcha, z-index). |

## Conformance

Goldens: overview (with badge and credit), a step with two timer chips, a running timer, done. Widget: CM-3
timer lifecycle (start / pause / resume / cancel / survive a step change); CM-6 toggle. Dart:
`cooking_session_controller` tests + the timers vectors.
