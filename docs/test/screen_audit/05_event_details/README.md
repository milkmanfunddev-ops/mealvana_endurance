# 05 Event Details

Event Details, Activity Details, and the related list views.

---

## my_events_empty
**Screenshot:** `screenshots/01_my_events_empty.png`
**Reached by:** Bottom-nav → 3rd icon (check/calendar with checkmark).

### Visible elements
| Role            | Label / Text                  | mobile-mcp coords   | Proposed ValueKey               |
|-----------------|-------------------------------|---------------------|---------------------------------|
| Heading         | "My Events"                   | center top          | `my_events.title`               |
| Button (icon)   | Settings gear                 | ~(405, 75)          | `my_events.settings_button`     |
| Empty state img | Calendar icon                 | (322, 642)          | (decorative)                    |
| Empty state     | "No Events Yet"               | (236, 738)          | `my_events.empty_title`         |
| Empty state     | "Create your first race event…" | (78, 793)         | `my_events.empty_subtitle`      |
| Button (primary)| "+ New Event"                 | (210, 893, 225x80)  | `my_events.new_event_button`    |

---

## my_events_with_event
**Screenshot:** `screenshots/01_my_events_with_event.png`
**Reached by:** Bottom-nav → 3rd icon after at least one event exists.

### Visible elements
| Role            | Label / Text                | mobile-mcp coords     | Proposed ValueKey                    |
|-----------------|-----------------------------|-----------------------|--------------------------------------|
| Heading         | "My Events"                 | center top            | `my_events.title`                    |
| Section heading | "UPCOMING EVENTS"           | (20, 215, 230x18)     | `my_events.upcoming_heading`         |
| Card            | "Test Race" / "JUN 11 / 2026" | (16, 277, 398x97)   | `my_events.event_card_<id>`          |
| Button          | "+ New Event"               | (210, 493, 225x80)    | `my_events.new_event_button`         |

### Notes
- Tapping a card → Event Details (`07_event_details.png`).
- Past events would presumably appear under a separate "Past Events" section (not exercised).

---

## event_details
**Screenshot:** `screenshots/07_event_details.png`, `screenshots/08_event_info_expanded.png` (Event Information tap variant)
**Reached by:** Tap event card from My Events or Calendar.

### Visible elements
| Role             | Label / Text                       | mobile-mcp coords     | Proposed ValueKey                       |
|------------------|------------------------------------|-----------------------|-----------------------------------------|
| Button (back)    | (arrow circle top-left)            | (4, 63, 48x48)        | `event_details.back_button`             |
| Heading          | "Event Details"                    | center top            | `event_details.title`                   |
| Button (icon)    | Home                               | (334, 63, 48x48)      | `event_details.home_button`             |
| Button (icon)    | More options (three dots)          | (382, 63, 48x48)      | `event_details.more_button`             |
| Title            | "Test Race" (event name)           | (32, 151, 112x34)     | `event_details.event_name`              |
| Subtitle         | "Thursday, June 11, 2026"          | (60, 201, 176x24)     | `event_details.event_date`              |
| Pill             | "1 month away"                     | (49, 246, 89x21)      | `event_details.event_countdown`         |
| Section heading  | "Event Information"                | (32, 324, 292x22)     | `event_details.event_info_heading`      |
| Section heading  | "Nutrition Planning"               | (32, 410, 366x22)     | `event_details.nutrition_heading`       |
| Button (primary) | "+ Create Nutrition Plan"          | (32, 448, 366x56)     | `event_details.create_nutrition_button` |
| Button (outline) | "+ Create Carb Loading Plan"       | (32, 516, 366x56)     | `event_details.create_carb_loading_button` |
| Button (outline) | "Race Day Checklist"               | (32, 584, 366x56)     | `event_details.checklist_button`        |
| Link             | "View events list"                 | (75, 685, 120x48)     | `event_details.view_events_link`        |
| Link             | "Create new event"                 | (219, 685, 135x48)    | `event_details.create_new_event_link`   |

### Variant: after carb loading plan created
- The button text changes from "+ Create Carb Loading Plan" to "Edit Carb Loading Plan" with a pencil icon (visible in `tmp/event2.png`).

### Notes
- "Create Nutrition Plan" navigates to the activity-create flow (we did NOT exercise this — could just route to the create-activity form with event context attached).

---

## event_more_menu
**Screenshot:** `screenshots/10_event_menu.png`
**Reached by:** Tap the three-dots "More options" button on Event Details.

### Visible elements
| Role          | Label / Text  | mobile-mcp coords  | Proposed ValueKey                    |
|---------------|---------------|--------------------|--------------------------------------|
| Menu item     | "Edit Event"  | dropdown           | `event_details.menu_edit`            |
| Menu item     | "Delete Event"| dropdown           | `event_details.menu_delete`          |

---

## race_day_checklist
**Screenshot:** `screenshots/09_race_day_checklist.png`
**Reached by:** Event Details → "Race Day Checklist".

### Visible elements
| Role             | Label / Text                       | mobile-mcp coords  | Proposed ValueKey                       |
|------------------|------------------------------------|--------------------|-----------------------------------------|
| Button (back)    | (arrow circle top-left)            | ~(28, 95)          | `checklist.back_button`                 |
| Heading          | "Race Day Checklist"               | center top         | `checklist.title`                       |
| Card (info)      | "Race Day Gear Checklist / Tap items to check them off as you pack!" | (16, 195, 398x150) | `checklist.intro_card` |
| Section heading  | "RACE DAY GEAR"                    | (16, 363, 250x24)  | `checklist.gear_section`                |
| Checkbox         | Running shoes / shorts/pants / shirt/singlet / Socks (moisture-wicking) / GPS watch/fitness tracker / Race bib / Race belt OR safety pins / Sunglasses / Hat or visor / Sunscreen / Body glide/anti-chafe cream / Band-aids/blister protection | rows ~(16, 415+row*42, 398x32) | `checklist.gear_item_<slug>` |
| Link             | "+ Add custom item"                | (16, 950, 200x40)  | `checklist.add_custom_button`           |

### Notes
- More sections below (Nutrition section visible at bottom-edge — not fully captured).

---

## activity_details
**Screenshot:** `screenshots/02_activity_detail.png`, `screenshots/05_activity_scrolled.png` (scrolled), `screenshots/06_activity_by_hour.png`
**Reached by:** Tap an activity card on Calendar.

### Visible elements
| Role             | Label / Text                       | mobile-mcp coords  | Proposed ValueKey                       |
|------------------|------------------------------------|--------------------|-----------------------------------------|
| Button (back)    | Arrow circle (top-left)            | (4, 63, 48x48)     | `activity_details.back_button`          |
| Heading          | "Activity Details"                 | center             | `activity_details.title`                |
| Button (icon)    | Bookmark/Save as Template          | (274, 63, 48x48)   | `activity_details.save_template_button` |
| Button (icon)    | Pencil/Edit Activity               | (322, 63, 48x48)   | `activity_details.edit_button`          |
| Button (icon)    | Trash/Delete Activity              | (370, 63, 48x48)   | `activity_details.delete_button`        |
| Hero image       | Sport graphic                       | (32, 130, 366x290) | `activity_details.hero_image`           |
| Label            | "RUN SCHEDULED FOR"                | (145, 447, 139x16) | `activity_details.scheduled_label`      |
| Label            | "12 mi · 1h 48m · 9:00/mi"         | (120, 471, 188x22) | `activity_details.summary_label`        |
| Label            | "DATE / May 12, 2026"              | (103, 505, 120x50) | `activity_details.date_label`           |
| Label            | "TIME / 4:45pm"                    | (256, 505, 69x50)  | `activity_details.time_label`           |
| Section heading  | "BEFORE RUN"                       | (34, 587, 334x23)  | `activity_details.before_section`       |
| Macro            | "103g Carbs / 8oz Fluids / 155mg Sodium" | (74, 625) | `activity_details.before_macros`         |
| Range slider     | Carbs slider                        | (38, 680)          | `activity_details.before_carbs_slider`  |
| Card             | "Pre-Workout Snack" suggestion     | (35, 709, 360x61)  | `activity_details.pre_workout_card`     |
| Card             | "Top-Off" suggestion                | (35, 784, 360x61)  | `activity_details.top_off_card`         |
| Section heading  | "DURING RUN"                       | (56, 906, 132x23)  | `activity_details.during_section`       |
| Toggle           | "Summary"                          | (216, 902, 90x30)  | `activity_details.during_summary_toggle`|
| Toggle           | "By Hour"                          | (306, 902, 90x30)  | `activity_details.during_by_hour_toggle`|
| Food card        | "4 Energy Gels"                    | scroll             | `activity_details.during_food_card_<n>` |
| Food card        | "4 cups Water"                     | scroll             | `activity_details.during_food_card_<n>` |
| Food card        | "3 Electrolyte Capsules"           | scroll             | `activity_details.during_food_card_<n>` |
| Button (outline) | "+ ADD FOOD"                       | scroll             | `activity_details.add_food_button`      |
| Section heading  | "AFTER RUN"                        | scroll             | `activity_details.after_section`        |
| Button (outline) | "Save"                             | bottom             | `activity_details.save_button`          |
| Button (primary) | "Complete"                         | bottom             | `activity_details.complete_button`      |

### Variant: delete confirmation
**Screenshot:** `screenshots/04_delete_confirm.png`
| Role          | Label / Text                                | mobile-mcp coords    | Proposed ValueKey                        |
|---------------|---------------------------------------------|----------------------|------------------------------------------|
| Dialog title  | "Delete Activity"                           | (64, 400, 302x26)    | `activity_details.delete_dialog_title`   |
| Body          | "Are you sure you want to delete…"          | (64, 442, 302x42)    | `activity_details.delete_dialog_body`    |
| Button (text) | "Cancel"                                    | (224, 508, 67x48)    | `activity_details.delete_cancel_button`  |
| Button (danger)| "Delete"                                   | (300, 508, 65x48)    | `activity_details.delete_confirm_button` |

### Variant: edit
**Screenshot:** `screenshots/03_activity_edit.png`
- The Edit pencil opens the Activity Create form (`06_activity_create`) pre-filled with this activity's data.

### Notes
- The "By Hour" toggle didn't fire on tap during audit (likely the same Flutter hit-test issue) — could not capture the by-hour variant.
- The "Save" and "Complete" buttons at the bottom of Activity Details also didn't fire reliably; the keys above are still proposed for use in tests.
