# 29-004 · Cold start untried path: switch tabs within a second of sign-in, before the first sync ends; console and each tab's first screen

- kind: followup-test
- status: triaged
- ticket: 29
- run: w16-20260924T2100Z
- screen: Timeline, Food
- decision: 

**Steps.**
1. Clear the app's data and cold start; log in as test@test.com.
2. Tap Food within a second of the Timeline appearing, before the first sync-all-data / FinalSurge sync finishes; then Events and Learn.
3. Read the console.

**Expected.**
No "setState() called after dispose", no provider "Bad state" and no exception line while the first sync races the tab switch; each tab fills in when the sync ends.

**Actual.**
Not run. In this run each tab was opened after the first sync had finished (21:03:47Z, about 1m45s after login), so the race was never tested.

**Evidence.**
- runs/29/notes.md

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 92 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
