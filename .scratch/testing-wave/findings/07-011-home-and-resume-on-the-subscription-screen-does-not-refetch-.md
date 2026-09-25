# 07-011 · Home and resume on the Subscription screen does not refetch the customer after a renewal

- kind: followup-test
- status: triaged
- ticket: 07
- run: w6-20260924T1118Z
- screen: Subscription
- decision: 

**Steps.**
1. A paid account opens Settings → Subscription.
2. Wait past a Test Store renewal (5 minutes).
3. Press Home, then resume the app.

**Expected.**
On resume the screen refetches the customer and shows the new renewal date (or the paywall, if Pro ended).

**Actual.**
At 11:38:47 Home and resume left the open Subscription screen as it was, with no refetch. Whether it should refetch on resume is untested; see 07-003 and 05-005 for the same resume question at the Gate. Written by the wave lead from the run's notes.

**Evidence.**
- runs/07/notes.md (11:38:47 entry)

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 107 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
Moved to retest ticket 123 when 107 was split (Lee, 2026-09-25).
