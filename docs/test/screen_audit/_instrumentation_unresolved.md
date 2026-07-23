# Instrumentation Unresolved Items

Items where the proposed README key could not be applied, with reasons.

---

## Key conflicts (existing key used instead of README proposal)

| README proposed key | Actual key used | Reason |
|---|---|---|
| `brick.back_button` | `activity_create.back_button` | `new_activity_app_bar.dart` already had this key from area 06 |
| `brick.title` | `activity_create.title` | Same as above |
| `brick.generate_plan_button` | `activity_create.generate_plan_button` | `new_activity_screen.dart` already had this key |
| `brick.datetime_labels` | `activity_create.datetime_labels` | `new_activity_date_time_section.dart` already had this key from area 06 |
| `brick.datetime_display` | `activity_create.datetime_display` | Same |
| `brick.edit_datetime_button` | `activity_create.edit_datetime_button` | Same |
| `dietary_edit.*` / `allergies_edit.*` | `dietary_preference.*` / `allergies.*` | The dietary and allergies screens reuse the onboarding screens (ScreenMode.settings); keys from area 02 already applied |

---

## Internal widget keys — not accessible from call site

| README proposed key | Widget | Reason |
|---|---|---|
| `brick.fueling_window_heading` | Label `Text` inside `KylePlusMinusControl` | Internal to widget; outer widget keyed as `brick.fueling_window_control` instead |
| `brick.fueling_window_minus` | `_ControlButton` inside `KylePlusMinusControl` | Private class, no key forwarding; outer widget keyed instead |
| `brick.fueling_window_plus` | `_ControlButton` inside `KylePlusMinusControl` | Same |
| `brick.fueling_window_value` | Value `Text` inside `KylePlusMinusControl` | Same |
| `cycling_prefs.bottles_minus` | `_ControlButton` inside `KylePlusMinusControl` | Same; outer widget keyed as `cycling_prefs.bottles_control` |
| `cycling_prefs.bottles_plus` | Same | Same |
| `cycling_prefs.bottles_label` | Label `Text` inside `KylePlusMinusControl` | Same |
| `nutrition_targets.during_run_carbs_field` | `_buildField` inside `DuringSportOverrideSection` | No key param exposed on that shared widget; would need widget modification |
| `nutrition_targets.during_run_sodium_field` | Same | Same |
| `nutrition_targets.during_run_fluids_field` | Same | Same |
| `nutrition_targets.during_bike_*` | Same | Same |
| `nutrition_targets.during_swim_*` | Same | Same |

---

## Third-party widgets — not keyable from Flutter side

| README proposed key | Widget | Reason |
|---|---|---|
| `feedback.step_indicator` | Wiredash NPS survey overlay | Wiredash renders its own native overlay; no Flutter widget handle |
| `feedback.close_button` | Same | Same |
| `feedback.nps_title` | Same | Same |
| `feedback.nps_body` | Same | Same |
| `feedback.nps_score_<n>` | Same | Same |
| `feedback.return_to_app_handle` | Same | Same |
| `feedback.nps_step2_*` | Same | Same |
| `bug_report.*` | Wiredash bug report overlay | Same as above |
| `lesson.fullscreen_button` | Chewie player control | Chewie renders its own controls internally |
| `lesson.mute_button` | Same | Same |
| `lesson.play_button` | Same | Same |
| `lesson.progress_bar` | Same | Same |
| `lesson.elapsed_label` | Same | Same |
| `lesson.remaining_label` | Same | Same |
| `barcode.camera_frame` | `MobileScanner` native view | Native camera view; not a Flutter widget tree node |

---

## Widgets not found in codebase

| README proposed key | Reason |
|---|---|
| `learn.settings_button` | No settings gear button found in `education_screen.dart`; may be in a parent scaffold not modified by this PR |

---

## Enum-based key naming divergence

The following README key names use human-readable labels while actual keys use Dart enum names. Patrol tests should use the actual keys below:

| README proposed key | Actual key |
|---|---|
| `nutrition_profile.activity_desk_button` | `nutrition_profile.activity_desk_button` (matches — `desk`) |
| `nutrition_profile.activity_very_active_button` | `nutrition_profile.activity_veryActive_button` (Dart enum is `veryActive`) |
| `nutrition_profile.phase_race_week_button` | `nutrition_profile.phase_raceWeek_button` (Dart enum is `raceWeek`) |
| `nutrition_profile.phase_off_season_button` | `nutrition_profile.phase_offSeason_button` (Dart enum is `offSeason`) |
