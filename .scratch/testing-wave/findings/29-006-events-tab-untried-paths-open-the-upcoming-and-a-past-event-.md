# 29-006 · Events tab untried paths: open the upcoming and a past event, New Event then back, on a cold start; console

- kind: followup-test
- status: triaged
- ticket: 29
- run: w16-20260924T2100Z
- screen: Events (My Events)
- decision: 

**Steps.**
1. Cold start, sign in, open Events.
2. Open IRONMAN Cozumel (upcoming) and Baton Rouge Half Marathon (past); back out of each.
3. Tap New Event (the sliver above the tab bar, 03-007), then back without saving.
4. Read the console.

**Expected.**
Each detail screen renders from a cold start with no exception line; backing out of New Event writes nothing.

**Actual.**
Not run. The run only looked at My Events' first screen (one upcoming, four past events), console clean.

**Evidence.**
- runs/29/10-events-tab.png

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 92 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
Moved to retest ticket 117 when 92 was split (Lee, 2026-09-25).
