# 10-001 · After resubscribing on a fresh install the timeline shows no meal logged before the lapse until the Food tab is opened; pull-to-refresh does not bring it

- kind: bug
- status: closed
- ticket: 10
- run: w8-20260924T1418Z
- screen: Timeline
- decision: 

**Steps.**
1. On a simulator where account D (ticket 09, Lapsed) had never been signed in, log in with email: the full-screen paywall.
2. Monthly → Continue → Test Store "Test valid purchase" (14:21:00Z). The app opens on Timeline, Today, September 24.
3. Look at the timeline; pull it down to refresh; tap the Meals filter.
4. Open Food (Plan, Shopping), then go back to Timeline.

**Expected.**
mp-280: "Their data is kept as it was and is all there again the moment Pro is back." D's breakfast logged in ticket 09 (meal_logs `346a6d5b`, "Eggs and Whole-grain toast", 278 kcal, eaten 12:32Z = 7:32 AM local, log_date 2026-09-24) shows on today's timeline as soon as the Gate opens, as it did in ticket 09 (runs/09/11-timeline-with-meal.png).

**Actual.**
At 14:21:04Z and again at 14:21:37Z the timeline for today was empty: only + Add Food / + Add Activity, no meal card (04-after-purchase.png, 05-timeline-30s-after-purchase.png). A pull-down on the timeline and the Meals filter still showed nothing (06-timeline-meals-filter-after-pull.png, 14:21:51Z). The server row was there the whole time (db-D-meal-log.txt at 14:21:32Z, `is_deleted false`). The console shows why: after login only `users_last_sync` and `activities_last_sync` were written (14:20:11Z); `meal_logs_last_sync` (with `meal_plans`, `saved_meals`, `user_memories`) was first written at 14:21:59Z, the moment Food was opened. Back on Timeline at 14:22:40Z the meal card was there (7:32 AM, EGGS AND W…, 278 kcal, 09-timeline-after-food-tab.png). So a returning account on a new device sees a day with no meals, and a net balance that counts none, until it happens to open Food. Probably not specific to resubscribing (any sign-in on a fresh install would do it), but this is where mp-280's "all there again" is checked.

**Evidence.**
- runs/10/04-after-purchase.png
- runs/10/05-timeline-30s-after-purchase.png
- runs/10/06-timeline-meals-filter-after-pull.png
- runs/10/09-timeline-after-food-tab.png
- runs/10/db-D-meal-log.txt
- runs/10/console-excerpts.log (lines 19-22: users/activities/integrations synced 09:20:11 local at login; lines 37-40: saved_meals/user_memories/meal_logs/meal_plans first synced 09:21:59 local, when Food opened)

**Decision quote.**
> 

**Triage.**
Fix ticket 46 (Lee, 2026-09-25). Closed by the retest after it merges.
Moved to retest ticket 115 when 91 was split (Lee, 2026-09-25).

Run by retest ticket 115 (run w32-20260925T2219Z, build e3367d2c): pass.
