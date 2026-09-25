# 89-006 · Use this plan again copy cannot be reached again once the athlete leaves it

- kind: bug
- status: triaged
- ticket: 89
- run: w29-20260925T1950Z
- screen: Earlier plan view > ⋮ > Use this plan again
- decision: 

**Steps.**
1. test@test.com with this week's plan confirmed (be6abf2f). Plan ⋮ > Previous plans > Sep 6 – Sep 12 > ⋮ > Use this plan again (20:10:36Z).
2. The view switches to the copy, "Sep 20 – Sep 26 · 4 meals" (1192963b, a draft with no conversation), with its Confirm at the bottom.
3. Tap Back, then look for the copy: the Plan tab, Previous plans, Conversations.

**Expected.**
mp-675: "Use this plan again" copies an earlier plan into this week as a new draft; confirming that draft replaces this week's plan. The athlete can come back to that draft to confirm it later.

**Actual.**
After Back the copy is nowhere: the Plan tab keeps the confirmed plan (`getPlan` prefers confirmed), Previous plans lists only plans that were confirmed (mp-677), and the copy has no conversation. It stays a live draft in the database that the athlete cannot open, the state 73-001 was about, one level up. Ticket 88's confirm at 20:21:43Z archived it. 73-001 itself holds: the second copy archived the first (9598807a). Product question: where should a Use this plan again copy live once the athlete leaves it (the Plan tab as a pending draft, the Previous plans list, a conversation)?

**Evidence.**
- runs/89/46-73-001-use-again-2.png: the copy's view.
- runs/89/47-plan-tab-after-use-again.png: the Plan tab still on be6abf2f.
- runs/89/45-after-use-again-back.png: Previous plans without the copy.
- runs/89/db-04-after-use-again.txt: 1192963b draft, no conversation.

**Decision quote.**
> 

**Triage.**

Held for the SSOT pass (Lee, 2026-09-25): a product question, no ticket until it is ruled on the page.
