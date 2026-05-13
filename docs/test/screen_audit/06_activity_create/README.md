# 06 Activity Create

Activity (workout) creation flow. Triggered by the calendar **FAB (+)**.

---

## activity_create_run
**Screenshot:** `screenshots/01_create_run.png`, `screenshots/02_create_run_scrolled.png`, `screenshots/03_create_run_scrolled_more.png`
**Reached by:** Calendar → tap FAB **+** (orange).

### Visible elements
| Role             | Label / Text                  | mobile-mcp coords        | Proposed ValueKey                       |
|------------------|-------------------------------|--------------------------|-----------------------------------------|
| Button (back)    | Arrow circle                  | (4, 63, 48x48)           | `activity_create.back_button`           |
| Heading          | "Create New Activity Plan"    | center                   | `activity_create.title`                 |
| Tab (selected)   | RUNNING                       | (20, 135, 80x80)         | `activity_create.tab_running`           |
| Tab              | BIKING                        | (112, 135, 80x80)        | `activity_create.tab_biking`            |
| Tab              | SWIMMING                      | (204, 135, 80x80)        | `activity_create.tab_swimming`          |
| Tab              | BRICK                         | (296, 135, 80x80)        | `activity_create.tab_brick`             |
| Hero image       | Sport image (runner)          | (40, 230, 350x230)       | (decorative)                            |
| Label            | "DATE / TIME"                 | row at (149, 463)        | `activity_create.datetime_labels`       |
| Label            | "May 12, 2026 / 4:15 pm"      | row at (108, 487)        | `activity_create.datetime_display`      |
| Link             | "Edit" (date/time)            | (20, 521, 390x16)        | `activity_create.edit_datetime_button`  |
| Field            | "Workout Name" (text)         | (20, 593, 390x54) value `12 mi Run` (default) | `activity_create.workout_name_field` |
| Section heading  | "WORKOUT DETAILS"             | (20, 671, 131x18)        | `activity_create.details_heading`       |
| Field            | "Distance *"                  | (20, 731, 364x46) value `12.0` | `activity_create.distance_field` |
| Toggle           | "By Duration"                 | (20, 793, 195x9)         | `activity_create.by_duration_toggle`    |
| Toggle           | "By Pace"                     | (215, 793, 195x9)        | `activity_create.by_pace_toggle`        |
| Button (primary) | "Generate Plan"               | (20, 822, 390x56)        | `activity_create.generate_plan_button`  |

### Scrolled elements (below the fold)
| Role             | Label / Text                  | Proposed ValueKey                          |
|------------------|-------------------------------|--------------------------------------------|
| Field            | Estimated Duration hr         | `activity_create.duration_hr_field`        |
| Field            | Estimated Duration mins       | `activity_create.duration_mins_field`      |
| Section heading  | "INTENSITY"                   | `activity_create.intensity_heading`        |
| Toggle           | "ESTIMATE" / "PRECISE"        | `activity_create.intensity_mode_toggle`    |
| Slider           | Intensity slider              | `activity_create.intensity_slider`         |
| Chip             | "Easy Run"                    | `activity_create.intensity_easy_chip`      |
| Chip             | "Long Run"                    | `activity_create.intensity_long_chip`      |
| Chip             | "Tempo Run"                   | `activity_create.intensity_tempo_chip`     |
| Chip             | "Intervals"                   | `activity_create.intensity_intervals_chip` |
| Chip             | "Race Pace"                   | `activity_create.intensity_race_pace_chip` |
| Chip             | "Recovery Run"                | `activity_create.intensity_recovery_chip`  |
| Section heading  | "PRE-RUN FUELING WINDOW"      | `activity_create.fueling_window_heading`   |
| Stepper          | "-"                           | `activity_create.fueling_window_minus`     |
| Stepper          | "+"                           | `activity_create.fueling_window_plus`      |
| Label            | "1 HOUR 30 MIN"               | `activity_create.fueling_window_value`     |
| Toggle           | "Fasted Workout"              | `activity_create.fasted_toggle`            |
| Section heading  | "TEMPERATURE" (badge "AUTO")  | `activity_create.temperature_heading`      |
| Link             | "View Forecast"               | `activity_create.view_forecast_link`       |
| Stepper          | Temperature +/-               | `activity_create.temp_minus` / `temp_plus` |
| Label            | "57°F"                        | `activity_create.temp_value`               |
| Section heading  | "HUMIDITY" (badge "AUTO")     | `activity_create.humidity_heading`         |
| Stepper          | Humidity +/-                  | `activity_create.humidity_minus` / `humidity_plus` |
| Label            | "85 % HUMIDITY"               | `activity_create.humidity_value`           |

---

## activity_create_bike
**Screenshot:** `screenshots/04_create_bike.png`
**Reached by:** Tap **BIKING** tab.

### Visible elements
- Tabs identical, BIKING selected.
- Hero image is cyclist.
- Workout Name default: **"25 mi Ride"**, Distance default: **25.0** (still mi).
- All other widgets analogous to run; intensity chips would presumably differ (not exercised here).
- Proposed keys identical to run with `_bike` suffix where appropriate, but the core form is shared so `activity_create.*` keys remain stable across tabs.

---

## activity_create_swim
**Screenshot:** `screenshots/05_create_swim.png`
**Reached by:** Tap **SWIMMING** tab.

### Visible elements
- Hero image is swimmer.
- Workout Name default: **"2000 m Swim"**, Distance default: **2000.0** with unit `meters`.
- Distance unit auto-switches to meters when sport=Swim. Key: `activity_create.distance_unit_label` (read-only).

---

## activity_create_brick
**Screenshot:** `screenshots/06_create_brick.png`
**Reached by:** Tap **BRICK** tab. See `13_brick/README.md` for full Brick spec.

### Notes / observations
- Generate Plan navigates to `07_nutrition_plan/01_adjust_macros.png` (Adjust Your Macros).
- The "Edit" link near date/time opens a Material date picker.
- All sport tabs share the same scaffold; only the hero image, default Workout Name, and unit (mi/meters) differ.
- Date picker variant captured in `screenshots/07_date_picker.png` — Cupertino-style modal with CANCEL/OK buttons (orange OK at (364, 656, 49x41)).

### Variants
- **Date picker open** (`screenshots/07_date_picker.png`): Material calendar grid, "Select year" buttons at top, prev/next month arrows, CANCEL / OK at bottom right. Proposed keys: `activity_create.date_picker_cancel`, `activity_create.date_picker_ok`.
