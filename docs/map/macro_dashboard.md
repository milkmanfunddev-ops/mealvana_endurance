# Timeline (home)

domain: 2 Your day · folders: `lib/features/macro_dashboard/` (the Timeline tab), `lib/features/home_shell/` (tab bar,
date header, calendar sheet), `lib/features/daily_macros/` (the daily-targets engine client, no screens),
`lib/features/fuel_timeline/` (one live widget, the brick row) · also `lib/features/calendar/` (date state and the
coach portal's month/week views)

The Timeline is the app's home: one day at a time, workouts and meals in time order, with the day's energy at the top.
It is tab 0 of the main shell (route `/main`); the other tabs are Events and Learn.

## What athletes can do here

- **Move between days.** "Previous day" / "Next day" chevrons in the header; the title reads "Today, October 12 ˅" or
  the weekday. There is no swipe between days.
- **Open the month.** Tap the date title. Filled teal dot = a workout done that day, hollow orange ring = one planned,
  no dot = rest or everything skipped; an orange tint = a meal was logged. Tap a day to open it; "Today" jumps back.
  The athlete app has no week view.
- **Read the day's energy.** The card at the top. Collapsed it shows "NET BALANCE": calories eaten minus calories
  burned so far today, with a band word: "on track" (within 200 kcal), "slight surplus" / "surplus", "slight deficit" /
  "deficit — time to eat" (more than 500 below). "Expand details" opens "NET ENERGY BALANCE" (eaten − burned = net,
  "N kcal to target") and a "Full Breakdown" button to a three-page pager: "Today's Energy", "Active Energy",
  "Today's Fuel". The card is hidden when tracking is off or the day has no targets yet.
- **Filter the day.** "All" / "Workout" / "Meals" pills. The card face follows: Workout → "TODAY'S WORKOUT · N done ·
  N planned"; Meals → "DAILY BUDGET · kcal · C · P · F". Two round buttons: the chart icon turns tracking off/on
  (hides the energy card and the kcal line on meals; remembered), the clock icon hides/shows times.
- **Add food or a workout.** "+ Add Food" opens the log-meal screen for the selected day; "+ Add Activity" opens the
  "Create New Activity Plan" form for that day; "Brick" appears when the day has two or more swim/bike/run workouts
  not already in a brick and not skipped.
- **Act on a workout card.** Tap it, or its "Pre · During · Recovery fuel ›" line, to open the plan screen (a workout
  with no plan opens the form instead). Swipe right: "Mark done" / "Mark undone" (not on a future day). Swipe left:
  "Skip" / "Unskip". Skip and unskip show a snackbar with Undo; done/undone show nothing on success. Chips: "Planned",
  "self-reported", "verified · Garmin / Final Surge / TrainingPeaks", "Skipped" (greyed, moved to the bottom of the
  day; a past workout nobody confirmed shows as Skipped by itself). A verified or platform-completed card is locked
  and only nudges when swiped.
- **Build or ungroup a brick.** "Brick" → "Pick legs to link" → tap the legs → "LEG ORDER" with "Swap" → "Create Brick
  (n)"; snackbar "Brick created · Run → Run" with Undo. The brick row shows "BRICK · n legs · min" and its legs;
  tapping anywhere on it opens the combined brick's plan. Its "⋯" menu: "Ungroup legs" (confirmation, legs come back
  as separate workouts) and "Delete brick" (same result, different words).
- **Act on a meal row.** Each row shows the food and "kcal · C · P · F". Tap to expand in place: "Edit food",
  "Remove" (immediate, "Meal deleted · Undo"), "Save as favorite". Meals of one type within 30 minutes share a row.
- **On a carb-loading day** the energy card becomes "CARB LOAD · DAY 2 OF 3" with the day's gram target ("LOADED" once
  met; today shows "On pace" / "N g behind pace"), and the meal rows become six fixed slots, "BREAKFAST 6:00 AM 0 / 136 g"
  to "EVENING SNACK 9:00 PM": grams eaten in the slot over the slot's share of the target. Tap a slot to open it.
- **Pull down** to force a sync of every connected platform and rebuild the day.
- **Reconnect notice.** When a platform needs a new sign-in, the first row reads "{platform} needs you to sign in again
  to keep syncing." with "Reconnect" and "×".
- **The tab bar** floats bottom-left and shrinks to one round button as the list scrolls; tapping it only re-expands
  the bar. The gear opens Settings. The blue wrench pill at the top edge exists only in dev builds.

## What the data means

**Daily targets** come from the server engine `calculate-daily-macros-v6` (QA calls it Engine B): calories, carbs,
protein and fat for each day of the Sunday-to-Saturday week, from the profile (sex, age, weight, height, body fat,
lifestyle, weekly hours, training phase) and the week's sessions (a workout sits on the day of actual ?? planned ??
scheduled time; skipped, deleted, hidden and archived brick legs are excluded; a brick is one session per leg).
Fluids and sodium are not daily targets. Rows live in `daily_macro_targets` (local cache keyed by local midnight,
written to Supabase fire-and-forget, never read back). **A row exists because the Timeline was opened, not because
the athlete did something** (the blueprint's ambient rule): the controller fires one week call whenever a cached day
is missing. An activity edit invalidates that week plus a day either side; a profile edit invalidates today onward;
rows below engine version 6.1.0 are recalculated. Errors shown: "Your weight/height/birthday is missing. Set it in
Settings → Preferences → Profile."

**Net balance** = eaten − burned so far, where burned = resting energy + daily movement + digestion (spread over the
waking hours elapsed) + finished workouts (device calories when measured, else duration × intensity). A past day
counts as fully elapsed, a future day as not started. "Remaining" subtracts logged food only. Day labels: "RACE
WEEK" / "TRAINING" / "LIGHT TRAINING" / "REST".

**Workout state** (`workout_state_resolver`): planned · done (confirmed by the athlete) · verified (Garmin
`garmin_summary_id`, or a platform `completion_type = provider`) · skipped (active, or passive for an unconfirmed
past workout). The same resolver feeds the calendar dots.

**Carb-loading slot figures** come from the stored loading-day target split across six slots, not from Engine B.

## What already exists to reuse

- `macro_dashboard/application/dashboard_assembler.dart`: builds the day's entries, the energy numbers and the
  breakdown; the one place a workout's calories are priced for every screen.
- `macro_dashboard/domain/workout_state_resolver.dart` + `dashboard_models.dart`: card states, chip labels, lock rule,
  number formatting. `application/carb_dashboard_assembler.dart`: the loading-day card and slots.
- `macro_dashboard/presentation/providers/macro_dashboard_providers.dart`: the day provider, slot merge, a
  "keep last targets while recalculating" guard, tracking/times view state.
- `macro_dashboard/presentation/widgets/`: `energy_summary_card`, `breakdown_pager`, `dashboard_filter_row`,
  `workout_card`, `meal_card`; `fuel_timeline/presentation/widgets/timeline_brick_tile.dart` (the brick row).
- `daily_macros/application/daily_macro_service.dart` (engine client, single-flight), `daily_macro_targets_repository.dart`
  (cache), `daily_macros_controller.dart`, `domain/intraday_display.dart` (net-balance maths), `macro_cache_invalidation.dart`,
  `macro_palette.dart` (macro colours, shared).
- `home_shell/application/home_shell_calendar_assembler.dart` (dots and tint), `shared/widgets/kyle_design/navigation/`
  (`kyle_calendar_sheet`, `kyle_date_header`, `kyle_tab_bar`), `home_shell/presentation/home_shell_chrome.dart`,
  `home_shell_tab_request.dart` (other screens switch the tab, e.g. Events' "Go to today's fuel").
- `calendar/`: `calendar_selected_date_provider.dart` (the app-wide selected day), `CalendarService` (events, loading
  days, activities for Events and sync), `calendar_{month,week}_view_kyle.dart` (coach portal only).
- `shared/widgets/dev_testing_tools.dart`: the dev-only wrench pill ("Open testing tools").

Don't add: another "which day" or "which state" rule (use `displayTime` and the resolver), another calorie pricing
(use the assembler), another energy or breakdown card. Dead and not to revive: all of `fuel_timeline/` except the
brick tile and `fuel_timeline_type.dart` (`timeline_node_tile`, `energy_dashboard_card`, `energy_breakdown_sheet`,
`weekly_fuel_chart`, `fuel_filter_row`, the controller and assembler); `daily_macros/presentation/widgets/*`
(`today_hero_card`, `daily_summary_card`, `periodization_bottom_sheet`, `energy_source_breakdown`…) and
`periodization_analysis_service`; `calendar/.../calendar_day_indicators_provider`, `upcoming_event_widget`;
`shared/widgets/environment_indicator.dart`.

Stale comments and a cache gap for the gardening pass: `macro_cache_invalidation.dart:82,93-97,111,149-158` (says the
engine keys on `scheduledDateTime`; it keys on actual ?? planned ?? scheduled, so a change to `actual_time` or
`planned_time` alone does not invalidate the cache); `macro_dashboard_screen.dart:49-50,193-194`;
`app_router.dart:559-560` (tab order); `tabs_screen.dart:161`; `kyle_tab_bar.dart:86-87`; `home_shell_chrome.dart:27`;
`daily_macro_targets.dart:3`; `daily_macro_service.dart:260`; `timeline_brick_tile.dart:32-33,51`; pager dots say
"Today's Fueling" while the page says "Today's Fuel".

## Links

- **qa:** `spec/daily-macros/` (README = Engine B, `intraday-display.md`, `assembly.md`, `platform-resolution.md`,
  `loading-day-coupling.md`, `energy-availability.md`, `neat-tef.md`, `session-demand.md`, `rmr.md`, `baseline-macros.md`,
  `multi-day-context.md`, `OPEN-QUESTIONS.md`) · `spec/design/surfaces/macro-dashboard.md`, `carb-loading-dashboard.md` ·
  `spec/design/components/{calendar-sheet,tab-bar,date-header,energy-card,macro-pill-row,workout-card,carb-slot-card,brick-leg-builder}.md`
  · `spec/domain/brick.md` · renderings `design/renderings/macro-dashboard@v1.html`, `home-shell-export-2026-09-06.html`.
- **ops open work:** bugs `energy-card-expand-shows-no-breakdown`, `brick-pill-ignores-moved-workout`,
  `fueling-synced-past-workout-marks-skipped`, `timeline-workout-card-title-truncates-to-two-characters`,
  `fuel-timeline-prices-completed-workout-at-estimate`, `dashboard-prices-distance-sessions-at-flat-60min`,
  `archived-brick-legs-double-feed-daily-macros`, `brick-priced-as-one-conservative-session`,
  `loading-day-daily-macros-split-parked-bundle-now-due`, `carb-nudge-tap-lands-on-timeline-not-event`,
  `breakdown-sheet-future-day-claims-day-is-over`, `dashboard-weight-fallback-70kg` · feature-request
  `weekly-schedule-component` (no week view exists).
- **Related map pages:** `activities.md` · `nutrition_plan.md` · `meal_logging.md` · `carb_loading.md` · `events.md` ·
  `integrations.md` · `education.md` · `settings.md`.
