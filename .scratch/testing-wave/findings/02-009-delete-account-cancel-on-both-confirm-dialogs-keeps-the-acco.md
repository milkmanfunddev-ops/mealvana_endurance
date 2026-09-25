# 02-009 · Delete account → Cancel on both confirm dialogs keeps the account and its session

- kind: followup-test
- status: triaged
- ticket: 02
- run: w2-20260923T1442Z
- screen: Paywall
- decision: 

**Steps.**
1. Paywall ⋯ → Delete account → Cancel. 2. Settings → Delete Account → Cancel. 3. Tap outside each dialog instead of Cancel.

**Expected.**
Nothing is deleted; the athlete stays where they were; footprint unchanged.

**Actual.**
Not run (look-around, ticket 02).

**Evidence.**
- runs/02/notes.md

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 109 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
