# 57: Harness scripts and tests read the world as it is

**Status:** in-progress (wave 19, 2026-09-25)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** `scripts/edge_logs.sh` uses the Management API's current `analytics/endpoints/logs` endpoint and treats a `message` body as a failure, never as "no rows". `ci_config_contract_test` matches Lee's 2026-08-21 ruling that `pr-validation` is PR-only (the test changes, not codemagic.yaml). Patrol's `TestConfig` has no stale default anon key: it reads the env file or fails with a clear message.

**Findings:** 05-006, 11-011, 02-007 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** none; the fix restores behaviour no decision disputes.

**Touches:** scripts/edge_logs.sh, test/shared/ci_config_contract_test.dart, integration_test/helpers/test_config.dart

- [ ] `edge_logs.sh` prints rows for a known function on dev.
- [ ] `ci_config_contract_test` green.
- [ ] Running Patrol with no env file fails fast with a clear message.
- [ ] codegen if annotations changed, `flutter analyze` and the suite green.

Next: /implement-lee testing-wave
