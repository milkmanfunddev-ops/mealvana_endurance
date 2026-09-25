# 26-009 · Quick log confirm sheet: time eaten is the time the sheet opened, a changed time and yesterday, offline

- kind: followup-test
- status: triaged
- ticket: 26
- run: w13-20260924T1904Z
- screen: Log a Meal → quick log sheet
- decision: 

**Steps.**
1. Open a quick log sheet, wait two minutes, Log it; compare eaten_at with the save time (in this run the recipe sheet said 2:09 PM and saved eaten_at 19:09Z although Log it was tapped at 19:10:05Z).
2. Change Time eaten to an earlier time today and to yesterday evening.
3. Swipe the sheet down without logging; tap the scrim.
4. Turn the network off, quick log, then back on.

**Expected.**
eaten_at is what the sheet showed (fine) or the moment of Log it (say which is intended). A time on yesterday lands on yesterday's log_date or the app says it will not. Dismissing writes nothing. Offline: the meal shows at once and uploads when the network returns (offline-first).

**Actual.**


**Evidence.**
- runs/26/17-recipe-confirm-sheet.png
- runs/26/db-meal-logs.txt

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 91 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
