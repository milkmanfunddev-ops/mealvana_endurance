# Formula library (formula_kit)

domain: 1 Fuel a workout · folder: `lib/features/formula_kit/` (45 files)

A library of fueling recipes for Before, During and After a workout: a list of foods and amounts plus tags for when
it applies. An athlete can browse them, copy one and edit it ("Make this mine"), or build their own, and **pin** a
formula so plan generation uses it whenever it fits. A pin overrides diet, allergy and preference filters.

## What athletes can do here

- **Open the library.** Settings → "Diet, Allergies & Formulas" → "Formula Library" (route
  `/settings/food-preferences/formula-library`), or from the plan screen's pin banner ("Pin your favorite formula →",
  "Edit in Formula Library →").
- **Browse.** Tabs Before / During / After, then scope chips: Before by timing "Meal" / "Snack" / "Top-up"; During
  by activity "Running", "Cycling", "Tri — Bike", "Tri — Run", "Tri — Transition" and duration "< 90 min", "90–150
  min", "150–240 min", "> 240 min"; After by activity and travel "In bag", "Cooler-friendly", "Home only". The
  thumbtack in the app bar shows pinned only; the sliders icon opens "More filters" (digestion speed, gut-training
  level, "Hide formulas with" diets and allergies). "Your Formulas" sits above the "Library" of system formulas.
- **Read a formula.** Its name, macros (Cal / Carbs / Protein / Fat / Sodium / Fluid), "Components", "Notes",
  "Activities", "Duration", "Gut training", "DIETARY"; During formulas note "Macros scale to your hourly carb target".
- **Pin or unpin** from the card or the detail page ("Pin formula" / "Unpin formula"). Pinning something that
  clashes with an allergy warns "This formula contains X, which you've listed as an allergy. Pinning it means
  Mealvana will always include it." with "Choose another" / "Pin anyway"; a diet clash shows "Doesn't match your X
  preference." The app tells, never blocks.
- **Make it yours.** "Make this mine" copies a system formula into "Your Formulas" and opens the editor. "+ New"
  starts from scratch: "Name" ("e.g. Pre-long-run oatmeal"), "Phase", scope ("Timing (required)" for Before,
  "Activities", "Duration", "Travel"), macro totals, food rows (swipe right to swap, swipe left to delete, quantity
  steppers on Before and After), "Add Food", "Notes (optional)", "Save formula" → "Formula saved". Swipe a personal
  card left to delete ("Delete formula?" → "Formula deleted").
- **Ask the coach** (dev builds only today): with at least one food in the editor, "Get a quick read on this formula
  from your coach." → "Get coach insight" → a short tip (one AI token unless a fixed rule answers), "Outdated — your
  formula changed." with "Refresh" after edits.
- **See what the plan did with your pins.** On the plan screen: "Using your pinned formulas", "Some pins honored,
  some skipped", "Pin didn't apply to this workout · No in-scope pin for this activity", or "Your formula didn't
  apply here · N of your formulas were skipped — tap ? for why" ("“X” is set for 90-150 min. This workout falls in
  < 90 min, so it wasn't used."). Details on `nutrition_plan/activity-detail.md`.

## What the data means

`formula_pins` (phone and Supabase): `template_id`, `template_kind` (pre_system | during_system | post_system |
personal_formula), `is_deleted` (unpin). `personal_formulas`: name, provenance (forked | from_scratch), phase,
source template, `sub_phase`, `digest_speed`, activities, durations, gut training, travel friendliness,
components JSON, notes, `coach_insight_text` / `_marker`, totals. System formulas are the read-only tables
`pre_workout_templates`, `during_workout_templates`, `post_workout_templates`, `templates`, `template_foods`. The
server matches a pin on activity × duration bracket × time window inside `generate-nutrition-plan-v3` (the
phone's offline fallback ignores duration); the pin outcome is stored inside the plan JSON. Pins choose foods, never
the target numbers. The "Top-up" timing in the library is spelled "Top-Off" on the plan screen. Analytics:
`formula_pinned` / `formula_unpinned` {template_id, template_kind, phase, source, sub_phase, activities,
duration_brackets}, `formula_library_opened`, `formula_detail_viewed`, `formula_fork_started`,
`personal_formula_created/edited/deleted`, `pin_status_banner_shown/expanded/formula_library_tapped`,
`coach_insight_requested/generated/failed`.

## What already exists to reuse

- `application/formula_pin_controller.dart` (pin set, toggle, analytics), `formula_library_controller.dart`
  (catalogue, filters), `personal_formulas_controller` + `formula_editor_controller`, `coach_insight_controller.dart`
  + `data/ai_coach_client.dart` (edge function `ai-coach`, mode insight), `domain/pin_decision.dart`,
  `domain/formula_profile_conflict.dart` + `athleteConflictProfileProvider`, `domain/before_sub_phase.dart`,
  `during_filter_options.dart`, `after_filter_options.dart`.
- Screens: `formula_library_screen`, `formula_detail_screen`, `formula_editor_screen`. Widgets: `pin_status_banner.dart`
  (with `nutrition_plan/.../pin_banner_rows_builder.dart`), `pin_toggle`, `pin_conflict_warning`, `pin_conflict_label`,
  `more_filters_sheet`, `coach_insight_panel`, `save_conflict_disclosure`.

Don't add: another scope model or pin store. Gardening: stale comments at `formula_library_screen.dart:262-264,457`,
`pin_status_banner.dart:36,70,564`, `save_conflict_disclosure.dart:7`, `formula_pin_controller.dart:22-23,66`,
`coach_insight_panel.dart:19`, `coach_insight_controller.dart:47-58`, `ai_coach_client.dart:36`, `app_router.dart:889`,
`personal_formula.dart:48`; "Top-up" vs "Top-Off".

## Links

- **qa:** `spec/design/components/formula-pin-surface.md` · `spec/fueling/food-recommendation.md` (§1a pin override) ·
  `spec/recommendation/generate-plan.md` · intake `personal-formula-conflict-labeling`, `pinned-instrument-block-ruling`,
  `pin-override-bypasses-allergens-and-clamp`.
- **ops open work:** bugs `formula-detail-shows-raw-component-ids`, `pins-and-forks-do-not-reach-the-saved-plan`,
  `ephemeral-default-formula-used-pin-true`, `brick-during-pins-invisible-and-tri-scope-unreachable`,
  `pinned-backfill-ships-salt-packets-tablet-not-in-pool` · feature-requests `formula-library-off-the-settings-shelf`,
  `formula-library-open-in-context`, `eng-task-qa-conformance-pins-superseded-carb-band`.
- **Related map pages:** `nutrition_plan/activity-detail.md` · `settings.md` · `ai_credits.md`.
