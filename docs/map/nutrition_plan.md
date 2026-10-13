# Nutrition plan (fuel for one workout)

domain: 1 Fuel a workout · folder: `lib/features/nutrition_plan/` (189 files, the app's largest)

The per-workout fuel plan: what to eat and drink before, during and after a session, and the log of what was
actually eaten. Five screens, each with its own page:

| Screen | Page | Route |
|---|---|---|
| "Create New Activity Plan" (the form) | `nutrition_plan/new-activity-form.md` | `/distancepacegut` |
| "Adjust Your Macros" | `nutrition_plan/adjust-macros.md` | `/adjust-macros` |
| the plan screen, also the workout's detail screen | `nutrition_plan/activity-detail.md` | `/plan` |
| "Log Workout Fuel" | `nutrition_plan/fuel-log.md` | `/fuel-log` |
| "Swap {food}" / "Add Food" | on the plan screen page | `/swap-food` |

The path from nothing to a saved plan: form → "Generate Plan" → Adjust Your Macros → "Create Plan" → plan screen
→ "Save Workout". A workout exists as a draft from "Generate Plan" onward and becomes a planned workout at "Create
Plan". "Use Routine" on the form skips Adjust Your Macros and lands on the plan screen with a saved routine's foods.

## What the data means

Everything lands on the `activities` row (see `activities.md`): the plan inputs (`distance_miles`, `duration_minutes`,
`pace_target_minutes_per_mile` as the engine's pace, `time_before_minutes`, `intensity_target`, `cycling_*`,
`swimming_*`; `intensity_level` is always `moderate` from this flow), `nutrition_plan_data` (the plan JSON: sections
Before / During / After with sub-phases, food items, per-phase targets, by-hour buckets, pin decisions, plus
`detailedMacroTargets` echoing the engine's pre / during / post targets, metrics and conditions) and
`needs_nutrition_refresh`. After the fuel log: `fuel_log_data` (per item planned vs actual quantity, added or
skipped; `overallSatisfaction`, `nutritionRating`, `notes`), `completed_at`, `completion_rating`,
`nutrition_rating`, `completion_notes`. Elsewhere: `events.activity_id` (the plan flow links a race to its workout),
`users.nutrition_target_overrides` (the fuel log's "How did the carbs feel?" answer changes the athlete's future
during-carb rate), `personal_templates` (routines). Temperature, humidity, their source and the intensity mix are
not columns; they go to the engine and come back inside `detailedMacroTargets`.

Two engines, on the server: `generate-macros-v4` turns the form into targets (carbs, protein, fluids, sodium for
pre / during / post; no pre-workout sodium target; fluids can be gated) and `generate-nutrition-plan-v3` turns targets
into foods. Pinned formulas change which foods are picked, never the target numbers. Targets edited on Adjust Your
Macros are sent as overrides and the engine widens its band to include them. Until "Create Plan", edited targets
live only in the phone's preferences cache. Abandoned drafts (left at Adjust Your Macros) stay on the row as status
`draft`; the cleanup fires only on sign-out.

## What already exists to reuse

- `presentation/providers/macro_targets_controller.dart`: the create flow (per-sport generate, draft row, Edit /
  Reset, Create Plan, routine use, event link, TrainingPeaks push).
- `presentation/providers/activity_detail_controller.dart`: the plan screen (load, save, move date via `movedTo`,
  food edits with auto-save, complete, fuel log, carb feedback). `presentation/providers/new_activity_coordinator.dart`
  + the four input controllers (running, cycling, swimming, brick; kept alive for the session on purpose, qa
  CF-9) and `resetFormStateForNewActivity`.
- `application/macro_generation_service.dart`, `brick_macro_service.dart` (v4 calls, offline fallback),
  `application/nutrition_plan_service.dart` (v3 call, client fallback), `macro_explanation_service*.dart` (the phase
  "?" sheet text), `application/pre_workout_before_card_assembler.dart` (BEFORE card arithmetic; delivered = sum
  of rows), `presentation/utils/pin_banner_rows_builder.dart`, `presentation/utils/post_create_navigation.dart`.
- `domain/fueling_window_authority.dart` + `fueling_window_limits.dart` (the pre-workout window defaults and cap),
  `domain/workout_preset.dart` (the intensity chips), `domain/conditions_source.dart` (Measured / Assumed / Manual).
- Widgets by screen: `widgets/new_activity/` (sport selector, date-time section, workout details, tab contents),
  `widgets/activity_detail/` (app bar, action buttons, schedule info, before/during/after sections, by-hour view,
  phase explanation sheet, stale warnings, completed badge), `widgets/fuel_log/`, `screens/swap_food_screen.dart`.
  From other folders: `personal_templates` (`template_picker_sheet`, `save_template_dialog`, `template_scaling_service`),
  `formula_kit/presentation/widgets/pin_status_banner.dart`, `weather/` (forecast and the WeatherDetailScreen),
  `shared/widgets/kyle_design/inputs/intensity_distribution_widget.dart`.

Don't add: another pace or distance coupling rule (the activity-editor rulings in qa intake), another fueling-window
default (the authority), another way to save food edits (they auto-save). Dead, not to revive: `application/llm_response_parser`,
`nutrition_plan_analytics`, `food_preference_resolver`; `data/transparency_feedback_store`, `food_database`;
`domain/pre_workout_food_composition`, `carb_transparency_data`, `swimming_parameters`, `cycling_parameters`;
widgets `macro_targets_widget`, `plan_container`, `plan_section_widget`, `macro_targets_expander`, `macro_section_card`,
`contextual_banner`, `macro_target_badges_widget`, `low_fuel_risk_badge`, `run_summary_header`,
`edit_macro_section_dialog`, `carb_full_story_section`, `carb_tldr_section`, `activity_coach_notes_widget`,
`completion_dialog`, `food_details_dialog`, `sip_throughout_row`, `fuel_log_compact_header`,
`new_activity_generate_button`, `deck_conditions_section`.

Gardening (stale comments): `new_activity_screen.dart:42-43,148-150,735`, `adjust_macros_screen.dart:40-42,618`,
`new_activity_coordinator.dart:38-44,173,311-312`, `running_input_controller.dart:484-487,835`,
`macro_targets_controller.dart:514` ("generate-macros"; it is v4), `nutrition_plan_service.dart:195` ("V2"; it is v3),
`activity_detail_app_bar.dart:235`, `activity_detail_screen.dart:51`, `nutrition_sections_builder.dart:169`,
`fuel_log_screen.dart:188-191`, `stale_plan_warning.dart:16-18`, `shared/services/notification_intent_routes.dart:99-100`.

## Links

- **qa:** `spec/design/surfaces/create-activity-plan.md`, `create-flow-fueling-controls.md` (CF-1…CF-9),
  `pre-workout-before-card.md` · `spec/design/components/formula-pin-surface.md`, `hydration-check.md` ·
  `spec/fueling/pre-workout-{carbs,hydration,sodium,food-composition}.md`, `during-workout-{carbs,hydration,sodium}.md`,
  `food-recommendation.md`, `post-workout.md`, `transition-nutrition.md` · intake `activity-editor-01…07`,
  `pre-workout-fluid-gate-thresholds`, `before-card-*`, `fueling-window-tier-authority`,
  `pin-override-bypasses-allergens-and-clamp`, `personal-formula-conflict-labeling`, `pre-workout-carb-band-ruling`,
  `pinned-instrument-block-ruling`, `during-carb-band-clamped-to-sport-ceiling`.
- **ops open work:** bugs `bike-plan-header-shows-run-pace` (same cause as swim "/mi"), `prerun-window-capped-for-past-session`,
  `pins-and-forks-do-not-reach-the-saved-plan`, `your-usual-pace-chip-is-tp-zone2-not-history`,
  `brick-swim-pace-baked-against-unseen-distance`, `deep-link-create-screen-back-button-dead`,
  `nudge-tap-back-button-dead-again`, `adjust-macros-renders-gated-fluid-as-0oz`, `fueling-window-sticks-across-activities`,
  `duplicate-activity-via-armed-back-stack`, `formula-detail-shows-raw-component-ids`, the `hydration-check-*` and
  `before-floor-fill` / `extreme-before-targets` / `pinned-backfill` family · feature-requests
  `mock-athlete-workout-edit-feels-like-create`, `auto-fuel-every-synced-workout`, `formula-library-open-in-context`,
  `by-hour-auto-assign-fuel-across-hours`, `plan-rating-revive-or-drop`, `instrument-fuel-log-started`,
  `eng-task-plan-viewed-event-coverage`.
- **Related map pages:** `activities.md` · `macro_dashboard.md` · `formula_kit.md` · `weather.md` ·
  `personal_templates.md` · `events.md` · `meal_logging.md` (the swap/add food search).
