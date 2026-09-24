# Ticket 32 expected records (run w9-20260924T1447Z)

From the ticket's criteria. Dev project vlmtsdzpnjnavdgytcmi only.

## Before the code is entered (after Sign up is tapped)
- auth.users has a row for `lee+e2e-32-<time>@rightpathprogramming.com`, `email_confirmed_at` IS NULL.
- A code email from support@mealvana.io reaches the rightpathprogramming mailbox within 2 minutes.

## Code tries
- A wrong code: refused with a message, account stays unconfirmed.
- An expired or reused code (the first code after Resend has issued a newer one): refused.
- Resend code: a new email arrives (dev allows 30 auth emails an hour).
- The right (latest) code: accepted, app lands on the onboarding paywall (no close button).

## After the code is entered
- auth.users.email_confirmed_at IS NOT NULL for the account.
- RevenueCat / entitlement: not in this ticket's criteria; no entitlement row expected (never paid).

## Forgot password
- From the login screen, a reset email arrives from support@mealvana.io.
- Its code (or link) works on the simulator; a new password is set.
- Signing in with the new password works; the old password is refused.

## End
- Account deleted through the app's delete-account flow; auth.users row gone.
- Credentials file row: state `deleted`.
