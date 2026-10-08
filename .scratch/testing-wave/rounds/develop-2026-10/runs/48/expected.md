# Ticket 48, expected records (written before the first tap)

Run: w5-20261008T1718Z. App build 3cf7e2b9 (dev flavour), simulator wave-pool-1 (A3AD7D54-6776-4A2B-ABFA-F20B04700B00).
Copied from the ticket's checks; the ticket names no RevenueCat records and no writes beyond the app's own flows.

## Screens (words, never keys)
- Verify your email: "Resend code in {n}s", "Resend code", "No code? This address may already have an account.",
  "Log in", "That code is not right. Check the email and try again.", "New code sent to {email}" (30-001, ticket 40).
- Settings: "Delete Account", "Sign Out", Profile & Preferences row in words; Sign Out dialog "Sign out?" / body /
  "Cancel" / "Sign out"; Delete dialog "Delete Account?" / "This will permanently delete your account and all associated
  data. This action cannot be undone." / "Cancel" / confirm button (ticket says "Delete Account"; ticket 35 kept "Delete").
- Delete dialog Cancel: account stays (auth user present, still signed in).

## Database (dev, SELECT with named columns)
- Check 3: `public.users.email` for the run's account equals the auth address before and after a Profile & Preferences
  save (Email read-only, labelled "Your login email").
- Check 10: after a delete-user call that fails (netcut), `auth.users` row and `public.users` row still present; the
  app shows "Deleting your account needs a connection. Nothing was deleted; try again when you're online."
- After the real delete: auth user gone; `sweep-accounts.mjs footprint <id>` reports no rows.

## Console / Sentry (dev, read-only)
- No `error_reported` for: Create Account rate limit (429), Google cancel, Apple sheet closed, email already registered,
  wrong password. Each is a breadcrumb or info/note line. No new dev Sentry error/warning event for them in the run's minutes.
- Signed-out launches: no Sentry warning "Notification permission answer not stored: no local profile"; the LaunchTrail
  tape carries "notification answer not stored: no local profile" when the callback fires.
- Onboarding: no "RenderFlex overflowed" in console or dev Sentry.
- Accessibility (idb describe-all): Build My Plan, Continue with Apple/Google, Sign up with Email are Buttons with
  labels; the consent switch carries a label.

## Relaunch on Verify (check 4)
- Relaunch lands on Verify your email with the countdown = 60 - seconds since the code was sent; onboarding answers kept
  (prefs `pending_signup_v1` holds the draft); the code sent before the relaunch is accepted.
