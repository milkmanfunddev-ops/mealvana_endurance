# 16-003 · Right after Confirm the Shopping sub-tab says No shopping list for several seconds while the confirmed list exists

- kind: bug
- status: triaged
- ticket: 16
- run: w9-20260924T1446Z
- screen: Food (Shopping sub-tab)
- decision: 

**Steps.**
1. Confirm a plan from the Review sheet (14:53:12.9Z); the app lands on Food (Plan sub-tab, 16-002).
2. Tap the Shopping sub-tab (about 14:54:14Z), screenshot at 14:54:17Z.
3. Screenshot again at 14:54:29Z.

**Expected.**
The list the server built at confirm (mp-244: "Confirm waits until the server says it is done"), or a loading state while it is fetched.

**Actual.**
At 14:54:17Z the tab showed the empty state "No shopping list. Confirm a meal plan and the shopping list builds itself." At 14:54:29Z the list showed: "Week of 2026-09-20, Confirmed Sep 24, 2026, 15 items". The list row had been in the database since 14:53:15.87Z (confirmed_at), a minute before the tab first showed it. The empty state reads as if the confirm had failed.

**Evidence.**
- runs/16/09-shopping-tab-after-confirm.png — "No shopping list" at 14:54:17Z.
- runs/16/10-shopping-list-scrolled.png — the list, loaded, a few seconds later.
- runs/16/db-after.txt — list 03c4c52b present with 15 items at 14:53:30Z.

**Decision quote.**
> 

**Triage.**
Fix ticket 46 (Lee, 2026-09-25). Closed by the retest after it merges.
Moved to retest ticket 115 when 91 was split (Lee, 2026-09-25).
