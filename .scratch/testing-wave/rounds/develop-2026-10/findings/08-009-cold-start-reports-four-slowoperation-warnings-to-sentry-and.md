# 08-009 · Cold start reports four SlowOperation warnings to Sentry, and deferred.notifications counts the time the permission prompt waits

- kind: bug
- status: closed
- ticket: 08
- run: w1-20261007T1105Z
- screen: none (startup)
- decision: 

**Steps.**
1. Part A first cold start on the leftover data (11:06:05Z), then the offline cold start (11:11:31Z).

**Expected.**
Startup work finishes within its thresholds, or a wait on the user is not reported as slow.

**Actual.**
First launch: deferred.notifications 10987 ms, deferred.revenuecat 14972 ms, dashboard.activities.background_sync 29200 ms, dashboard.integration_sync 29194 ms, each a degraded Sentry event. Offline launch: deferred.notifications 18145 ms, which spans the OS 'Would Like to Send You Notifications' prompt left on screen ~15 s until I tapped Don't Allow. Caveats: on the first launch the mobile MCP helper took the foreground at ~11:06:10Z and the app was in the background until 11:06:51Z; three wave simulators ran at once. So part of the first-launch numbers may be the environment, but the permission-prompt wait is counted as app slowness regardless.

**Evidence.**
- runs/08/console-redacted.log 'Slow operation:' lines
- runs/08/notes.md Part A timing caveat

**Decision quote.**
> 

**Triage.**
fix ticket: the deferred.notifications timer excludes the time the OS permission prompt is up; the four thresholds stay; ticket 17's retest on a lone simulator decides whether the other three are real

**Closed (wave 3, 2026-10-08).** retest passed in ticket 32 (runs/32/notes.md)
