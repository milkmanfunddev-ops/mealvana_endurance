# 28-006 · The barcode button in the Log search bar has no accessibility label

- kind: bug
- status: triaged
- ticket: 28
- run: w15-20260924T2040Z
- screen: Log — Sep 23 (search bar); Build a Meal → Add food (search bar)
- decision: 

**Steps.**
1. Open Log — Sep 23. Read the accessibility tree (`idb ui describe-all`).
2. Same on Build a Meal → + Add food.

**Expected.**
The orange barcode icon at the right of "Search anything to add..." is a button with a label such as "Scan barcode", so VoiceOver users can find it.

**Actual.**
The tree lists the search TextField, the tabs and the other buttons, but no element for the barcode icon (nor for the round search button next to it); the run had to tap it by screen position (314, 153). The scanner's own flash, Reset and Switch buttons are also absent as buttons (only the "Reset" and "Switch" captions appear as text).

**Evidence.**
- runs/28/06-add-food-sep23.png
- runs/28/18-build-add-food.png
- runs/28/notes.md

**Decision quote.**
> 

**Triage.**
Fix ticket 51 (Lee, 2026-09-25). Closed by the retest after it merges.
Moved to retest ticket 118 when 93 was split (Lee, 2026-09-25).
