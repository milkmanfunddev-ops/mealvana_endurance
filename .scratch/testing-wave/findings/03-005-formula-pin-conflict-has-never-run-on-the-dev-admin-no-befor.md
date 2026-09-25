# 03-005 · formula_pin_conflict has never run on the dev admin: no Before library formula conflicts with its allergies

- kind: followup-test
- status: triaged
- ticket: 03
- run: w3-20260923T1942Z
- screen: Formulas (pin)
- decision: 

**Steps.**
1. Give the Patrol account an allergy that a Before library formula contains (or pick an account
   that already has one), with a fresh Before formula to pin.
2. Run `integration_test/flows/formula_pin_conflict_flow_test.dart` with
   `--dart-define=PATROL_FAIL_ON_SKIP=true`.

**Expected.**
The pin warns about the allergy first, is honored, then carries the conflict label and unpins
(the flow's own assertions).

**Actual.**
Not run: as the dev admin it skipped at its precondition ("No Before formulas in the library for
this account — the pin feature has nothing to act on") and Patrol reported it passed (03-001).

**Evidence.**
- runs/03/device-suite-rest.log, the "No Before formulas in the library" line
- runs/03/patrol-suite-rest.log, formula_pin_conflict ✅ with 14 steps and no pin

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 92 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
Moved to retest ticket 116 when 92 was split (Lee, 2026-09-25).
