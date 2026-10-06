# 25: Close reclassified telemetry issues

**What to build:** MEALVANA-ENDURANCE-AN, CD (MetricKit metrics), the `Slow operation:` set (AK, AP, AJ, AQ, BC, B0, AR, AM, BA, CT, CS, AW, D0, CV, AX and the dev set), C6, C8, B9, D2, BD, BG. Once ticket 11 ships, resolve these in Sentry with a note that the data now lives in logs, spans or warning events.

**Blocked by:** 11 Telemetry leaves the error quota

**Status:** ready-for-agent

- [ ] Every listed issue resolved in Sentry with the note
- [ ] No new `Slow operation:` or `MetricKit metric payload` event in the dev project after the first launch of the new build
