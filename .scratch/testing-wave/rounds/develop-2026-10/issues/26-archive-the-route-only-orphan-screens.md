# 26: Archive the route-only orphan screens

**Status:** in-progress (wave 2b, 2026-10-07)
**Labels:** fix, round:develop-2026-10, area:navigation
**Branch:** `develop-next` (fix-wave worktree)
**Blocked by:** 29 (runs first and alone; see Overlaps)
**Next:** `/testing-wave develop-2026-10` (fix wave)
**Model:** opus

**What to build:** Lee ruled (TRIAGE 08-003, 08-004, 08-005, 08-010, 08-011, 08-012, 08-014, 2026-10-07): comment
out the routes and move the screens to `_archived`, never delete, "carefully: mealplanning and a paywall are
coming, so /pro will likely be needed again". The never-built classes (`ROUND/issues/README.md`, "No way in at
all") go the same way. All from code at `f2e8576e`.

**The archive convention** (how this repo already does it):
- Dart: `lib/features/_archived/<feature>/<same sub-path>`, as `lib/features/_archived/user_journal/` did
  (`1162c69c`). `analysis_options.yaml:14` excludes `lib/features/_archived/**`, so archived files are not
  analysed or compiled.
- Tests: retired tests go under the root `_archived/` (`_archived/test/`, `_archived/integration_test/`,
  excluded at `analysis_options.yaml:16`). This ticket **deletes** tests that only test an archived screen
  (listed per item). Tests mixed into shared smoke files lose only their block.
- Routes: comment the `GoRoute` out where it stands, with one line above it:
  `// ARCHIVED 2026-10-07 (round develop-2026-10, ticket 26): screen at lib/features/_archived/<path>; restore by moving it back and uncommenting.`
  Comment out its `import` the same way (an unused import is an analyzer warning). Never delete the block.
- In each moved file, rewrite relative imports (`../../../…`) to `package:mealvana_endurance/…` imports, so
  restoring `/pro` later is a file move plus an uncomment. The analyzer won't check archived files, so get
  this right by hand.

Method for every screen below: `grep -rnw <Class> lib test integration_test` and
`grep -rln <file>.dart lib test integration_test` (results shown). No screen file exports a widget that a kept
file imports: every importer is `app_router.dart` or a test. So each file moves whole, and no shared widget
needs moving to a kept file.

**Routes** (`lib/shared/core/app_router.dart`)

1. **`/pro` → `ProVersionScreen` (08-003, 08-010).** Route `:613-618`, import `:68`. File
   `lib/features/pro_version/presentation/screens/pro_version_screen.dart` (320 lines; `ProVersionScreen`,
   `_FeatureCard`) → `lib/features/_archived/pro_version/presentation/screens/pro_version_screen.dart`. The
   feature folder holds only this file, so `lib/features/pro_version/` disappears. Grep: router `:617`,
   `test/smoke_tests/misc_smoke_test.dart:16-17`, and a comment in
   `lib/features/education/presentation/widgets/coming_soon_section_widget.dart:5` ("matching ProVersionScreen's
   _FeatureCard pattern"). Point that comment at the archived path. Test: delete the `ProVersionScreen renders
   without overflow` block and its import from `misc_smoke_test.dart`.
2. **`/settings/sport-settings` → `SportSettingsScreen` (08-004, 08-005, 08-011).** Route `:662-667`, import
   `:35`. `lib/features/settings/presentation/screens/sport_settings_screen.dart` (635 lines) →
   `lib/features/_archived/settings/presentation/screens/`. Grep: router `:666`; the only push is
   `settings_menu_screen.dart:61`, which is archived in item 11. `test/features/settings/sport_details_live_surface_test.dart:4`
   only names it in a comment (stays). Test: delete block §4 `SportSettingsScreen builds without crash`
   (`test/smoke_tests/settings_smoke_test.dart:153-175`) and import `:21`.
3. **`/settings/food-preferences-consolidated` → `FoodSettingsConsolidatedScreen` (08-003, 08-012).** Route
   `:711-716` (its comment already says "DEPRECATED"), import `:39`.
   `lib/features/settings/presentation/screens/food_settings_consolidated_screen.dart` (530 lines) →
   `lib/features/_archived/settings/presentation/screens/`. Grep: router `:715`, `settings_smoke_test.dart:238-248`.
   Test: delete block §9 and import `:26`.
4. **`/settings/food-preferences/add-food` → `AddFoodScreen` (08-012).** Route `:765-770`, import `:57`.
   `lib/features/barcode_scanning/presentation/screens/add_food_screen.dart` (829 lines) →
   `lib/features/_archived/barcode_scanning/presentation/screens/`. Grep: router `:769`,
   `test/smoke_tests/food_smoke_test.dart:17-18`. Comment-only mentions stay: `foods_dao.dart:243`,
   `test/features/user_foods/duplicate_client_food_id_test.dart`, `test/shared/database/daos/foods_dao_client_food_id_dedup_test.dart`.
   Those tests exercise the DAO, not the screen, and stay. Test: delete the `AddFoodScreen renders` block and its
   import from `food_smoke_test.dart`.
5. **`/meal-log/manual` → `ManualLogScreen` (08-004, 08-014).** Route `:1018-1022`, import `:83`.
   `lib/features/meal_logging/presentation/screens/manual_log_screen.dart` (65 lines) →
   `lib/features/_archived/meal_logging/presentation/screens/`. It is a thin shell over `ManualLogForm`
   (`widgets/manual_log_form.dart`), which the sheet (`log_meal_screen.dart`) and `build_meal_screen.dart`
   import. The form stays where it is. Update the doc comments that name the screen:
   `widgets/manual_log_form.dart:17`, `widgets/manual_component_form.dart:12` ("still used by the standalone
   `ManualLogScreen` route"), `screens/edit_meal_log_screen.dart:38`. Tests: delete `ManualLogScreen builds`
   (`test/smoke_tests/events_meal_logging_smoke_test.dart:204-208`) and group 4 `ManualLogScreen — content and
   validation` (`test/seeded_tests/events_meal_logging_content_test.dart:721-~850`, plus header line `:11`), and
   their imports.
6. **`/meal-log/photo` → `PhotoCaptureScreen` (08-004, 08-014).** Route `:1024-1028`, import `:84`.
   `photo_capture_screen.dart` (341 lines) → `lib/features/_archived/meal_logging/presentation/screens/`. Grep:
   router `:1027`, `events_meal_logging_smoke_test.dart:210-215`. Delete that block and its import.
7. **`/meal-log/describe` → `DescribeMealScreen` (08-004, 08-014).** Route `:1030-1034`, import `:85`.
   `describe_meal_screen.dart` (287 lines) → same archive folder. Grep: router `:1033`, a comment in
   `log_meal_screen.dart:1881` ("DescribeMealScreen carries the same pair"; reword to stand alone),
   `events_meal_logging_smoke_test.dart:218-221`. Delete that block and its import.
8. **`/meal-log/recent-saved` → `RecentSavedPickerScreen` (08-004, 08-014).** Route `:1042-1046`, import `:87`.
   `recent_saved_picker_screen.dart` (407 lines) → same folder. Comment mentions to reword:
   `log_meal_screen.dart:808`, `widgets/log_sheet_helpers.dart:2`. Tests: delete
   `events_meal_logging_smoke_test.dart:233-239`, and groups 1 and 1b (`RecentSavedPickerScreen — Saved tab`,
   `— Recent tab`, `test/seeded_tests/meal_weather_ai_coach_content_test.dart:287-~470`, header line `:7`), with
   their imports.
9. **`/meal-log/recipe` → `RecipePickerScreen` (08-004, 08-014).** Route `:1048-1052`, import `:88`.
   `recipe_picker_screen.dart` (472 lines) → same folder. Tests: delete
   `events_meal_logging_smoke_test.dart:242-246`, group 2 of `meal_weather_ai_coach_content_test.dart:488-~660`
   (header `:8`), and the whole file `test/features/meal_logging/recipe_picker_eaten_at_test.dart`. That file is
   the regression test for bug 3a3e3fdb (eatenAt on a back-dated recipe) on the standalone screen. The sheet's
   recipe path (`log_meal_screen.dart:372` `_quickLogRecipe` → `logRecipe`) is covered by
   `test/features/meal_logging/quick_log_confirm_sheet_eaten_at_test.dart`, so nothing is lost. Confirm that
   file still runs green.
10. **The redirect guard.** `app_router.dart:132-137` sends `/meal-log/photo`, `/meal-log/describe`, `/jade`
    and `/buy-credits` to `/` when `describeMealEnabled` is off. Drop the two `/meal-log/*` lines. They match no
    route now. Leave `/jade` to ticket 27 and `/buy-credits` as is. A stale deep link to any commented-out
    path now lands on the router's `errorBuilder` ("Page Not Found", `:1064`). That is expected.

**Never-built classes** (no route, no constructor in `lib/`; README "No way in at all")

11. **`SettingsMenuScreen`.** `lib/features/settings/presentation/screens/settings_menu_screen.dart` (179
    lines) → `lib/features/_archived/settings/presentation/screens/`. Grep: only
    `settings_smoke_test.dart:333-339` (§15) and import `:18`. Delete both.
12. **`CoachDashboardScreen`, `AthleteDetailScreen`.** `lib/features/coach_mode/presentation/screens/coach_dashboard_screen.dart`
    (322) and `athlete_detail_screen.dart` (804) → `lib/features/_archived/coach_mode/presentation/screens/`.
    Grep: only `test/smoke_tests/coach_formula_smoke_test.dart` (header `:6`, `:44` comment, blocks `:237-~250`
    and `:253-~275`). Delete both blocks and their imports. Leave the calendar-provider fixture at `:44` if
    other blocks still use it.
13. **`CyclingInputScreen`, `SwimmingInputScreen`.** `lib/features/nutrition_plan/presentation/screens/cycling_input_screen.dart`
    (775) and `swimming_input_screen.dart` (865) → `lib/features/_archived/nutrition_plan/presentation/screens/`.
    Grep: only `test/smoke_tests/nutrition_plan_smoke_test.dart:208-213`. Delete both blocks and their imports.
14. **`RecipesScreen`.** `lib/features/recipes/presentation/screens/recipes_screen.dart` (462) →
    `lib/features/_archived/recipes/presentation/screens/`. The rest of `lib/features/recipes/` (service,
    repository, domain) is used by the sheet and stays. Grep: only `test/smoke_tests/auth_misc_smoke_test.dart`
    (header `:6`, `:17`, block `:232-236`). Delete the block and its import.
15. **`ShareNutritionPlanScreen`.** `lib/features/sharing/presentation/screens/share_nutrition_plan_screen.dart`
    (420) → `lib/features/_archived/sharing/presentation/screens/`. Grep: only `auth_misc_smoke_test.dart`
    (header `:6`, block `:241-~250`). Delete the block and its import. After the move, `share_form_controller`
    (+`.g.dart`) has no caller outside `lib/features/sharing/`. `pdf_generator_service` and `email_service` are
    still referenced by `test/features/sharing_and_barcode_domain_test.dart` (unverified whether they have any
    caller in `lib/`). Leave the sharing application layer in place and note the dead code in the commit
    body. It is outside this ruling.
16. **`MacroDashboardScreen`: NOT archived, it can't be separated cleanly.** The class is mounted nowhere, but it
    carries the Body's implementation. `MacroDashboardBody._layout` (`macro_dashboard_screen.dart:1478`) does
    `const screen = MacroDashboardScreen();` and calls `screen._dayWorkouts`, `screen._railRow` and
    `MacroDashboardScreen._dockGap` (`:1509`). The ~1,300 lines of `_pinnedBlockContent`/`_railRow`/brick code
    live on the screen class. `test/features/macro_dashboard/macro_dashboard_screen_test.dart` (`:251`, `:277`,
    `:522`, `:614`), `macro_dashboard_brick_test.dart:122` and `test/features/home_shell/home_shell_gestures_test.dart`
    pump `MacroDashboardScreen` directly. Removing the class means moving those methods into
    `_MacroDashboardBodyState` or a helper and rewriting three test files. That is a refactor, not an archive.
    Leave it, and add one line to the class doc saying it is the Body's method host and is not mounted.
    `integration_test/flows/brick_plan_flow_test.dart:111` and `macro_dashboard_flow_test.dart:92` mention it
    in comments only.

**Not in this ticket:** `/buy-credits` (08-004 lists it among the seven; it is ticket 23's), `/athlete/feedback`
(08-013, Lee: not archived), `/jade` (ticket 27). `docs/testing-wave/COVERAGE.md:33` is the lead's ledger.

**Findings:** 08-003, 08-004 (all but `/buy-credits`), 08-005, 08-010, 08-011, 08-012, 08-014.

**Decisions:** Lee, 2026-10-07 (TRIAGE): comment out, move to `_archived`, never delete; `/pro` will be needed
again. This ticket: tests that only exercise an archived screen are deleted (the root `_archived/test/` is the
alternative if the lead prefers to keep them). `MacroDashboardScreen` stays (item 16).

**Touches:** lib/shared/core/app_router.dart;
moved (old → `lib/features/_archived/…` same sub-path): lib/features/pro_version/presentation/screens/pro_version_screen.dart,
lib/features/settings/presentation/screens/{sport_settings_screen.dart,food_settings_consolidated_screen.dart,settings_menu_screen.dart},
lib/features/barcode_scanning/presentation/screens/add_food_screen.dart,
lib/features/meal_logging/presentation/screens/{manual_log_screen.dart,photo_capture_screen.dart,describe_meal_screen.dart,recent_saved_picker_screen.dart,recipe_picker_screen.dart},
lib/features/coach_mode/presentation/screens/{coach_dashboard_screen.dart,athlete_detail_screen.dart},
lib/features/nutrition_plan/presentation/screens/{cycling_input_screen.dart,swimming_input_screen.dart},
lib/features/recipes/presentation/screens/recipes_screen.dart,
lib/features/sharing/presentation/screens/share_nutrition_plan_screen.dart;
comments only: lib/features/education/presentation/widgets/coming_soon_section_widget.dart,
lib/features/meal_logging/presentation/widgets/{manual_log_form.dart,manual_component_form.dart,log_sheet_helpers.dart},
lib/features/meal_logging/presentation/screens/{edit_meal_log_screen.dart,log_meal_screen.dart},
lib/features/macro_dashboard/presentation/screens/macro_dashboard_screen.dart;
tests edited: test/smoke_tests/{misc_smoke_test.dart,settings_smoke_test.dart,food_smoke_test.dart,events_meal_logging_smoke_test.dart,coach_formula_smoke_test.dart,nutrition_plan_smoke_test.dart,auth_misc_smoke_test.dart},
test/seeded_tests/{events_meal_logging_content_test.dart,meal_weather_ai_coach_content_test.dart};
test deleted: test/features/meal_logging/recipe_picker_eaten_at_test.dart.
No generated file changes: none of the moved screens has a `.g.dart`.

**Overlaps:** 27 (`app_router.dart`: the redirect guard at `:132-135` and the import and route blocks;
`test/smoke_tests/auth_misc_smoke_test.dart`; `test/seeded_tests/meal_weather_ai_coach_content_test.dart`;
`describe_meal_screen.dart` and `photo_capture_screen.dart`, whose `ai_thinking_status` import 27 would
otherwise repoint). Run 26 and 27 in one agent, or 26 first and then 27 on top. With 26 first, 27 leaves the
two archived screens' imports alone. 24 (`edit_meal_log_screen.dart`, a comment line here). 29 (`app_router.dart`; `recent_saved_picker_screen.dart`, which
29 item 22 edits before this ticket archives it; the comment-only files `log_meal_screen.dart`,
`edit_meal_log_screen.dart`, `manual_log_form.dart`, `manual_component_form.dart`, `log_sheet_helpers.dart`,
`coming_soon_section_widget.dart`, `macro_dashboard_screen.dart`; `meal_weather_ai_coach_content_test.dart`). 29 runs
first. Re-read line numbers after it lands.

- [x] For every class above, `grep -rnw <Class> lib test integration_test` returns no constructor or import
      outside `lib/features/_archived/`, except `MacroDashboardScreen`, which stays.
- [x] `grep -nE "path: '/(pro|settings/sport-settings|settings/food-preferences-consolidated|settings/food-preferences/add-food|meal-log/(manual|photo|describe|recent-saved|recipe))'" lib/shared/core/app_router.dart`
      shows each only on a commented-out line, under its `ARCHIVED 2026-10-07` note.
- [x] `flutter analyze` clean.
- [x] The edited test files and `quick_log_confirm_sheet_eaten_at_test.dart` are green. The lead runs the full
      suite after merge (fix-wave rule).
- [ ] Optional retest (ticket 32 or the wave lead): deep-link `/pro` and `/meal-log/manual`. Each lands on
      "Page Not Found".
