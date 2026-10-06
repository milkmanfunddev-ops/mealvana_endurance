# 11: Telemetry leaves the error quota

**What to build:** iOS MetricKit metric payloads arrive as structured logs instead of info events; MetricKit diagnostic payloads stay events. Slow-operation thresholds in the performance telemetry record span measurements on the existing startup and dashboard transactions instead of error events, and one warning event remains for a step over a 10-second ceiling. A Sentry dashboard widget shows p95 per startup step. The dashboard-targets and plan-generation anomaly messages stay as warning events.

**Blocked by:** 01 Report service exists

**Status:** ready-for-agent

- [ ] A fresh launch of a dev build produces no `MetricKit metric payload` event; the data is visible under Logs
- [ ] A MetricKit diagnostic payload still produces an event tagged `metrickit`
- [ ] A slow startup step appears as a measurement on the startup transaction; no `Slow operation:` event is produced below the ceiling; one warning event is produced above it
- [ ] A dashboard named for startup performance exists in the org with a p95-per-step widget
- [ ] Tests cover the ceiling boundary and the span emission through the transport
