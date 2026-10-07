# Ticket 29 run notes: backport the mealplanning round's shared fixes

Branch `testing-wave/develop-2026-10/29-backport`, on develop-next `ab437b7d`. Four agents ran one
after another: A (items 1–9), B (11–17), C (18–30), D (31–34 and the final gates). Every commit says
`[skip ci]`. Nothing was pushed, merged or deployed. The source of each row below is its commit body
(`git log ab437b7d..HEAD`).

Verdicts: **clean** (applied as is), **near-clean** (1–2 hunks on context only), **hand** (merged by
hand). "(n)" marks a new file.

## Items

| # | Fix | Source sha(s) | Landed as | Verdict | Dropped (mealplanning-only or out of scope) | Tests |
|---|-----|---------------|-----------|---------|---------------------------------------------|-------|
| 1 | A wrong code is not "expired"; Log In stays busy (01-002) | 2a5cc75f | 80ebed71 | near-clean | `emailAuthHandoffProvider` and `appGateProvider.settle()` hunks in email_login_screen | verification_code_error_test (n), email_login_busy_test (n) |
| 2 | A password reset signs out every session | d2411107 | 584a2966 | near-clean | none (recovery controller rewritten on Report) | password_reset_signs_out_everywhere_test (n) |
| 3 | Sign-out offers no guest mode; confirms read content (08-021) | 807a867a, 2626f5b7 | 57db9836 | hand | paywall.* keys (the same text now lives under settings.*); 2626f5b7's paywall test | settings_account_dialogs_test (n), anonymous_session_actions_test |
| 4 | `user_registered` sends the device id | 2626f5b7 (onboarding_service only) | e3c9a1db | clean | Vana mic, paywall, content parts | onboarding_service_registered_device_id_test (n) |
| 5 | Sign-out clears the last account from the device | 495b97fc | 95ebf8ee | hand | subscription_status_provider, subscription_service and their test; personal_info_screen (item 10) | sign_out_clears_device_test (n), onboarding_integration_profile_provider_test (n), revenuecat_service_test |
| 6 | `users.created_at` goes out as UTC; OAuth cancels are quiet | 68143bc6 | 9c8752bd | hand | home_city/lat/lon/timezone in auth_migration_service | oauth_cancel_is_quiet_test (n), profile_created_at_utc_test (n) |
| 7 | Code screens wait 60 s; Log In errors under the form; abandoned signups discarded; recovery signs out unless saved | e2c2a457 + predecessors 8a67bad7 (t81), 1307c1ed (t102), f1cba43b (t94, item 3 only), 7b206f04 (`ContentKeys.format`) | fcef9c1a, 532ef481, 361260ec | hand | redeem-code (function, controller, sheet, key); meal_plans/plan_meals keep-parent arms; meal-plan and user-memory repos in sign-out; Pro clear on cancel; early RevenueCat configure (t85); grace-claim and old-anonymous parts; config.toml blocks for redeem-code, grace-claim, send-nutrition-plan-email, upload-all-data | code_fields_autofill_test, clear_user_data_keeps_unsynced_test, auth_listener_sign_in_sweep_test, coach_repository_athlete_code_test, email_sign_in_errors_test, code_screens_cooldown_test, login_error_line_test, password_recovery_marker_test, code_fields_auto_submit_test (all n); welcome_sign_out_notice_test, app_startup_version_check_test (edited); Deno discard-signup |
| 8 | Delete account waits for the server | 40618e4d (shared paths) | 375fe72f | hand | ticket 139 items 14 and 16 (Pro clear order, sign_out_source, paywall_screen) | sign_out_clears_device_test (delete group), settings_account_dialogs_test, anonymous_session_actions_test |
| 9 | The plan-reveal carb edit survives signup | d6f43ce0 | 2abc286c | clean code, hand test | mp-459 account-first tests, temp-id re-key test | onboarding_controller_test (03-009 group, through the real notifier) |
| 10 | 02-002 | none | none | already on develop-next | t33's hunk | none |
| 11 | A TrainingPeaks connection that needs signing in says so | ea674652 + fb0d514a (t76) | 554cc7ff | hand | kDebugMode prints | tp_refresh_requires_reconnect_seam_test (n), connected_apps_reconnect_test (n); tp_writeback_400_test edited |
| 12 | Garmin disconnect and account delete deregister at Garmin; leftover pushes skipped; auth logs no headers | 63c269c2 + 0d5c31cd (t65), f5cef058 (t95, shared paths) | a133a6af, 5d0638d9 (discard-signup's `withSentry` name) | hand | redeem-code, revenuecat-webhook and subscription changes; the RevenueCat client's entitlement calls; mealplanning's garmin-backfill 401 answer (develop keeps 409 `garmin_reauth_required`) | Deno _shared/garmin {auth, push_log, token}, delete-user, garmin-push, garmin-user-mapping, _shared/revenuecat |
| 13 | Reconnect notice, last good sync, `requires_reauth` kept, UTC stamps, FinalSurge 7-day lookback, Garmin chip only when it differs | e3aedcb6 + c27d547f (t42), e62ee202 (t99), c4743fe4 (t101), 1d914924 (t103), e4b7e854, 0b8f5676 (test part) | 56d5f68d, 8505b68d, 88a5a23a, e5f13ffb, f520c110, 2cbbc923 | hand | docs/ssot proposal (agents never write there); home_location_v22_migration_test; e4b7e854's RevenueCat configure retry; mealplanning's RefreshIndicator (came later with item 30) | activity_sync_handler_timestamptz_test, final_surge_completion_sync_seam_test, final_surge_completion_test, dashboard_provider_completion_test, completion_type_v23_migration_test, activity_upload_completion_type_test, provider_completion_is_final_test, provider_completion_card_test, pull_keeps_dirty_rows_test, sync_coordinator_upload_failure_test, final_surge_lookback_test, reconnect_notice_test, sync_status_write_seam_test, body_comp_garmin_chip_test (all n) |
| 14 | Profile & Preferences: email read-only, "Discard changes?", cleared names save cleared, its own title | e3d5e3f5 + 5ba1fa05, 9ff15611, f1cba43b (settings tile), 0b8f5676 (preferences hunk) | 788134a2, 08155375 | hand | home-location params; triple-tap debug GestureDetector; f1cba43b's other items | preferences_clear_text_fields_test, preferences_discard_changes_test, settings_profile_row_content_test (all n); settings_state_test, settings_content_test edited |
| 15 | One allergen normaliser; Omnivore is not a hide chip | ef1ec8d9 | bbd1040c | clean | none | allergen_normalizer_test, more_filters_omnivore_test, connected_apps_garmin_reauth_test (all n); Deno _shared/nutrition; run-algorithm-tests.sh |
| 16 | A dirty `users` row uploads at the next online moment; the notification ask waits for sign-in; its answer is stored | 0bd8ea01 + b42f9322 (t79, notification_service only), a50a88c1 (sync_coordinator part), 0b8f5676 (users-upload fix) | 4ebc9425 | hand | t79's Vana mic part; mealplanning debugPrints | notification_permission_moment_test (n), users_upload_owed_seam_test (n) |
| 17 | VoiceOver names the unnamed controls | cfdd876e (path-limited) | 12d688e9, baf868ec | near-clean | meal_add_button, meal_catalog_browser, vana_browse_screen_test; barcode_scanner_screen_test (needs mealplanning's base) | preferences_water_bottle_test, food_search_bar_test, kyle_sheet_header_test (all n) |
| 18 | New Event scrolls clear of the tab bar (08-008) | 818578e7 (path-limited) | 545abeef | near-clean | paywall_screen, redeem_code_sheet, snackbar bottomClearance | events_list_new_event_clears_tab_bar_test (n) |
| 19 | One fair event countdown | 76e0b2a6 | 5683f21e | clean | none | event_countdown_test (n) |
| 20 | Analyze stays above the keyboard (02-011) | 818578e7 (log_meal_screen only) | bf43ab0f | clean | none | log_meal_screen_keyboard_test (n) |
| 21 | Meal data syncs where it is read | d31988e4 (path-limited) | b9928d27 | near-clean | kroger_availability, meal_plan_controller, plan_tab, shopping_tab and their tests | meal_log_providers_sync_seam_test (n) |
| 22 | Quick logs keep their source | 906a233a | 57d84e77 | near-clean | `_diary.recordLogged()`; the plan-log test case | quick_logs_keep_what_they_came_from_test (n), log_meal_screen_quick_logs_test (n) |
| 23 | Unknown numbers stay unknown; decimal kcal rounds | a56a4c0f | 9dbf4953 | clean | none | unknown_numbers_stay_unknown_test (n), meal_logging_business_logic_test |
| 24 | Recent updates at once; edits keep the server's `created_at` | 84f6740f | 021c0839 | near-clean | `_diary.recordLogged()`; plan_meal_id fixture | meal_log_created_at_upload_test (n) |
| 25 | Meal upload retry, Recent per-serving base, readable portions, rounded scaled logs, `meal_logs.servings` | a50a88c1, 9f70360b, 89817f21 (test), c08d4dcb, 0b74732a (g25 test) | 13131f66, b838ae1f | hand | logging_analytics_tell_the_truth_test hunk; DiarySession; pro_gate / writeAccessProvider in tests | meal_log_upload_retry_seam_test, recent_per_serving_base_test, scaled_logs_store_rounded_numbers_test, meal_logs_servings_v24_migration_test (all n); portion_quantity_test, schema_version_guard_test, g25 edited |
| 26 | Build a Meal, saved meals, Manual and Edit | 25ec246a, d355aae3 + 6f7415ef (t83), 0cedd08b (t44), 109adef0 (t98) | 3fc7e0aa, b7fd969b, cc5ab1fb, dcac5fd3, 29e2170c, 13d65949 | hand | ai_action_guard (subscription), diary_session; showGlassSheet (came with Kroger and paywall; develop's composition of the same recipe used); redeem_code reformat hunk | ai_note_survives_the_save_test, barcode_scanner_route_test, barcode_scanner_screen_test, barcode_scanner_manual_entry_test, food_search_barcode_query_test, build_a_meal_and_manual_widget_test, saved_meals_favorites_and_edit_seam_test (all n) |
| 27 | Timeline meal cards follow the clock | 76aa826c | f4605d4f | clean | none | dashboard_meal_cards_test (n) |
| 28 | Pre-workout BEFORE cards add up | f7247c9e | 228ce832 | clean | none | pre_workout_before_card_assembler_test (n) |
| 29 | During-carbs conformance harness | 2ee4fb64 | 5895bc43 | clean, test-only | none | during_workout_carbs_conformance_test (n): 18 pass, 3 skipped |
| 30 | Ticket 137 items 2, 4, 6–16 | f669185a, 733eec97, 542b1b19, e54736fd + e663c3bb (overrides-clear part), 483d7281 | d5bf3c3e, 19fe9da1, 33f39077, 43331478, 50beb223, a8e163ad | clean except e54736fd (hand) | home-location fields in nutrition_overrides_clear_test | calendar_selected_date_user_reset_test, workout_card_title_test, kyle_date_header_chevrons_test, template-food-queries.test.ts, open_activity_fuel_test, running_input_location_gate_test, forecast_window_test, nutrition_overrides_clear_test, light_theme_readability_test (all n); run-algorithm-tests.sh 100/100 |
| 31 | Learn: Notify Me records and confirms; Learn works offline | 8df9fbab, 1d92deca | 9c7456be | hand | the vana `mic_permission` content hunk | education_repository_cache_test (n), education_screen_offline_test (n), coming_soon_section_widget_test |
| 32 | VoiceOver sweep, shared bullets | cba57836 + 0b8f5676 (the email row of its test) | c4503d2b | hand | meal_photo_thumbnail + review_photo_thumbnail_test (t97); meal_catalog_browser, vana_round_button, vana_controls_accessibility_test; the Paywall bullet (a8649f54) | auth_accessibility_test, event_form_back_button_test, integration_provider_card_semantics_test, onboarding_accessibility_test, preferences_accessibility_test (all n) |
| 33 | One dev-tools pill at the top edge | 45d78e75 (t68), e5b345cb | c8d6dcd8 | hand | the Ask Vana anchor (rebuilt without it: e5b345cb's end state has none); mealplanning's dev_tools_switch_controller gate | dev_testing_tools_test (n; a plain bottom-right FAB stands in for Ask Vana) |
| 34 | Patrol `TestConfig` has no built-in Supabase project | 38e8f1b3 | efd0692e | near-clean | README's `--bundle-id` paragraph; the `launchApp($)` permission-prompt lines | patrol_test_config_test (n) |
| 35 | Already on develop-next (111-003, 142 items 1, 2, 5) | none | none | nothing to do | none | none |

Final-gate commits (D): `ecc4a038` (delete-user's secret note names no redeem-code) and `cad2a476` (the
report source guard is green again). Both are described below.

## Predecessors brought (Lee's ruling 2026-10-07: shared paths only)

All 16 on the ticket's "Needs a ruling" list came along:
c27d547f (t42), e62ee202 (t99), c4743fe4 (t101), fb0d514a (t76), 1307c1ed (t102), 1d914924 (t103),
b42f9322 (t79, notification_service only), 8a67bad7 (t81), 6f7415ef (t83), 109adef0 (t98),
0cedd08b (t44), 5ba1fa05 (31-004), f1cba43b (t94, partial: item 3 and the Settings tile), 0d5c31cd (t65),
45d78e75 (t68, folded into item 33's end state), f5cef058 (t95, the delete-user split and a
deleteCustomer-only RevenueCat client).

Also taken, outside that list: 9ff15611 (31-014, item 14), e4b7e854 (item 13), e663c3bb (overrides-clear
part, item 30), 7b206f04 (`ContentKeys.format`, item 7), and the matching test or code parts of
0b8f5676 and 0b74732a.

## Drift

- **v23** = `activities.completion_type` (t99, B `8505b68d`). Pin `_pinnedFingerprint`
  `138f2619e791e7194565870a6d4298e01b4a1dc4b4649151395cf6d0e4952afa`.
- **v24** = `meal_logs.servings` REAL NOT NULL DEFAULT 1.0 (C `13131f66`). Pin
  `6439b5387ef989a9f51f3ca56856140a34e92e9333bb95230632d5c16c1a0e90`.
- Both match mealplanning's numbers and steps. Both steps re-add `activities.duration_source`
  idempotently. A device already at mealplanning's v23 or v24 still never gets it (from == to).

## Deploys owed to the lead (dev, after merge; nothing was deployed)

- discard-signup (new), delete-user, garmin-user-mapping, garmin-backfill, garmin-push, garmin-ping,
  garmin-deregistration, generate-nutrition-plan-v3, generate-macros-v4.
- delete-user wants `REVENUECAT_SECRET_KEY` (optional `REVENUECAT_PROJECT_ID`) on the project. Without
  the key it still deletes the account and logs the skipped RevenueCat customer.
- `/security-review` on discard-signup and delete-user has **not** been run (ticket checklist).
- `scripts/clear_finalsurge_past_provider_deleted.sql` (t42) is a one-off cleanup query. It has not been run.

## Prod blocker

`supabase/migrations/20260926163500_meal_logs_servings.sql` is applied on dev only. Prod needs it
before any build carrying Drift v24 talks to prod, because the app always sends `servings`. It also
needs `app_config.current_schema_version` 24 (23 → 24 at cutover), at Xuan's direction (playbook §3/§7).

## `/design-sync` owed (Lee runs it)

lib/shared/widgets/kyle_design/: buttons/segmented_control.dart (32), data/kyle_source_chip.dart (32),
inputs/kyle_input_field.dart (26/t98), materials/glass.dart (30), navigation/kyle_date_header.dart (30),
sheets/kyle_sheet_header.dart (17). lib/theme/kyle_design/: app_materials.dart, app_theme.dart,
me_surface_tokens.dart (n) (30).

## Final gates (D, on `cad2a476`)

1. **Codegen**: one unfiltered `build_runner build --delete-conflicting-outputs`. It changed nothing and
   deleted no generated files.
2. **flutter analyze**: 0 errors. There are 988 issues (897 info, 91 warning), the same multiset
   by severity, file and rule as `ab437b7d`. The comparison was made by analyzing a `git archive`
   of `ab437b7d` in scratch. No issue is new.
3. **Grep gate** (`vana|paywall|subscription|kroger|shopping|meal_plan|redeem|is_admin` on the 325
   files changed since `ab437b7d`, against the same files at `ab437b7d`): the raw count of new hits is
   558. Every hit but 18 is the `mealvana` package name in new imports. The 18 remaining:
   - Comments that say what stayed behind: content_keys.dart (×2, "no paywall on develop"),
     settings_account_dialogs_test.dart, auth_listener_sign_in_sweep_test.dart (Vana's
     user_memories), _shared/revenuecat/client.ts ("its paywall; those stay there"),
     revenuecat_service.dart ("the previous person's subscription").
   - Not the product word: OneSignal's push `subscription` (notification_service.dart ×5,
     notification_permission_moment_test.dart ×5), and Dart's `StreamSubscription`
     (sync_coordinator.dart).
   - One real leftover, fixed: delete-user/index.ts named the redeem-code function in its secret
     note (comment only; `ecc4a038`).
4. **Deno** (`--allow-all`; Deno rejects it together with `--allow-sys`): _shared/garmin,
   _shared/nutrition, delete-user, garmin-push, garmin-user-mapping, discard-signup: **225 passed
   (489 steps), 0 failed**. Fuelling vectors: C's run-algorithm-tests.sh run was 100/100 (incl. the
   vector and parity suites) after item 30. B's 98/99 had one red, fixed in `5d0638d9`.
5. **Flutter tests**: test/features/education, test/shared, and D's five a11y tests all pass. The run
   found the report source guard red: 14 unlisted catch blocks from items 7, 8, 11, 13 (t103), 16,
   30 and 31. In `cad2a476`, five sites now report (two auth notes, one education degraded,
   two sync notes per D9). Nine are reasoned allow-list entries, each naming where the failure is
   already reported. After the fix, test/shared, test/features/auth, education, test/new_sync and
   the meal upload retry seam test pass. The full suite is the lead's job.

## Open product questions and notes for other tickets

- **Wrong vs expired code (01-002).** Item 1 lands mealplanning's "wrong or has expired" text. Lee
  ruled that a wrong code gets its own message. Ticket 21 splits it.
- **RevenueCat on develop.** delete-user now deletes the RevenueCat customer after the auth account
  (t95). The ticket marked this "unverified whether develop wants it". Sign-out and abandoned-recovery
  call `RevenueCatService.logOut()`, because develop identifies to RevenueCat for AI credits.
  Mealplanning does a Pro clear here instead. Does develop want both?
- **Learn Notify Me** (item 31) records `education_notify_me_tapped` and says "We'll let you know".
  Nothing yet reads that event to tell anyone. Who keeps that promise?
- **Signup eye-button names** (item 32) are literal 'Show password' / 'Hide password' strings, as Log
  In's are, not content keys. CLAUDE.md wants content keys when the content system exists.
- **Dev-tools pill** (item 33) is left out of the semantics tree on purpose. At 18pt it would fail
  the checker's own tap-target rule.
- **Garmin dead token**: develop keeps ticket 19's 409 `garmin_reauth_required`, plus
  `requires_reauth: true` in the body. Mealplanning answers 401. The app accepts both.
- **Drift lineage**: a device that ran mealplanning's v23/v24 never gains `duration_source`.
- **For ticket 21**: the profile save no longer sends `email` (item 14, e3d5e3f5).
- **For ticket 22**: item 6 is 22's 01-004 for `users.created_at`.
- **For ticket 24**: t83 (AI note) is landed (`3fc7e0aa`). Item 26 shares edit_meal_log_screen.dart and
  meal_component_editor.dart.
- **For ticket 28**: 08-008 is closed here. Strike the Events-padding item and
  events_list_new_event_clears_tab_bar_test. `_showTrailDialog` in root_app_widget.dart is untouched;
  item 33 only replaced `_appShell` and removed the inline tool classes.
- **Unverified; retests decide**: 01-016 (item 8, retest 30), 08-019 (item 31), 08-023 (item 27,
  retest 32).
- **Not run here**: Patrol (no simulators in a fix wave). The notification-testing skill is not on this
  branch (B read notification_service.dart end to end instead; IMPROVEMENTS #101).
