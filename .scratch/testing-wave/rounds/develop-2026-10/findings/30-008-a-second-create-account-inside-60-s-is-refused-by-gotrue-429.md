# 30-008 · A second Create Account inside 60 s is refused by GoTrue (429) and reported as a failed signup instead of a wait

- kind: bug
- status: closed
- ticket: 30
- run: w3-20261008T1255Z
- screen: Sign Up with Email
- decision: fix ticket 42 (pending signup survives a relaunch; 429 is a wait)

**Steps.**
1. Upgrade path (anonymous 1ffc8851…). Create Account at 13:12:10Z; Verify your email → Use a different email.
2. Type a different address, Create Account at 13:13:09Z (59 s after the first send).

**Expected.**
The form says the athlete must wait (with the seconds, as ticket 21 did for Resend), or the button waits out the
server's 60 s gap. No Sentry event for a rate limit.

**Actual.**
GoTrue answered 429 `over_email_send_rate_limit` "you can only request this after 0 seconds". The form stayed with no
message visible in the screenshot 5 s later; from code (`email_signup_screen.dart:176-182`) the athlete is shown the
generic "Account creation failed. Please try again." snackbar (not captured: gone by the screenshot). Console:
`email_account_linking_failed`, `auth_flow_failed`, `error_reported {severity: degraded, area: auth, exception_type:
AuthApiException}`. A second tap at 13:13:27Z went through.

**Evidence.**
- runs/30/30b4-03-second-address-submit.png
- runs/30/console-redacted.log (08:13:10 local)
- runs/30/sentry-30a.md

**Decision quote.**
> 

**Triage.**
