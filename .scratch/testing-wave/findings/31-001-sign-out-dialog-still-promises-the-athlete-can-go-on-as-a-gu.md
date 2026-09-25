# 31-001 · Sign-out dialog still promises the athlete can go on as a guest

- kind: ssot-conflict
- status: triaged
- ticket: 31
- run: w11-20260924T1648Z
- screen: Settings
- decision: mp-508

**Steps.**
1. Log in as test@test.com (app built from 52c68764).
2. Timeline > Settings gear > Settings.
3. Tap Sign Out.

**Expected.**
The confirm dialog says the athlete will need to sign in again to use the app, and nothing offers to carry on as a guest (mp-508 clause 2).

**Actual.**
The dialog reads "Sign Out? You'll continue using the app as a guest. Your preferences will be saved on this device. Sign in again to sync across devices." with Cancel and Sign Out. Confirming goes to Welcome (not a guest session), so the copy promises something the app does not do. The same string is at lib/features/settings/presentation/screens/settings_screen.dart:668 at dcc4a14e.

**Evidence.**
- runs/31/17-signout-dialog.png: the dialog with the guest copy
- runs/31/18-after-signout.png: Welcome after confirming, no guest session
- runs/31/console-excerpts.log: settings_sign_out_tapped, Signing out user with scope local, going to /welcome

**Decision quote.**
> Settings no longer shows the guest card, so there is no Create Account, Log In or sign-out-without-an-account there. The sign-out dialog now says the athlete will need to sign in again to use the app. An install from before the paywall that still has no account will reach sign-up through a redirect that ticket 09 builds, not through Settings; until ticket 09 lands it has no way to register. Example: an athlete signed in with Apple taps Sign out on 2 October; the dialog says they will need to sign in again, and nothing offers to carry on as a guest.

**Triage.**
Fix ticket 47 (Lee, 2026-09-25). Closed by the retest after it merges.
