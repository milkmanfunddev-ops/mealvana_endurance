# 18-010 · Meal detail opened from Browse: heart (Save to mine), Team review, Start cooking, Add photo, See the original recipe, Swaps

- kind: followup-test
- status: closed
- ticket: 18
- run: w16-20260924T2100Z
- screen: Meal detail (opened from Browse)
- decision: 

**Steps.**
1. From Browse, open a card's detail (?pick=).
2. Try the heart (Save to mine), Good recipe / Not good and Send review (Team review, admin only), Start cooking, Add photo, See the original recipe, the Swaps icon, and Back from each.
3. After each, check that Browse still ticks only what Add to plan picked.

**Expected.**
Each control does its own thing without adding to the draft; Back returns to Browse with the filter kept.

**Actual.**
Not run in w16: only Back and Add to plan were used on the detail (18-001).

**Evidence.**
- runs/18/28-detail-from-browse.png: the detail's controls.

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 89 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).

Run by retest ticket 89 (run w29-20260925T1950Z, build e3367d2c): fail, filed as 89-009, 89-010, 89-014; closed here, the new Findings carry it.
