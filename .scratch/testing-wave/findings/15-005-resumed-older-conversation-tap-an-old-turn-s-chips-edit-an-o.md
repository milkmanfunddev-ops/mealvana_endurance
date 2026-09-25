# 15-005 · Resumed older conversation: tap an old turn's chips, Edit an old user turn, and change servings on an archived Draft

- kind: followup-test
- status: closed
- ticket: 15
- run: w12-20260924T1712Z
- screen: Vana chat (meal planning), opened from Conversations
- decision: 

**Steps.**
1. Open an older conversation whose Draft is archived (`ebac747d`) and one whose plan is confirmed (`1a24f2bf`).
2. Tap a chip on an old turn (for example "Dinners only" under turn 5, "That's my week" under turn 3, "Lean on what worked last week" under the opener).
3. Tap Edit under an old user turn.
4. In the expanded plan bar, tap + on a meal, then × on a meal.
5. Tap a meal card's checkbox on an old turn.
6. After each, read vana_messages, meal_plans (status, updated_at) and plan_meals for both conversations and the week's confirmed plan. Needs `COST spend` first: a chip or Edit sends a turn to Vana.

**Expected.**
Old chips on a finished turn either do nothing or send a new turn that is scoped to this conversation. Edits never change an archived plan in place and never touch the week's confirmed plan; if editing an archived Draft is allowed, it says what happens (per mp-241, a fresh Draft for this conversation).

**Actual.**


**Evidence.**
- runs/15/14-ebac747d-scroll-4.png — live chips and Edit on old turns.
- runs/15/17-ebac747d-plan-bar-expanded.png — -/+ and × on the archived Draft.

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 88 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).

Closed by retest ticket 88 (run w29-20260925T1949Z, build e3367d2c): pass, evidence in runs/88/verdicts.md. Side problems filed as 88-003.
