# 23-001 · Describe tab: the keyboard covers the Analyze button, only a thin strip of it shows above the keys

- kind: bug
- status: closed
- ticket: 23
- run: w13-20260924T1903Z
- screen: Log a Meal (Describe)
- decision: 

**Steps.**
1. Signed in as test@test.com, Timeline, + Add Food. Log a Meal opens on the Describe segment.
2. Tap "What did you eat?" and type a three-line description.

**Expected.**
The Analyze button stays reachable above the keyboard (the page scrolls it up), or the keyboard offers a way to dismiss it.

**Actual.**
The keyboard covers Analyze. The element list gives it a 14-pt tall visible frame (y 525-539) above the suggestion bar; the screenshot shows only the top edge of the orange button. The multiline field's return key inserts a new line, so it does not submit or dismiss. I pressed Analyze by tapping that 14-pt strip. An athlete with a longer description (the field grows to 6 lines) would see none of it.

**Evidence.**
- runs/23/07-described.png: typed description, keyboard up, Analyze hidden behind it.
- runs/23/06-add-food.png: the same screen before typing, Analyze at y 525-581.

**Triage.**
Fix ticket 52 (Lee, 2026-09-25). Closed by the retest after it merges.
Moved to retest ticket 118 when 93 was split (Lee, 2026-09-25).

Run by retest ticket 118 (run w36-20260926T0031Z, build 72d3723e): pass; Analyze stays visible above the keyboard with 3 and 6 lines typed.
