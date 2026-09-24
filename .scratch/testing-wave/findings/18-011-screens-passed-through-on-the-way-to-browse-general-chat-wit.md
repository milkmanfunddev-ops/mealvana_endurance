# 18-011 · Screens passed through on the way to Browse: general chat with no plus, Review plan on an old conversation's draft, Plan tab note card, Shopping tab after a browse pick

- kind: followup-test
- status: open
- ticket: 18
- run: w16-20260924T2100Z
- screen: Vana chat (general and planning), Food (Plan and Shopping sub-tabs)
- decision: 

**Steps.**
1. Vana general chat (Plan tab note card "Ask Vana anything"): its composer has no plus, so Browse is planning-only; check whether a general question that names a meal offers a way to Browse, and what the header's New conversation and Conversations do.
2. Planning chat 0401b3d8 after the browse picks: tap the plan bar and Review plan; see whether Confirm is offered for a draft in a week that already has confirmed be6abf2f, and what Confirm would archive (mp-241). Do not confirm on the shared account.
3. Tap the old conversation's opener chips (Batch cook, Cook most nights, Repeat what worked last week, Show me what you usually eat): which ones are fixed chips (no model call) and which spend a chat or a plan.
4. Food > Shopping after a pick into draft 173cebb2: Previous lists, List options, Shop with Kroger on a draft's list.
5. The Ask Vana FAB sits under the debug "Open testing tools" button: tap it at its lower edge and check it opens the day's sheet.

**Expected.**
Each step behaves as its decision says; no plan is generated unless the step is meant to; console clean.

**Actual.**
Not run in w16 (outside ticket 18's one screen).

**Evidence.**
- runs/18/09-vana-sheet.png: the general chat with no plus.
- runs/18/39-chat-after-done-5s.png: plan bar with Review plan.
- runs/18/44-shopping-after.png: Shopping tab on the draft's list.

**Decision quote.**
> 

**Triage.**

