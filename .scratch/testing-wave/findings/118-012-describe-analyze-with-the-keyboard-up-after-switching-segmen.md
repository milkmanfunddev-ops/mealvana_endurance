# 118-012 · Describe: Analyze with the keyboard up after switching segments, rotating the text size to the 1.6 cap, and a 12-line description

- kind: followup-test
- status: open
- ticket: 118
- run: w36-20260926T0031Z
- screen: Log a Meal (Describe)
- decision: 

**Steps.**
1. Timeline → + Add Food → Describe; set text size to the cap (testing tools).
2. Type 12 lines; switch to Manual and back with the keyboard up.
3. Check Analyze's frame each time (do not press it without a logging spend).

**Expected.**
Analyze stays visible and hit-testable above the keyboard in every case.

**Actual.**
Not run (look-around, ticket 118).

**Evidence.**
- runs/118/48-describe-six-lines.png

**Decision quote.**
> 

**Triage.**
