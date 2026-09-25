# 04-002 · A signed-in new account relaunched cold lands on the paywall again

- kind: followup-test
- status: triaged
- ticket: 04
- run: w4-20260924T0418Z
- screen: Paywall
- decision: 

**Steps.**
1. Sign up a new account and reach the paywall.
2. Kill the app (swipe away or `simctl terminate`) and launch it again.
3. Also: background it for a minute and bring it back.

**Expected.**
mp-457: the app opens on the paywall again, still signed in, with no close button, and never shows
a tab or the timeline for a frame first.

**Actual.**
Not run (look-around, ticket 04).

**Evidence.**
- runs/04/14-paywall.png (the state to start from)

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 107 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
Moved to retest ticket 121 when 107 was split (Lee, 2026-09-25).
