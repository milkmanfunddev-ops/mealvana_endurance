# Ticket 48 run notes

Run: w5-20261008T1718Z. App build **3cf7e2b9** (dev flavour, installed by the lead). Simulator wave-pool-1
(A3AD7D54-6776-4A2B-ABFA-F20B04700B00), app data cleared by the lead. Slot claimed 17:18:57Z.

Window 17:18Z-17:47Z. Accounts: A `lee+e2e-48-20261008T1726Z@rightpathprogramming.com` (auth 1c31d98e-1413-4233-92ad-1991d1737355,
anonymous from 17:21:03Z, verified 17:31:19Z, deleted in the app 17:44:27Z); B `lee+e2e-48-20261008T1736Zb@rightpathprogramming.com`
(never verified, see Leftover accounts). Clock times of every step: listed per check below; screenshots are named in order.

## Checks

1. **40 / 30-001: PASS 30-001** (screens). Verify your email: "Resend code in 57s", "Resend code", "No code? This address may
   already have an account.", "Log in", "That code is not right. Check the email and try again.", snackbar "New code sent to …"
   (48-24, 48-28, 48-30, 48-31). Settings rows in words (48-35); Sign Out dialog "Sign out?" / "You'll need to sign in again to use
   Mealvana. Your data stays with your account." / Cancel / Sign out (48-36); Delete dialog in words (48-37); Log In "That email or
   password isn't right." (48-53); offline delete snackbar in words (48-42). No raw key anywhere seen. Ticket 40 closes.
2. **35: PASS 35.** Title "Delete Account?", body "This will permanently delete your account and all associated data. This action
   cannot be undone.", buttons Cancel / **Delete** (the ticket says "Delete Account"; ticket 35 item 1 kept "Delete" on purpose;
   "Delete Account" is the Settings row). Cancel at 17:32:13Z: still on Settings, signed in; auth user present
   (db-48-A-after-delete-cancel.txt). 48-37, 48-38.
3. **36: PASS 36 (email/password half).** Profile & Preferences shows "Your login email" with the address as read-only text
   (ui: StaticText, no TextField; tapping it opens nothing). Save Changes is disabled until something changes; changed "I run with
   a water bottle" and saved 17:32:58Z: `public.users.runs_with_water_bottle` true, `updated_at` 17:32:59Z, `email` unchanged
   (db-48-A-users-before/after-profile-save.txt). Apple hidden-address half: device check, Lee's phone (ticket 51).
4. **42 / 30-007: PASS 30-007.** On Verify (Resend at 17:29:51Z), terminated 17:29:54Z, relaunched 17:30:10Z: Verify your email
   reopened at once (tape `pending signup: resuming verify (emailChange)`), "Resend code in 35s" at 17:30:17Z = 60 - 25 s since the
   stored send time 17:29:52Z (48-32). The code sent before the relaunch (844982, 17:28:44Z) was accepted at 17:31:19Z (pasted).
   Onboarding answers kept: public.users first/last name "Wave Tester", onboarding_surveys sports [running], goals [performance],
   pitfalls [energy_crash] = what was entered before the relaunch (db-48-A-after-verify.txt). Note: the Resend sent no email (48-002),
   so "the original code" here is the 17:28:44Z one.
5. **42 / 30-008: PASS 30-008.** Create Account 17:27:17Z → Verify → Use a different email (address and both passwords kept) →
   Create Account 17:27:31Z: button turned to "Create Account in 46s" / "…44s", disabled, no snackbar (48-26); GoTrue 429 at 17:27:31Z
   (auth-logs); console no `error_reported`, no `auth_flow_failed`; no Sentry event. After the countdown, Create Account at 17:28:43Z
   went through (48-27).
6. **41 / 30-005: new Finding 48-001** (Apple). Google cancel 17:26:01Z: no message, `expected_failure {reason: oauth_cancelled}`,
   no Sentry event: pass. Email already registered 17:36:09Z: "Account Already Exists" dialog in words, `expected_failure
   {reason: account_exists}`, no error_reported, no Sentry event: pass (48-45). Wrong password 17:37:49Z and 17:42:55Z: one line
   "That email or password isn't right.", `expected_failure {reason: wrong_credentials}`, no Sentry event: pass (48-48, 48-53).
   Apple sheet closed 17:26:18Z: snackbar "Sign in failed. Please try again." + error_reported + Sentry warning: fail → 48-001.
   30-005 stays open on the Apple half.
7. **41 / 30-011: PASS 30-011.** No "Notification permission answer not stored" warning in dev Sentry for any launch in the run
   (sentry-48.md), none in the console. The tape has the info line on launches with an anonymous session:
   `12:21:15.004 notification answer not stored: no local profile` (prefs-launch3-after-notif-answer.txt) and `12:30:18.088` (relaunch on
   Verify). On the three launches with no session at all (17:33:55Z, 17:34:10Z, 17:34:25Z) the answer callback does not run
   ("permission ask + heal wait for an athlete id"), so no line and no warning (tape-signed-out-launches.txt). The notification prompt
   itself appeared on the first Build My Plan tap (17:21:02Z), before any account, as 30-003 already records; answered Don't Allow.
8. **43 / 30-002, 30-010: PASS 30-002, PASS 30-010.** Onboarding walked twice with the console on, names typed with the keyboard up on
   Tell us about yourself: no "overflowed" line in the console, no RenderFlex event in dev Sentry. `idb ui describe-all`:
   `Button 'Build My Plan'` (ui-01-welcome.txt), `Button 'Continue with Apple'`, `Button 'Continue with Google'`, `Button 'Sign up with
   Email'` (ui-18-create-account.txt), `CheckBox 'Share usage data' '0'` → `'1'` after the tap (ui-04-consent.txt). Other tiles: 48-006.
   **How consent was reached:** app terminated; `xcrun simctl spawn UDID defaults write <data container>/Library/Preferences/
   com.milkman.mealvanaendurance.dev flutter.privacy_geo_country -string GB` and `defaults delete … flutter.privacy_geo_region`
   (source stayed `geo`), then `netcut.sh slow 3000 SCRATCH --only app.mealvana.io --relaunch UDID`; Build My Plan → Your privacy.
   A first try that edited the plist file directly with plistlib while cfprefsd held the domain was lost (US/AL came back): write
   through `defaults` instead.
9. **30-013: hint's Log in → new Finding 48-003; paste PASS; double tap PASS; expired code not seen live → 48-004.** Hint's Log in
   (17:37:09Z) opens Log In with the address prefilled (48-47), but a successful log in from there lands on the Sign Up form (48-003).
   Paste: `simctl pbcopy` + long-press → Paste at 17:31:18Z; six digits auto-submitted and verified (no iOS paste prompt). Verify tapped
   twice in 0.15 s at 17:29:04Z on a wrong code: one `POST /verify` (17:29:05Z) in the auth log, one error line. Expired code: run
   lasted 27 min, not seen live.
10. **30-014 + 30-015: PASS 30-014, PASS 30-015 (500 replaced by a dropped connection, 48-004).** Consent: switch ON → prefs
    `analytics_consent_status=granted`, regime strict (48-08); Privacy Policy opened Safari on the Mealvana Privacy Policy (48-06),
    Terms on the Terms of Use (48-07), back to the app via the status-bar breadcrumb, consent screen intact. Back from Your plan
    (17:25:00Z) → Nutrition Settings → Body composition with values kept; forward again rebuilt the same plan (48-16). Delete paths:
    Cancel keeps the account (check 2); delete with `netcut.sh on` at 17:33:23Z: snackbar "Deleting your account needs a connection.
    Nothing was deleted; try again when you're online.", still on Settings signed in, auth.users and public.users rows intact
    (48-42, db-48-A-after-offline-delete.txt); one degraded error_reported + Sentry warning OSError (the D9 record). `netcut slow` was not
    used for this: delete-user has no client timeout, so a slowed reply would have deleted the account for real.

Fix tickets: 35, 36 (email half), 40, 42 close on this run's passes. 41 does not close (48-001). 43 closes.

## Console and server notes
- 12:24:03 local `error_reported {area: content, HandshakeException}` + Sentry warning 17:24:02Z: known noise, caused by this run's
  slowproxy (upstream to 104.18.38.10 ETIMEDOUT at 17:24:02.896Z in slowproxy.log) while holding app.mealvana.io.
- `region lookup timeout: device fallback` on held launches: expected, the ticket held the host.
- Auth log extract: auth-logs-1727-1731.txt. Sentry read: sentry-48.md.
- My own slip, no app fault: at 17:37:49Z-17:41:38Z three log-in attempts went out with the address field reading
  `…programming.com.com` (an incomplete clear of the B address); the "wrong password" at 17:37:49Z and the two failed real-password
  attempts were against that address. Redone with the right address at 17:42:55Z (wrong password) and 17:43:23Z (success). Checked that
  idb types the password exactly (compared in memory, never printed) and that GoTrue accepts it directly (POST /token 200, 17:38:52Z).

## Leftover accounts
- Anonymous auth user **656d8eb7-2238-43f5-bf42-747103670f5a** (created 17:34:53Z), holding B
  `lee+e2e-48-20261008T1736Zb@rightpathprogramming.com` in `email_change`, never verified. Signed out when A logged in, so the in-app
  delete cannot reach it. CRED row for B set to `leftover`. Sweep with `sweep-accounts.mjs delete --id 656d8eb7-2238-43f5-bf42-747103670f5a --apply`.
- A: deleted in the app 17:44:27Z, auth user gone, footprint no rows (footprint-A.txt), CRED `deleted`.

## Device check
Ran on wave-pool-1. Apple hidden-address half of 36: device check, Lee's phone (ticket 51). No spend (cost: none).
