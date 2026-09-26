# 115-003 · First sign-in with the network cut: what Timeline, Recent, the Plan loading card and the Shopping spinner show when the first reads cannot answer

- kind: followup-test
- status: triaged
- ticket: 115
- run: w32-20260925T2219Z
- screen: Timeline, Log a Meal (Recent), Food (Plan, Shopping)
- decision: 

**Steps.**
1. Clear the app, sign in as test@test.com online.
2. Right after the sign-in lands, `netcut.sh on SCRATCH --relaunch UDID`.
3. Open + Add Food > Recent, then Food > Plan, then Shopping; wait 30 s on each.

**Expected.**
Each screen shows what is already local or says it cannot load; none sits on a spinner forever or shows "No plan yet" / "No shopping list" over data the server holds.


**Actual.**
Not run. Fix 46 added loading states that pass online (this run: 26-001, 19-004, 20-003, 16-003 all pass); nobody has seen what they do when the first read never answers. The Shopping tab showed a bare centred spinner for about 1-2 s online (16-cold-shopping-1s.png); offline it may stay there.


**Evidence.**
- runs/115/16-cold-shopping-1s.png — the Shopping spinner online.
- runs/115/06-food-plan-0s.png — the Plan loading card online.

**Decision quote.**
> 

**Triage.**

Folded into the retest of its screen after the 2026-09-26 fix tickets (Lee, 2026-09-26: every follow-up test goes into the retests). Record: `triage-20260926.md`.
