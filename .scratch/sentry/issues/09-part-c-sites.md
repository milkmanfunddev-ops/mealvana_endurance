# 09 part C: sites — the remaining feature directories

Scope: every `lib/features/<x>` directory with baseline entries that is not
app_startup, auth, ai_credits, subscription, nutrition_plan, settings,
meal_logging, integrations, coach_mode, meal_planning, formula_kit, ai_coach or
daily_macros; `macro_dashboard/application/dashboard_transient_telemetry.dart`
is ticket 11's and untouched. Area = feature folder name.

Line numbers below are as of `f3ed24ba` (the `sentry` HEAD this work started
from), so `git show f3ed24ba:<path>` lands on the catch being described. 84
baseline lines deleted (81 catch sites; three carried both an `unreportedCatch`
and a `printInCatch` entry). No `## reasoned` entries added. Zero findings
remain in scope.

Two recurring rulings, so they are not repeated per line:

- **Analytics swallow** (`try { analytics.track(...) } catch (_) {}`): Fault.
  `MixpanelAnalyticsTracker.track` already catches its own failures, so the
  only thing these catches ever see is a provider read blowing up, which is a
  bug, not noise.
- **UI catch over a controller call that already reports and rethrows**
  (`restoreActivity`, `skipWorkout`, `markWorkoutDone`, the brick controller's
  typed exceptions): Note. The controller owns the Fault; the UI branch records
  that the failure copy / dialog was shown so the breadcrumb rides the event.

## Sites

### activities
- lib/features/activities/data/activities_repository.dart:1517 — Degraded — inner provider-key lookup failed during the insert fallback; the original insert error is reported and rethrown right after, this was the second failure hiding behind it
- lib/features/activities/presentation/providers/activities_controller.dart:225 — Fault — analytics swallow (`workout_planned`)
- lib/features/activities/presentation/providers/activities_controller.dart:239 — Fault — analytics swallow (`first_activity_added`)
- lib/features/activities/presentation/widgets/activity_card.dart:276 — Note — undo-delete `restoreActivity` failed; the controller reported before rethrowing, UI shows "Could not restore activity"
- lib/features/activities/presentation/widgets/calendar_date_indicators.dart:53 — Removed — hand-rolled `tryParse`; replaced with `DateTime.tryParse`, same fallback, no catch

### barcode_scanning
- lib/features/barcode_scanning/presentation/screens/add_food_screen.dart:65 — Degraded — `SearchException` is the service's own typed, expected failure; its message is shown to the athlete
- lib/features/barcode_scanning/presentation/screens/add_food_screen.dart:70 — Fault — untyped search failure
- lib/features/barcode_scanning/presentation/screens/add_food_screen.dart:155 — Degraded — `ProductDetailException`, typed and expected, message shown
- lib/features/barcode_scanning/presentation/screens/add_food_screen.dart:164 — Fault — untyped product-detail failure
- lib/features/barcode_scanning/presentation/screens/barcode_scanner_screen.dart:129 — Note — `MobileScannerException` on start is the documented benign init race (MEALVANA-ENDURANCE-79); start skipped, controller will be running once init completes
- lib/features/barcode_scanning/presentation/screens/barcode_scanner_screen.dart:139 — Note — same race on stop; nothing to stop yet
- lib/features/barcode_scanning/presentation/screens/barcode_scanner_screen.dart:231 — Fault — barcode lookup failed; error copy shown

### calendar
- lib/features/calendar/domain/event_subtype.dart:269 — Removed — `firstWhere` + catch-everything as a find-or-null; replaced with a loop returning null

### carb_loading
- lib/features/carb_loading/application/food_import_service.dart:323 — Fault — categories column matched neither the Postgres-array nor the JSON shape; row still imports without categories
- lib/features/carb_loading/application/food_selection_service.dart:54 — Fault — analytics swallow (`carb_loading_food_added`)
- lib/features/carb_loading/domain/carb_foods_list.dart:140 — Removed — `firstWhere` + catch as find-or-null; loop returning null
- lib/features/carb_loading/domain/meal_type.dart:89 — Fault — `meal_types` column unparseable; `parseMealTypeIds` gained an optional `report` parameter (global Report by default) so the test can assert it
- lib/features/carb_loading/presentation/providers/carb_loading_food_selection_controller.dart:319 — Fault — Open Food Facts search failed, results cleared (offline auto-downgrades)
- lib/features/carb_loading/presentation/providers/carb_nudge_coordinator.dart:55 — Fault — was `appLoggerProvider.warning`; the nudge sweep failing is not expected
- lib/features/carb_loading/presentation/screens/carb_loading_day_detail_page.dart:48 — Fault — analytics swallow (`carb_loading_day_viewed`)
- lib/features/carb_loading/presentation/screens/carb_loading_food_selection_screen.dart:832 — Fault — Open Food Facts import failed; error copy shown
- lib/features/carb_loading/presentation/screens/carb_loading_food_selection_screen.dart:890 — Fault — catalog import failed; error copy shown
- lib/features/carb_loading/presentation/screens/carb_loading_food_selection_screen.dart:1074 — Fault — duplicate-to-custom-food failed; `debugPrint` removed
- lib/features/carb_loading/presentation/screens/carb_loading_food_selection_screen.dart:1205 — Fault — user food delete failed; `debugPrint` removed
- lib/features/carb_loading/presentation/screens/carb_loading_food_selection_screen.dart:1262 — Fault — user food update failed; two `debugPrint`s removed
- lib/features/carb_loading/presentation/screens/carb_loading_protocol_selection_screen.dart:246 — Fault — analytics swallow (`carb_loading_protocol_selected`)
- lib/features/carb_loading/presentation/screens/create_custom_carb_loading_food_screen.dart:97 — Fault — custom food create failed; error copy shown

### content
- lib/features/content/application/content_service.dart:49 (`.catchError`) — Fault — not a catch block by the guard's rules, but the same swallow one line up from site 53; background content refresh failed, app continues on cached/default content
- lib/features/content/application/content_service.dart:53 — Fault — synchronous throw from `refreshContent()` before a Future existed
- lib/features/content/application/content_service.dart:75 — Fault — manual refresh failed, returns false (offline auto-downgrades)
- lib/features/content/application/content_service.dart:135 — Fault — bundled content defaults failed to load; a build problem that must be seen. Static class, so this one uses `SentryReport.global`

### education
- lib/features/education/presentation/screens/education_screen.dart:250 — Fault — analytics swallow (`education_video_opened`)
- lib/features/education/presentation/screens/video_player_screen.dart:49 — Fault — analytics tracker unavailable at initState; the screen caches a `Report` in initState for the same reason it caches the tracker (dispose cannot touch `ref`)
- lib/features/education/presentation/screens/video_player_screen.dart:94 — Fault — analytics swallow (`education_video_completed`, fires from dispose)
- lib/features/education/presentation/screens/video_player_screen.dart:136 — Fault — video player failed to initialise; error state shown

### events
- lib/features/events/application/events_service.dart:54 — Removed — `DateTime.parse` + catch as tryParse; `DateTime.tryParse`
- lib/features/events/application/public_events_service.dart:60 — Fault — public events search failed, returns none (the TODO in that catch asked for exactly this)
- lib/features/events/presentation/providers/events_controller.dart:370 — Removed — `DateTime.parse` + catch as tryParse; `DateTime.tryParse`
- lib/features/events/presentation/screens/event_detail_screen.dart:316 — Fault — event delete failed; error copy shown
- lib/features/events/presentation/screens/event_form_screen.dart:246 — Fault — public event search failed, suggestions cleared
- lib/features/events/presentation/screens/event_form_screen.dart:401 — Fault — location search failed, suggestions cleared
- lib/features/events/presentation/screens/event_form_screen.dart:615 — Fault — event create/update failed; error copy shown
- lib/features/events/presentation/screens/events_list_screen.dart:121 — Removed — `DateTime.parse` + catch as tryParse-and-skip; `DateTime.tryParse` with the same `continue`
- lib/features/events/presentation/widgets/event_action_buttons_card.dart:246 — Fault — carb-loading plan creation from the event failed; error copy shown

### fuel_timeline
- lib/features/fuel_timeline/presentation/widgets/energy_breakdown_sheet.dart:210 — Fault — analytics swallow (`weekly_overview_viewed`)

### macro_dashboard
- lib/features/macro_dashboard/presentation/providers/macro_dashboard_providers.dart:82 — Fault — profile weight read failed; dashboard prices with the engine weight instead (fail-soft kept)
- lib/features/macro_dashboard/presentation/providers/macro_dashboard_providers.dart:122 — Fault — carb-plan lookup failed; ordinary day rendered (fail-soft kept)
- lib/features/macro_dashboard/presentation/screens/macro_dashboard_screen.dart:535 — Note — `_guardWrite`: controller reported, rolled back and rethrew; UI owns the failure copy. `_guardWrite` gained a `WidgetRef` parameter
- lib/features/macro_dashboard/presentation/screens/macro_dashboard_screen.dart:574 — Note — skip/unskip failed; controller reported and rolled back
- lib/features/macro_dashboard/presentation/screens/macro_dashboard_screen.dart:596 — Note — undo-skip `restoreActivity` failed; controller reported
- lib/features/macro_dashboard/presentation/screens/macro_dashboard_screen.dart:1006 — Note — undo brick creation (`ungroupBrick`) failed; controller reported
- lib/features/macro_dashboard/presentation/screens/macro_dashboard_screen.dart:1013 — Note — `BrickValidationException`: user input the controller rejected; dialog explains it
- lib/features/macro_dashboard/presentation/screens/macro_dashboard_screen.dart:1021 — Note — `BrickCreationException`: controller `logger.error`s the underlying error before wrapping it; UI shows the dialog and offers retry
- lib/features/macro_dashboard/presentation/screens/macro_dashboard_screen.dart:1031 — Fault — untyped error creating a brick (nothing upstream caught it)
- lib/features/macro_dashboard/presentation/screens/macro_dashboard_screen.dart:1077 — Note — `BrickUngroupException`: controller reported before wrapping
- lib/features/macro_dashboard/presentation/screens/macro_dashboard_screen.dart:1087 — Fault — untyped error ungrouping a brick
- lib/features/macro_dashboard/presentation/screens/macro_dashboard_screen.dart:1168 — Note / Fault — delete brick: Note when the error is a `BrickUngroupException` (controller reported), Fault otherwise

### onboarding
- lib/features/onboarding/application/onboarding_snapshot_service.dart:60 — Fault — was `logger?.warning`; snapshot write to SharedPreferences failing should never happen. Service gained a `Report? report` constructor parameter; `writeSnapshot` lost its unused `logger` parameter (no caller passed one)
- lib/features/onboarding/application/onboarding_snapshot_service.dart:92 — Fault — corrupt snapshot dropped; test asserts the Fault
- lib/features/onboarding/presentation/providers/onboarding_preview_providers.dart:69 — Note — no local profile yet on first run is the expected branch; the auth and temp ids still apply
- lib/features/onboarding/presentation/providers/onboarding_preview_providers.dart:273 — Fault — integration autofill failed; forms keep defaults (offline auto-downgrades)
- lib/features/onboarding/presentation/screens/allergies_screen.dart:103 — Fault — loading current allergies failed; defaults shown
- lib/features/onboarding/presentation/screens/cycling_details_screen.dart:122 — Fault — loading cycling details failed; defaults shown
- lib/features/onboarding/presentation/screens/daily_plan_preview_screen.dart:104 — Fault — analytics swallow (`daily_preview_tab_viewed`)
- lib/features/onboarding/presentation/screens/dietary_preference_screen.dart:98 — Fault — loading dietary preference failed; defaults shown
- lib/features/onboarding/presentation/screens/goals_screen.dart:73 — Fault — analytics swallow (`goals_selected`)
- lib/features/onboarding/presentation/screens/onboarding_pageview_screen.dart:243 — Fault — analytics swallow (`onboarding_step_completed`)
- lib/features/onboarding/presentation/screens/onboarding_pageview_screen.dart:263 — Fault — analytics swallow (`onboarding_completed`)
- lib/features/onboarding/presentation/screens/pitfalls_screen.dart:80 — Fault — analytics swallow (`pitfalls_selected`)
- lib/features/onboarding/presentation/screens/plan_reveal_screen.dart:437 — Fault — analytics swallow (`sweat_test_link_tapped`)
- lib/features/onboarding/presentation/screens/plan_reveal_screen.dart:474 — Fault — analytics swallow (`plan_target_edited`)
- lib/features/onboarding/presentation/screens/running_details_screen.dart:90 — Fault — loading running details failed; defaults shown
- lib/features/onboarding/presentation/screens/sports_selection_screen.dart:97 — Fault — analytics swallow (`sports_selected`)
- lib/features/onboarding/presentation/screens/swimming_details_screen.dart:128 — Fault — loading swimming details failed; defaults shown

No onboarding body copy was touched.

### personal_templates
- lib/features/personal_templates/domain/personal_template.dart:56 — Fault — `planData` column not valid JSON; template loads empty. Domain factory with no injection point, uses `SentryReport.global`
- lib/features/personal_templates/domain/personal_template.dart:65 — Fault — `brickSegmentOrder` not valid JSON; dropped. Same handle

### race_checklist
- lib/features/race_checklist/presentation/screens/race_checklist_screen.dart:638 — Fault — loading event details for the nutrition plan failed; error copy shown

### recipes
- lib/features/recipes/data/repositories/recipe_repository.dart:251 — Fault — cached list column not valid JSON (we wrote it); test asserts the Fault. Repository gained `Report? report`
- lib/features/recipes/presentation/screens/recipes_screen.dart:76 — Fault — loading recipes failed; error state shown

### sharing
- lib/features/sharing/application/email_service.dart:55 — Fault — email send failed; `ShareResult.failure` returned. Service gained `Report? report`
- lib/features/sharing/presentation/providers/share_form_controller.dart:198 — Fault — share failed before the email went out; the existing `plan_share_failed` analytics event stays

### user_foods
- lib/features/user_foods/data/user_foods_repository.dart:363 — Fault — array column not valid JSON; row uploads without it. `_decodeJsonArray` became an instance method so it can reach `_report`; repository gained `Report? report`

## Legacy alias conversions in the same files (brief: "while you are there")

`_logger.error` → `_report.fault`, `_logger.warning` → `_report.degraded`,
one for one (same message, same extra data, `LoggedFault(message)` where no
error object was passed), via a scripted rewrite reviewed in the diff:

- activities_repository.dart: 40 (class gained `Report? report`, provider passes it; `_logger.info/debug` and `_sentry.*` untouched — ticket 10)
- activities_controller.dart: 12 (`_logger` getter replaced by `_report`; `_backgroundSync` caches the Report before its awaits, as it did the logger, because that catch can run on a disposed ref)
- events_service.dart: 11 (class gained `Report? report`, provider passes it)
- events_controller.dart: 9 (the per-method `final logger = ref.read(appLoggerProvider)` cache became `final report = ref.read(reportProvider)` for the same disposed-ref reason)
- recipe_repository.dart: 1
- add_food_screen.dart: 2 `DebugLogger.error` lines in one catch → one Fault; 3 `DebugLogger.warning` branch lines (duplicate food, widget unmounted) → Notes. `DebugLogger.info/debug` untouched

## Tests

- `onboarding_snapshot_service_test`: corrupt-snapshot test asserts one Fault, area `onboarding`.
- `content_service_test`: refresh-throws test asserts the manual-refresh Fault by message (the background refresh kicked by `initialize()` may report the same stub); `_container()` overrides `reportProvider` with a `RecordingReport`.
- `meal_type_parsing_test`: malformed-JSON test asserts one Fault, area `carb_loading`.
- `recipe_repository_test`: malformed-ingredients test asserts one Fault, area `recipes`.
