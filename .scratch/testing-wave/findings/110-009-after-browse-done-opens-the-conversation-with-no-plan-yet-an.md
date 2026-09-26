# 110-009 · After Browse, Done opens the conversation with No plan yet and Your plan 0 meals though its draft holds the pick

- kind: bug
- status: triaged
- ticket: 110
- run: w30-20260925T2103Z
- screen: Vana chat (meal planning)
- decision: 

**Steps.**
1. Open Browse for planning conversation 7cc15497 (deep link /vana/browse?c=7cc15497-...; the conversation had no plan).
2. + on Sweet rice cake with jam (21:24:12Z): draft 9be88811 is made for 7cc15497 with that meal x4.
3. Tap Done (21:24:47Z).

**Expected.**
The chat's header and plan bar show the draft with its one meal.

**Actual.**
The header reads "No plan yet" and the plan bar "Your plan · 0 meals — Tap a meal above and it lands here." 8 s later still the same. The DB has the meal on 9be88811. Possibly the same cause as 88-002 (Conversations rows read No plan yet), seen here inside the chat.

**Evidence.**
- runs/110/68-after-done.png — chat right after Done.
- runs/110/69-chat-after-done-8s.png — 8 s later.
- runs/110/db-11-after-browse-add.txt — draft 9be88811 with conversation 7cc15497.

**Decision quote.**
> 

**Triage.**

Fix ticket 134, Meal plans and Vana (Lee, 2026-09-26). Closed by the retest after it merges. Record: `triage-20260926.md`.
