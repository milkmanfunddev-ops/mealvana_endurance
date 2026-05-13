# Screen Audit — Mealvana Endurance

**Purpose:** Document every visible app screen, the interactive elements on
each one, and the `ValueKey` we plan to add so integration tests can drive the
UI deterministically.

**Method:** Drive the iPhone 15 Pro Max simulator end-to-end via mobile-mcp.
Screenshots saved per-area under `{NN_area}/screenshots/`. Each area also has
a `README.md` documenting elements + proposed keys.

**Captured against:** `com.milkman.mealvanaendurance.dev` (Endurance Dev)
on iOS 17.5, screen size 430×932.

**Started:** 2026-05-12

## Area index

| #  | Area              | Notes                                      |
|----|-------------------|--------------------------------------------|
| 01 | welcome_auth      | Welcome, login, signup, forgot password    |
| 02 | onboarding        | Dietary → allergies → foods → sports → sport details |
| 03 | calendar          | Week/month, navigation, empty state        |
| 04 | event_create      | Sport, distance, name, location, date      |
| 05 | event_details     | Detail page + create-plan CTAs             |
| 06 | activity_create   | Distance, pace, gut training, generate     |
| 07 | nutrition_plan    | Adjust macros, plan view, swap, add food   |
| 08 | carb_loading      | Carb loading plan + log                    |
| 09 | settings          | Profile, appearance, sign out              |
| 10 | integrations      | TP, Final Surge, Garmin, Strava            |
| 11 | fuel_log          | Logging consumed food                      |
| 12 | food_management   | Food preferences sliders/chips             |
| 13 | brick             | Brick workouts (bike→run, etc.)            |
| 14 | other             | Misc bottom-nav destinations               |

## Key naming convention

`<screen>.<role>` — e.g. `calendar.create_event_fab`, `login.email_field`,
`event_details.create_nutrition_plan_button`.

Always use lower_snake_case. The screen prefix matches the area folder name
(or sub-screen name where there are multiple screens in one area).

## Edge-case states captured

After the happy path, return to capture: empty plan, generation error, no
events, disconnected integration, network error banner. Stored as
`NN_<state>.png` alongside the happy-path screenshots.
