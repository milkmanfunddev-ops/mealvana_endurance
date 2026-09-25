# 16-009 · Shopping list after confirm: the Farro count, row menu, share, check-off and Kroger button

- kind: followup-test
- status: triaged
- ticket: 16
- run: w9-20260924T1446Z
- screen: Food (Shopping sub-tab)
- decision: 

**Steps.**
1. On the confirmed list, tap the "2" count on Farro.
2. Open a row's ⋮ menu; try each item. Tap "Add an item".
3. Tap the share icon at the top.
4. Check off two rows, switch sub-tabs and back, and relaunch.
5. Switch Settings to metric and back.
6. Edit the plan (remove a meal, change servings) and reopen the list.
7. Tap "Shop with Kroger" with no Kroger connection.

**Expected.**
mp-244: the count lists both meals and leads back to either recipe; imperial unless Settings says metric; no per-row "have it" switch; Share sends plain text; the list is rebuilt after every plan edit with checks kept. Kroger without a connection asks to connect.

**Actual.**


**Evidence.**
- runs/16/10-shopping-list-scrolled.png — Farro with the count 2; row ⋮ menus; Add an item.

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 90 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
