# Instrumentation Summary

All 14 screen audit areas have been processed. Every proposed `ValueKey` from each area README has been applied where technically feasible.

---

## Scope

- **14 areas** covering the full Mealvana Endurance screen inventory
- **~400+ keys** added across the Flutter widget tree
- **Zero new analyzer errors** introduced (baseline: 2046 pre-existing info/warnings throughout)
- All changes are `lib/`-only — no test files, no generated files, no commits

---

## Files modified

### Features / Presentation

| File | Keys added |
|---|---|
| `lib/features/auth/presentation/screens/sign_in_screen.dart` | `sign_in.*` |
| `lib/features/auth/presentation/screens/sign_up_screen.dart` | `sign_up.*` |
| `lib/features/onboarding/presentation/screens/welcome_screen.dart` | `welcome.*` |
| `lib/features/onboarding/presentation/screens/sports_selection_screen.dart` | `sports_selection.*` |
| `lib/features/onboarding/presentation/screens/running_details_screen.dart` | `running_prefs.*` |
| `lib/features/onboarding/presentation/screens/cycling_details_screen.dart` | `cycling_prefs.*` |
| `lib/features/onboarding/presentation/screens/swimming_details_screen.dart` | `swimming_prefs.*` |
| `lib/features/onboarding/presentation/screens/dietary_preference_screen.dart` | `dietary_preference.*` |
| `lib/features/onboarding/presentation/screens/allergies_screen.dart` | `allergies.*` |
| `lib/features/onboarding/presentation/screens/nutrition_profile_screen.dart` | `nutrition_profile_onboarding.*` |
| `lib/features/nutrition_plan/presentation/screens/calendar_screen.dart` | `calendar.*` |
| `lib/features/nutrition_plan/presentation/screens/new_activity_screen.dart` | `activity_create.*` |
| `lib/features/nutrition_plan/presentation/widgets/new_activity/shared/new_activity_date_time_section.dart` | `activity_create.datetime_*` |
| `lib/features/nutrition_plan/presentation/widgets/new_activity/shared/activity_name_field.dart` | (widget accepts super.key) |
| `lib/features/nutrition_plan/presentation/widgets/new_activity/shared/fasted_toggle.dart` | `activity_create.fasted_toggle` |
| `lib/features/nutrition_plan/presentation/widgets/new_activity/brick/brick_sport_toggle_selector.dart` | `brick.discipline_*` |
| `lib/features/nutrition_plan/presentation/widgets/new_activity/brick/brick_tab_content.dart` | `brick.*` |
| `lib/features/nutrition_plan/presentation/screens/activity_detail_screen.dart` | `activity_detail.*` |
| `lib/features/daily_macros/presentation/screens/daily_macros_screen.dart` | `nutrition_diary.heading` |
| `lib/features/daily_macros/presentation/widgets/daily_summary_card.dart` | `nutrition_diary.daily_total_card` |
| `lib/features/daily_macros/presentation/widgets/macro_breakdown_row.dart` | `nutrition_diary.carbs_label / protein_label / fat_label` |
| `lib/features/daily_macros/presentation/widgets/energy_source_breakdown.dart` | `nutrition_diary.breakdown_*` |
| `lib/features/daily_macros/presentation/widgets/weekly_overview_chart.dart` | `weekly_chart.*` |
| `lib/features/settings/presentation/screens/settings_screen.dart` | `settings.*` |
| `lib/features/settings/presentation/screens/preferences_screen.dart` | `profile_edit.*` |
| `lib/features/settings/presentation/screens/sport_preferences_hub_screen.dart` | `sport_prefs.*` |
| `lib/features/settings/presentation/screens/food_preferences_hub_screen.dart` | `food_prefs.*` |
| `lib/features/settings/presentation/screens/food_preferences_screen.dart` | `food_likes.*` |
| `lib/features/settings/presentation/screens/nutrition_profile_screen.dart` | `nutrition_profile.*` |
| `lib/features/settings/presentation/screens/nutrition_targets_screen.dart` | `nutrition_targets.*` |
| `lib/features/settings/presentation/screens/coach_connection_screen.dart` | `coach_connection.*` |
| `lib/features/settings/presentation/screens/connected_apps_screen.dart` | `connected_apps.*` |
| `lib/features/settings/presentation/screens/help_feedback_screen.dart` | `help.*` |
| `lib/features/integrations/presentation/screens/connect_training_screen.dart` | `connect_training.*` |
| `lib/features/integrations/presentation/widgets/integration_provider_card.dart` | (key propagated) |
| `lib/features/barcode_scanning/presentation/screens/barcode_scanner_screen.dart` | `barcode.*` |
| `lib/features/education/presentation/screens/education_screen.dart` | `learn.*` |
| `lib/features/education/presentation/screens/video_player_screen.dart` | `lesson.*` |
| `lib/features/fuel_log/presentation/screens/fuel_log_screen.dart` | `fuel_log.*` |

### Shared widgets

| File | Keys added |
|---|---|
| `lib/shared/screens/food_detail_screen.dart` | `custom_food.*` |
| `lib/shared/widgets/food_detail/nutrition_input_fields.dart` | `custom_food.*` |
| `lib/shared/widgets/food_detail/category_selector.dart` | `custom_food.timing_*` |
| `lib/features/education/presentation/widgets/coming_soon_section_widget.dart` | `notifyButtonKey` param added |

---

## Patterns applied

- `const ValueKey(...)` for all compile-time constant strings
- `ValueKey(...)` (non-const) for runtime-computed strings (e.g. `'brick.segment_card_$index'`)
- `super.key` added to private widget classes (`_MacroChip`, `_BreakdownRow`, `_LegendItem`, `_SportToggleButton`, `_SectionHeader`, `_CompactVideoCard`) so call sites can pass a key
- Optional `Key?` params added to helper methods (`_buildHubTile`, `_buildSectionTitle`, `_buildTextField`, `_buildNutritionField`, `_buildCategoryCheckbox`, `_buildControlButton`, `_buildFeedbackOption`, `_buildBugReportOption`, `_buildContactOption`, `_buildRadioOption`, `_buildRadioTile`) to thread keys through without refactoring into separate widgets
- `keyPrefix` variable in `_buildComingSoonProviders` to produce `connect_training.*` vs `connected_apps.*` depending on mode

---

## Unresolved items

See `_instrumentation_unresolved.md` for full details. Summary:

- **Key conflicts**: 7 items where existing keys from earlier areas are used instead of README proposals (no change needed; existing keys work)
- **Internal widget keys**: 10 items inside `KylePlusMinusControl` / `DuringSportOverrideSection` that require internal widget refactoring — out of scope for this PR
- **Third-party overlays**: Wiredash (rate/bug-report) and Chewie (video controls) render native views; no Flutter widget tree handles available
- **Not found**: `learn.settings_button` not present in `education_screen.dart`

---

## Code generation

No Riverpod or Drift annotations were modified. Code generation (`flutter pub run build_runner build`) is NOT required for this PR.

---

## Recommended follow-up

1. Run `/task-checker` before merging to verify no regressions
2. For `KylePlusMinusControl` internal keys (`fueling_window_minus/plus/value`, `bottles_minus/plus/label`): add optional `minusKey`, `plusKey`, `valueKey` params to `KylePlusMinusControl` in a dedicated refactor ticket
3. For `DuringSportOverrideSection` during-sport field keys: expose `Key?` params from `_buildField` helper in a dedicated refactor ticket
