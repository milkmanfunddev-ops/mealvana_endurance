# Ticket 02, run w2-20260923T1442Z: expected records

Written before the app was touched. Dev project `vlmtsdzpnjnavdgytcmi` only.
Rows are read with `node scripts/testing-wave/sweep-accounts.mjs footprint <user id>`, which
counts `auth.users`, `auth.identities` and every uuid user column in a public base table.

## Account A: `lee+e2e-02-<UTC time>@rightpathprogramming.com`, deleted from the paywall's ⋯ menu

Before delete (after signup, on the paywall):
- `auth.users`: 1 row, `email_confirmed_at` set (dev auto-confirms, so no signup code is expected).
- `auth.identities`: 1 row (provider email).
- `public.users`: 1 row, `onboarding_completed = true`.
- `public.onboarding_surveys`: 1 row.
- `public.user_entitlements`: 0 rows (never paid).
- Any other rows the footprint shows are recorded as found, not judged.
- RevenueCat: a customer whose id is A's user id may exist (SDK login at signup), with no
  active entitlement and no subscription.

After delete:
- The app lands on the welcome screen.
- Footprint for A's id: no rows at all (auth and public).
- The delete-user function logged a 200 for A.
- RevenueCat: the customer for A's id is looked up by API and whatever it holds is recorded.
  Nothing in the app deletes it, so it is expected to still exist.

## Account A2: the same address signed up again

- A new user id, different from A's.
- The Gate shows the paywall: no entitlement row, RevenueCat customer for the new id has no
  active entitlement.
- Buy the trial through the Test Store (the only way past the paywall for a new account), then
  delete from Settings. RevenueCat then holds a Test Store subscription for A2's id; the
  `user_entitlements` row, if the webhook wrote one, must be gone after the delete.

After the Settings delete: footprint for A2's id shows no rows; RevenueCat customer for A2's id
looked up and recorded.

## Plus-address code

Dev auto-confirms signups, so signup sends no code. To prove a code reaches the plus address,
the run asks for a password-reset code for the account from the sign-in screen (Forgot password)
and reads it with the Gmail tool. If it never arrives: a Finding, and the fallback is the plain
work address. Dev's email rate limit is 2 per hour, so only one code is requested.

## Hard stop

If either delete leaves the auth user or the public.users row behind, the ticket stops there.
