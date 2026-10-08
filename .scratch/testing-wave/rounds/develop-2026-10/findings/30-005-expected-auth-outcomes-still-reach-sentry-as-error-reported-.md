# 30-005 · Expected auth outcomes still reach Sentry as error_reported: Google cancel (fault), Apple sheet closed, email already registered, wrong login password

- kind: bug
- status: triaged
- ticket: 30
- run: w3-20261008T1255Z
- screen: Create account
- decision: fix ticket 41 (expected outcomes are breadcrumbs)

**Steps.**
1. Create account (post-onboarding, anonymous session): Continue with Google, Cancel on the system sheet (13:11:08Z).
2. Continue with Apple, Close on "Sign in to your Apple Account" (simulator has no Apple account) (13:11:25Z).
3. Sign up with email at an address that is already a live account (B), Create Account (13:19:36Z).
4. Log In with email using a deleted account's address and old password (13:23:01Z).

**Expected.**
Ticket 21 made signup outcomes breadcrumbs (01-005). A cancel, an existing account and a wrong password are what an
athlete does, not faults: a breadcrumb at most, no `error_reported`, no Sentry error event. 01-015: after a cancel,
back on the screen with no error box.

**Actual.**
1. Google cancel: back on Create account, no message (good), but `error_reported {severity: fault, area: unknown,
   exception_type: OAuthCancelledException}` and a Sentry `level: error` event.
2. Apple close: snackbar "Sign in failed. Please try again." and `error_reported {severity: degraded, area: unknown,
   exception_type: SignInWithAppleAuthorizationException}` (code 1000, the athlete closed the sheet).
3. Already registered: the "Account Already Exists" dialog is right, but two events: `error_reported degraded
   AccountAlreadyExistsException` and `error_reported fault AuthApiException` (422 email_exists), both `area: unknown`;
   Sentry has the 422 at `level: error`.
4. Wrong credentials: Sentry `WrongCredentialsException` at `level: error` plus an `AuthApiException invalid_credentials`
   warning.
Retest of 01-015 (Google/Apple cancel) and 01-016 (a), (d). Ticket 21's `AuthFlowOutcome` marker covers only the
email-verification types.

**Evidence.**
- runs/30/console-redacted.log (08:11:18 local, 08:11:33, 08:19:36 `error_reported` lines)
- runs/30/30b3-04-after-google-cancel.png
- runs/30/30b3-06-after-apple-close.png
- runs/30/30b6a-02-signup-existing-later.png
- runs/30/sentry-30a.md

**Decision quote.**
> 

**Triage.**
