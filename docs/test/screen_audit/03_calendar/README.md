# 03 Calendar

Main hub of the app. After login/onboarding, user lands here.

---

## calendar_by_week_empty
**Screenshot:** `screenshots/01_calendar_anon_empty.png` (also `01_calendar_by_week_empty.png`)
**Reached by:** Tap "Continue without signing in" on Create Account screen (anonymous onboarding complete).

### Visible elements
| Role           | Label / Text          | mobile-mcp coords     | Proposed ValueKey                    |
|----------------|-----------------------|-----------------------|--------------------------------------|
| Tab (selected) | "BY WEEK"             | (104, 71, 93x19)      | `calendar.by_week_toggle`            |
| Tab            | "BY MONTH"            | (217, 71, 108x18)     | `calendar.by_month_toggle`           |
| Button (icon)  | Settings gear         | ~(405, 75, 40x40)     | `calendar.settings_button`           |
| Label          | "May 2026"            | (177, 114, 75x25)     | `calendar.month_label`               |
| Button (icon)  | Previous month "<"    | ~(235, 120, 25x20)    | `calendar.prev_month_button`         |
| Button (icon)  | Next month ">"        | ~(412, 120, 25x20)    | `calendar.next_month_button`         |
| Date cells     | 7-day strip (S-S)     | row at y=181, height 60, cells 61 wide | `calendar.day_cell_<date>` (e.g. `calendar.day_cell_2026_05_12`) |
| Empty state    | "No fueling plans yet"| (132, 608, 164x23)    | `calendar.empty_title`               |
| Empty state    | "Tap + to fuel your next workout" | (95, 639, 238x21) | `calendar.empty_subtitle`     |
| Nav (1)        | Calendar tab          | (88, 870, 42x41)      | `bottom_nav.calendar_tab`            |
| Nav (2)        | Diary/fork tab        | (138, 870, 42x41)     | `bottom_nav.diary_tab`               |
| Nav (3)        | My Events check tab   | (188, 870, 42x41)     | `bottom_nav.events_tab`              |
| Nav (4)        | Learn cap tab         | (238, 870, 42x41)     | `bottom_nav.learn_tab`               |
| FAB            | Orange "+"            | ~(322, 890, 60x60)    | `calendar.create_activity_fab`       |

### Notes
- Today (May 12) is highlighted with white background.
- Bottom nav is a single pill-shaped container floating above the FAB on the right.
- Tapping a date cell selects that date (the white highlight moves).

---

## calendar_by_month
**Screenshot:** `screenshots/02_calendar_by_month.png`
**Reached by:** Tap **BY MONTH** toggle.

### Visible elements
Same as `calendar_by_week_empty` except the date region renders a full 6-row month grid (S/M/T/W/T/F/S header at y=155, rows of 7 cells starting y=183, each 61 wide × 44 tall). Cells outside the current month appear dimmer.

### Notes
- Identical key naming applies (`calendar.day_cell_<date>`).

---

## calendar_with_activity
**Screenshot:** `screenshots/03_calendar_with_activity.png`
**Reached by:** After saving an activity (e.g. the "12 mi Run" generated via FAB).

### Visible elements (in addition to base calendar)
| Role             | Label / Text                       | mobile-mcp coords | Proposed ValueKey                       |
|------------------|------------------------------------|-------------------|-----------------------------------------|
| Day cell dot     | Teal dot under selected date "12"  | inside day cell   | `calendar.day_cell_has_activity_dot`    |
| Section heading  | "Today's Activities"               | (16, 420, 230x26) | `calendar.todays_activities_heading`    |
| Card             | "12 mi Run / 4:45 PM · 12.0 mi · 9:00/mi" | (16, 488, 398x67) | `calendar.activity_card_<id>` |

### Notes
- Tapping the activity card navigates to **05_event_details/02_activity_detail.png** (Activity Details).

---

## calendar_with_events_and_activities
**Screenshot:** `screenshots/04_calendar_with_events_and_activities.png`
**Reached by:** After both an Event (e.g. Test Race) and an Activity exist.

### Additional elements
| Role             | Label / Text                       | mobile-mcp coords | Proposed ValueKey                       |
|------------------|------------------------------------|-------------------|-----------------------------------------|
| Section heading  | "Upcoming Races"                   | (16, 420, 230x26) | `calendar.upcoming_races_heading`       |
| Card             | "Test Race / 1 month away"         | (16, 488, 398x67) | `calendar.event_card_<id>`              |
| Section heading  | "Today's Activities"               | further down      | `calendar.todays_activities_heading`    |
| Card             | Activity card                       | further down      | `calendar.activity_card_<id>`           |

### Notes
- Tapping the race card → Event Details screen (see `05_event_details`).
- Tapping the activity card → Activity Details screen.
