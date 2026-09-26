# 118-015 · Barcode scanner without a camera: Enter a barcode by hand, Search for the food instead, and Don't Allow on the camera prompt

- kind: followup-test
- status: triaged
- ticket: 118
- run: w36-20260926T0031Z
- screen: Scan to Add Food
- decision: 

**Steps.**
1. Build a Meal → + Add food → Scan barcode; on a fresh install answer Don't Allow.
2. With camera allowed, use Enter with a known barcode, then Search for the food instead.

**Expected.**
Don't Allow explains how to turn the camera on; a typed barcode finds the food; the link opens search.

**Actual.**
Not run (look-around, ticket 118).

**Evidence.**
- runs/118/52-scanner-open.png

**Decision quote.**
> 

**Triage.**

Folded into the retest of its screen after the 2026-09-26 fix tickets (Lee, 2026-09-26: every follow-up test goes into the retests). Record: `triage-20260926.md`.
