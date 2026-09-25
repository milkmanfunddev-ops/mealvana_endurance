# 03-006 · meal_plan_build's last leg (Ate it to a meal_logs row) was not reached: the first plan tile had no servings left

- kind: followup-test
- status: closed
- ticket: 03
- run: w3-20260923T1942Z
- screen: Food › Plan (tile sheet)
- decision: 

**Steps.**
1. Run `integration_test/flows/meal_plan_build_flow_test.dart` as an account whose plan has a
   meal with servings left (or a fresh plan), with `--dart-define=PATROL_FAIL_ON_SKIP=true`.
2. Consider making the flow try each plan tile until one offers "Ate it", instead of only the
   first.

**Expected.**
"Ate it" on a plan tile writes a `meal_logs` row with `plan_meal_id` set, read back by the probe.

**Actual.**
Not reached. As the dev admin the Plan tab already held a draft, so the flow skipped the chat leg
(no plan generated), confirmed it (Confirm disappeared: acked), opened Shopping, then found no
"Ate it" on the first tile ("every serving of this plan meal is already logged") and skipped,
which fail-on-skip turned into a failure. Confirming also archived the admin's other plans for
that week (mp-241), as the flow always does on its account.

**Evidence.**
- runs/03/patrol-batch6.log (steps 5 to 10: Confirm, Shopping, tile)
- runs/03/device-batch6.log, "Skipped, and this run does not allow skips: The tile sheet offers no \"Ate it\""

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 88 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).

Run by retest ticket 88 (run w29-20260925T1949Z, build e3367d2c): fail, filed as 88-017; closed here, the new Findings carry it.
