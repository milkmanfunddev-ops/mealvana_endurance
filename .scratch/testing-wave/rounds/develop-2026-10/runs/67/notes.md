# Ticket 67 run notes

Run: w7-20261008T2308Z. App build **ff4e0ffb** (dev flavour, installed by the lead). Simulator wave-pool-1
(76508EA6-8E7C-483A-9558-3E1AD6099562), app data cleared by the lead. Slot claimed 23:08:49Z. Cost: none.

Window 23:08Z-23:31Z. Accounts: A `lee+e2e-67-20261008T2313Z@rightpathprogramming.com` (auth e482a890-d753-4497-9d2e-74bf50be3931,
anonymous from 23:10:02Z, verified 23:18:58Z, deleted in the app 23:27:40Z); B `lee+e2e-67-20261008T2322Zb@rightpathprogramming.com`
(never verified, see Leftover accounts). Screenshots are numbered in order.

**Simulator shutdown (67-007).** At ~23:13:04Z wave-pool-1 (and wave-pool-3) went to Shutdown on its own; the log stream died with it.
Booted it again (23:14:35Z), restarted the log stream appending to console.log (gap 23:13:04Z-23:14:37Z), relaunched. App data survived;
the app opened on Welcome (67-003) and I walked onboarding again to reach Create Your Account. Checks 1-3 ran before the shutdown.

## Checks

1. **48-005 first half: PASS 48-005 (first half).** Consent start state: first launch through `netcut.sh launch` wrote US/AL, source geo;
   terminated; `defaults write … flutter.privacy_geo_country -string GB`, `defaults delete … flutter.privacy_geo_region`; then
   `netcut.sh slow 3000 SCRATCH --only app.mealvana.io --relaunch UDID` (23:09:48Z). Build My Plan 23:10:01Z → notification prompt
   (Don't Allow) → Your privacy (67-03, ui-03-consent.txt `CheckBox 'Share usage data' '0'`). `netcut.sh off` 23:10:19Z. Switch ON
   23:10:19Z (`'1'`, 67-04), Continue 23:10:26Z → Sports. Prefs (read through `defaults read`, app running):
   `analytics_consent_status=granted`, regime strict, at 18:10:26 local, version 1 (prefs-check1-after-continue.txt). Console: the
   ON tap itself logs nothing (by design, the code map says it writes nothing); from Continue on, `📊 [ANALYTICS] app_opened` 18:10:27,
   `screen_viewed {Sports Selection Onboarding}` and every onboarding event after. Format is the Noop echo throughout; no Mixpanel-format
   line in the whole run (see 67-002).
2. **48-006: new Finding 67-001** (Retest of 48-006). All tiles StaticText, no selected state; `Back\nBack` still on three screens.
3. **55 / 48-001: PASS 48-001.** Create Your Account → Continue with Apple 23:12:31Z → iOS "Sign in to your Apple Account" →
   Close 23:12:39Z. No snackbar (67-17 taken 0.7 s after, 67-17b at 3 s). Console: `auth_flow_started {apple, post_onboarding}`,
   `auth_apple_native_started {ios}`, `expected_failure {area: auth, reason: apple_no_account}` 18:12:40.762; none of
   `auth_apple_native_failed`, `auth_flow_failed`, `error_reported`, "Apple Sign-In failed" anywhere in the run (count 0). Dev Sentry:
   nothing in that minute (sentry-67.md). Ticket 55's Apple half closes here (V.O2 Cancel half is ticket 69).
4. **Signup A + 48-005 second half: PASS 48-005 (second half).** Sign up with Email as A, Create Account 23:18:40Z, code 722284
   (mailed 23:18:42Z) typed 23:19:01Z, auto-verified → Timeline (67-24). db-67-A-after-verify.txt: email confirmed 23:18:58Z, not
   anonymous, public.users row 1. Settings → Privacy: switch ON (ui-26 `'1'`). First tap at the card text (200,246) at 23:19:55Z did
   nothing; tap on the switch 23:20:09Z → OFF, snackbar "Usage data sharing is off", line "Usage data is off. The app works exactly the
   same." (67-27); prefs `denied` at 18:20:09 local (prefs-check4-after-off.txt). Two screens after (Settings, Timeline): no
   `📊 [ANALYTICS]` line (neither screen emitted one while ON either). A third visit to Settings → Privacy at 23:20:59Z printed
   `📊 [ANALYTICS] settings_privacy_tapped {}`: the Noop echo the code map describes, which prints whatever the consent. Verdict on the
   prefs value and the line format; Mixpanel not open; "never sent" stays unproven in this build (67-002). Left OFF.
5. **57 / 48-003: PASS 48-003.** Sign Out 23:21:30Z → Welcome (67-30). Build My Plan → onboarding straight away (no Your privacy:
   consent `denied` is stored; expected, per the lead). Sign up with Email as B, Create Account 23:23:10Z → Verify your email (67-34).
   B's anonymous auth user **f514bc05-1a9d-4c56-adce-e6060ec34ba0** (created 23:21:41Z, B in `email_change`; db-67-B-on-verify.txt);
   pending record present with otp_type emailChange, anonymous_user_id f514bc05 (prefs-B-pending-signup-before-hint.txt). Hint's
   Log in 23:23:30Z → Log In with B prefilled (67-35). Cleared it, typed A, A's password, Log In 23:24:21Z → **Timeline** signed in as A
   (67-37: no Sign Up form, no Create Your Account), with the expected info snackbar "You're signed in to your existing account, so its
   saved settings are being used instead of the answers you just entered. You can adjust anything in Settings." Settings shows
   "Signed in with Email", A's address, User ID e482a890 (67-38). Console: `screen_viewed {Email Login}` 18:23:30, `auth_flow_started
   {email, post_onboarding_login}`, `startup snapshot refreshed (signed_in): user=true onboarded=true`, `email_sign_in_success
   {e482a890}`, `auth_flow_completed`. Terminated, plist read with plistlib: no `flutter.pending_signup_v1`, no key with "pending"
   (prefs-check5-after-login-terminated.txt). As the code map says, the record goes at the hint tap, so the plist read proves the hint
   path ran; the Timeline-as-A proves the login landed. The "Pending signup cleared" logger box did not show in the console (Report
   info boxes did not reach this console in this run; no Finding, the plist read covers it).
6. **56 / 50-005: PASS 50-005; 50-016 step 2 answered.** Relaunched as A (23:25:05Z), on the Timeline. `openurl …:///welcome`
   23:25:17Z → iOS "Open in Endurance Dev?" → Open: Timeline at 1 s and 4 s (67-41, 67-41b), never Welcome; tape
   `welcome redirect: signed in -> /main` 18:25:25.787. Build My Plan cannot be reached over the live session, which closes 50-016's
   step-2 half (a Welcome deep link over a signed-in session). Step 1 (held notification tap across sign-in) stays with ticket 69.
7. **56 / 49-001: PASS 49-001.** `openurl …:///settings/connected-apps` 23:25:38Z → Connected Apps (no iOS prompt this time; my
   planned tap on "Open" landed on the screen beside V.O2's Connect and started nothing: console shows only screen_viewed and the
   controller's user lines). Back arrow 23:25:56Z → Timeline; tape `back fallback: canPop=false — going home`. Same session: Settings
   still A, no signed_in / signed_out / snapshot line between 18:25 and 18:26.
8. **56 signed-out half: PASS (56 signed-out half).** Settings → Sign Out → Sign out 23:26:17Z → Welcome (67-44). `openurl …:///welcome`
   23:26:28Z on Welcome: Welcome with Build My Plan; then from Log In (I already have an account) `openurl …:///welcome` 23:26:40Z →
   Welcome with Build My Plan and I already have an account (67-45). The first sign-out (check 5, 23:21:30Z) also landed on Welcome.
9. **48-004: not run.** 500 half: needs a server-side fault injection, not run (the lead names no dev fault switch; delete-user has none,
   and `netcut slow` would delete for real). Expired code: not seen live. B's code (sent 23:23:11Z, never used) would expire at
   ~00:23Z; the run ended ~23:31Z, and B left Verify for the hint's Log in at 23:23:30Z, so no unused code was on Verify 60 min later.
   Both halves stay open with these reasons.
10. **56 delete half: PASS (56 delete half).** Welcome → I already have an account → Log in with email → A 23:27:17Z → Timeline.
    Settings → Delete Account → "Delete Account?" / "This will permanently delete your account and all associated data. This action
    cannot be undone." / Cancel / Delete (67-48) → Delete 23:27:39Z → Welcome (67-49, 67-49b). delete-user 200 at 23:27:40.845Z;
    function logs: deleted public.users, auth account, RevenueCat customer (edge-67-2308-2331.txt). auth.users has no row for A
    (db-67-after-delete-A.txt); footprint: "no rows keyed to e482a890-…" (footprint-A.txt). Console: `settings_delete_account_tapped`,
    `user_signed_out`, `startup snapshot refreshed (signed_out)`; no error.

Fix tickets: 55 closes (its Apple half passes here; its V.O2 half is ticket 69's). 56 closes on checks 6, 7, 8 and 10. 57 closes
(check 5). Followups 48-005 closes (both halves, prefs-based; 67-002 carries the Mixpanel proof), 48-006 confirmed as 67-001,
48-004 stays open (check 9), 50-016 step 2 closed here.

## Console and server notes
- `region lookup timeout: device fallback` on the held launch: expected, the ticket held the host. No `expected_failure {privacy,
  timeout}` analytics line followed, unlike run 48: known noise, ticket 54 (`cee2d94d`) moved startup expected failures to a Sentry
  counter on purpose (`report.dart` `trackExpectedFailure`).
- 18:15:31 `⚠️ [performance] Slow operation: startup.total` + `error_reported {degraded, performance, SlowOperation}`: the cold boot
  after the shutdown; filed for its wrong uptime field (67-005).
- `📊 [ANALYTICS]` lines continue after `denied` (Noop echo, debug build): known, the code map's console section; 67-002.
- Edge extract: edge-67-2308-2331.txt. Other runs' errors in the window: 67-006. Sentry read: sentry-67.md.
- Accessibility: tapping the Privacy card's text does not toggle the switch (67-002).

## Look-around (one followup-test per screen at most)
- Privacy (Settings): 67-002. Create Your Account: 67-003. Log In: 67-004 is a bug, not a followup. Other screens visited (Welcome,
  Your privacy, onboarding pages, Sign Up with Email, Verify your email, Settings, Connected Apps, Timeline): their other paths are
  covered by open Findings from rounds 48-50 (Resend, wrong code, Use a different email, offline delete, Google cancel), so no new one.

## Leftover accounts
- Anonymous auth user **f514bc05-1a9d-4c56-adce-e6060ec34ba0** (created 23:21:41Z), holding B
  `lee+e2e-67-20261008T2322Zb@rightpathprogramming.com` in `email_change`, never verified. Signed out when A logged in, so the in-app
  delete cannot reach it. CRED row for B set to `leftover`. Sweep with
  `sweep-accounts.mjs delete --id f514bc05-1a9d-4c56-adce-e6060ec34ba0 --apply`.
- A: deleted in the app 23:27:40Z, auth user gone, footprint no rows (footprint-A.txt), CRED `deleted`.

## Device check
Ran on wave-pool-1. VoiceOver for 67-001 and 67-002's VoiceOver half is a device check (ticket 51). No spend (cost: none).
