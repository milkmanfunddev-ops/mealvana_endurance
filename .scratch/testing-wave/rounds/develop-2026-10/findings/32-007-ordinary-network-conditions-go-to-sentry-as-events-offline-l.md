# 32-007 · Ordinary network conditions go to Sentry as events: offline login (x2), offline cold start, a 2 s region timeout online, and an offline lesson as severity fault

- kind: bug
- status: open
- ticket: 32
- run: w3-20261008T1256Z
- screen: none (startup, Log In, lesson player)
- decision: 

**Steps.**
1. Signed out, cold start offline (netcut), then Log In with email offline.
2. Signed in, open a Learn lesson offline.
3. Cold launch online with three wave simulators running.

**Expected.**
An athlete being offline, or a 2 s geo lookup timing out with a fallback, is a breadcrumb or a handled
state, not a Sentry event (D9 asks for a PROD-readable record of silent paths, which a breadcrumb gives);
nothing ordinary is a `fault`.

**Actual.**
- 08:04:03 local, offline cold start: `error_reported degraded area: startup _ClientSocketException`
  ("Version check failed; using cached result") and `area: privacy` ("Region lookup failed; falling back
  to device signals").
- 08:05:18, offline Log In: two events for one tap, `AuthRetryableFetchException` and `NoConnectionException`, both `area: unknown`.
- 08:17:09, lesson 1.1 offline: `error_reported {severity: fault, area: education, exception_type:
  PlatformException}` ("Video player failed to initialise"); the screen shows "Failed to load video" + Retry, correctly.
- 08:30:28, online relaunch: `TimeoutException after 0:00:02` in `PrivacyRegionService._refresh`
  (`privacy_region_service.dart:73` 2 s timeout) → `error_reported degraded area: privacy`.
Related: 01-005 (normal signup outcomes reported to Sentry).

**Evidence.**
- runs/32/console-redacted.log the five `error_reported` lines at the times above
- runs/32/b05-offline-login-14s.png offline Log In
- runs/32/f13-lesson-offline.png offline lesson

**Decision quote.**
> 

**Triage.**
