# Log Workout Fuel

domain: 1 Fuel a workout · screen `nutrition_plan/presentation/screens/fuel_log_screen.dart` · route `/fuel-log`
· door page `../nutrition_plan.md`

What the athlete actually ate around a workout, plus how it went. Opens from "Complete" on the plan screen when a
plan exists, and by itself when a completed workout has a plan but no log yet. The app bar reads "Log Workout Fuel
· Adjust what you consumed" with "X" (close without saving) and "Done".

## What athletes can do here

- **Adjust what was eaten.** A copy of the plan, section by section ("BEFORE RUN": Full Meal, Pre-Workout Snack,
  Top-Off; "DURING RUN"; "AFTER RUN"), each food with ± in half servings; rows become "Added", "Skipped", "Partial"
  or "More than planned". "ADD FOOD" per section opens the food search. Garmin workouts note "Workout calories and
  duration".
- **Say how it went.** "How did it go?": "Overall Rating" stars (required; "Done" without one shows "Please add a
  rating before completing"), "How did the carbs feel?" with a card showing this workout's carbs per hour
  ("72 g CARBS / HR", "First effort", "Building baseline 1 / 4 Runs · Log fuel on 3 more completed 90+ min runs to
  unlock your carb trend. Imported workouts count once you complete them and log your fuel.") and five chips "Way
  Too Much" · "A Bit Too Much" · "Just Right" · "Needed More" · "Way Too Little", then "Notes (optional) · How did
  the nutrition feel? Any GI issues?".
- **Done** saves the log, marks the workout completed with the rating and notes, re-sends the plan and feedback to
  TrainingPeaks when connected, and shows "Fuel Logged · Your workout nutrition has been saved" with "Back to
  Activity". **The carbs answer changes the athlete's future during-workout carb rate** (anything but "Just Right"
  nudges the personal override up or down for later plans).
- **Without a plan:** "No fueling plan for this workout · Generate fueling plan / Close".

Writes `activities.fuel_log_data`, `completed_at`, `completion_rating`, `nutrition_rating`, `completion_notes`,
and `users.nutrition_target_overrides`. The Timeline counts logged fuel as eaten, so a log on a workout that has
not happened yet moves the day's net balance.

## Links

- `../activities.md` (completion fields), `../macro_dashboard.md` (net balance), `../meal_logging.md` (food search).
- qa: `spec/fueling/post-workout.md`, intake `during-carb-band-clamped-to-sport-ceiling`. ops: feature-requests
  `instrument-fuel-log-started`, `plan-rating-revive-or-drop`; bug `fueling-synced-past-workout-marks-skipped`.
- Previous: `activity-detail.md`.
