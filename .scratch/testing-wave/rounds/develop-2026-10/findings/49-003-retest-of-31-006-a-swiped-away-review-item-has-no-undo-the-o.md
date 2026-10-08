# 49-003 · Retest of 31-006: a swiped-away Review item has no undo; the only way back is Back + Review again, which silently drops every edit

- kind: bug
- status: triaged
- ticket: 49
- run: w5-20261008T1719Z
- screen: Review & Log
- decision: 

**Steps.**
1. Describe "two scrambled eggs, a slice of whole wheat toast with butter, a banana" -> Review & Log. Rename the meal, swap the toast for Apple (medium) ×2.
2. 17:29:37Z swipe the Apple row left to right.
3. Wait 4 s. Then Back, then "Review again".

**Expected.**
31-006 asked for an undo or a confirm on destructive actions, or a ruling that none is wanted. The Timeline's meal Remove now has an Undo snackbar (passes, see notes); an item remove on Review should offer the same, or Back should warn before it drops edits.

**Actual.**
Step 2: the item is gone at once, no confirm, no snackbar, no undo; Total 477 -> 287. Step 3: Back leaves with no "discard changes?" prompt; Review again reopens the original AI analysis (toast back, the AI's name back, the swap gone). It is free (no ledger row), so nothing is lost but the edits, yet the athlete gets no warning that Back throws away the rename and the swap. Retest of 31-006 (ticket 45 left it out of scope).

**Evidence.**
- runs/49/20-review-after-swap.png — before the swipe: Apple ×2, Total 477
- runs/49/22-item-removed.png — after the swipe: Apple gone, no undo
- runs/49/23-review-again-after-remove.png — Back + Review again: original analysis, edits gone

**Decision quote.**
> 

**Triage.**
