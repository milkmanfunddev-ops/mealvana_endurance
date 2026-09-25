# 19-010 · New list: Add an item, Share and rename on a hand-made list, and New list twice in a day

- kind: followup-test
- status: closed
- ticket: 19
- run: w11-20260924T1647Z
- screen: Food (Shopping sub-tab)
- decision: 

**Steps.**
1. ⋯ > New list, then Add an item (short name, long name, a name with a quantity), tick it, rename the list (tap the title or the sheet's Rename).
2. Share the hand-made list: plain text, as mp-244 says for Share.
3. New list a second time the same day: two lists both called "List <date>"?
4. New list with the network cut.
5. Open the header's Share icon on an empty list.

**Expected.**
Rows land in shopping_items with the new list's id; names are unique or told apart; Share sends plain text; offline says it needs the network.

**Actual.**


**Evidence.**
- runs/19/10-after-new-list-tap.png: the empty new list with Add an item.
- runs/19/db-02-after-new-list.txt: the row the New list made (plan_id null, 0 items).

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 90 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
Moved to retest ticket 110 when 90 was split (Lee, 2026-09-25).

Run by retest ticket 110 (run w30-20260925T2103Z, build e3367d2c): pass.
