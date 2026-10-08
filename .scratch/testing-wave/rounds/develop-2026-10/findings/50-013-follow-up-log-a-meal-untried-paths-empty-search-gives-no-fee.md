# 50-013 · Follow-up: Log a Meal untried paths (empty Search gives no feedback, barcode Enter, start from saved meal, Describe offline)

- kind: followup-test
- status: open
- ticket: 50
- run: w5-20261008T1720Z
- screen: Log a Meal
- decision: 

**Steps.**
1. Header Search with an empty field: today nothing happens and nothing says why (m05). Search with text.
2. Scan barcode → Enter: type a known barcode; an unknown one.
3. Build a meal → Start from a saved meal / recent, then Back without saving.
4. Describe tab offline (credit counter visible: is a credit spent on a failed call?). Needs a COST spend.

**Expected.**
Clear states, nothing written unless saved, no credit spent on a call that failed.

**Actual.**
Not run (only the screens were opened; see notes Check 9).

**Evidence.**
- runs/50/m01-log-meal-sheet.png the sheet header
- runs/50/m04-scan-camera-denied.png camera denied state
- runs/50/m05-search-empty.png empty search, no change

**Decision quote.**
> 

**Triage.**

