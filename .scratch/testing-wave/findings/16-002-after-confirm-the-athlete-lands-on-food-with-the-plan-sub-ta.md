# 16-002 · After Confirm the athlete lands on Food with the Plan sub-tab open, not Shopping

- kind: ssot-conflict
- status: triaged
- ticket: 16
- run: w9-20260924T1446Z
- screen: Food (Plan / Shopping sub-tabs)
- decision: mp-235

**Steps.**
1. In a meal-plan conversation, Review plan → Confirm plan (14:53:12.9Z).
2. The app navigates; the console logs `GoRouter: INFO: going to /main?tab=food&food=shopping` at 09:53:16 local.
3. Look at the screen (14:53:21Z).

**Expected.**
The Food tab opens on its Shopping part with the tab bar showing (mp-235), after a "you're set" card.

**Actual.**
The Food tab opens with the Plan sub-tab selected and the tab bar showing. The router target says `food=shopping`, so the sub-tab query is not applied. No "you're set" card, no share, reminder chip or "Open shopping list / Lay it across the week / Adjust" chips were shown. This is the second run to see it: 09-007 (followup-test, wave 7) logged the same route and the same Plan sub-tab; this run confirms it as a conflict with mp-235.

**Evidence.**
- runs/16/console-excerpts.log — line 32517, `going to /main?tab=food&food=shopping`.
- runs/16/08-after-confirm-8s.png — Food with the Plan sub-tab selected.

**Decision quote.**
> Confirm shows a "you're set" card with the week, the cooking sessions, the size of the list and where things live, plus a plain-text share and a "remind me the night before cook day" chip; no calendar, email or PDF in the first version. The athlete lands on the main screens with the Food tab's Shopping part open, so the tab bar is there. The chips after it are Open shopping list, Lay it across the week and Adjust; laying it across shows read-only day cards, and an athlete who never taps it keeps the plan as a set of meals with servings. Example: an athlete confirms, taps the reminder chip, lands on Food > Shopping with the tab bar showing, and never lays the plan across the week, so it stays a set of meals with no days attached.

**Triage.**

Fix ticket 72 (Lee, 2026-09-25). Closed by the retest after it merges.
