# 88-008 · The Plan tab's Add meal and New meal plan buttons sit under the floating tab bar

- kind: bug
- status: open
- ticket: 88
- run: w29-20260925T1949Z
- screen: Food > Plan
- decision: 

**Steps.**
1. Food > Plan with a 4-meal plan (20:08:12Z). Look for Add meal and New meal plan.
2. Scroll to the end of the page (20:08:45Z).

**Expected.**
Both buttons can be seen and tapped above the tab bar.

**Actual.**
Unscrolled, both buttons are fully behind the floating tab bar; a tap at their place hit the Learn tab (20:08:13Z). Scrolled to the end, they still sit half under the tab bar. With 1–2 meals they sit higher and show.

**Evidence.**
- runs/88/53-food-plan-before-new-plan.png: buttons hidden, only an orange edge shows beside Learn.
- runs/88/57-food-plan-scrolled.png: scrolled to the end, buttons half covered.

**Decision quote.**
> 

**Triage.**
