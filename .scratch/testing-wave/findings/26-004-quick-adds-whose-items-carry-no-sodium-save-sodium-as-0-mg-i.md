# 26-004 · Quick adds whose items carry no sodium save sodium as 0 mg instead of unknown

- kind: bug
- status: triaged
- ticket: 26
- run: w13-20260924T1904Z
- screen: Log a Meal (Common, Recent) → quick log sheet
- decision: 

**Steps.**
1. Log "Oatmeal + raisins" from Common (its two items have no sodium value in `kQuickAssemblies`).
2. Re-log "Rice cake and Almond butter" from Recent (the source's items have no sodium; the source row itself already says 0.0).
3. Read `sodium_mg` on both new rows.

**Expected.**
An unknown sodium stays unknown (null), as the repo's nutrition rule "null ≠ 0" asks, so the day's sodium total does not look complete when it is not.

**Actual.**
Row f952f981 has `sodium_mg 0.0` although neither item has a sodium value; row 00a120e5 has `sodium_mg 0.0` and its synthetic item now carries `"sodium_mg": 0`, turning the unknown into a stated zero inside the items too. The totals come from summing the items with a missing value counted as 0. The recipe row (46b1d076) had a real sodium value (450) and kept it.

**Evidence.**
- runs/26/db-meal-logs.txt (rows f952f981 and 00a120e5, items and sodium_mg)

**Decision quote.**
> 

**Triage.**
Fix ticket 41 (Lee, 2026-09-25). Closed by the retest after it merges.
