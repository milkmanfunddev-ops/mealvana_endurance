# Ticket 30, expected records (written before the first tap)

Run: w3-20261008T1255Z. App build a89ace2a (dev flavour). Copied from the ticket's "Expected records".

## Every signup (A, B, C)
- After the code: `auth.users.email_confirmed_at` set.
- `public.users.email` equals `auth.users.email`, both lowercase (01-009).
- `public.users.created_at`, first `daily_macro_targets.created_at`, `onboarding_surveys.created_at` each
  within 2 minutes of `auth.users.email_confirmed_at` (01-004).
- Plain signup (30a): `auth.users.is_anonymous` false and `email` set once Create Account runs.

## Resend (30a step 4, 01-003)
- `auth.users.confirmation_sent_at` (plain signup) moves to the resend time; a second code email
  from support@mealvana.io arrives within 2 minutes. A server refusal shows on screen; success with no
  email is a fail.

## Console
- No `error_reported` with `exception_type` `EmailVerificationRequiredException`,
  `InvalidVerificationCodeException` or `DashboardTargetsAnomaly` (01-005, 01-006). Breadcrumb/info is fine.
- No new Sentry events for those exception types in the run's minutes (dev Sentry, read-only).

## After every delete (A, B, C, anonymous)
- `sweep-accounts.mjs footprint <user id>` reports no rows; the auth user is gone.
- A delete that fails server-side while the screen reports success is a bug (01-016 b).
- Double tap on Delete: one `delete-user` request in edge logs.

## Consent / region prefs (30b-7)
- (i) failed lookup on empty cache: `flutter.privacy_region_source=device`, no `flutter.privacy_geo_*` keys;
  no consent screen on Build My Plan; Settings -> Privacy usage data OFF.
- (ii) cached geo GB: consent screen before onboarding. Decline stores
  `flutter.analytics_consent_status=denied`, `flutter.analytics_consent_regime=strict`,
  `flutter.analytics_consent_at=<ISO>`, `flutter.analytics_consent_version=1`; Settings -> Privacy OFF.

## Notification prompt (30b-5, 01-010)
- After delete -> relaunch signed out: no iOS notification prompt on Welcome (a prompt there is a bug).
- `Slow operation: deferred.notifications` excludes the prompt wait; no `SlowOperation` error_reported.
