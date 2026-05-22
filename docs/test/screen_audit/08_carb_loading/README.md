# 08 Carb Loading

Carb loading protocol selection and per-day tracker.

---

## protocol_selection
**Screenshot:** `screenshots/01_carb_loading.png`, `screenshots/02_carb_loading_scrolled.png`
**Reached by:** Event Details → tap **"+ Create Carb Loading Plan"**.

### Visible elements
| Role             | Label / Text                       | mobile-mcp coords  | Proposed ValueKey                       |
|------------------|------------------------------------|--------------------|-----------------------------------------|
| Button (back)    | Arrow circle                       | (4, 63)            | `carb_loading.back_button`              |
| Heading          | "Choose Carb Loading Prot…"        | center top         | `carb_loading.title`                    |
| Heading          | "Select Your Protocol"             | (16, 130, 250x22)  | `carb_loading.subheading`               |
| Body             | "Choose a carb loading protocol…"  | (16, 170, 398x80)  | `carb_loading.description`              |
| Card             | "3-Day Classic" + RECOMMENDED badge| (16, 280, 398x250) | `carb_loading.protocol_3_day_card`      |
| Card sub         | "Balanced approach with moderate loading / Intermediate" | | (decorative) |
| Card sub         | "Best For" + Marathon / Half Marathon / Long distance races chips | | `carb_loading.protocol_3_day_tag_<slug>` |
| Button (primary) | "Select 3-Day Protocol"            | (40, 510, 350x56)  | `carb_loading.select_3_day_button`      |
| Card             | "2-Day Quick" + ADVANCED badge     | (16, 580, 398x250) | `carb_loading.protocol_2_day_card`      |
| Card sub         | "Rapid loading for time-constrained athletes / Advanced" |  | (decorative)  |
| Card sub         | "Best For" + 10K / 15K / Experienced athletes / Late race registration chips | | `carb_loading.protocol_2_day_tag_<slug>` |
| Button (primary) | "Select 2-Day Protocol"            | (40, 825, 350x56)  | `carb_loading.select_2_day_button`      |

---

## plan_day_view
**Screenshot:** `screenshots/03_carb_plan_detail.png`, `screenshots/04_carb_plan_scrolled.png`, `screenshots/05_carb_plan_scrolled_more.png`
**Reached by:** Protocol Selection → tap **Select 3-Day Protocol**.

### Visible elements
| Role             | Label / Text                       | mobile-mcp coords  | Proposed ValueKey                       |
|------------------|------------------------------------|--------------------|-----------------------------------------|
| Button (back)    | Arrow circle                       | (4, 63)            | `carb_plan_day.back_button`             |
| Heading          | "CARB LOADING …"                   | center top         | `carb_plan_day.title`                   |
| Subtitle         | "Monday, Jun 8" (day-of-protocol)  | center top         | `carb_plan_day.date_label`              |
| Button (text)    | "Done" (top-right)                 | (318, 63, 64x48)   | `carb_plan_day.done_button`             |
| Button (icon)    | "Show menu" (three dots top-right) | (382, 63, 48x48)   | `carb_plan_day.menu_button`             |
| Section card     | "Total Daily Progress" / "0g / 617g" / "Edit Target" link | (16, 130, 398x110) | `carb_plan_day.daily_total_card` + `carb_plan_day.edit_target_button` |
| Section heading  | "BREAKFAST" + "0/154g" pill        | (16, 270)          | `carb_plan_day.section_breakfast`       |
| Chip             | "Cereal (1/2 cup dry) / 14g carbs" | row                | `carb_plan_day.food_chip_<slug>`        |
| Chip             | "Banana (1 medium) / 27g carbs"    | row                | `carb_plan_day.food_chip_banana`        |
| Chip             | "Bagel (1 large) / 72g carbs"      | row                | `carb_plan_day.food_chip_bagel`         |
| Chip             | "Toast (1 slice) / 13g carbs"      | row                | `carb_plan_day.food_chip_toast`         |
| Chip             | "Pancake (1 medium) / 18g carbs"   | row                | `carb_plan_day.food_chip_pancake`       |
| Chip             | "Waffle (1 medium) / 32g carbs"    | row                | `carb_plan_day.food_chip_waffle`        |
| Chip             | "Orange juice (1 cup) / 27g carbs" | row                | `carb_plan_day.food_chip_orange_juice`  |
| Chip             | "Smoothie (1 cup) / 26g carbs"     | row                | `carb_plan_day.food_chip_smoothie`      |
| Chip             | "Oats (1/2 cup) / 14g carbs"       | row                | `carb_plan_day.food_chip_oats`          |
| Button (outline) | "+ ADD FOOD" (per section)         | end of section     | `carb_plan_day.add_food_breakfast`      |
| Section heading  | "MORNING SNACK" + "0/62g"          |                    | `carb_plan_day.section_morning_snack`   |
| Section heading  | "AFTERNOON SNACK" + "0/93g"        |                    | `carb_plan_day.section_afternoon_snack` |
| Section heading  | "DINNER" + "0/123g"                |                    | `carb_plan_day.section_dinner`          |
| (presumed)       | "LUNCH" / "EVENING SNACK"          |                    | `carb_plan_day.section_<meal>`          |

### Variant: menu
**Screenshot:** `screenshots/07_menu.png`
| Menu item     | "Reset Progress"  | `carb_plan_day.menu_reset_progress` |
| Menu item     | "Mark Complete" (already checked) | `carb_plan_day.menu_mark_complete` |

### Notes
- Each food chip is tappable to log it as consumed (toggles checked state).
- The day shown defaults to **start of protocol window** (Monday June 8, 3 days before Test Race on Jun 11).
- A day-picker / day-tabs UI was visible briefly at the top of the screen showing protocol day navigation; not fully captured in screenshots — proposed key: `carb_plan_day.day_tab_<n>`.
- "Edit Target" link near Total Daily Progress opens a per-day macro edit (not exercised).
