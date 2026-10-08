# 50-007 · Cancelling V.O2 Connect at the iOS sign-in prompt sends error_reported (degraded) to Sentry as an authentication_error (32-007 family)

- kind: bug
- status: closed
- ticket: 50
- run: w5-20261008T1720Z
- screen: Connected Apps (V.O2 card)
- decision: 

**Steps.**
1. test@test.com, V.O2 disconnected (`is_active false`). Settings → Connected Apps → V.O2 Connect (17:47:25Z).
2. iOS prompt "“mealvana_endurance” Wants to Use “vdoto2.com” to Sign In" → Cancel.

**Expected.**
A user's own Cancel is not an error: a breadcrumb or `expected_failure`, no Sentry event, no `error_reported`
(ticket 41 / 32-007's rule for ordinary conditions).

**Actual.**
Console: `PlatformException(CANCELED, User canceled login, null, null)`, "⚠️ [vdot] vdot connect failed",
`integration_connect_failed {provider: vdot, error_type: authentication_error, …}` and
`error_reported {severity: degraded, area: vdot, exception_type: PlatformException, sentry_event_id: af2b85d7…}`.
The card went back to Connect; the `integrations` vdot row is unchanged (db-vdot-after-cancel.txt), so nothing was
written. Every athlete who backs out of the V.O2 prompt makes a Sentry event and is counted as an auth failure.
Not tried: the same Cancel on TrainingPeaks (its sheet is ephemeral and shows no iOS prompt; its sheet's X was not
tapped in this run).

**Evidence.**
- runs/50/o01-vo2-connect.png the iOS prompt
- runs/50/o02-vo2-after-cancel.png card after Cancel
- runs/50/db-vdot-after-cancel.txt row unchanged
- runs/50/console-redacted.log 12:47:26-12:47:3x local: CANCELED → error_reported

**Decision quote.**
> 

**Triage.**
- closed · retest passed or ran in wave 7 (ticket 69 check 8) · lead, 2026-10-09
