# 49-002 · Describe's field errors are cut to one line with an ellipsis: "like what you at…", "Describe what …"

- kind: bug
- status: triaged
- ticket: 49
- run: w5-20261008T1719Z
- screen: Log a Meal (Describe tab)
- decision: 

**Steps.**
1. Timeline -> + Add Food -> Describe. Type "egg" (3 characters; iOS capitalises it to "Egg").
2. Tap Analyze (17:26:14Z).

**Expected.**
The whole line from content, `meal_log.describe.too_short` with n=5: "Add a bit more: at least 5 characters, like what you ate and how much.", readable on screen.

**Actual.**
The field's error shows one line, "Add a bit more: at least 5 characters, like what you at…", cut with an ellipsis. The accessibility label carries the full sentence, so the text is right and the error line's max lines (one) cuts it on a 402 pt wide iPhone 17 Pro. The minimum (5) is still visible, so ticket 45 item 5 holds (PASS 31-007 in notes); only the "what you ate and how much" half is lost. The not-food line (content key meal_log.describe.not_food) is cut the same way at 17:33:36Z: "That doesn't sound like food or drink. Describe what …".

**Evidence.**
- runs/49/10-short-input.png — the error line ends "like what you at…"
- runs/49/38-gallery-open.png — the same cut on the not-food line: "That doesn't sound like food or drink. Describe what …"

**Decision quote.**
> 

**Triage.**
