# 18-009 · Browse from a conversation whose plan is archived or confirmed: Add writes into that plan (code read), check what the athlete sees

- kind: followup-test
- status: closed
- ticket: 18
- run: w16-20260924T2100Z
- screen: Browse meals
- decision: 

**Steps.**
1. Open the planning conversation whose plan is archived (d8efbdb3 -> 54a02440, or 1f805690 -> b82409d9), plus > Browse meals, "+" on a card.
2. Repeat from f6a0f7fa, whose plan be6abf2f is confirmed.
3. Check meal_plans / plan_meals / shopping_lists and the Plan and Shopping tabs after each.

**Expected.**
Browse either starts a fresh draft for an archived plan's conversation or tells the athlete the plan is archived; picking into a confirmed plan is an edit of that plan and rebuilds its list (mp-244). What the athlete sees matches.

**Actual.**
Not run (would have changed plans the w16 prompt protected). From the code, plan.ts getConversationPlan returns the conversation's newest non-deleted plan whatever its status, so Add writes into an archived plan and rebuilds its list, and from f6a0f7fa writes into the confirmed plan.

**Evidence.**
- runs/18/expected.md: the run decision and the code path.
- runs/18/db-00-before.txt: which conversation owns which plan.

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 88 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).

Run by retest ticket 88 (run w29-20260925T1949Z, build e3367d2c): fail, filed as 88-005; closed here, the new Findings carry it.
