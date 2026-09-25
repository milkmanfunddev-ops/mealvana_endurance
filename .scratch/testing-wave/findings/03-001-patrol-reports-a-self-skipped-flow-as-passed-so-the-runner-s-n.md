# 03-001 · Patrol reports a self-skipped flow as passed, so the runner's no-skip check never fired

- kind: bug
- status: wontfix
- ticket: 03
- run: w3-20260923T1942Z
- screen: none
- decision: 

**Steps.**
1. Run any flow whose precondition is missing, so it calls `markTestSkipped` and returns (here:
   every credentialed flow as the lapsed integration-test account, 03-003, which sits on the
   paywall where `ensureAuthenticated` finds neither the shell nor the welcome screen).
2. Read `patrol test`'s summary, which is what `.github/workflows/tests-selfhosted.yml`'s
   "Assert the suite actually ran" step greps.

**Expected.**
A skipped flow is counted under `Skipped:` (or fails), so the runner's "a skip is not a pass"
check stops the job.

**Actual.**
Patrol 4.10.0's native harness reports it as passed: `✅ … (103s)`, `Successful: 8`,
`Skipped: 0`. In suite attempt 2 all eight "passes" (activities_crud to formula_create_pin) ran
one Patrol step each, the permission-dialog check, and took ~103 s: 10 s of prompt wait plus
`ensureAuthenticated`'s 90 s poll, then a skip. Nothing behind the login was tested. The same
happened to ai_coach_chat (device log: "Mealvana AI entry not available …", summary ✅) and to
formula_pin_conflict as the dev admin ("No Before formulas in the library …", summary ✅). The
runner's skip guard has therefore never been able to fire on this toolchain.

Test code, fixed in this ticket: flows call `skipFlow(reason)` (helpers/flow_launcher.dart),
which fails instead of skipping under `--dart-define=PATROL_FAIL_ON_SKIP=true`, and the runner
passes that define. Left open for triage because every green Patrol result before this commit
is suspect, and the fix only covers flows that go through `skipFlow`.

**Evidence.**
- runs/03/patrol-suite.log (attempt 2: each ✅ flow has one step and ~103 s)
- runs/03/device-batch3.log, the "Mealvana AI entry not available" line beside a ✅ in
  runs/03/patrol-batch3.log
- runs/03/device-suite-rest.log, "No Before formulas in the library" beside formula_pin_conflict's
  ✅ in runs/03/patrol-suite-rest.log

**Decision quote.**
> 

**Triage.**

Won't fix (Lee, 2026-09-25): fixed in wave 3 (`PATROL_FAIL_ON_SKIP`, `skipFlow()`), and Patrol left the testing waves on 2026-09-24.
