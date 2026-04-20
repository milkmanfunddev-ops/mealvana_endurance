# Responsiveness Architecture

## Purpose
Define one canonical, project-wide responsive architecture so all active app screens work on:
- Small phones (compact + short-height)
- Standard phones
- iPad portrait/landscape
- Desktop/web expanded layouts
- Coach portal full-width desktop mode

This document is the source of truth for responsive layout decisions, migration waves, and QA acceptance.

## Non-Goals
- Re-designing visual language or component styling.
- Replacing `flutter_screenutil` globally.
- Migrating archived screens unless intentionally revived.

## Canonical Breakpoints and Size Classes
Use window size, never device type.

### Width classes
- `compact`: `< 600`
- `medium`: `>= 600 && < 1200`
- `expanded`: `>= 1200 && < 1600`
- `large`: `>= 1600`

### Height classes
- `short`: `< 700`
- `regular`: `>= 700 && < 900`
- `tall`: `>= 900`

### Rules
- Branch layout by width/height classes and constraints, not hardware labels.
- Keep coach portal as explicit full-bleed exception.
- Preserve existing large-screen behavior unless fixing a bug.

## Standard Page Composition
Use the shared primitives in `lib/shared/widgets/adaptive/`:
- `AdaptivePageScaffold`: standard constrained/full-bleed page wrapper.
- `AdaptiveScrollableBody`: `LayoutBuilder -> SingleChildScrollView -> ConstrainedBox(minHeight)`.
- `AdaptiveSpacing`: compact-height spacing helpers.

Recommended structure for form/detail/onboarding pages:
1. `AdaptivePageScaffold(contentWidth: narrow|standard|wide)`
2. `AdaptiveScrollableBody(padding: ...)`
3. Optional footer CTA pinned with safe-area handling.

## Approved Primitives and Anti-Patterns
### Approved
- `MediaQuery.sizeOf(context)` and/or local `LayoutBuilder` constraints.
- `ContentArea` for width constraints.
- Scroll-safe bodies with min-height constrained scroll view.
- `flutter_screenutil` for fine-grained spacing/typography only.

### Anti-patterns
- Top-level fixed vertical stacks that can overflow on short phones.
- Device-type checks (`phone/tablet/desktop`) for layout branching.
- Orientation-only branching at top-level layout.
- Full-width text/form content on large screens when constrained content is expected.

## Screen Migration Matrix
Status values:
- `active`: in mandatory migration scope.
- `legacy`: non-archived but currently unreferenced.
- `archived`: inventory only.

Progress snapshot (`2026-03-31`):
- Wave 1 migrated in code:
  `force_upgrade_screen.dart`, `welcome_screen.dart`, `sports_selection_screen.dart`,
  `user_profile_screen.dart`, `dietary_preference_screen.dart`, `allergies_screen.dart`,
  `running_details_screen.dart`, `cycling_details_screen.dart`, `swimming_details_screen.dart`,
  `food_preferences_v2_screen.dart`, `post_onboarding_auth_screen.dart`,
  `email_signup_screen.dart`, `email_login_screen.dart`, `forgot_password_screen.dart`,
  `verify_reset_code_screen.dart`, `set_new_password_screen.dart`.
- Wave 2 migrated in code:
  `settings_screen.dart`, `food_preferences_hub_screen.dart`,
  `sport_preferences_hub_screen.dart`, `help_feedback_screen.dart`.
- Remaining screens in Waves 2–4 and Wave L are still pending migration.

### Wave 1 (foundation + highest-risk entry flows)
- `active` `lib/features/app_startup/presentation/screens/force_upgrade_screen.dart`
- `active` `lib/features/onboarding/presentation/screens/welcome_screen.dart`
- `active` `lib/features/onboarding/presentation/screens/onboarding_pageview_screen.dart`
- `active` `lib/features/onboarding/presentation/screens/sports_selection_screen.dart`
- `active` `lib/features/onboarding/presentation/screens/user_profile_screen.dart`
- `active` `lib/features/onboarding/presentation/screens/dietary_preference_screen.dart`
- `active` `lib/features/onboarding/presentation/screens/allergies_screen.dart`
- `active` `lib/features/onboarding/presentation/screens/running_details_screen.dart`
- `active` `lib/features/onboarding/presentation/screens/cycling_details_screen.dart`
- `active` `lib/features/onboarding/presentation/screens/swimming_details_screen.dart`
- `active` `lib/features/onboarding/presentation/screens/food_preferences_v2_screen.dart`
- `active` `lib/features/auth/presentation/screens/post_onboarding_auth_screen.dart`
- `active` `lib/features/auth/presentation/screens/email_signup_screen.dart`
- `active` `lib/features/auth/presentation/screens/email_login_screen.dart`
- `active` `lib/features/auth/presentation/screens/forgot_password_screen.dart`
- `active` `lib/features/auth/presentation/screens/verify_reset_code_screen.dart`
- `active` `lib/features/auth/presentation/screens/set_new_password_screen.dart`

### Wave 2 (core app shell/settings/navigation)
- `active` `lib/features/activities/presentation/screens/activities_list_screen.dart`
- `active` `lib/features/daily_macros/presentation/screens/daily_macros_screen.dart`
- `active` `lib/features/events/presentation/screens/events_list_screen.dart`
- `active` `lib/features/education/presentation/screens/education_screen.dart`
- `active` `lib/features/settings/presentation/screens/settings_screen.dart`
- `active` `lib/features/settings/presentation/screens/preferences_screen.dart`
- `active` `lib/features/settings/presentation/screens/nutrition_profile_screen.dart`
- `active` `lib/features/settings/presentation/screens/nutrition_targets_screen.dart`
- `active` `lib/features/settings/presentation/screens/food_preferences_hub_screen.dart`
- `active` `lib/features/settings/presentation/screens/sport_preferences_hub_screen.dart`
- `active` `lib/features/settings/presentation/screens/food_settings_consolidated_screen.dart`
- `active` `lib/features/settings/presentation/screens/food_preferences_screen.dart`
- `active` `lib/features/settings/presentation/screens/sport_settings_screen.dart`
- `active` `lib/features/settings/presentation/screens/help_feedback_screen.dart`
- `active` `lib/features/settings/presentation/screens/connected_apps_screen.dart`
- `active` `lib/features/settings/presentation/screens/coach_connection_screen.dart`
- `active` `lib/features/settings/presentation/screens/debug_screen.dart`

### Wave 3 (core nutrition/activity/event/weather/barcode)
- `active` `lib/features/nutrition_plan/presentation/screens/new_activity_screen.dart`
- `active` `lib/features/nutrition_plan/presentation/screens/activity_detail_screen.dart`
- `active` `lib/features/nutrition_plan/presentation/screens/adjust_macros_screen.dart`
- `active` `lib/features/nutrition_plan/presentation/screens/fuel_log_screen.dart`
- `active` `lib/features/nutrition_plan/presentation/screens/swap_food_screen.dart`
- `active` `lib/features/events/presentation/screens/event_form_screen.dart`
- `active` `lib/features/events/presentation/screens/event_detail_screen.dart`
- `active` `lib/features/barcode_scanning/presentation/screens/barcode_scanner_screen.dart`
- `active` `lib/features/barcode_scanning/presentation/screens/add_food_screen.dart`
- `active` `lib/features/weather/presentation/screens/weather_detail_screen.dart`
- `active` `lib/features/settings/presentation/screens/weather_detail_screen.dart`
- `active` `lib/shared/screens/food_detail_screen.dart`

### Wave 4 (secondary active flows)
- `active` `lib/features/carb_loading/presentation/screens/carb_loading_protocol_selection_screen.dart`
- `active` `lib/features/calendar/presentation/screens/carb_loading_protocol_selection_screen.dart`
- `active` `lib/features/carb_loading/presentation/screens/carb_loading_day_detail_page.dart`
- `active` `lib/features/carb_loading/presentation/screens/carb_loading_food_selection_screen.dart`
- `active` `lib/features/carb_loading/presentation/screens/create_custom_carb_loading_food_screen.dart`
- `active` `lib/features/coach_mode/presentation/screens/coach_portal_screen.dart`
- `active` `lib/features/coach_mode/presentation/screens/coach_registration_screen.dart`
- `active` `lib/features/coach_mode/presentation/screens/coach_directory_screen.dart`
- `active` `lib/features/coach_mode/presentation/screens/my_coaches_screen.dart`
- `active` `lib/features/coach_mode/presentation/screens/athlete_feedback_screen.dart`
- `active` `lib/features/coach_mode/presentation/screens/coach_chat_screen.dart`
- `active` `lib/features/education/presentation/screens/video_player_screen.dart`
- `active` `lib/features/personal_templates/presentation/screens/personal_templates_screen.dart`
- `active` `lib/features/pro_version/presentation/screens/pro_version_screen.dart`
- `active` `lib/features/feedback/presentation/screens/survey_page_1.dart`
- `active` `lib/features/feedback/presentation/screens/survey_page_2.dart`

### Wave L (legacy audit, non-mandatory now)
- `legacy` `lib/features/calendar/presentation/screens/calendar_month_screen.dart`
- `legacy` `lib/features/carb_loading/presentation/screens/carb_loading_screen.dart`
- `legacy` `lib/features/coach_mode/presentation/screens/athlete_detail_screen.dart`
- `legacy` `lib/features/coach_mode/presentation/screens/coach_dashboard_screen.dart`
- `legacy` `lib/features/feedback/presentation/screens/survey_screen.dart`
- `legacy` `lib/features/nutrition_plan/presentation/screens/current_plan_screen.dart`
- `legacy` `lib/features/nutrition_plan/presentation/screens/cycling_input_screen.dart`
- `legacy` `lib/features/nutrition_plan/presentation/screens/swimming_input_screen.dart`
- `legacy` `lib/features/onboarding/presentation/screens/sport_preferences_screen.dart`
- `legacy` `lib/features/recipes/presentation/screens/recipes_screen.dart`
- `legacy` `lib/features/settings/presentation/screens/settings_menu_screen.dart`
- `legacy` `lib/features/sharing/presentation/screens/share_nutrition_plan_screen.dart`

### Wave A (archived inventory only)
- `archived` `lib/features/_archived/user_journal/presentation/screens/plan_how_well_screen.dart`
- `archived` `lib/features/_archived/user_journal/presentation/screens/voice_memo_screen.dart`
- `archived` `lib/features/_archived/user_journal/presentation/screens/voice_notes_list_screen.dart`

## QA Matrix and Acceptance Criteria
For each migrated active screen, verify:
1. Small phone portrait (compact + short)
2. Standard phone portrait
3. iPad portrait
4. iPad landscape
5. Desktop/web expanded
6. Coach portal full-width desktop (coach routes)

Acceptance criteria:
- No `RenderFlex overflow` warnings.
- Primary CTA visible and tappable.
- Inputs and keyboard interactions remain functional.
- Scroll behavior remains usable and predictable.
- No desktop/iPad regressions in width constraints or navigation patterns.

## Responsive Verification Harness
### Automated checks
- Add widget smoke tests for critical entry screens at multiple surface sizes.
- Capture and assert no overflow-related Flutter errors in tests.

### Manual checklist
- Maintain per-wave screenshot checklist for before/after comparisons.
- Record regressions and fixes in wave-level tracking notes.

### Merge gate
- No known overflow regressions in targeted responsive tests for migrated screens.

## Rollout and Regression Process
1. Ship shared primitives first (no broad behavior change).
2. Migrate screens wave-by-wave.
3. Run responsive smoke tests + manual screenshot pass for that wave.
4. Merge only when wave acceptance criteria pass.
5. Revisit `Wave L` and `Wave A` only when those screens are revived or re-routed.
