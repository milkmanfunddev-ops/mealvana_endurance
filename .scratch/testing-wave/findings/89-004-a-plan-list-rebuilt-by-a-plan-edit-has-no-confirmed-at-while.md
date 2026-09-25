# 89-004 · A plan list rebuilt by a plan edit has no confirmed_at, while Rebuild shopping list stamps one

- kind: bug
- status: triaged
- ticket: 89
- run: w29-20260925T1950Z
- screen: Food (Shopping sub-tab)
- decision: 

**Steps.**
1. test@test.com, confirmed plan be6abf2f with no list (its list deleted).
2. Edit the plan (Plan tab > meal ⋮ > Swap). Open Shopping; read `shopping_lists` for plan be6abf2f.
3. Delete that list, then Plan ⋮ > Rebuild shopping list. Open Shopping; read the row again.

**Expected.**
Both ways of remaking the confirmed plan's list give the same list: `rebuildShoppingList`'s own comment says "A confirmed plan's remade list is confirmed with it".

**Actual.**
After the edit (19:57:11Z) list 10579cbf has `confirmed_at` NULL and the header reads "Week of Sep 20 · Made Sep 25, 2026". After Rebuild (20:06:09Z) list 2a4cbd64 has `confirmed_at` set and the header reads "Confirmed Sep 25, 2026". The edit path (`refreshShopping` → `syncPlanList` → `ensurePlanList`) never calls `markListConfirmedIfUnset`. The tab opened both, since the default is picked by plan_id, but the sort (coalesce(confirmed_at, created_at)) and the header wording differ, and `dropArchivedDraftLists` relies on `confirmed_at` as its second guard. mp-244 (19-009) itself held: the edit rebuilt the list.

**Evidence.**
- runs/89/db-01-after-swap.txt: list 10579cbf, confirmed_at None.
- runs/89/12-19-009-shopping-after-swap.png: "Made Sep 25, 2026".
- runs/89/33-after-rebuild.png: list 2a4cbd64, see db-02-at-flag.txt.
- runs/89/34-after-rebuild-10s.png: "Confirmed Sep 25, 2026".
- runs/89/db-02-at-flag.txt: 2a4cbd64 with confirmed 09-25 20:06.

**Decision quote.**
> 

**Triage.**

Fix ticket 127 (Lee, 2026-09-25). Closed by the retest after it merges.
