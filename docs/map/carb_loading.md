# Carb loading

domain: 3 Race week · folder: `lib/features/carb_loading/` (35 files)

A one-, two- or three-day high-carb plan before a race, sized to body weight in grams per kilo and split across six
meal slots a day. On loading days the Timeline shows how the athlete is pacing against the day's target and logs food
into the slots. Entered from a race's details page.

## What athletes can do here

- **Set it up.** Race → "Set Up Carb Loading" → "Choose Carb Loading Protocol": three cards, "3-Day Classic"
  (RECOMMENDED; 8 g/kg on days 3 and 2 out, 10 g/kg the day before), "2-Day Quick" (ADVANCED; 9 then 11 g/kg),
  "1-Day" (RACE WEEK; 11 g/kg), each with "Best For" chips, "Show Details" (research, phases) and "Select N-Day
  Protocol". A protocol that no longer fits before race day is greyed with "Needs N day(s) before race day". Selecting
  one creates the plan at once from the profile's body weight ("Please complete your profile first" if missing);
  snackbar "Created N-day carb loading plan!", with "Go to today's fuel" if loading has already started. The race
  row now reads "Carb Loading Plan".
- **See and edit the plan.** "Carb Loading Plan": "{PROTOCOL} · {window}", one row per day ("DAY n · date · g ·
  g/kg", "EDITED" when changed). Tap today or a future day → "Edit Carb Target" (per kg or total grams; past days are
  fixed). "Change protocol" re-opens the chooser; if targets were edited it asks "Keep your edited targets?" ("Keep my
  targets" / "Reset to protocol"). "Remove carb loading plan" → "Targets and schedule are deleted. Food you've already
  logged stays in your log."
- **Load on the day.** On the Timeline the energy card becomes "CARB LOAD · DAY n OF m" ("LOADED" once met): a future
  day shows "{g} g planned", a past day "{eaten} g of {target} g", today "On pace" / "N g behind pace" / "N g ahead of
  pace" / "Loaded". Six slot cards replace the meal rows, Breakfast 6:00 AM (25% of the day) · Morning Snack 9:00 AM
  (10%) · Lunch 12:00 PM (25%) · Afternoon Snack 3:00 PM (15%) · Dinner 6:00 PM (20%) · Evening Snack 9:00 PM (5%),
  each "eaten / target g" with "Show items" and, today only, "Edit in {slot} ›".
- **Log into a slot** (today only). The slot page: "{time} · {g} carbs", "Add Food" (the normal log-meal screen
  pre-set to the slot), "LOGGED" rows (tap to edit), and "RECOMMENDED FOR {SLOT}" rows with a ⊕ that logs the food
  in one tap ("{food} logged"). Food logged here is an ordinary meal log tagged with the slot.
- **See the day's breakdown.** The energy card's "Full Breakdown" on a loading day: hero figure and bar, a
  carbs/protein/fat/kcal strip, "By meal", "Day n" chips to switch days, "Manage plan".
- **Get reminded.** "Fuel up for race day · Your carb load for {event} can start now — set up your plan." at 6:00 AM
  on race day −3, −2 and −1 while no plan exists; never on race day. Tapping opens the race.
- **How it ends.** Loading runs up to the day before the race; race day has no carb surface and the Timeline is back
  to normal. The plan is never deleted by itself.

Where the buttons live: `events` (the race row, plan creation) · `carb_loading` (chooser, plan summary, slot page,
breakdown page) · `macro_dashboard` (the loading-day card and slot cards) · `meal_logging` (Add Food).

## What the data means

Supabase and local, synced: `carb_loading_plans` (one per race; creating replaces the old one) and
`carb_loading_days` (`plan_date`, `day_number`, `carb_target_grams`, `carb_protocol_g_per_kg`, six slot percentages).
On `events`: `has_carb_loading`, `carb_loading_days`, `carb_loading_start_date`. `carb_loading_foods` is a server
catalogue pulled down. Loading-day food is written to `meal_logs` with a slot tag, not to `carb_loading_day_meals`
(that table and `carb_loading_user_foods` are legacy, local-only, used only by the coach-portal day page). Pace =
target × (minutes elapsed in the slot schedule). Preferences: `carb_nudge_last_shown_day`, `carb_nudge_armed_{eventId}`.
Analytics: `carb_loading_protocol_selected` {protocol, protocol_days, event_id}, `notif_scheduled/cancelled/fired`.

## What already exists to reuse

- `presentation/providers/carb_loading_controller.dart` (create, delete, `updateDayTarget`, `previewRepickProtocol`,
  `applyRepickProtocol`; `carbLoadingPlanProvider`, `carbLoadingDaysForPlanProvider`, `carbLoadingDaysForRangeProvider`),
  `application/carb_loading_service.dart` + repository (offline first, re-pick in place).
- `domain/carb_loading_entryway_engine.dart` (which protocols fit; the re-pick decision),
  `domain/carb_loading_pace_engine.dart` (rates, slot split and times, pace), `domain/carb_nudge_engine.dart`,
  `application/carb_load_nudge_service.dart`, `presentation/providers/carb_nudge_coordinator.dart`,
  `carb_slot_recommendations` (curated foods + matching).
- Screens: `CarbPlanSummaryScreen.open`, `CarbBreakdownScreen.open`, `CarbSlotScreen.open`,
  `carb_loading_protocol_selection_screen`. Widgets: `edit_carb_target_dialog`, `carb_repick_dialogs`. On the
  Timeline: `macro_dashboard/application/carb_dashboard_assembler.dart`, `kyle_design/fueling/carb_load_bar.dart`,
  `carb_slot_card.dart`.

Don't add: another slot schedule or pace rule (the pace engine), another eligibility check (the entryway engine).
Legacy, coach-portal only, not for athletes: `carb_loading_day_detail_page`, `carb_loading_food_selection_screen`,
`create_custom_carb_loading_food_screen`, `food_selection_service`, `food_import_service`,
`carb_loading_user_food_repository`, `carb_loading_day_meal_repository` (routes `/carb-loading-select-food`,
`/create-custom-carb-loading-food`). Unused: `CarbLoadingController.deleteCarbLoadingDay`. Stale TODOs at
`carb_loading_food_selection_controller.dart:530,543,612,725`.

## Links

- **qa:** `spec/fueling/carb-loading.md`, `carb-loading-entryway.md` (+ vectors) · `spec/design/surfaces/carb-loading-dashboard.md`,
  `carb-loading-entryway.md` · `spec/design/components/carb-slot-card.md`, `energy-card.md` · `spec/daily-macros/loading-day-coupling.md`.
- **ops open work:** bugs `race-move-may-strand-carb-loading-days`, `loading-day-daily-macros-split-parked-bundle-now-due`,
  `carb-nudge-fires-twice-in-one-day`, `carb-nudge-tap-lands-on-timeline-not-event`,
  `carb-plan-created-snackbar-go-to-todays-fuel-lands-on-events-list`, `carb-plan-removal-leaves-event-details-stale-then-blank`,
  `carb-loading-plan-missing-for-some-events`, `coach-portal-carb-progress-dead-columns` · feature-requests
  `carb-load-day-n-reminder-when-plan-exists`, `carb-loading-realistic-nutritionist-food-ideas`, `carb-load-progress-bar-shine-sweep`,
  `eng-task-race-window-carb-nudge-has-no-telemetry`, `eng-task-carb-nudge-cancel-reasons-unemitted`.
- **Related map pages:** `events.md` · `macro_dashboard.md` · `meal_logging.md` · `daily_macros.md`.
