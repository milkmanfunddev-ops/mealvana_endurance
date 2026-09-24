# 09-003 · The dev meal library's salmon salad (AD-001) shows a striped test photo credited Photo by Lee (ticket 05 live check) in every athlete's plan

- kind: bug
- status: open
- ticket: 09
- run: w7-20260924T1219Z
- screen: Food (Plan tab), Review plan
- decision: 

**Steps.**
1. Account D confirms a Vana plan at 12:34:36Z. The plan holds "Salmon, quinoa, asparagus & spinach salad" (meal library id AD-001).
2. Look at its thumbnail on Review plan and on the Plan tab.

**Expected.**
A real dish photo or no photo (ADR 0003, "dish or nothing").

**Actual.**
The thumbnail is a green and brown striped test pattern. Its accessibility label is "Photo by Lee (ticket 05 live check)". On dev, `meal_library.photo_credit` for AD-001 is that string and `meal_photo_history` has the row from 2026-09-16 12:24Z (meal imagery ticket 05's live check). The test photo was never taken back out, so every dev athlete whose plan includes AD-001 sees it. Dev data, not prod, but it makes every later plan screenshot on dev misleading.

**Evidence.**
- runs/09/16-review-plan.png, runs/09/17-after-confirm.png
- runs/09/db-test-photo-credit.txt

**Decision quote.**
> 

**Triage.**

