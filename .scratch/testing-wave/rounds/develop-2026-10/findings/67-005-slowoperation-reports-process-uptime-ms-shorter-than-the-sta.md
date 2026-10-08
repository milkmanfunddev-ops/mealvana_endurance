# 67-005 · SlowOperation reports process_uptime_ms shorter than the startup it measured (6132 ms vs 11860 ms)

- kind: bug
- status: open
- ticket: 67
- run: w7-20261008T2308Z
- screen: none
- decision: 

**Steps.**
1. Cold-boot the simulator (here: after it shut down, 67-007) and launch the app signed in anonymously.

**Expected.**
A SlowOperation record whose `process_uptime_ms` is at least the measured duration, so triage can tell a cold process from a slow step.

**Actual.**
Console 18:15:31 local (23:15:31Z): `⚠️ [performance] Slow operation: startup.total` with `Data: {operation: startup.total,
duration_ms: 11860, process_uptime_ms: 6132}`, then `error_reported {severity: degraded, area: performance, exception_type:
SlowOperation, sentry_event_id: a9e66bbf54f54a4088d40fb3d8bb1e46}`; dev Sentry has it (user e482a890, 23:15:31Z). The launch
command ran ~23:14:37Z, so the process was ~54 s old. `PerformanceTelemetry._processUptime` is a static `Stopwatch()..start()`
(`performance_telemetry.dart:35`), which starts on the class's first use, not at process start, so the field misreports uptime.
The slowness itself is known noise: a cold simulator boot, and another simulator logged the same (11733 ms, 23:16:32Z).

**Evidence.**
- runs/67/console-redacted.log
- runs/67/sentry-67.md

**Decision quote.**
> 

**Triage.**

