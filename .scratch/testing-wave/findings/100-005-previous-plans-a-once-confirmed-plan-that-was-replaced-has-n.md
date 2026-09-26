# 100-005 · Previous plans: a once-confirmed plan that was replaced has no tag, so this week's two rows look alike

- kind: idea
- status: wontfix
- ticket: 100
- run: w39-20260926T1013Z
- screen: Previous plans (sheet)
- decision: 

**Steps.**
1. test@test.com, Food > Plan > ⋮ > Previous plans.

**Expected.**
Each row says enough to tell this week's earlier plans apart.

**Actual.**
The two Sep 20 rows read "Sep 20 – Sep 26 · 1 meal" and "Sep 20 – Sep 26 · 5 meals", no tag. Both were confirmed once (666be167 at 09-25 20:28, be6abf2f on 09-24) and then replaced by a later confirm; ticket 97 tags only status confirmed. Idea: tag them "Replaced" or show the confirm date or the first meal names, as 17-004 suggested.

**Evidence.**
- runs/100/48-previous-plans.png
- runs/100/db-test-plans-start.txt

**Decision quote.**
> 

**Triage.**

Won't fix (Lee, 2026-09-26): plans are not really weeks; leave it. The next retest checks that deleting an older, replaced plan from Previous plans works.
