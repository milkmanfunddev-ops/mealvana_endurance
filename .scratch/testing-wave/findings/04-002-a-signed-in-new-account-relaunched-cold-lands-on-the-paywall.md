# 04-002 · A signed-in new account relaunched cold lands on the paywall again

- kind: followup-test
- status: open
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

