# 50-003 · Offline cold start still sends error_reported for the content fetch (x2) and the Learn lesson list (retest of 32-007)

- kind: bug
- status: closed
- ticket: 50
- run: w5-20261008T1720Z
- screen: none (startup chain, offline cold start); Learn
- decision: 

**Steps.**
1. test@test.com signed in. `netcut.sh on SCRATCH --relaunch UDID` at 17:34:17Z (offline cold start).
2. Grep the console from the relaunch for `error_reported` and `expected_failure`.
3. Open Learn, open lesson 1.1 offline.

**Expected.**
Ordinary offline conditions leave breadcrumbs and `expected_failure`, never `error_reported` (ticket 41 / 32-007).

**Actual.**
Converted, as expected: region lookup (`[LAUNCH] region lookup offline: device fallback`, `expected_failure
{area: privacy, reason: offline}`), version check (`version check offline: cached result`, `expected_failure
{area: startup, reason: offline}`), offline login (17:23Z, `expected_failure {area: auth, reason: offline}`), the
offline lesson video (`expected_failure {area: education, reason: offline}`, screen "Failed to load video" / Retry).
Not converted: on the same cold start, `error_reported {severity: degraded, area: content, exception_type:
_ClientSocketException}` twice (GET `/rest/v1/app_content`, errno 51) and `error_reported {severity: degraded,
area: education, …}` once ("⚠️ [education] Failed to fetch education content", GET `/rest/v1/education_content`).
The lesson list fetch runs on the cold start itself, before Learn is opened, and Learn then shows the cached
lessons, so the athlete sees nothing wrong while Sentry/Mixpanel get three error events per offline launch. From
code (unverified): `education_repository.dart:68` (`degraded`) and `content_repository.dart:113` (`fault`).
The notification-answer path was not exercised (permission already granted).

**Evidence.**
- runs/50/console-redacted.log 12:34:19-12:34:2x local: the three `error_reported` lines and the two `expected_failure` lines
- runs/50/i01-offline-cold-start.png Timeline after the offline cold start
- runs/50/i02-learn-offline.png Learn shows cached lessons offline
- runs/50/i03-lesson-offline.png lesson video offline: Failed to load video / Retry

**Decision quote.**
> 

**Triage.**
- closed · retest passed or ran in wave 7 (ticket 69 check 4) · lead, 2026-10-09
