# Onboarding

domain: 9 Account and app · folder: `lib/features/onboarding/` (43 files)

The first run: Welcome, nine steps, the plan reveal, then the account screen (`auth.md`). An onboarded athlete never
sees it again and cannot redo it; answers are edited later under Settings.

## What athletes can do here

- **Welcome** (`/welcome`): "Get more out of every session. · Fueling plans built for how you train — so you stop
  guessing your carbs mid-race." → "Build My Plan" (keeps any existing session, otherwise starts an anonymous one)
  or "I already have an account". Athletes in the EEA, UK or Washington first see "Your privacy · Share usage
  data" (off by default; `privacy.md`).
- **The nine steps** (`/onboarding`; "Continue" on each, system back goes one step):
  1. "Which sports do you train for?" Running / Cycling / Swimming / Triathlon, at least one.
  2. "What's your goal?" four goals, any number.
  3. "What's getting in the way?" eight pitfalls, any number.
  4. "Your training changes daily. Your fueling should too." The connect cards (TrainingPeaks, Final Surge, V.O2,
     Runna, Garmin Connect; TriDot and Strava "COMING SOON" with "Notify Me"), the tile "I don't use training plan
     apps.", and "Continue" (always enabled, so continuing is the skip). Garmin shows the "Turn on Historical Data"
     primer first ("Continue to Garmin" / "Not now"). Connecting imports workouts at once. See `integrations.md`.
  5. "Tell us about yourself": optional first name, last name, email; "Gender" (the one required answer); "Birth
     year" wheel (1930–2012, saved as July 1). Pre-filled from TrainingPeaks or Final Surge when connected, with a
     source chip.
  6. "Basic body composition": Imperial / Metric, height and weight wheels (default 5 ft 8 in, 150 lb; Garmin
     weight when connected). Its button reads "Build My Plan".
  7. "Nutrition Settings · Two dials that tune your per-hour targets.": "GUT TRAINING LEVEL" Low / Moderate / High
     and "SWEAT RATE" Light / Medium / Heavy, defaults Moderate / Medium.
  8. "Building your plan…" then "YOUR FUELING PLAN · We built your plan, {name}. · Every number traces back to
     what you told us.": editable long-session carb, fluid and sodium targets per hour with "Reset to our
     recommendation", "Personalize with a sweat test" (points to Settings → Sweat Profile), a "Connect now" nudge
     when no platform is connected, "Continue to See My Daily Plan".
  9. "YOUR DAILY PLAN · And here's how to eat every day.": tabs Workout day / Rest day / Carb load, "Your Macros"
     (Carbs / Protein / Fat / Calories), a "Connect with Garmin" nudge, "Save My Plan" → the account screen.
- **Edit the answers later.** Settings → "Profile & Preferences" (name, gender, birthday, units, gut training,
  sweat rate), "Body Composition" (weight, height), "Nutrition Targets" (the plan-reveal edits). Sports, goals and
  pitfalls are kept but never shown again.

## What the data means

Answers live in memory until the account screen saves them, then: `users` (`auth_provider`, `is_anonymous`,
`gender`, `birthday`, `height_feet/inches`, `weight_pounds`, `gut_training`, `sweat_rate`, `unit_system`,
`onboarding_completed = true`, `first_name`, `last_name`, `email`, `dietary_preference = omnivore`, `allergies = []`,
`nutrition_target_overrides` for edited targets, `app_version`); `onboarding_surveys` (sports, goals, pitfalls,
`survey_payload` with connected provider, declined flag, TriDot interest, sweat-test interest). Phone:
`onboarding_temp_user_id` (lets a platform connect before a profile exists; moved to the real user at save),
`onboarding_snapshot_v1` (a safety copy restored if the user row is missing). Analytics: `welcome_get_started_tapped`,
`welcome_login_tapped`, `screen_viewed`, `onboarding_step_completed` {step_name, step_index} (Continue only, not
swipes), `sports_selected`, `goals_selected`, `pitfalls_selected`, `connect_training_declined`,
`integration_notify_me_tapped`, `plan_preview_viewed`, `plan_target_edited`, `sweat_test_link_tapped`,
`daily_preview_tab_viewed`, `onboarding_completed` {step_count, duration_sec}; `user_registered` fires on every
profile creation, anonymous skips included.

## What already exists to reuse

- `presentation/providers/onboarding_controller.dart` (the draft; one-batch save and upload; `resetOnboarding` has
  no callers), `onboarding_session_controller.dart` (reuse or create the session), `onboarding_analytics.dart`,
  `onboarding_preview_providers.dart` + `application/plan_preview_service.dart` / `training_insight_service.dart`
  (offline plan preview, platform pre-fill), `application/onboarding_snapshot_service.dart`.
- Screens per step under `presentation/screens/`; shared layout `onboarding_step_scaffold`, `onboarding_multi_select_step`,
  `onboarding_spec_cta`, `onboarding_connect_nudge_card`, `onboarding_back_circle`, `onboarding_build_loader`,
  `onboarding_week_chart_card`, `garmin_historical_primer_sheet`; the connect step is `settings/.../connected_apps_screen.dart`
  in onboarding mode.

Don't add: another place that creates the profile (the controller's save). Dead: `expandable_more_options_widget.dart`,
`onboarding_navigation_footer.dart`, the onboarding-mode branches of `allergies_screen`, `dietary_preference_screen`,
`running/cycling/swimming_details_screen` (now reached only from Settings), `onboarding_widgets.dart`,
`onboarding_progress_bar.dart`. Gardening: stale comments at `connected_apps_screen.dart:40,198,781` ("Skip for now"),
`onboarding_pageview_screen.dart:112-114`, `personal_info_screen.dart:752-755`, `body_composition_screen.dart:24`,
`privacy_consent_screen.dart:23`, `app_router.dart:258,336` ("Get Started"); qa `spec/integrations/training-peaks.md:69`
and `field-map.md:16` say email is not copied from TrainingPeaks, but the code pre-fills it.

## Links

- **qa:** none dedicated; `spec/design/vana/cards.md:93` (the nine-step wizard), `spec/design/surfaces/integrations-data-display.md`
  (D-3, D-4 onboarding connect), `spec/daily-macros/README.md:11-22`.
- **ops open work:** bugs `anonymous-profile-reset-invents-150lb-and-5ft8`, `user-registered-fires-on-auth-skipped`,
  `new-anonymous-uid-minted-per-open-and-signout` · feature-requests `fr-onboarding-first-activity`,
  `eng-task-randomize-onboarding-survey-option-order`, `garmin-historical-data-off-by-default`.
- **Related map pages:** `auth.md` · `integrations.md` · `settings.md` · `privacy.md` · `app_startup.md`.
