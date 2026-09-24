# 14-009 · New meal plan offline or with the opener failing

- kind: followup-test
- status: open
- ticket: 14
- run: w8-20260924T1418Z
- screen: Vana chat (New meal plan)
- decision: 

**Steps.**
1. Turn the network off. 2. Plan tab → New meal plan. 3. Also: network on but the vana-chat call failing or slow (for example a 403 or a timeout).

**Expected.**
The chat says it cannot reach Vana and offers a retry; no half conversation row or plan row is left on dev; the Plan tab is unchanged.

**Actual.**
Not run (followup).

**Evidence.**
- runs/14/03-new-meal-plan-opened-typing.png — the chat while the opener loads.

**Decision quote.**
> 

**Triage.**

