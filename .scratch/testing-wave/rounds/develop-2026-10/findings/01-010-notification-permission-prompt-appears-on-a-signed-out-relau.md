# 01-010 · Notification permission prompt appears on a signed-out relaunch after account deletion, and its wait is reported as a slow operation

- kind: followup-test
- status: triaged
- ticket: 01
- run: w1-20261007T1103Z
- screen: Welcome
- decision: 

**Steps.**
1. Follow CLAUDE.md's notification rule first (the notification-testing skill and `ops/docs/messaging-relay-and-testing.md`); this run did not test notifications.
2. Fresh install: launch, sign up, delete the account from Settings (lands on Welcome), terminate and relaunch the app.
3. Note when the iOS "Would Like to Send You Notifications" prompt appears and what a signed-out athlete has been told before it; leave it up for ~10 s; read the console for `SlowOperation`.

**Expected.**
The permission prompt comes at a moment the athlete can understand (after signup, with context), not on a cold launch of a signed-out app on Welcome; and a system dialog waiting for the user is not reported to Sentry as a slow operation.

**Actual.**
On the first launch of the run (fresh data) no prompt showed (launch trail: `push heal: permission=false optedIn=false ... no action`). After two signups and deletes, the relaunch at 11:18:50Z put the iOS notification prompt over the signed-out Welcome screen; it was answered "Don't Allow". The console then logged `[performance] Slow operation: deferred.notifications {duration_ms: 11322}` and sent `error_reported {area: performance, exception_type: SlowOperation}` (06:19:07 local), which is the time the dialog sat waiting for a tap.

**Evidence.**
- runs/01/36-C-launch.png
- runs/01/console-redacted.log (06:19:07 local)

**Decision quote.**
> 

**Triage.**
retest ticket 30 (retest: auth and account), wave 3 (Lee: all 27 followups into four retest tickets)
