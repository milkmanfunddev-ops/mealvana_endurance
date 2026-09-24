# 27-004 · Timeline meal row Edit food / Remove: untried Undo, remove offline, remove then kill before upload, a second phone, rows with items

- kind: followup-test
- status: open
- ticket: 27
- run: w15-20260924T2039Z
- screen: Timeline (meal row ⋯ → Edit food / Remove, Meal deleted snackbar)
- decision: 

**Steps.**
1. Timeline → Meals → a meal row's ⋯ expands Edit food and Remove inline. Remove deletes at once (no confirm) and shows "Meal deleted · Undo".

**Expected.**
Paths not run in ticket 27, each to check against the timeline, the totals and dev meal_logs:
- Undo on the snackbar: the row comes back (restoreLog), is_deleted false on the server, totals back up.
- Remove with the network cut (netcut): row gone locally, needs_upload kept, tombstone uploaded after netcut off; totals right throughout.
- Remove, then kill the app within a second (before the immediate upload): does the row come back on relaunch from the server?
- The same account on a second phone: the edit and the delete show there after its sync (tombstones propagate).
- Edit food / Remove on a row with items (built bowl ae7dba02 is another run's evidence, so make a new one), a photo row, a recipe row.
- Tap ⋯ on two rows in turn: does only one stay expanded? Scroll while expanded.
- Remove the last meal of a day: empty state and totals 0.

**Actual.**
Not run (out of ticket 27's scope). Only the plain edit and plain remove were run; both passed.

**Evidence.**
- runs/27/16-row-menu-edit.png
- runs/27/21-after-remove-tap.png

**Decision quote.**
> 

**Triage.**
