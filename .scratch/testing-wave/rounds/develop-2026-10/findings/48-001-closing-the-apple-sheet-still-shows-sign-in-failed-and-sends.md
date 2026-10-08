# 48-001 · Closing the Apple sheet still shows Sign in failed and sends error_reported plus a Sentry warning

- kind: bug
- status: closed
- ticket: 48
- run: w5-20261008T1718Z
- screen: Create Your Account
- decision: 

**Steps.**
1. Build 3cf7e2b9, wave-pool-1 (no Apple account signed in on the simulator). Welcome → Build My Plan → onboarding → Save My Plan.
2. On Create Your Account, Continue with Apple (17:26:09Z). iOS shows "Sign in to your Apple Account / You need to sign in to your
   Apple Account in Settings." Tap Close (17:26:18Z).

**Expected.**
Ticket 41 / 30-005: closing the Apple sheet is something the athlete chose, not a fault. Back on Create Your Account with no error
message, a breadcrumb or info line at most, no `error_reported`, no Sentry event.

**Actual.**
- Snackbar "Sign in failed. Please try again." under the pills.
- Console: `auth_apple_native_failed`, `auth_flow_failed {provider: apple, error: SignInWithAppleAuthorizationException(AuthorizationErrorCode.unknown, … error 1000.)}`,
  `error_reported {severity: degraded, area: auth, exception_type: SignInWithAppleAuthorizationException}` from
  `SentryReport.fault` ← `OAuthService.linkAppleAccount` (oauth_service.dart:315).
- Dev Sentry: warning "Apple Sign-In failed" at 17:26:19Z, user 1c31d98e.
The sheet answers code 1000 (`unknown`), not 1001 (`canceled`), when the device has no Apple account, so the cancel mapping from
ticket 41 does not catch it. Whether a real device with an Apple account answers 1001 on Cancel is not known from here (device check).
The Google half of 30-005 passes: Cancel on the google.com prompt gave `expected_failure {area: auth, reason: oauth_cancelled}`, no
message, no Sentry event.
Retest of 30-005.

**Evidence.**
- runs/48/48-21-apple-sheet.png (the sheet)
- runs/48/48-22-after-apple-close.png (snackbar "Sign in failed. Please try again.")
- runs/48/48-20-after-google-cancel.png (Google cancel: no message)
- runs/48/console-redacted.log (12:26:19 local: error_reported SignInWithAppleAuthorizationException)
- runs/48/sentry-48.md

**Decision quote.**
> 

**Triage.**
- closed · retest passed or ran in wave 7 (ticket 67 check 3) · lead, 2026-10-09
