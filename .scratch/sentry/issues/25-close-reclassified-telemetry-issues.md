# 25: Close reclassified telemetry issues

**What to build:** MEALVANA-ENDURANCE-AN, CD (MetricKit metrics), the `Slow operation:` set (AK, AP, AJ, AQ, BC, B0, AR, AM, BA, CT, CS, AW, D0, CV, AX and the dev set), C6, C8, B9, D2, BD, BG. Once ticket 11 ships, resolve these in Sentry with a note that the data now lives in logs, spans or warning events.

**Blocked by:** 11 Telemetry leaves the error quota

**Status:** done except the first-launch check (needs a build carrying ticket 11)

- [x] Every listed issue resolved in Sentry with the note (44 issues, `resolvedInNextRelease`, 2026-10-06)
- [ ] (owed: no build with ticket 11 has launched yet) No new `Slow operation:` or `MetricKit metric payload` event in the dev project after the first launch of the new build

## Done (2026-10-06, lead, Sentry API)

44 issues set to `resolvedInNextRelease` with a comment, not plain `resolved`: builds older than ticket 11 still
emit these messages, and a plain resolve would regress each group and fire the prod Regression alert on every
old-build launch. `resolvedInNextRelease` holds the group closed until the project sees a new release.

Prod (23): AN, CD (MetricKit metrics → logs); AK, AP, AJ, AQ, BC, B0, AR, AM, BA, CT, CS, AW, D0, CV, AX
(`Slow operation:` → perf.step spans, warning only above 10 s, fingerprint `[slow-operation, step]`); C6, C8
(→ `DashboardTargetsAnomaly`, fingerprint `[dashboard-targets, msg]`); BD, D2 (→ `DatabaseReset`,
`[database-reset, reason]`); B9, BG (typed `Report.degraded` warnings).
Dev (21): 5V, 80 (metrics), 5X (diagnostic, untyped form), the 15 `Slow operation:` groups (5W, 5Y, 63, 64,
66, 67, 68, 69, 6H, 6M, 6V, 7M, 94, 9V), 8E, 8F, 62, 6S.

Left OPEN on purpose: DEV-A5, A7 (`DatabaseReset`), A8, A9 (`DashboardTargetsAnomaly`) are the NEW typed
warning form from the 2026-10-06 dev run; they are the live signal, not the old noise.

Owed: after the first launch of a build carrying ticket 11, confirm no new `Slow operation:` or `MetricKit
metric payload` event in dev, and that the 44 groups did not regress.
