# Ticket 124 expected records (w37-20260926T0221Z)

Judged against these, written before the app was touched.

## Sign up and verify (02-014, 32-004, 32-005, 02-013, 04-007)
- 04-007: a mismatched confirm password and a too-short password are refused on the form with a
  field message; no auth.users row and no auth email for either. An address with no `@` is refused
  on the field.
- 02-014: after Create Account, auth.users has the address with email_confirmed_at NULL and a
  confirmation_sent_at; the code email arrives from support@mealvana.io; the right code sets
  email_confirmed_at and the app moves on to the onboarding paywall (never-paid account).
- 32-004: "Use a different email" returns to the form; the first address stays in auth.users
  unconfirmed; onboarding answers (public.users profile) land on the second account only; the first
  address can sign up again later.
- 32-005: after terminate + relaunch on the code screen, the athlete can still finish verifying
  (back to the code screen, or Log In says the email is not confirmed and offers a resend);
  nothing lands the account in the app unconfirmed.
- 02-013: signing up again with a live confirmed address shows "Account Already Exists" offering
  Sign In; auth.users keeps one row for the address; its public.users profile is unchanged.
- RevenueCat: no customer entitlement for either account (never paid). Dev: no entitlements row.

## Reset (32-003, 32-006, 32-008, 02-011, 02-012)
- 02-011: Forgot Password for an address with no account shows the same "check your email" answer
  as a real one and no email arrives.
- 02-012: a wrong code and a superseded code are refused with a clear message; Resend delivers a new
  code that works.
- 32-006: Cancel / back / relaunch after the right reset code leaves the device signed out on Log In,
  the old password still works, and no recovery session stays usable (auth.sessions).
- 32-008: a success message ("Password reset successfully") shows on Log In after Reset Password.
- 32-003 (retest of 108): after the reset, auth.sessions for the account holds only the sign-in made
  after the reset (the recovery session and the script's password-grant session are gone), and the
  script session's refresh token fails.

## End
- Every account made is deleted in the app: no auth.users and no public.users row for it after.
