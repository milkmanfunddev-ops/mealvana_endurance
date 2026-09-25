# 26-002 · Re-logging a Recent meal collapses its items into one 1-serving line and saves it as source saved with no saved meal id

- kind: bug
- status: closed
- ticket: 26
- run: w13-20260924T1904Z
- screen: Log a Meal (Recent) → quick log sheet
- decision: 

**Steps.**
1. Log a Meal → Recent → tap "Rice cake and Almond butter" (source meal_logs 9162543b, logged 09-23, two items).
2. Servings 1, Meal type Snack (the source's slot), Log it (19:08:35–19:08:37Z).
3. Read the new row from dev meal_logs.

**Expected.**
The ticket: "each saves as the source had it". The new row carries the source's items: Rice cake (2 cakes, 70 kcal, 15 C, 1.4 P, 0.6 F) and Almond butter (1 tbsp, 98 kcal, 3 C, 3.4 P, 9 F), plus the same totals, so the log can later be edited item by item as the original could.

**Actual.**
New row 00a120e5 (created 19:08:36Z): totals, name and slot equal the source (168 kcal, 18.0 C, 4.8 P, 9.6 F, 0.0 Na, snack). But `items` holds one synthetic line `{"name":"Rice cake and Almond butter","portion":"1 serving", ...totals}` instead of the two source items (SQL `items_eq false`, 1 item vs 2). The row's `source` is `saved` although it came from history, not from a saved meal, and `saved_meal_id` is null, so nothing links it to the log it copied; the source itself was `manual`. The code does this on purpose (`_onRecentTap` → `syntheticFromLog`), so this is a product question as much as a bug: whether a re-log should copy the items, and what `source` a history re-log should carry.

**Evidence.**
- runs/26/09-recent-confirm-sheet.png
- runs/26/11-recent-after-log.png
- runs/26/db-meal-logs.txt (source row, new row 00a120e5, and the "recent" comparison line)

**Decision quote.**
> 

**Triage.**

Fix ticket 58 (Lee, 2026-09-25). Closed by the retest after it merges.
Moved to retest ticket 112 when 91 was split (Lee, 2026-09-25).

Run by retest ticket 112 (run w34-20260925T2320Z, build e3367d2c): pass.
