# 113-005 · Log a Meal Manual: Save with an empty name shows nothing when the form is scrolled; the Name is required message sits above the view

- kind: bug
- status: open
- ticket: 113
- run: w40-20260926T1051Z
- screen: Log a Meal → Manual tab
- decision: 

**Steps.**
1. Follow-up 25-002 ("save with an empty name"). Log a Meal → Manual, nothing typed.
2. Scroll down to Save (it is below the fold on this simulator) and tap it (10:55Z).

**Expected.**
The athlete sees why nothing saved: the form scrolls to the name field, or the message shows near Save.

**Actual.**
Nothing visible happens. The validator does set "Name is required" under Meal name, but that field is scrolled out of view; it is seen only after scrolling back up. Nothing is saved (correct).

**Evidence.**
- runs/113/15-manual-empty-save.png (after Save: no message on screen)
- runs/113/16-manual-name-required.png (scrolled up: the message under Meal name)

**Decision quote.**
> 

**Triage.**
