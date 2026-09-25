# 14-005 · The New meal plan opener talks about last week's plan and last week's talk

- kind: idea
- status: wontfix
- ticket: 14
- run: w8-20260924T1418Z
- screen: Vana chat (New meal plan)
- decision: 

**Steps.**
1. Plan tab → New meal plan (14:22:03Z). 2. Read the opener (14:22:13Z).

**Expected.**
The server's own rule for this opener (`persona.ts` NEW_PLAN_OPENER) says: do not mention the existing plan and do not open a check-in or a debrief; build the new plan.

**Actual.**
The opener starts "You've got the Ironman in 60 days and a solid week behind you — all 6 planned meals happened last week" and ends "Last week we talked about your race concerns — this week's plan starts setting you up right." That reads as a debrief of last week's plan (f2c0bc78, 6 meals). Not an SSOT clash: it is the prompt's rule the model did not keep. Idea: check whether last week's plan belongs in the new-plan opener at all, or tighten the rule.

**Evidence.**
- runs/14/05-new-conversation-opener-only.png — the opener text.
- runs/14/db-after-pick.txt — the opener row carries metadata new_plan=true, opener=true.

**Decision quote.**
> 

**Triage.**

Won't fix as an app ticket (Lee, 2026-09-25): model behaviour, added to the Vana evals corpus as a scenario (ticket 94).
