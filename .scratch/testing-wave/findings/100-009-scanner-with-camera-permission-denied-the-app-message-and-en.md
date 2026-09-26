# 100-009 · Scanner with camera permission denied: the app message and Enter barcode

- kind: followup-test
- status: open
- ticket: 100
- run: w39-20260926T1013Z
- screen: Scan to Add Food
- decision: 

**Steps.**
1. Fresh install, Log a Meal > Scan barcode.
2. At the iOS camera prompt choose Don't Allow (or turn Camera off in Settings).

**Expected.**
The app-written message (ticket 98) with Search for the food instead and Enter, as for a device with no camera.

**Actual.**
Not run: this run chose Allow, so only the no-camera state was seen.

**Evidence.**
- runs/100/64-scanner-no-camera.png

**Decision quote.**
> 

**Triage.**

