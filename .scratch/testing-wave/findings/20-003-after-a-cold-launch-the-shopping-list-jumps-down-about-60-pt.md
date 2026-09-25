# 20-003 · After a cold launch the Shopping list jumps down about 60 pt a few seconds after it appears, when the server's list replaces the local copy

- kind: bug
- status: triaged
- ticket: 20
- run: w10-20260924T1614Z
- screen: Food (Shopping sub-tab)
- decision: 

**Steps.**
1. Online, with three rows ticked, cold restart the app (16:19:03Z), open Food, then the Shopping sub-tab (16:19:47Z).
2. Screenshots at about 1 s, 4 s and 10 s.

**Expected.**
The rows stay where they are while the list refreshes, so a tap lands on the row the athlete aimed at.

**Actual.**
At 1 s the tab showed the list with no "Shop with Kroger" button and the rows starting just under the header (Avocado at y≈365 pt). By 10 s the button had appeared above "15 items" and every row had moved down about 60 pt (Avocado at y≈425 pt). A tick aimed during the first seconds lands on the row above the one intended (a tap on Bell pepper at y≈461 pt, where it was at 1 s, hits Beets after the jump). Across the run the first view after sign-in (16:18:15Z) also showed "No shopping list" for several seconds before the list loaded, as 16-003 already reports.

**Evidence.**
- runs/20/09-shopping-after-cold-restart-online-1s.png — no Kroger button, rows high.
- runs/20/09-shopping-after-cold-restart-online-4s.png — mid-swap.
- runs/20/09-shopping-after-cold-restart-online-10s.png — Kroger button present, rows about 60 pt lower.
- runs/20/05-shopping-online-before.png — "No shopping list" right after sign-in (16-003 again).

**Decision quote.**
> 

**Triage.**
Fix ticket 46 (Lee, 2026-09-25). Closed by the retest after it merges.
Moved to retest ticket 115 when 91 was split (Lee, 2026-09-25).
