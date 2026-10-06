# 10: Contract: old services deleted

**What to build:** The logger, the debug logger, the in-memory debug log storage and the old Sentry reporter no longer exist as separate things, nor do any aliases on `Report`. The debug screen's log view reads from `Report`. The guard's allow-list has no baseline section left, only reasoned entries. The Sentry SDK is imported in exactly two places.

**Blocked by:** 02 One bootstrap; 03 Riverpod net; 05, 06, 07, 08, 09 Migrate batches

**Status:** ready-for-agent

- [ ] `AppLogger`, `PrettyAppLogger`, `DebugLogger`, `DebugLogStorage`, `SentryReporter` and their providers are deleted; no alias method remains on `Report`
- [ ] The debug screen still shows recent log lines, now sourced from `Report`
- [ ] The guard allow-list has no baseline section; every remaining entry has a reason
- [ ] Sentry SDK imports exist only in the service and the bootstrap
- [ ] Full suite green; analyzer clean; no dead file references in docs
