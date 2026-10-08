# 30-011 · Every signed-out launch sends a Sentry warning 'Notification permission answer not stored: no local profile'

- kind: bug
- status: triaged
- ticket: 30
- run: w3-20261008T1255Z
- screen: none
- decision: fix ticket 41 (expected outcomes are breadcrumbs)

**Steps.**
1. On a simulator whose notification permission was already answered (Don't Allow at A's signup, 13:02:37Z), launch the
   app signed out or with only an anonymous session (13:06:58Z, 13:13:58Z, 13:23:16Z launches).

**Expected.**
No profile yet is the normal state of a signed-out launch; the answer is stored once a profile exists. At most a
breadcrumb or LaunchTrail line (D9 asks for a record, not a warning event per launch).

**Actual.**
Dev Sentry got `level: warning` "Notification permission answer not stored: no local profile" at 13:07:06Z, 13:14:05Z and
13:23:34Z (users 2A6B3725… and 1ffc8851…), one per launch. Every fresh install and every signed-out relaunch would add
one. Not checked whether the answer is stored later once a profile exists.

**Evidence.**
- runs/30/sentry-30a.md

**Decision quote.**
> 

**Triage.**
