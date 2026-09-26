# 125-003 · Closing the Google sign-in page (a cancel) shows Sign in failed. Please try again.

- kind: bug
- status: open
- ticket: 125
- run: w37-20260926T0221Z
- screen: Log In
- decision: 

**Steps.**
1. Signed out, Welcome → I already have an account → Continue with Google → iOS "Endurance Dev Wants to Use google.com to Sign In" → Continue.
2. On accounts.google.com ("Sign in to continue to Mealvana Endurance"), tap the X without signing in.
3. Same with Continue with Apple on a simulator with no Apple Account: iOS "Sign in to your Apple Account" → Close.

**Expected.**
A cancel returns quietly to Log In, with no error message and no error log line. A real failure says so.

**Actual.**
After the X (02:38:34Z) the Log In chooser shows "Sign in failed. Please try again." The console logs `Exception: Google Sign-In cancelled`, then `⛔ [OAUTH_NATIVE] Google Sign-In failed` and `⛔ [AUTH] Post-onboarding auth: Google Sign-In failed`, so the app knows it was a cancel and reports it as a failure. Apple's Close (02:37:53Z) gives the same message; there iOS reports `AuthorizationErrorCode.unknown` because the simulator has no Apple Account, so the Apple case may be right. Signing in with either provider was not run.

**Evidence.**
- runs/125/45-google-page.png
- runs/125/46-after-google-close.png
- runs/125/42-apple-sheet.png
- runs/125/43-after-apple-close.png
- runs/125/console-redacted.log (21:37:53, 21:38:34 local)

**Decision quote.**
> 

**Triage.**
