# 15-008 · The full-screen general chat shows a third suggestion chip the Ask Vana sheet did not

- kind: followup-test
- status: closed
- ticket: 15
- run: w12-20260924T1712Z
- screen: Ask Vana sheet and full-screen general chat
- decision: 

**Steps.**
1. Signed in as test@test.com, Food > Plan, tap Ask Vana: the sheet opens a general conversation with its suggestion chips.
2. Expand the sheet to the full-screen general chat.

**Expected.**
The same conversation offers the same suggestions in the sheet and full screen, or the difference is deliberate and documented.


**Actual.**
The full-screen chat shows a third chip, "Pick my dinner and plan the rest of the week", that the sheet did not show. Not checked against the code: it may be a layout cut (the sheet has less room) or a different chip source. Retest: open both views on one conversation, list the chips, and read where each list comes from. Filed by the wave lead from ticket 15's notes.


**Evidence.**
- runs/15/06-vana-sheet.png: the sheet's chips
- runs/15/07-general-chat-full.png: the full-screen chat's chips, three

**Triage.**

Picked for retest ticket 88 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).

Closed by retest ticket 88 (run w29-20260925T1949Z, build e3367d2c): pass, evidence in runs/88/verdicts.md.
