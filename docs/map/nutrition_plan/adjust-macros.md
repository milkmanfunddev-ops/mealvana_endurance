# Adjust Your Macros

domain: 1 Fuel a workout · screen `nutrition_plan/presentation/screens/adjust_macros_screen.dart` · route `/adjust-macros`
· door page `../nutrition_plan.md`

The engine's targets for this workout, shown once before foods are chosen. Reached only from "Generate Plan" on
the form.

## What athletes can do here

- **Read the targets.** Header "{sport} · {h} h • {N}MI" (miles rounded to a whole number), pace and "TOTAL BURN"
  cards (swim pace per 100 m here; a brick shows one pace card per leg), then "Your Nutritional Targets": PRE /
  DURING / POST × CARBS, PROTEIN, FLUIDS, SODIUM. A dash means no target: there is never a pre-workout sodium
  target, and pre-workout fluids can be gated for short sessions.
- **(i)** opens "Nutrition Guidelines": general notes on carbohydrates, sodium, fluids, protein, fats and "Key
  References". The text is fixed; it does not use this workout's numbers.
- **"Edit Macros"** opens "Edit Macro Targets" with fields for each phase ("CARBS (g)", "PROTEIN (g)", "FLUIDS
  (oz|mL)", "SODIUM (mg)"), "Save Changes" / "Cancel". Every field must hold a number ("Invalid input: enter a number
  in every field"), including pre-workout sodium, which starts empty. Edits are kept only on the phone until
  "Create Plan"; the engine then treats them as overrides and widens its band to include them.
- **"Reset All"** → "Reset to Recommended · This will reset all macro values to the recommended amounts. Continue?"
  → "Cancel" / "Reset".
- **"Create Plan"** asks the engine for foods ("Crafting your perfect fuel strategy…"), writes the plan to the
  workout (status planned), pushes it to TrainingPeaks when connected, links the race if the form came from one,
  and opens the plan screen.

The numbers here are targets. The plan screen's big numbers are what the chosen foods deliver, so they differ
(a 51 g target can become 49 g of bagel; pre-workout sodium appears there as the sodium in the foods, 407 mg,
although there was no target). See `activity-detail.md`.

## Links

- Engine: `generate-macros-v4` (targets), then `generate-nutrition-plan-v3` (foods) on Create Plan. Writes:
  `activities.nutrition_plan_data`, `duration_minutes`, `pace_target_minutes_per_mile`, `needs_nutrition_refresh`
  (`../activities.md`).
- ops: bug `adjust-macros-renders-gated-fluid-as-0oz`. Known gaps for the gardening pass: the fluid fields in
  "Edit Macros" are pre-filled and saved in mL whatever the label says; a gated pre-fluid pre-fills as "0"; the
  pre-sodium field is required although no target exists.
- Next screen: `activity-detail.md`. Previous: `new-activity-form.md`.
