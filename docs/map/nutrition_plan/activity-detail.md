# The plan screen (workout detail)

domain: 1 Fuel a workout · screen `nutrition_plan/presentation/screens/activity_detail_screen.dart` · route `/plan`
(also `/current-plan`) · door page `../nutrition_plan.md`

One screen with two jobs: the fuel plan for a workout, and the workout's own detail page. Reached from "Create
Plan" (as a new plan), from a workout card or its "Pre · During · Recovery fuel ›" line, from a race's "View
Nutrition Plan", from notifications, and from the coach portal.

## What athletes can do here

- **Read the header.** The workout's title (a race's name when linked), "Planned 1h 8m ahead" (time until the
  start, while it is in the future), the sport image, "RUN SCHEDULED FOR" with "{distance} · {duration} · {pace}",
  "DATE" and "TIME". For a swim the pace reads "/mi" here (a known gap; Adjust Your Macros shows it per 100 m).
- **Move the workout.** Tap the date or the time: one picker each; the change saves at once through the same rule
  every move uses (`movedTo`), with no "Save" needed and without marking the plan stale.
- **Top-right icons.** Bookmark "Save as Routine" (saves the foods as a routine, up to ten: "Routine limit reached
  (10)…"; "No nutrition plan to save as routine" without one), pencil "Edit Activity" (reopens the form
  pre-filled) or, once completed, "Edit Fuel Log", and the trash "Delete Activity" → "Are you sure you want to
  delete this activity? This action cannot be undone." → "Cancel" / "Delete".
- **Read the pin banner** (only for athletes with pinned formulas): "Using your pinned formulas", "Some pins
  honored, some skipped · N honored · M skipped", "Pin didn't apply to this workout · No in-scope pin for this
  activity", or "Your formula didn't apply here · N of your formulas were skipped — tap ? for why". "?" opens "Why
  your formula wasn't used" with one line per formula ("“X” is set for 60-90 min. This workout falls in …, so it
  wasn't used.") and "Edit in Formula Library →". The chevron lists each phase (Meal / Snack / Top-Off / During /
  After) with the formula used or "No pin found". Athletes with no pins see "Pin formulas you love · We'll use them
  whenever they fit your activity." See `../formula_kit.md`.
- **Stale warnings.** "Schedule Changed · Schedule has changed since this plan was generated. Regenerate to match
  your updated workout." with "Regenerate Plan" (after a platform moved or resized the workout; the same words
  appear after a nutrition-settings change), and "Nutrition Settings Changed · Nutrition settings changed. Regenerate
  plan to apply new targets." Both buttons reopen the form pre-filled.
- **BEFORE.** Three figures, CARBS · FLUIDS · SODIUM, each the sum of the foods below, with a band and a triangle
  at the engine's target for carbs and fluids (none for sodium; "No fluid target for this session" when gated).
  Feeding cards "Pre-Run Meal" (so named for every sport), "Light Meal" or "Pre-Workout Snack", and "Top-Off", each
  with a window line ("FINISH BY 2H OUT", "NOW UNTIL 30 MIN OUT", "LAST 30 MIN"…) and food rows with ± steppers in
  half servings (whole for indivisible foods; stepping to zero removes the row), "+ Add Food", and a hydration
  check when the window is two hours or more.
- **DURING.** "?" explains the phase with this workout's numbers. "Summary" / "By Hour" ("Hour N" buckets,
  "UNASSIGNED", "SIP THROUGHOUT", "Drag or tap to place in a specific hour"). Food rows: swipe right to "Swap"
  (opens "Swap {food}"), swipe left to "Delete" (confirm "Delete Food Item"); tap to expand "Quantity" and
  "Nutrition Facts". "ADD FOOD". The summary bars round to 5 g and 25 ml.
- **AFTER.** Food rows with swap and delete, no figures; "?" explains why.
- **Every food change saves itself** (swap, delete, quantity, hour).
- **Bottom buttons by state.** Just created: "Save Workout" (saves and returns to the Timeline) and "Save as
  Routine". Later: "Save" and "Complete". "Complete" with a plan opens "Log Workout Fuel" (`fuel-log.md`); without a
  plan it opens "Workout Complete!" (stars, "Add notes (optional)", "How did the carbs feel?", "Complete" / "Skip").
  A coach sees only "Save".
- **No plan yet.** "No nutrition plan yet · Generate a nutrition plan to see recommendations" with "Generate Plan"
  (the form, pre-filled).
- **Once completed.** "Workout Completed" with the date, "Rating" stars and the carbs feeling, read-only (edit via
  the pencil). A completed and logged workout also gets a "Planned" / "Actual" toggle and a "CARBS / HR" card.
  Garmin workouts show the Garmin attribution under the date and a footer "Insights derived in part from Garmin
  {device} data."

## Links

- Reads and writes `activities.nutrition_plan_data`, the time fields via `movedTo`, completion fields
  (`../activities.md`); routines → `personal_templates`. Swap/Add food search → `../meal_logging.md`.
- qa: `spec/design/surfaces/pre-workout-before-card.md` (B-1 delivered = sum of rows; F-2 no sodium band),
  `spec/design/components/formula-pin-surface.md`, `hydration-check.md`, `spec/fueling/during-workout-*.md`,
  `post-workout.md`. ops: bugs `bike-plan-header-shows-run-pace`, `pins-and-forks-do-not-reach-the-saved-plan`,
  `after-phase-ignores-fluid-target`, `brick-during-pins-invisible-and-tri-scope-unreachable` · feature-request
  `by-hour-auto-assign-fuel-across-hours`.
- Previous: `adjust-macros.md`. Next: `fuel-log.md`.
