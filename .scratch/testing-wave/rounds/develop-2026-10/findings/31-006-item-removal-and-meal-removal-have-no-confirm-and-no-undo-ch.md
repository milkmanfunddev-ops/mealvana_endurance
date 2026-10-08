# 31-006 · Item removal and meal removal have no confirm and no undo: check recovery from an accidental swipe or tap

- kind: followup-test
- status: closed
- ticket: 31
- run: w3-20261008T1256Z
- screen: Review & Log / Timeline
- decision: retest ticket 49 (meal logging), wave 5

**Steps.**
1. On Review & Log, swipe an item left to right: it is removed at once (seen 13:05Z).
2. On the Timeline, ⋯ -> Remove on a meal card: removed at once (seen 13:12:59Z).
3. Try: is there any undo (snackbar, shake)? Does a removed Review item come back with Back? Does a Timeline remove made offline survive a relaunch and sync?

**Expected.**
Either an undo or a confirm on destructive actions, or a ruling that none is wanted; a remove made offline syncs is_deleted on reconnect.

**Actual.**


**Evidence.**
- runs/31/26-review-after-remove.png — item gone, no undo shown
- runs/31/53-remove-tapped.png — meal gone from the Timeline, no undo shown

**Decision quote.**
> 

**Triage.**

