# 68-010 · Retest of 50-013: Log a Meal header Search with an empty field gives no feedback (button or keyboard submit)

- kind: bug
- status: open
- ticket: 68
- run: w7-20261008T2309Z
- screen: Log a Meal (header search)
- decision: 

**Steps.**
1. Log a Meal opened (Describe tab showing).
2. Tapped the Search (magnifier) button with an empty field.
3. Tapped into the field and pressed Return.

**Expected.**
Some feedback: a hint to type a food, a focus with the keyboard, or a message.


**Actual.**
Nothing visible happens either way; the screen stays as it was, no console line.


**Evidence.**
- runs/68/12a-empty-search-tap.png: after the Search tap.
- runs/68/12b-empty-search-submit.png: after Return.

**Decision quote.**
> 

**Triage.**

