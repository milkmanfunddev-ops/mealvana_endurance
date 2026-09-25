# 73-001 · Use this plan again leaves an older conversation-less draft for the week live but hidden

- kind: bug
- status: closed
- ticket: 73
- run: w22-20260925T1215Z
- screen: Previous plans → earlier plan → Use this plan again
- decision: 

**Steps.**
1. From Previous plans, open an earlier plan and tap Use this plan again (makes a conversation-less draft for this week).
2. Go back, open another earlier plan and tap Use this plan again.

**Expected.**
The second copy replaces the first unconfirmed copy; the week never holds a live draft the athlete cannot reach.

**Actual.**
`usePlanAgain` in `_shared/vana/plan.ts` inserts a new week-level draft without archiving an existing conversation-less draft for the week. `getPlan` then shows the newest draft, and the older one stays live but hidden. Found in wave 22's review; code read.

**Evidence.**
- supabase/functions/_shared/vana/plan.ts (usePlanAgain → insertDraft)

**Decision quote.**
> 

**Triage.**
Fix ticket 75 (filed by the wave lead from wave 22's review, 2026-09-25). Closed by the retest after it merges.

Closed by retest ticket 89 (run w29-20260925T1950Z, build e3367d2c): pass, evidence in runs/89/verdicts.md. Side problems filed as 89-006.
