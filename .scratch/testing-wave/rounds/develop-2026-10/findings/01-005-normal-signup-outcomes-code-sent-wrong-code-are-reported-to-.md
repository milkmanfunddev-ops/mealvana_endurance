# 01-005 · Normal signup outcomes (code sent, wrong code) are reported to Sentry as errors

- kind: bug
- status: triaged
- ticket: 01
- run: w1-20261007T1103Z
- screen: Verify your email
- decision: 

**Steps.**
1. Sign up with email (Create Account).
2. On Verify your email, type a wrong code and tap Verify.
3. Read the console for `error_reported`.

**Expected.**
"A code was sent, go and enter it" and "the athlete typed a wrong code" are expected flow states. They show on screen; they are not app faults and do not go to Sentry as errors (at most a breadcrumb).

**Actual.**
Each signup logs `EmailVerificationRequiredException: verification code sent` as a warning box and sends `error_reported {severity: degraded, area: unknown, exception_type: EmailVerificationRequiredException}` (three events this run: 06:09:46, 06:15:43, 06:22:21 local). The wrong code sends `error_reported ... InvalidVerificationCodeException` (06:10:30). Every new email signup therefore adds at least one Sentry issue event, which buries real auth failures. `area: unknown` also means they are not even tagged as auth.

**Evidence.**
- runs/01/console-redacted.log (06:09:46, 06:10:30, 06:15:43, 06:22:21 local)

**Decision quote.**
> 

**Triage.**
fix ticket: expected signup outcomes become breadcrumbs, not Sentry errors; real auth failures tagged area auth
