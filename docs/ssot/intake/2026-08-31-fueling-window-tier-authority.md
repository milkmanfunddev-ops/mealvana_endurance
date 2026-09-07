> **RESOLVED 2026-09-03 → option 1 FULLY RULED: mechanism + clamp + §3a table values + early-start rule (values confirmed by Xuan same day)**

type: ruling-request
bundle: (food-recommendation ratification; pre-workout-carbs@v2 tier activation)

## Why this matters
An unratified client-side heuristic — not the athlete, not a spec — decides whether a marathon gets a pre-workout MEAL at all; today it decided "no" and the meal was three bananas' worth of snack.

## The question
Who owns `hours_before` (the fueling window that drives tier activation: meal iff ≥120min, snack iff ≥30min)? Today it is `recommendedHoursBefore(sport, intensity, duration)` in `lib/features/nutrition_plan/domain/meal_type.dart:42-67` — a formula (duration 60% + intensity 40%, sport-capped at 3.5h) that has never been ratified, plus it is NOT clamped to the actual time until the workout.

## Evidence (F-28, F-38 — probe register)
- Sim: 24-mi run whose duration was mis-derived as 108min (see ops pace-fallback bug) → recommended window 1.5h → active phases [snack, top_up] only → pre-workout plan for a marathon = "Banana ×3 + gel + coconut water" (`13-created.png`, stored subPhases).
- Same formula at 240min gives 2h15m → meal active (`20.png` vs `24.png`).
- Plan generated 1h11m before the workout still renders "Pre-Run Meal — FINISH BY 2H OUT" — the window is not clamped to time-remaining (`24.png`).

## Options
1. Ratify a timing table into the carbs SSOT (duration/intensity → recommended window), require clamp to time-until-workout, and surface the window prominently at creation (recommended — the tier engine's INPUT deserves the same governance as the tiers).
2. Make the window purely user-chosen with a spec'd default (e.g. 3h for ≥2h workouts).
3. Ratify the current formula as-is.

## Gates
"No meal before a marathon" class of plans; F-38 clamp fix scope; where the window control lives in the create flow.

## Suggested spec home
`spec/fueling/pre-workout-carbs.md` — new section "fueling-window (hours_before) authority", cross-referenced from pre-workout.notes.

## PARTIAL RULING (Xuan, 2026-09-02, dossier thread db654def)
**The clamp is RULED:** the fueling window may never exceed the actual time until the workout;
tiers whose minimum window exceeds the remaining gap are not offered; feedings are never
scheduled in the past. Folded into `spec/fueling/food-recommendation.md` §3. **Still open:**
window authority inside the clamp (options 1–3 of this file / dossier Q-FR2).

## RULING (Xuan, 2026-09-03, RULING-DESK block — option 1; values research-gated)
**Mechanism RULED:** a ratified timing table (duration/intensity → DEFAULT window, user-adjustable
within the already-ruled clamp), surfaced at creation. Xuan: "the recommended window would be a
default window — for example, for race effort ~3 hrs ahead; please do research on sports nutrition
what the best recommendation would be." → table VALUES enter as a research-derived PROPOSED table
in food-recommendation.md §3 for his sign-off (research delivered 2026-09-03).
