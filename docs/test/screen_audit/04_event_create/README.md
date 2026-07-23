# 04 Event Create

Race event creation flow (separate from Activity creation).

---

## new_event
**Screenshot:** `screenshots/01_new_event.png`, `screenshots/02_race_distance.png` (distance dropdown variant)
**Reached by:** My Events tab → Tap **"+ New Event"** button (empty state) OR Event Details → "Create new event".

### Visible elements
| Role             | Label / Text             | mobile-mcp coords        | Proposed ValueKey                          |
|------------------|--------------------------|--------------------------|--------------------------------------------|
| Button (close)   | "X" (top-left)           | (4, 63, 48x48)           | `event_create.close_button`                |
| Button (home)    | Home icon (top-right)    | (382, 63, 48x48)         | `event_create.home_button`                 |
| Heading          | "New Event"              | center top               | `event_create.title`                       |
| Section heading  | "Sport Category"         | (16, 131, 132x26)        | `event_create.sport_category_heading`      |
| Card (chip)      | Run                      | (16, 169, 100x74)        | `event_create.sport_run_chip`              |
| Card (chip)      | Ride                     | (128, 169, 100x74)       | `event_create.sport_ride_chip`             |
| Card (chip)      | Swim                     | (240, 169, 100x74)       | `event_create.sport_swim_chip`             |
| Card (chip)      | Triathlon                | (352, 169, 100x74)       | `event_create.sport_triathlon_chip`        |
| Card (chip)      | Duathlon (horizontal scroll) | off-screen           | `event_create.sport_duathlon_chip`         |
| Card (chip)      | Multisport (scroll)      | off-screen               | `event_create.sport_multisport_chip`       |
| Card (chip)      | Brick (scroll)           | off-screen               | `event_create.sport_brick_chip`            |
| Section heading  | "Race Distance"          | (16, 263, 123x26)        | `event_create.race_distance_heading`       |
| Dropdown         | "Half Marathon (13.1 mi)"| (16, 301, 398x48)        | `event_create.race_distance_dropdown`      |
| Field            | "Event Name"             | (16, 369, 398x54)        | `event_create.name_field`                  |
| Field            | "Location (optional)"    | (16, 443, 398x54)        | `event_create.location_field`              |
| Selector         | "Event Date" / "Thursday, June 11, 2026" | (16, 551, 398x56) | `event_create.date_button` |
| Selector         | "Start Time" / "3:11 PM" | (16, 661, 398x56)        | `event_create.time_button`                 |
| Section heading  | "Additional Details (Optional)" | (16, 742, 398x61) | `event_create.additional_heading`          |
| Button (primary) | "+ Create Event"         | (16, 828, 398x56)        | `event_create.create_button`               |

### Race Distance Dropdown variant
**Screenshot:** `screenshots/02_race_distance.png`
Options listed: 5K (3.1 mi), 10K (6.2 mi), 15K (9.3 mi), 10 Mile, **Half Marathon (13.1 mi)** [selected], 25K (15.5 mi), 30K (18.6 mi), Marathon (26.2 mi), 50K Ultra (31 mi), 50 Mile Ultra, 100K Ultra (62 mi), 100 Mile Ultra, 12 Hour Ultra, 24 Hour Ultra, Custom Distance.

Each option proposed key: `event_create.race_distance_option_<slug>` (e.g. `event_create.race_distance_option_half_marathon`).

### Notes
- The "Home" button (top-right) is a quick-return-to-calendar shortcut, not a back button.
- "Additional Details (Optional)" is an expandable section (chevron down icon at right) — not fully exercised.
- Date selector opens an in-screen Cupertino-style date picker (similar to activity create).
- Default date is +30 days from today; default time is current time + ~30 min.
