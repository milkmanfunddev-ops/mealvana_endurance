# 117-005 · Timeline has no pull to refresh: an upstream workout change has no manual way in

- kind: idea
- status: triaged
- ticket: 117
- run: w40-20260926T1052Z
- screen: Timeline
- decision: 

**Steps.**
Idea, from 30-006 step 4 ("Pull to refresh after an upstream change"): the Timeline has no pull to refresh. A pull on today moved the list and did nothing else; no sync line in the console. `fuel_timeline` and `macro_dashboard` have no RefreshIndicator. An athlete whose coach moves a FinalSurge workout has no manual way to fetch it; the sync runs at sign-in and skips as "data is fresh" after that. Decide whether the Timeline should offer pull to refresh (a product question). Horizontal swipes between days also do nothing (no handler); same question.

**Expected.**
A way on the Timeline to fetch upstream workout changes now.

**Actual.**


**Evidence.**
- runs/117/17-today-pull-refresh.png

**Decision quote.**
> 

**Triage.**

Fix ticket 137, Timeline and activities (Lee, 2026-09-26). Ruling: pull-to-refresh on the Timeline syncs connected apps (137). Closed by the retest after it merges. Record: `triage-20260926.md`.
