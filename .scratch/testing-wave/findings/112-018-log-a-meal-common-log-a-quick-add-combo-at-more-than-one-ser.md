# 112-018 · Log a Meal Common: log a quick-add combo at more than one serving, and search results offline

- kind: followup-test
- status: triaged
- ticket: 112
- run: w34-20260925T2320Z
- screen: Log a Meal (Common)
- decision: 

**Steps.**
1. Quick-add combo sheets have no servings stepper (Oatmeal + raisins, Eggs + toast); try to log a double portion from Common.
2. Search "egg" offline: the catalog and nutrition-product search call edge functions (search-catalog, search-nutrition-products).

**Expected.**
A way to log 2x a combo (or the tile says why not); offline search shows local matches and a clear message for the rest.

**Actual.**


**Evidence.**
- runs/112/13-common-oatmeal-sheet.png
- runs/112/29-search-egg.png

**Decision quote.**
> 

**Triage.**

Folded into the retest of its screen after the 2026-09-26 fix tickets (Lee, 2026-09-26: every follow-up test goes into the retests). Record: `triage-20260926.md`.
