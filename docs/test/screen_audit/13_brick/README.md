# 13 Brick

Brick workout (multi-discipline) creation flow.

---

## brick_create
**Screenshot:** `screenshots/01_brick_create.png`, `screenshots/02_brick_scrolled.png`
**Reached by:** Calendar → FAB **+** → tap **BRICK** tab.

### Visible elements
| Role             | Label / Text                          | mobile-mcp coords  | Proposed ValueKey                          |
|------------------|---------------------------------------|--------------------|--------------------------------------------|
| Button (back)    | Arrow circle                          | (4, 63)            | `brick.back_button`                        |
| Heading          | "Create New Activity Plan"            | center             | `brick.title`                              |
| Tab              | RUNNING                               | (20, 135, 80x80)   | `activity_create.tab_running`              |
| Tab              | BIKING                                | (112, 135, 80x80)  | `activity_create.tab_biking`               |
| Tab              | SWIMMING                              | (204, 135, 80x80)  | `activity_create.tab_swimming`             |
| Tab (selected)   | BRICK                                 | (296, 135, 80x80)  | `activity_create.tab_brick`                |
| Hero image       | Swimmer + Runner composite            | (32, 230)          | (decorative)                               |
| Label            | "DATE / TIME"                         | row                | `brick.datetime_labels`                    |
| Label            | "May 12, 2026 / 5:15 pm"              | row                | `brick.datetime_display`                   |
| Link             | "Edit"                                | center             | `brick.edit_datetime_button`               |
| Field            | "Workout Name" (default "SWIMMING/RUNNING BRICK") | (20, 593, 390x54) | `brick.workout_name_field` |
| Toggle (chip)    | SWIM (with swim icon)                 | (16, 660, 130x80)  | `brick.discipline_swim_chip`               |
| Toggle (chip)    | BIKE                                  | (148, 660, 130x80) | `brick.discipline_bike_chip`               |
| Toggle (chip)    | RUN (highlighted)                     | (282, 660, 130x80) | `brick.discipline_run_chip`                |
| Section heading  | "PRE-ACTIVITY FUELING WINDOW"         | scroll             | `brick.fueling_window_heading`             |

### Scrolled elements
| Role             | Label / Text                       | Proposed ValueKey                       |
|------------------|------------------------------------|-----------------------------------------|
| Stepper          | "-" / "+" around "30 MINUTES"      | `brick.fueling_window_minus` / `brick.fueling_window_plus` |
| Label            | "30 MINUTES"                        | `brick.fueling_window_value`            |
| Toggle           | "Fasted Workout"                    | `brick.fasted_toggle`                   |
| Card             | "= 1. SWIM 30 MIN" (with reorder ⌘) | `brick.segment_card_<index>`            |
| Card             | "= 2. RUN 27 MIN"                   | `brick.segment_card_<index>`            |
| Label            | "TOTAL DURATION: 57 MINUTES"        | `brick.total_duration_label`            |
| Button (primary) | "Generate Plan"                     | `brick.generate_plan_button`            |

### Notes
- Each segment card has:
  - A reorder handle (=) → `brick.segment_reorder_<index>`.
  - An expand chevron (▼) → `brick.segment_expand_<index>`.
  - Discipline icon + ordinal + label + duration.
- Default brick is **2-discipline (SWIM + RUN)** with 30+27 min. Bike can be added by tapping the BIKE chip.
- Discipline chips toggle which segments appear in the workout (multi-select, ordered).
