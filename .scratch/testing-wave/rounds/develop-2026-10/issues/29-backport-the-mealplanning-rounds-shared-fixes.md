# 29: Backport the mealplanning round's fixes to shared code

**Status:** in-progress — fixed, awaiting retest (wave 2, 2026-10-07)
**Labels:** fix, round:develop-2026-10, area:backport
**Branch:** `develop-next` (fix-wave worktree)
**Blocked by:** none. **Runs first and alone in the fix wave** (Overlaps below: it shares files with 21, 22, 23,
24, 26, 27 and 28).
**Next:** `/testing-wave develop-2026-10` (fix wave)
**Model:** opus

**What to build:** Lee ruled (TRIAGE 08-025, 2026-10-07): "any fixes like this that you can find that are on
some other branch? … cherry-pick the shared-code fixes now". The fixes of round `mealplanning-2026-09` that touch
code develop-next has are extracted from their mealplanning landing commits onto develop-next, each with its
test. No paywall, subscription, Vana, meal-plan, shopping or Kroger code comes across, ever. When a commit mixes
the two, take only the shared paths (`git show <sha> -- <paths> | git apply -3`), and drop hunks that reference
mealplanning-only symbols.

Survey from code at `f2e8576e` against `origin/mealplanning`, read-only. The method: `git apply --check` per
commit on its shared paths, then a replay of the shared commits in order on a scratch copy of HEAD's files.
Nothing was compiled. Three facts the agent needs first:
- **BUGS.md is not on `origin/mealplanning`.** The `fixed @<sha>` rows live in develop-next's
  `docs/testing-wave/BUGS.md` (added in `d9ea11a5`).
- **The `fixed @<sha>` shas are mostly retest build heads or docs commits, not the fixes.** `5e05f8a6`,
  `e3367d2c`, `72d3723e`, `38e8f1b3` (for 111-003), `f8ea7233` and `3ac7c5bf` are examples. The real fix commits
  below were found through their ticket numbers. Every sha below is on `origin/mealplanning` and none is on
  develop-next (`git merge-base --is-ancestor`, checked).
- **Most rejects are context-only.** develop-next has the Sentry `Report` refactor (imports and log calls), and
  mealplanning has earlier tickets develop-next never got. `content_keys.dart` and `content_defaults.json` reject
  almost everywhere, but every one of those hunks only appends keys: merge by hand.

Verdicts: **clean** (applies as is on its shared paths), **near-clean** (1–2 hunks fail on context only),
**hand** (extract by hand; the reason is given). "(n)" marks a file not on develop-next.

**Wave-1 Findings that close here.** 01-002 (= BUGS 32-001), 08-008 (= 03-007), 08-021 (= 06-003 / 31-001,
followup) and 02-011 (= 23-001, followup) close through this ticket, and 08-025 (= 138 item 3) is its source.
Tickets 21 and 28 must not redo them. If this ticket lands first, the lead strikes 28's Events-padding item
(08-008) and the test `events_list_new_event_clears_tab_bar_test.dart`, which this ticket brings. For 21 and
01-002, one caveat (the lead decides): `2a5cc75f` says "wrong **or** expired" in one message. Lee's ruling is "a
wrong code gets its own message; expired stays for expired". 21 already reads what 29 landed and splits the
text, so keep 21's split and strike only what 29 fully closed.

## Shared fixes, by area

**Auth and account**
1. **32-001 + 12-003: a wrong code is not "expired"; Log In stays not-busy after an error (01-002).** `2a5cc75f`
   (t53), refined by `e2c2a457` (item 7). Files: `lib/features/auth/application/email_auth_service.dart`
   (HEAD..mp +291/−221; HEAD still maps any "expired" at `:524-525`),
   `lib/features/auth/domain/auth_exceptions.dart`, `lib/features/auth/presentation/screens/email_login_screen.dart`.
   Tests (n): `test/features/auth/application/verification_code_error_test.dart`,
   `test/features/auth/presentation/email_login_busy_test.dart`. **Near-clean** (2 hunks in `email_login_screen`).
2. **32-003: a password reset signs out every session.** `d2411107` (t108). Files:
   `lib/features/auth/application/supabase_auth_service.dart` (applies),
   `lib/features/auth/presentation/providers/password_recovery_controller.dart` (1 hunk). Test (n):
   `test/features/auth/presentation/password_reset_signs_out_everywhere_test.dart`. **Near-clean.**
3. **06-003 / 31-001 + 02-006: sign-out no longer says "continue as a guest" (08-021); the confirms read from
   the content system.** `807a867a` (t47), then `2626f5b7` (t104) for the single sign-out text, its shared paths
   only (its paywall and Vana-mic parts stay behind). File: `lib/features/settings/presentation/screens/settings_screen.dart`
   (the guest text is still at `:583`; 1 of 4 hunks fails), plus content keys and defaults. Tests:
   `test/features/settings/anonymous_session_actions_test.dart`, `test/features/settings/settings_account_dialogs_test.dart` (n).
   **Near-clean.**
4. **86-006: `user_registered` sends the user id as device_id.** `2626f5b7` (t104), path-limited to
   `lib/features/onboarding/application/onboarding_service.dart`. Test (n):
   `test/features/onboarding/application/onboarding_service_registered_device_id_test.dart`. **Clean** on that path.
5. **02-001 + 03-002: sign-out clears the last account (no stranger's onboarding prefill; RevenueCat logs out).**
   `495b97fc` (t33). Files: `lib/features/onboarding/presentation/providers/onboarding_preview_providers.dart`
   (1 hunk), `lib/features/settings/presentation/providers/settings_controller.dart` (+`.g.dart`; 5 hunks fail,
   HEAD..mp +463/−209), `lib/shared/database/app_database.dart` (`clearUserData`, applies),
   `lib/features/ai_credits/data/revenuecat_service.dart` (`logOut`; develop identifies to RevenueCat for AI
   credits, `revenuecat_service.dart:203`). Tests: `test/features/onboarding/onboarding_integration_profile_provider_test.dart` (n),
   `test/features/settings/sign_out_clears_device_test.dart` (n), `test/features/ai_credits/data/revenuecat_service_test.dart`.
   **Hand:** the commit also touches `subscription_status_provider` / `subscription_service`, and those hunks
   stay behind.
6. **139 items 4, 11: `users.created_at` goes out as UTC; OAuth cancels are quiet.** `68143bc6`. Files:
   `lib/features/auth/domain/user_preferences.dart`, `lib/features/auth/data/user_repository.dart`,
   `lib/features/auth/application/{auth_migration_service.dart,oauth_service.dart}`, `auth_exceptions.dart`,
   `lib/features/auth/presentation/providers/post_onboarding_auth_controller.dart`,
   `lib/features/auth/presentation/screens/post_onboarding_auth_screen.dart`. Tests (n):
   `test/features/auth/oauth_cancel_is_quiet_test.dart`, `test/features/auth/profile_created_at_utc_test.dart`.
   **Hand** (4 of 9 files fail). This is ticket 22's 01-004 for `users`. Tell 22.
7. **139 items 5–10, 12, 13, 15: code screens wait 60 s and count down a 429; Log In errors sit under the field;
   a discarded signup is cleaned up; the startup version check; Welcome's signed-out notice.** `e2c2a457`. Files:
   `email_auth_service.dart`, `auth_exceptions.dart`, `password_recovery_controller.dart`, screens
   `email_login_screen.dart`, `email_signup_screen.dart`, `verify_email_screen.dart`,
   `verify_reset_code_screen.dart`, `set_new_password_screen.dart`, `post_onboarding_auth_screen.dart`;
   `lib/features/app_startup/application/{app_startup_provider.dart,app_startup_provider.g.dart,app_startup_service.dart}`,
   `lib/shared/core/app_router.dart` (+5/−1), `lib/features/onboarding/presentation/screens/welcome_screen.dart`,
   `supabase/config.toml`, `supabase/functions/discard-signup/{index.ts,handler.ts,handler.test.ts}` (n). Tests
   (n): `test/features/auth/application/email_sign_in_errors_test.dart`,
   `test/features/auth/presentation/{code_screens_cooldown_test,login_error_line_test,password_recovery_marker_test}.dart`,
   `test/features/onboarding/welcome_sign_out_notice_test.dart`, and `test/new_sync/app_startup_version_check_test.dart`.
   **Hand:** 14 of 25 files fail, and it sits on t81 `8a67bad7` (code fields, not on HEAD). A new edge function
   means `/security-review` and a dev deploy.
8. **139 item 17: Delete account waits for the server.** `40618e4d`, shared paths only. Files:
   `settings_controller.dart`, `settings_screen.dart`, `lib/features/settings/domain/account_deletion_exceptions.dart` (n),
   with the tests from items 3 and 5. **Hand:** items 14 and 16 (Pro clear, paywall source,
   `sign_out_source.dart`) and `paywall_screen` stay behind. Likely closes 01-016 (unverified; retest 30).

**Onboarding**
9. **03-009: the plan-reveal carb edit survives signup.** `d6f43ce0` (t40).
   `lib/features/onboarding/presentation/providers/onboarding_controller.dart` is **clean**.
   `test/features/onboarding/onboarding_controller_test.dart` has diverged (8 hunks): merge the test by hand.
10. **02-002: already fixed on develop-next** (`personal_info_screen.dart:139-145`). Drop t33's hunk for it.

**Settings and integrations**
11. **21-004: a TrainingPeaks connection that needs signing in says so.** `ea674652` (t64). Files:
    `lib/features/integrations/application/{training_peaks_oauth_service.dart,training_peaks_sync_service.dart}`
    (both diverged under Sentry ticket 22), `lib/features/integrations/domain/integration.dart`,
    `…/presentation/providers/connect_training_controller.dart`, `…/presentation/widgets/integration_provider_card.dart`,
    `lib/features/settings/presentation/screens/connected_apps_screen.dart`, `lib/shared/widgets/tabs_screen.dart`.
    Tests (n): `test/features/integrations/tp_refresh_requires_reconnect_seam_test.dart`,
    `test/features/settings/connected_apps_reconnect_test.dart`. **Hand.**
12. **138 items 1–4, 6: Garmin disconnect and account delete deregister at Garmin; a leftover push is `skipped`,
    not an error (08-025); garmin-auth logs no headers or IPs; "Token is not active" marks `requires_reauth`.**
    `63c269c2`, on top of `0d5c31cd` (t65, `push_log.ts`) and `f5cef058`'s delete-user `handler.ts` split (t95,
    shared paths only; its RevenueCat-customer delete is account deletion, which develop has. Unverified whether
    develop wants it). Files: `supabase/functions/_shared/garmin/auth.ts`, `_shared/garmin/{push_log.ts,token.ts}` (n),
    `supabase/functions/delete-user/{index.ts,index.test.ts}`, `delete-user/handler.ts` (n),
    `supabase/functions/garmin-backfill/index.ts`, `supabase/functions/garmin-push/{index.ts,index.test.ts}`
    (HEAD warns at 5 sites), `supabase/functions/garmin-user-mapping/{index.ts,index.test.ts}`,
    `garmin-user-mapping/delete.ts` (n). Tests (n): `_shared/garmin/{auth,push_log,token}.test.ts`.
    **Hand** (8 of 14 files fail). Deploy (lead, dev): garmin-user-mapping, delete-user, garmin-backfill,
    garmin-push, garmin-ping, garmin-deregistration (they share `_shared/garmin`). 138 item 5 (dev orphan
    deregistration) is lead ops.
13. **138 items 7–10, 17, 18: a network error keeps `requires_reauth`; the Reconnect notice; last good sync;
    `last_sync_at` in UTC; FinalSurge looks back 7 days; the Garmin chip shows only when it differs; the note says
    Sync Now.** `e3aedcb6`. Files: `lib/features/integrations/data/integrations_repository.dart`,
    `lib/features/integrations/application/{training_peaks_oauth_service,final_surge_sync_service,vdot_sync_service}.dart`,
    `…/domain/integration_exceptions.dart`, `…/presentation/providers/{integrations_providers,connect_training_controller}.dart` (+`.g.dart`),
    `…/presentation/providers/reconnect_notice_controller.dart` (+`.g.dart`, n), `…/presentation/widgets/reconnect_notice.dart` (n),
    `connected_apps_screen.dart`, `lib/features/settings/presentation/screens/nutrition_profile_screen.dart`,
    `lib/features/macro_dashboard/presentation/screens/macro_dashboard_screen.dart`. Tests (n):
    `test/features/integrations/{final_surge_lookback_test,reconnect_notice_test,sync_status_write_seam_test}.dart`,
    `test/features/settings/body_comp_garmin_chip_test.dart`. **Hand:** 13 of 22 files fail. It sits on t42
    `c27d547f`, t99 `e62ee202`, t101 `c4743fe4` and t76 `fb0d514a` (see "Needs a ruling").
14. **138 items 11, 12: email is read-only; "Discard changes?" on leaving.** `e3d5e3f5`. File:
    `lib/features/settings/presentation/screens/preferences_screen.dart` (2 hunks). Tests (n):
    `test/features/settings/presentation/screens/preferences_discard_changes_test.dart`,
    `preferences_clear_text_fields_test.dart` (from `5ba1fa05`). **Hand.** It stops sending `email` in the
    profile save, which touches ticket 21's email item.
15. **138 items 14, 15: one allergen normaliser (Peanut matches `peanuts`); Omnivore is not a hide chip.**
    `ef1ec8d9`. **Clean** (13 of 13): `lib/features/onboarding/domain/allergen_normalizer.dart` (n),
    `lib/features/formula_kit/application/formula_library_controller.dart`,
    `lib/features/formula_kit/presentation/widgets/more_filters_sheet.dart`,
    `lib/features/nutrition_plan/domain/selection_precedence.dart`,
    `supabase/functions/_shared/nutrition/{selection-precedence.ts,allergen-normalize.ts (n),allergen-normalize.test.ts (n)}`.
    Tests (n): `test/features/onboarding/allergen_normalizer_test.dart`, `test/features/formula_kit/more_filters_omnivore_test.dart`,
    `test/features/settings/connected_apps_garmin_reauth_test.dart` (item 12's test, carried here). A fuelling
    change: `docs/ssot/vectors/` must stay green. Deploy generate-nutrition-plan-v3 and generate-macros-v4 to dev.
16. **138 items 13, 16: a dirty `users` row uploads at the next online moment; the notification answer is
    stored.** `0bd8ea01`. Files: `lib/features/app_startup/application/app_startup_service.dart`,
    `lib/features/auth/data/user_repository.dart`, `lib/features/auth/domain/user_preferences.dart`,
    `lib/shared/database/daos/user_dao.dart`, `lib/shared/services/notification_service.dart`. Tests (n):
    `test/features/auth/users_upload_owed_seam_test.dart`, `test/shared/services/notification_permission_moment_test.dart`
    (from t79 `b42f9322`). **Hand.** CLAUDE.md: invoke the `notification-testing` skill first, and D9 applies
    to every new early return.
17. **31-002 + 28-006: VoiceOver names the unnamed controls.** `cfdd876e` (t51), path-limited:
    `preferences_screen.dart`, `lib/features/barcode_scanning/presentation/screens/barcode_scanner_screen.dart`,
    `lib/shared/widgets/food_selection/food_search_bar.dart`, `lib/shared/widgets/kyle_design/sheets/kyle_sheet_header.dart`.
    Tests (n): `test/features/settings/presentation/screens/preferences_water_bottle_test.dart`,
    `test/shared/widgets/food_selection/food_search_bar_test.dart`, `test/shared/widgets/kyle_design/sheets/kyle_sheet_header_test.dart`.
    **Near-clean.** Skip `barcode_scanner_screen_test.dart`: it needs mealplanning's base. Touches
    `kyle_design/`, so `/design-sync` is owed (Lee runs it).

**Events**
18. **03-007: New Event scrolls clear of the tab bar (08-008).** `818578e7` (t52), path-limited:
    `lib/features/events/presentation/screens/events_list_screen.dart` (HEAD has `xxxl` at `:220`; 1 of 2 hunks
    fails), `lib/shared/widgets/tabs_screen.dart` (1 hunk; HEAD has `const EventsListScreen()` at `:173`). Test
    (n): `test/features/events/events_list_new_event_clears_tab_bar_test.dart`. **Near-clean.**
19. **141 item 4: one fair event countdown.** `76e0b2a6`. **Clean:** `lib/features/events/domain/event_countdown.dart` (n),
    `lib/features/events/presentation/widgets/{event_countdown_badge,upcoming_event_card_kyle,upcoming_event_widget}.dart`.
    Test (n): `test/features/events/event_countdown_test.dart`.

**Meal logging**
20. **23-001: Analyze stays above the keyboard (02-011).** `818578e7`, path-limited to
    `lib/features/meal_logging/presentation/screens/log_meal_screen.dart`. Test (n):
    `test/features/meal_logging/log_meal_screen_keyboard_test.dart`. **Clean.**
21. **26-001 + 10-001: meal data syncs where it is read.** `d31988e4` (t46), path-limited:
    `lib/features/meal_logging/data/{meal_log_repository.dart,saved_meals_repository.dart}`,
    `lib/features/meal_logging/presentation/providers/meal_log_providers.dart` (+`.g.dart`; 2 hunks). Test (n):
    `test/features/meal_logging/meal_log_providers_sync_seam_test.dart`. **Near-clean**; run codegen.
22. **26-002 / 26-003: quick logs keep their source.** `906a233a` (t58). Files:
    `lib/features/meal_logging/application/meal_logging_service.dart`, `…/domain/{meal_auto_name.dart,meal_relog.dart (n)}`,
    `meal_log_providers.dart`, `log_meal_screen.dart` (1 hunk), `…/screens/recent_saved_picker_screen.dart`
    (1 hunk; ticket 26 archives this file afterwards), `…/widgets/log_sheet_helpers.dart`. Tests (n):
    `log_meal_screen_quick_logs_test.dart`, `quick_logs_keep_what_they_came_from_test.dart`. **Near-clean.**
23. **26-004 (+25-001): unknown numbers stay unknown; decimal kcal rounds.** `a56a4c0f` (t41). **Clean** (6 of 6:
    includes `manual_log_form.dart`, `manual_component_form.dart`, `…/domain/macro_rounding.dart` (n)). Test (n):
    `test/features/meal_logging/unknown_numbers_stay_unknown_test.dart`.
24. **26-005: Recent updates at once; edits keep the server's `created_at`.** `84f6740f` (t54), after item 21.
    Still 4 files fail after it. Test (n): `test/features/meal_logging/meal_log_created_at_upload_test.dart`.
    **Hand.** Touches `meal_log.dart` / `meal_log_repository.dart`, which are in ticket 22's area.
25. **135 items 1–9: retry a failed meal upload, Recent per-serving base, readable portions, rounded scaled
    logs, `meal_logs.servings`.** `a50a88c1`, `9f70360b`, `89817f21`, `c08d4dcb`, plus the codegen part of
    `0b74732a`. **Hand.** Drift: mealplanning goes to v24 (`meal_logs.servings`), but develop-next is v22 (t99's
    v23 isn't here). Renumber to v23, or bring t99 (ruling). Migration (n)
    `supabase/migrations/20260926163500_meal_logs_servings.sql` is already applied on dev; prod needs it with an
    `app_config` schema bump (playbook §3/§7, Xuan's direction). Touches `lib/shared/services/sync/sync_coordinator.dart`
    (+`.g.dart`; D9), `lib/shared/database/{app_database.dart,app_database.g.dart,tables/meal_logs_table.dart}`,
    `…/domain/{portion_quantity.dart,consumed_totals.dart,quick_assembly.dart}`. Tests (n):
    `meal_log_upload_retry_seam_test.dart`, `recent_per_serving_base_test.dart`,
    `scaled_logs_store_rounded_numbers_test.dart`; edited: `portion_quantity_test.dart`,
    `test/shared/database/schema_version_guard_test.dart`, `test/features/carb_loading/g25_one_tap_log_test.dart`.
26. **136 items 1–11: Build a Meal, saved meals, Manual and Edit.** `25ec246a`, `d355aae3`. **Hand:** 10 of 18
    files fail, and it sits on t83, t98, t44, t41, t54, t58, t59. Touches `build_meal_screen.dart`,
    `edit_meal_log_screen.dart`, `meal_component_editor.dart`, `draft_meal_controller.dart`,
    `quick_log_confirm_sheet.dart`. Tests (n): `build_a_meal_and_manual_widget_test.dart`,
    `saved_meals_favorites_and_edit_seam_test.dart`, `barcode_scanner_manual_entry_test.dart`. Shares two files
    with ticket 24.

**Timeline, activities, fuelling**
27. **27-001: Timeline meal cards follow the clock.** `76aa826c` (t59). Only one import hunk fails
    (`meal_slot.dart`, on HEAD). Test (n): `test/features/macro_dashboard/application/dashboard_meal_cards_test.dart`.
    **Near-clean.** Likely closes 08-023 (unverified; retest 32).
28. **30-004: pre-workout BEFORE cards add up.** `f7247c9e` (t62). **Clean.**
29. **30-003: during-carbs conformance harness.** `2ee4fb64` (t63). **Clean**, test-only
    (`test/qa_conformance/during_workout_carbs_conformance_test.dart` (n)). The engine was already right.
30. **137 items 2, 4, 15** `f669185a` (clean after item 27); **137 items 6, 7, 8, 10** `733eec97` (clean);
    **137 item 16** `542b1b19` (clean; fuelling: vectors green, deploy the two nutrition functions);
    **137 item 9** `483d7281` (clean after `733eec97`; touches `lib/theme/kyle_design/`, so `/design-sync` is
    owed); **137 items 11–14** `e54736fd` (12 of 15 apply; `cycling_input_controller` and `settings_controller`
    fail; `nutrition_overrides_clear_test.dart` (n); **hand**).

**Learn, dev tools, harness**
31. **141 items 3, 5: Notify Me records and confirms; Learn works offline.** `8df9fbab`, `1d92deca`.
    `education_repository.dart` and `coming_soon_section_widget.dart` fail. Tests (n):
    `test/features/education/{education_repository_cache_test,education_screen_offline_test}.dart`. **Hand.**
    Likely closes 08-019 (unverified).
32. **141 item 1, shared bullets: the VoiceOver sweep** (onboarding, signup eye buttons, Log In chooser and New
    Event back, Connected Apps, Profile & Preferences, theme dialog, Nutrition Targets). `cba57836`. 16 of 21
    files apply. Adds `lib/shared/widgets/inputs/field_name.dart` (n) and touches `kyle_design/`
    (`/design-sync`). **Hand:** skip the Review & Log thumbnail bullet (`meal_photo_thumbnail.dart` came with
    mealplanning t97), and the Vana, Browse and Paywall bullets (`a8649f54`).
33. **141 item 2 (= IMPROVEMENTS #98): one dev-tools pill at the top edge.** `e5b345cb`, which needs `45d78e75`
    (t68: moved the code into `lib/shared/widgets/dev_testing_tools.dart` (n), placed relative to Ask Vana).
    develop-next's `root_app_widget.dart` still has both buttons inline. **Hand:** rebuild the pill without any
    Ask Vana anchor. Test (n): `test/shared/widgets/dev_testing_tools_test.dart`.
34. **02-007: Patrol `TestConfig` has no built-in Supabase project.** `38e8f1b3`.
    `integration_test/helpers/test_config.dart` applies; `flow_launcher.dart` and `integration_test/README.md`
    fail. Test (n): `test/shared/patrol_test_config_test.dart`. **Near-clean.**
35. **Already on develop-next** (patches reverse-apply): 111-003, 142 items 1, 2, 5. Nothing to do.

## Needs a ruling before the agent starts (lead asks Lee)
The fixes above sit on mealplanning tickets whose BUGS rows are `triaged` or `closed`, not `fixed`. So they are
outside the 71, and none is on develop-next: `c27d547f` (t42), `e62ee202` (t99, Drift v23), `c4743fe4` (t101) for
FinalSurge; `fb0d514a` (t76) for the TrainingPeaks reconnect; `1307c1ed` (t102), `1d914924` (t103) for sync;
`b42f9322` (t79) for permission prompts; `8a67bad7` (t81) for code fields; `6f7415ef` (t83) for the AI note,
which ticket 24 ports itself; `109adef0` (t98), `0cedd08b` (t44) for barcode; `5ba1fa05` (31-004); `f1cba43b`
(t94); `0d5c31cd` (t65); `45d78e75` (t68); `f5cef058` (t95). Either bring them along as prerequisites (bigger,
cleaner applies), or hand-port the dependent items without them (smaller, riskier).

## Not backported (mealplanning-only)
- **BUGS rows (44).**
  - Paywall, subscription, Test Store and codes: 02-003 (its shared wipe code rides with item 5), 05-004, 06-002,
    08-001, 08-002, 09-001, 11-005, 11-012, 32-002.
  - Plans, Vana chat, Previous plans and Browse: 14-001..003 (the wipe code rides with item 5), 15-001..003,
    16-001..005, 17-001..003, 18-001..006, 09-002, 61-001, 73-001.
  - Shopping and Kroger: 19-001, 19-003, 19-004, 20-002, 20-003, 20-008, 21-001..003, 22-003, 22-005.
  - **29-001 is mealplanning-only.** It was on the starting list, but its fix `705fec6a` touches only `_shared/vana`
    (the plan picker).
- **Tickets.**
  - 127, 128, 129, 131, 132, 133, 134, 140 (all items): meal plans, shopping, Kroger, paywall and codes.
  - 130 (all items, including item 5's admin read: `is_admin_provider.dart` and `users.is_admin` don't exist on
    develop-next).
  - 139 items 1, 2, 3, 14, 16 (entitlement, admin read, Vana 401, Pro clear, paywall source), and its
    `is_admin` migration `63f509ef`.
  - 141 item 6 (Vana mic) and item 1's Vana, Browse and Paywall bullets. 142 item 4 (Pro grant seed).
- **No change at all:** 137 items 1, 3, 5 (held for Xuan, or won't fix); 138 item 5 (lead ops).

**Findings:** 08-025 (source). Closes 01-002, 08-008, 08-021, 02-011. Likely helps 01-003, 01-004, 01-014,
01-016, 08-019, 08-023 (unverified; retests 30–32 decide).

**Decisions:** Lee, 2026-10-07 (TRIAGE 08-025). Rulings 2026-10-07 (Lee, wave 2 open): **bring the predecessor
tickets along** (shared paths only; the list under "Needs a ruling"), and **Drift goes v23 (t99) then v24 (servings),
the same numbering as mealplanning.**

**Touches** (the union of the shared paths of the commits above; the agent leaves out any hunk tied to
mealplanning-only code; "(n)" = new on develop-next):
- *Content:* assets/config/content_defaults.json, lib/features/content/domain/content_keys.dart.
- *Auth:* lib/features/auth/application/{email_auth_service,supabase_auth_service,oauth_service,auth_migration_service}.dart;
  lib/features/auth/data/user_repository.dart; lib/features/auth/domain/{auth_exceptions,user_preferences}.dart;
  lib/features/auth/presentation/providers/{password_recovery_controller,post_onboarding_auth_controller}.dart;
  lib/features/auth/presentation/screens/{email_login_screen,email_signup_screen,verify_email_screen,verify_reset_code_screen,set_new_password_screen,post_onboarding_auth_screen}.dart.
- *Startup and router:* lib/features/app_startup/application/{app_startup_provider.dart,app_startup_provider.g.dart,app_startup_service.dart};
  lib/shared/core/app_router.dart.
- *Onboarding:* lib/features/onboarding/application/onboarding_service.dart;
  lib/features/onboarding/domain/allergen_normalizer.dart (n);
  lib/features/onboarding/presentation/providers/{onboarding_controller,onboarding_preview_providers}.dart;
  lib/features/onboarding/presentation/screens/{welcome_screen,personal_info_screen}.dart;
  lib/features/onboarding/presentation/widgets/{onboarding_multi_select_step,onboarding_step_scaffold}.dart;
  lib/shared/widgets/navigation/figma_onboarding_footer.dart.
- *Settings:* lib/features/settings/domain/account_deletion_exceptions.dart (n);
  lib/features/settings/presentation/providers/settings_controller.dart (+.g.dart);
  lib/features/settings/presentation/screens/{settings_screen,preferences_screen,connected_apps_screen,nutrition_profile_screen,nutrition_targets_screen}.dart.
- *Integrations:* lib/features/integrations/application/{training_peaks_oauth_service,training_peaks_sync_service,final_surge_sync_service,vdot_sync_service}.dart;
  lib/features/integrations/data/integrations_repository.dart;
  lib/features/integrations/domain/{integration,integration_exceptions}.dart;
  lib/features/integrations/presentation/providers/{connect_training_controller,integrations_providers}.dart (+.g.dart each);
  lib/features/integrations/presentation/providers/reconnect_notice_controller.dart (+.g.dart) (n);
  lib/features/integrations/presentation/widgets/integration_provider_card.dart;
  lib/features/integrations/presentation/widgets/reconnect_notice.dart (n);
  lib/features/ai_credits/data/revenuecat_service.dart.
- *Formula kit and nutrition plan:* lib/features/formula_kit/application/formula_library_controller.dart;
  lib/features/formula_kit/presentation/widgets/more_filters_sheet.dart;
  lib/features/nutrition_plan/domain/{selection_precedence,pre_workout_before_card_model}.dart;
  lib/features/nutrition_plan/application/{pre_workout_before_card_assembler,by_hour_sync_service}.dart;
  lib/features/nutrition_plan/presentation/providers/{cycling_input_controller,running_input_controller,swimming_input_controller}.dart (+.g.dart each);
  lib/features/nutrition_plan/presentation/utils/post_create_navigation.dart;
  lib/features/nutrition_plan/presentation/widgets/activity_detail/{by_hour_view,hour_bucket_widget}.dart;
  lib/features/activities/presentation/navigation/open_activity_fuel.dart;
  lib/features/weather/domain/forecast_window.dart (n);
  lib/features/calendar/presentation/providers/calendar_selected_date_provider.dart.
- *Events:* lib/features/events/domain/event_countdown.dart (n);
  lib/features/events/presentation/screens/{events_list_screen,event_form_screen}.dart;
  lib/features/events/presentation/widgets/{event_countdown_badge,upcoming_event_card_kyle,upcoming_event_widget}.dart.
- *Education:* lib/features/education/data/education_cache.dart (n);
  lib/features/education/data/education_repository.dart (+.g.dart);
  lib/features/education/presentation/screens/education_screen.dart;
  lib/features/education/presentation/widgets/coming_soon_section_widget.dart.
- *Meal logging:* lib/features/meal_logging/application/meal_logging_service.dart;
  lib/features/meal_logging/data/{meal_log_repository.dart,meal_log_repository.g.dart,saved_meals_repository.dart};
  lib/features/meal_logging/domain/{consumed_totals,meal_auto_name,meal_log,portion_quantity,quick_assembly}.dart;
  lib/features/meal_logging/domain/{macro_rounding,meal_relog}.dart (n);
  lib/features/meal_logging/presentation/providers/{draft_meal_controller.dart,meal_log_providers.dart,meal_log_providers.g.dart};
  lib/features/meal_logging/presentation/screens/{build_meal_screen,edit_meal_log_screen,log_meal_screen,recent_saved_picker_screen}.dart;
  lib/features/meal_logging/presentation/widgets/{log_sheet_helpers,manual_component_form,manual_log_form,meal_component_editor,quick_log_confirm_sheet}.dart;
  lib/features/barcode_scanning/presentation/screens/barcode_scanner_screen.dart.
- *Timeline and theme:* lib/features/macro_dashboard/application/dashboard_assembler.dart;
  lib/features/macro_dashboard/domain/dashboard_models.dart;
  lib/features/macro_dashboard/presentation/{me_tokens.dart,screens/macro_dashboard_screen.dart};
  lib/features/macro_dashboard/presentation/widgets/{breakdown_pager,dashboard_filter_row,energy_summary_card,meal_card,workout_card}.dart;
  lib/features/home_shell/presentation/widgets/home_shell_calendar_host.dart;
  lib/theme/kyle_design/{app_materials,app_theme}.dart; lib/theme/kyle_design/me_surface_tokens.dart (n);
  lib/shared/widgets/kyle_design/{buttons/segmented_control,data/kyle_source_chip,materials/glass,navigation/kyle_date_header,sheets/kyle_sheet_header}.dart.
- *Shared infra:* lib/shared/database/{app_database.dart,app_database.g.dart,tables/meal_logs_table.dart,daos/user_dao.dart};
  lib/shared/services/notification_service.dart;
  lib/shared/services/sync/sync_coordinator.dart (+.g.dart);
  lib/shared/widgets/{root_app_widget,tabs_screen}.dart;
  lib/shared/widgets/food_selection/food_search_bar.dart;
  lib/shared/widgets/{dev_testing_tools.dart,inputs/field_name.dart} (n).
- *Supabase:* supabase/config.toml;
  supabase/migrations/20260926163500_meal_logs_servings.sql (n);
  supabase/functions/_shared/garmin/auth.ts; supabase/functions/_shared/garmin/{push_log,token}.ts (n);
  supabase/functions/_shared/nutrition/{during-template-solver,post-template-solver,selection-precedence,template-food-queries}.ts;
  supabase/functions/_shared/nutrition/allergen-normalize.ts (n);
  supabase/functions/delete-user/{index.ts,index.test.ts}; supabase/functions/delete-user/handler.ts (n);
  supabase/functions/discard-signup/{index.ts,handler.ts,handler.test.ts} (n);
  supabase/functions/garmin-backfill/index.ts; supabase/functions/garmin-push/{index.ts,index.test.ts};
  supabase/functions/garmin-user-mapping/{index.ts,index.test.ts}; supabase/functions/garmin-user-mapping/delete.ts (n).
- *Deno tests:* supabase/functions/_shared/garmin/{auth,push_log,token}.test.ts (n);
  supabase/functions/_shared/nutrition/{allergen-normalize,template-food-queries}.test.ts (n);
  supabase/functions/_shared/nutrition/during-template-solver.test.ts.
- *Integration harness:* integration_test/helpers/{test_config,flow_launcher}.dart; integration_test/README.md.
- *Flutter tests, new:* everything named "(n)" in items 1–34. The list is in `git show --name-only` of the
  commits; around 75 files under `test/features/{auth,onboarding,settings,integrations,events,meal_logging,macro_dashboard,education,formula_kit,nutrition_plan,weather,calendar,activities,barcode_scanning}`,
  `test/shared/`, `test/qa_conformance/`.
- *Flutter tests, edited:* test/features/ai_credits/data/revenuecat_service_test.dart,
  test/features/carb_loading/g25_one_tap_log_test.dart, test/features/education/coming_soon_section_widget_test.dart,
  test/features/home_shell/home_shell_gestures_test.dart,
  test/features/macro_dashboard/{day_relativity_test,macro_dashboard_goldens_test,macro_dashboard_screen_test}.dart,
  test/features/meal_logging/{meal_log_slot_seam_test,meal_logging_business_logic_test,portion_quantity_test}.dart,
  test/features/nutrition_plan/application/{by_hour_apportionment_service_test,pre_workout_hydration_check_service_test}.dart,
  test/features/nutrition_plan/presentation/{utils/post_create_navigation_test,widgets/hour_bucket_widget_test}.dart,
  test/features/onboarding/{onboarding_controller_test,personal_info_screen_test}.dart,
  test/features/settings/anonymous_session_actions_test.dart, test/new_sync/app_startup_version_check_test.dart,
  test/seeded_tests/meal_weather_ai_coach_content_test.dart, test/shared/database/schema_version_guard_test.dart.

**Overlaps** (by file; why this ticket runs first and alone):
- **21:** `email_auth_service.dart`, `auth_exceptions.dart`, `verify_email_screen.dart`, `user_preferences.dart`,
  `user_dao.dart`, `content_defaults.json`. 21 already expects 29 first (`2a5cc75f`, `e2c2a457`).
- **22:** `user_preferences.dart`, `user_repository.dart`, `auth_migration_service.dart` (item 6 is 22's `users`
  created_at), `notification_service.dart`, `app_startup_service.dart`.
- **23:** `content_keys.dart`, `content_defaults.json` only. No credits function is touched.
- **24:** `edit_meal_log_screen.dart`, `meal_component_editor.dart` (item 26).
- **26:** `app_router.dart` (item 7); `recent_saved_picker_screen.dart` (item 22 edits it, then 26 archives it);
  `log_meal_screen.dart`, `edit_meal_log_screen.dart`, `manual_log_form.dart`, `manual_component_form.dart`,
  `log_sheet_helpers.dart`, `coming_soon_section_widget.dart`, `macro_dashboard_screen.dart` (26 edits comments
  there); `meal_weather_ai_coach_content_test.dart`.
- **27:** `app_router.dart`, `log_meal_screen.dart`, `edit_meal_log_screen.dart`, `meal_weather_ai_coach_content_test.dart`.
- **28:** `events_list_screen.dart`, `tabs_screen.dart`, `root_app_widget.dart` (item 33),
  `events_list_new_event_clears_tab_bar_test.dart` (item 18; 28 then drops it).
- **25:** none.

Size: about 45 commits across about 200 files. **Suggestion for the lead:** split by area into sequential agents
inside this one ticket (auth → onboarding → settings and integrations → Garmin backend → events → meal logging →
timeline → learn and dev tools). Nearly every commit appends to `content_keys.dart` and `content_defaults.json`,
so the agents can't run in parallel.

Deploy (wave lead, dev, after merge): discard-signup (new); delete-user; garmin-user-mapping, garmin-backfill,
garmin-push, garmin-ping, garmin-deregistration; generate-nutrition-plan-v3, generate-macros-v4. Same names,
inputs and outputs: overwrite in place (playbook §6). Prod: the `meal_logs.servings` migration and the
`app_config` bump are owed at cutover, at Xuan's direction.

- [x] Each item lands with the test(s) it names, ported from mealplanning. `flutter test` on those files is
      green, and codegen ran after the Riverpod and Drift changes (items 5, 7, 13, 21, 25, 30, 31).
- [x] Deno: `deno test --allow-all --allow-sys supabase/functions/_shared/garmin supabase/functions/_shared/nutrition supabase/functions/delete-user supabase/functions/garmin-push supabase/functions/garmin-user-mapping supabase/functions/discard-signup`
      is green. The fuelling vectors in `docs/ssot/vectors/` are green (items 15, 30).
      (Ran with `--allow-all` alone, since Deno rejects it with `--allow-sys`: 225 passed, 0 failed.
      Vectors: run-algorithm-tests.sh 100/100 after item 30. See `runs/29/notes.md`.)
- [ ] `grep -rniE "vana|paywall|subscription|kroger|shopping|meal_plan|redeem|is_admin" $(git diff --name-only f2e8576e)`
      shows nothing new beyond what HEAD already had.
      (Open, for the lead: 18 new hits after the `mealvana` package name. All are comments about what
      stayed behind, OneSignal's push `subscription`, or Dart's `StreamSubscription`. The one real
      leftover was fixed. List in `runs/29/notes.md`.)
- [ ] `flutter analyze` is clean. `/security-review` is run on discard-signup and delete-user.
      (analyze: 0 errors, no issue new since `ab437b7d`. `/security-review` has not been run; the lead owes it.)
      `/design-sync` is owed for items 17, 30 and 32 (Lee runs it).
- [x] The commit body lists each item's mealplanning sha and its verdict (clean / near-clean / hand), and every
      item skipped with its reason.
