# 07 Nutrition Plan

Activity-level nutrition plan generation and review.

---

## adjust_macros
**Screenshot:** `screenshots/01_adjust_macros.png`
**Reached by:** Activity Create → tap **Generate Plan**.

### Visible elements
| Role             | Label / Text                       | mobile-mcp coords  | Proposed ValueKey                       |
|------------------|------------------------------------|--------------------|-----------------------------------------|
| Button (back)    | Arrow circle                       | ~(28, 95)          | `adjust_macros.back_button`             |
| Heading          | "Adjust Your Macros"               | center top         | `adjust_macros.title`                   |
| Subtitle         | "During this Run / 1.8 H · 12MI"   | (20, 145, 390x66)  | `adjust_macros.activity_summary`        |
| Stat             | Pace icon + "9:00/mi"              | (32, 220, 180x80)  | `adjust_macros.pace_stat`               |
| Stat             | Flame icon + "1489 kcal"           | (212, 220, 180x80) | `adjust_macros.calories_stat`           |
| Section heading  | "Your Nutritional Targets"         | (32, 388, 366x22)  | `adjust_macros.targets_heading`         |
| Button (icon)    | Help "i" (info)                    | top-right of card  | `adjust_macros.help_button`             |
| Table headers    | "PRE / DURING / POST" columns      |                     | (decorative)                            |
| Row              | "CARBS / 116g / 95g / 77g"         | row                | `adjust_macros.row_carbs`               |
| Row              | "PROTEIN / 12g / 0g / 27g"         | row                | `adjust_macros.row_protein`             |
| Row              | "FLUIDS / 8oz / 34oz / 34oz"       | row                | `adjust_macros.row_fluids`              |
| Row              | "SODIUM / 150mg / 830mg / 300mg"   | row                | `adjust_macros.row_sodium`              |
| Button (outline) | "Edit Macros"                      | (32, 680, 165x56)  | `adjust_macros.edit_macros_button`      |
| Button (outline) | "Reset All"                        | (208, 680, 165x56) | `adjust_macros.reset_all_button`        |
| Button (primary) | "Create Plan"                      | (32, 750, 366x56)  | `adjust_macros.create_plan_button`      |

---

## edit_macros (modal)
**Screenshot:** `screenshots/02_edit_macros.png`
**Reached by:** Tap **Edit Macros** on Adjust Your Macros.

### Visible elements (modal dialog)
| Role             | Label / Text                       | mobile-mcp coords  | Proposed ValueKey                       |
|------------------|------------------------------------|--------------------|-----------------------------------------|
| Dialog title     | "Edit Macro Targets"               | top                | `edit_macros.title`                     |
| Section          | "CARBS (g)" with PRE/DURING/POST fields | column 1      | `edit_macros.carbs_pre_field`, `edit_macros.carbs_during_field`, `edit_macros.carbs_post_field` |
| Section          | "PROTEIN (g)" with PRE/DURING/POST | column 2           | `edit_macros.protein_*_field`           |
| Section          | "FLUIDS (oz)" with PRE/DURING/POST | column 3           | `edit_macros.fluids_*_field`            |
| Section          | "SODIUM (mg)" with PRE/DURING/POST | column 4           | `edit_macros.sodium_*_field`            |
| Button (outline) | "Cancel"                           | bottom             | `edit_macros.cancel_button`             |
| Button (primary) | "Save Changes"                     | bottom             | `edit_macros.save_button`               |

### Notes
- Dialog dismisses when tapping outside (scrim).

---

## plan_detail (before)
**Screenshot:** `screenshots/03_plan_detail.png`
**Reached by:** Adjust Your Macros → tap **Create Plan**.

### Visible elements
| Role             | Label / Text                       | mobile-mcp coords  | Proposed ValueKey                       |
|------------------|------------------------------------|--------------------|-----------------------------------------|
| Button (back)    | Arrow circle                       | ~(28, 95)          | `plan_detail.back_button`               |
| Heading          | "New Activity"                     | center top         | `plan_detail.title`                     |
| Hero image       | Sport image                        | (32, 130)          | (decorative)                            |
| Label            | "RUN SCHEDULED FOR / 12 mi · 1h 48m · 9:00/mi" | center  | `plan_detail.summary_label`             |
| Label            | DATE / TIME                        | row                | `plan_detail.date_label` / `plan_detail.time_label` |
| Section heading  | "BEFORE RUN"                       | section            | `plan_detail.before_section`            |
| Macro stats      | "103g Carbs / 8oz Fluids / 155mg Sodium" |             | `plan_detail.before_macros`             |
| Slider           | Carbs slider with min/max          |                    | `plan_detail.before_carbs_slider`       |
| Card             | "> Pre-Workout Snack / Rice Cake + Jam / Jelly + Banana" | (35, 720, 360x61) | `plan_detail.pre_workout_card` |
| Card             | "> Top-Off / Energy Chews + Water" | (35, 795, 360x61)  | `plan_detail.top_off_card`              |

---

## plan_detail (during)
**Screenshot:** `screenshots/04_plan_during.png`
**Reached by:** Scroll down on plan_detail.

### Visible elements
| Role             | Label / Text                       | Proposed ValueKey                       |
|------------------|------------------------------------|-----------------------------------------|
| Macro stats      | "100g Carbs / 35oz Fluids / 790mg Sodium" | `plan_detail.during_macros`        |
| Card (dropdown)  | "4 Energy Gels" (expandable chevron) | `plan_detail.during_item_<n>`         |
| Card (dropdown)  | "4 cups Water"                      | `plan_detail.during_item_<n>`          |
| Card (dropdown)  | "3 Electrolyte Capsules"            | `plan_detail.during_item_<n>`          |
| Button (outline) | "+ ADD FOOD"                        | `plan_detail.during_add_food_button`   |
| Section heading  | "AFTER RUN"                         | `plan_detail.after_section`            |
| Macro stats      | "78g Carbs / 22g Protein / 392mg Sodium" | `plan_detail.after_macros`         |
| Card             | "> 2 Bananas + Electrolyte Capsule + Protein Bar + 4 cups W…" | `plan_detail.after_card` |

---

## plan_detail (save)
**Screenshot:** `screenshots/05_plan_after.png`
Bottom of scrolled plan.

### Visible elements
| Role             | Label / Text                       | mobile-mcp coords  | Proposed ValueKey                       |
|------------------|------------------------------------|--------------------|-----------------------------------------|
| Button (primary) | "Save Workout"                     | (32, 805, 366x56)  | `plan_detail.save_workout_button`       |
| Button (outline) | "Save as Template"                 | (32, 873, 366x56)  | `plan_detail.save_template_button`      |

### Notes
- Tapping "Save Workout" stores the activity and routes to **Activity Details** (`05_event_details/02_activity_detail.png`).
- The activity then appears on the calendar with a teal dot under the date.
