# 11-011 · ci_config_contract_test is red at the wave base: the 'a push to develop runs the dev tests' check fails

- kind: bug
- status: closed
- ticket: 11
- run: w5-20260924T0840Z
- screen: none
- decision: 

**Steps.**
1. At cfa054c8 (wave 5 base), `flutter test test/shared/ci_config_contract_test.dart`.

**Expected.**
Green, or the check changed to match the current CI rule.

**Actual.**
`every deploy has a test gate on the same trigger a push to develop runs the dev tests as well as the dev build` fails: it expects `pr-validation` in codemagic.yaml to trigger on `push` to develop, but codemagic.yaml says PR-only ("PR-only (Lee, 2026-08-21): the every-push run doubled build minutes … add `- push` back here to restore"). The test looks stale against Lee's 08-21 ruling rather than the config being wrong; which one changes is triage's call. Found while checking this ticket's runner_exclusions.json change; the ticket's own change passes the file's other 14 checks. Not run as part of the full suite (the wave lead's job).

**Evidence.**
- test/shared/ci_config_contract_test.dart lines 201-227
- codemagic.yaml, `pr-validation` → `triggering.events`

**Decision quote.**
> 

**Triage.**
Fix ticket 57 (Lee, 2026-09-25). Closed by the retest after it merges.

Closed by the wave lead (2026-09-25): `flutter test test/shared/ci_config_contract_test.dart` at 5e05f8a6 passes all 15 checks (ticket 57).
