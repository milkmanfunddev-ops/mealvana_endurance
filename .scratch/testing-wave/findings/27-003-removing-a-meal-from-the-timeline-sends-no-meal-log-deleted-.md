# 27-003 · Removing a meal from the timeline sends no meal_log_deleted analytics event, and diary_closed reports items_logged 0 after two manual logs

- kind: bug
- status: triaged
- ticket: 27
- run: w15-20260924T2039Z
- screen: Timeline row → Remove; Log a Meal close
- decision: 

**Steps.**
1. Log two meals on Log a Meal → Manual, then Back (15:44:26 local).
2. Timeline → ⋯ → Edit food → Save changes (15:45:37 local).
3. Timeline → ⋯ → Remove on another row (15:46:16 local).
4. Read the console for [ANALYTICS] lines.

**Expected.**
meal_logged ×2, diary_closed with items_logged 2, meal_log_updated, meal_log_deleted (MealLogController.deleteLog tracks 'meal_log_deleted').

**Actual.**
meal_logged ×2 and meal_log_updated are printed. diary_closed prints items_logged 0 (duration 81 s) after two manual saves. No meal_log_deleted line at all, although the row went is_deleted true on the server and the "Meal deleted" snackbar showed. deleteLog returns early on `if (!ref.mounted) return;` before tracking, which is the likely cause (the row's menu closes as the row leaves the list). Same family as 24-002 (diary_closed 0 after a photo log); this one is Manual.

**Evidence.**
- runs/27/console-redacted.log (search "[ANALYTICS]": meal_logged 15:43:41 and 15:44:17, diary_closed items_logged 0 15:44:26, meal_log_updated 15:45:37, nothing for the Remove at 15:46:16)
- runs/27/db-totals-after-delete.txt (7c20d895 is_deleted true, updated_at 20:46:17Z)

**Decision quote.**
> 

**Triage.**
Fix ticket 50 (Lee, 2026-09-25). Closed by the retest after it merges.
