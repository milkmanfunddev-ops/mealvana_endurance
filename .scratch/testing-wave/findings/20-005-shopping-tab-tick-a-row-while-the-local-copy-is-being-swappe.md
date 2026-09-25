# 20-005 · Shopping tab: tick a row while the local copy is being swapped for the server's list, and double-tap a row fast

- kind: followup-test
- status: triaged
- ticket: 20
- run: w10-20260924T1614Z
- screen: Food (Shopping sub-tab)
- decision: 

**Steps.**
1. Cold launch online, open Shopping and tick a row within the first second, before the server's list replaces the local copy (20-003).
2. Online, double-tap one row's box quickly, and tick three rows in under a second.
3. SQL on shopping_items after each; edge logs for update_shopping_item.

**Expected.**
The row tapped is the row ticked; the final database state matches the screen; a double tap ends unticked-then-ticked-back consistently on both.

**Actual.**


**Evidence.**
- runs/20/09-shopping-after-cold-restart-online-1s.png — the local copy shown before the swap.

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 90 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
