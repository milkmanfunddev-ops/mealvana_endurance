# Ticket 86 (retest, wave 25): expected records

Run w25-20260925T1324Z. App build 5e05f8a6. Simulator wave-pool-1 (F4B54D93…), app data NOT
cleared: it carries the dev simulator's leftover local rows (users 37129f7e and 607f9dd5).

From the fix tickets' criteria (33, 40, 47, 53, 79, 80, 85) and each Finding's Expected:

## Local database (Drift, read-only copy)
- After signing in as test@test.com (607f9dd5): no row whose user_id is another account (14-004).
- After any sign-out: no row of the signed-out account (ticket 33).

## RevenueCat
- Signed out on Welcome: the SDK is anonymous; no `customer info updated {active: true}` line (03-002).
- A new account's first status after signup is `active: false`; never `active: true` before its own
  RevenueCat login (32-002). RevenueCat customer for the new account: no active entitlement.
- Cold launch signed in: one `logIn`, after `configured`; no `logIn skipped: SDK not configured` (09-013).

## Dev database
- New email account A: `public.users.email` = its signup address (02-001);
  `nutrition_target_overrides` holds the long-run carb rate edited on the plan reveal (03-009);
  no `user_entitlements` row (never paid).
- After A is deleted through the app: no `public.users` / `auth.users` row for A.

## Console
- No "Tried to modify a provider while the widget tree was building" on Personal Info (02-002).
- No "Pro entitlement clear failed" on sign-out, from Settings or from the paywall menu (02-003).

## Screens
- Onboarding Personal info: empty, no TrainingPeaks tag (02-001). Daily plan preview: no Connect with
  Garmin after "I don't use training plan apps" (04-008; the plan reveal's nudge is ticket 94's).
- Wrong signup code says the code is not right (or "wrong or expired"), not "expired" (32-001).
- Log In stays busy until the tabs shell (12-003).
- Plan tab after login lists only the confirmed plan's meals (14-003).
- Sign-out dialog: sign in again to use the app, no guest (31-001, 06-003). Settings delete confirm reads
  the same as the paywall's (02-006).
- Profile & Preferences has its own title (31-014; the Settings tile string is ticket 94's).
- No notification prompt before Welcome on a fresh install (03-004). No Speech Recognition prompt on
  opening a Vana chat; the mic tap asks (09-004; purpose wording is ticket 94's).
