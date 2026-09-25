# 88-016 · Confirm shows no you're set card, share or reminder chip, and Confirm from the Plan tab stays on Plan

- kind: ssot-conflict
- status: open
- ticket: 88
- run: w29-20260925T1949Z
- screen: Review plan sheet > Food > Shopping
- decision: mp-235

**Steps.**
1. Draft 8ebeb6da in `449da56d`: Review plan > Confirm plan (20:21:41Z). Screenshots at 1, 3, 6, 10 s.
2. Later, draft 666be167: Food > Plan > "Confirm plan · build shopping list" (20:28:08Z).

**Expected.**
mp-235: a "you're set" card with the week, cooking sessions, list size and where things live, a plain-text share and a "remind me the night before cook day" chip, then chips Open shopping list / Lay it across the week / Adjust; the athlete lands on Food > Shopping with the tab bar there.

**Actual.**
Step 1 lands on Food > Shopping (router `/main?tab=food&food=shopping`), which fixes 16-002's landing; but no "you're set" card, share or reminder chip appears at any point, the chat is left straight from the Review sheet, and the tab bar shows collapsed to a small Food bubble (tap to expand). Step 2 confirmed 666be167 and stayed on Food > Plan with no card and no Shopping landing. 16-002 recorded the missing card too; its fix ticket (72) covered only the landing.

**Evidence.**
- runs/88/98-confirm-1s.png, runs/88/99-confirm-3s.png, runs/88/101-confirm-10s.png: sheet, then Shopping; no card.
- runs/88/105-food-plan-tabbar-state.png: collapsed tab bar.
- runs/88/116-14-007-confirm-from-plan-tab-2s.png, runs/88/117-14-007-confirm-from-plan-tab-7s.png: Plan tab confirm stays on Plan.
- runs/88/console-redacted.log: `going to /main?tab=food&food=shopping` at 15:21:4x local.

**Decision quote.**
> Confirm shows a "you're set" card with the week, the cooking sessions, the size of the list and where things live, plus a plain-text share and a "remind me the night before cook day" chip; no calendar, email or PDF in the first version. The athlete lands on the main screens with the Food tab's Shopping part open, so the tab bar is there. The chips after it are Open shopping list, Lay it across the week and Adjust; laying it across shows read-only day cards, and an athlete who never taps it keeps the plan as a set of meals with servings. Example: an athlete confirms, taps the reminder chip, lands on Food > Shopping with the tab bar showing, and never lays the plan across the week, so it stays a set of meals with no days attached.

**Triage.**
