# Ticket 30 notes, run w3-20261008T1255Z

App build: a89ace2a (dev flavour, com.milkman.mealvanaendurance.dev), per ROUND/app-build.json and the prompt.
Simulator: wave-pool-1 5776C11D-ECDE-4489-96CD-0DDC714A84BC. Slot claimed 12:55:44Z.

## 30a, account A (lee+e2e-30-20261008T125637Z@rightpathprogramming.com)

- 12:56:41Z netcut launch (network on). Welcome shown, no notification prompt on first launch (screenshot 30a-01-welcome.png).
- 12:56:58Z `netcut.sh on` (7 open sockets shut), tapped Build My Plan 12:56:59Z; onboarding (sports page) opened at 12:57:00Z offline.
  netcut.log shows blocked connects at 12:56:59-:57:00Z (Supabase hosts). 12:57:10Z `netcut.sh off`.
- The failed anonymous sign-in printed nothing to the Flutter console (no `error_reported`, no info line; the app's
  report.info lines are not echoed to the console in this build). Checked instead by SQL: no auth.users row created in the
  5 minutes up to 12:57:30Z. So no session existed at Create Account: plain-signup path expected.
- Onboarding walked: Running; "Dial in performance nutrition and race a PR"; "Energy crash on long efforts"; no training app;
  personal info Lee / Wave / `Lee+E2E-30-20261008T125637Z@rightpathprogramming.com`, Male, default birth year; 5 ft 8 in,
  150 lb (defaults); gut Moderate, sweat Medium (defaults). Save My Plan → Create account → Sign up with email.
- Sign Up with Email: the Email field was empty (not prefilled from personal info; that idea is in the review queue, not filed).
  Typed the same mixed-case address, `CRED type` x2 (19 dots each = password length 19). Create Account 12:59:27Z.
- **Path: plain signup.** SQL 12:59:40Z (db-30a-step2-auth-user.txt): id a869be25-c973-46f8-ba86-7a665c079913,
  `is_anonymous` false, `email` lowercase, `email_change` '', `confirmation_sent_at` 12:59:28Z, `email_change_sent_at` null.
- First code email 12:59:29Z (code read with Gmail).

### Checks
- **01-002 (ticket 21): new Finding 30-001.** Wrong code (real code with the last digit changed) refused; GoTrue answered
  403 `otp_expired` (auth log 13:00:01Z) and the app picked the right reason: the line under the field is
  `auth.verify_email.error_wrong_code`, not `error_expired`. But the athlete reads that raw key, not "That code is not
  right…" (30a-15-wrong-code.png). Every `auth.verify_email.*` text on the screen is a raw key (30-001).
  Typing the sixth digit auto-submits: auth logs show two `/verify` 403s, 12:59:58Z (auto-submit while typing) and
  13:00:01Z (my Verify tap re-sending the same code). Known noise: auto-submit on the sixth digit plus a manual tap;
  both refused the same wrong code, no harm, nothing shown twice.
- **01-003 (ticket 21): PASS 01-003** for delivery, text issue in 30-001. Resend enabled at 13:01:12Z (the countdown
  label is a raw key, so its seconds never show). Tapped 13:01:17Z; auth log `/resend` 200 at 13:01:18Z
  (`user_confirmation_requested`); `confirmation_sent_at` moved 12:59:28Z → 13:01:17.7Z (db-30a-step4-resend.txt);
  second email arrived 13:01:47Z (30 s) with a new code. Snackbar text was the raw key `auth.verify_email.resent`
  (30a-17-after-resend.png). Newest code typed 13:02:17Z, auto-submitted, accepted.
- **01-005 (ticket 21): PASS 01-005.** Console from Create Account to the Timeline: `auth_flow_started`,
  `email_verification_required`, `email_verification_resent`, `email_verification_completed`, no `error_reported` line at all.
  Dev Sentry (sentry-30a.md): no EmailVerificationRequiredException / InvalidVerificationCodeException event for this
  simulator's Sentry user (2A6B3725…) or a869be25… in the window.
- **01-009 (ticket 21): PASS 01-009.** `public.users.email` = `auth.users.email` =
  `lee+e2e-30-20261008t125637z@rightpathprogramming.com` (lowercase, equal = true). `count(*) where email <> lower(email)` = 0
  (db-30a-step6-7.txt).
- **01-004 (ticket 22): PASS 01-004.** `email_confirmed_at` 13:02:18.57Z; `public.users.created_at` 13:02:18Z;
  first `daily_macro_targets.created_at` 13:02:21.7Z (7 rows); `onboarding_surveys.created_at` 13:02:19Z. All within 4 s.
- **01-006 (ticket 22): PASS 01-006** for the event half. Timeline shown 13:02:41Z. No `DashboardTargetsAnomaly`
  `error_reported` in the console and no such event in dev Sentry for this run. The `[macro_dashboard]` lines and the
  transient's `duration_ms` are not in the console stream (this build prints only analytics and `[LAUNCH]` lines to the
  console; report breadcrumbs are not echoed), so `duration_ms` was not recorded: not seen.
- The iOS notification prompt appeared the moment the code was accepted (13:02:18Z, 30a-19-notif-prompt-after-verify.png),
  over the Timeline, with nothing in the app saying why first. Left up ~19 s, Don't Allow. Console: `[LAUNCH] permission
  prompt wait 19037ms granted=false`. Filed as idea 30-003 (no pre-prompt explanation).
- Look-around, Timeline and Settings: Settings shows raw keys too (`settings.delete_account_button`,
  `settings.profile_preferences_title`, `…_subtitle`), and the Delete dialog's title, body and both buttons are raw keys
  (`settings.delete_confirm_title`, `settings.delete_confirm_body`, `settings.confirm_cancel`,
  `settings.delete_confirm_action`), so an athlete cannot tell Cancel from Delete (30a-22-delete-dialog.png). Same cause
  as 30-001, added there. Ticket 35's wording is not re-filed.
- **Step 9:** Delete tapped 13:04:36Z (the `settings.delete_confirm_action` button); Welcome at 13:04:41Z. `footprint`
  a869be25…: no rows; auth.users count 0 (footprint-A.txt). `CRED update … --state deleted`.

## 30b-5 (01-010), right after A's delete
- Terminated and relaunched 13:04:54Z (plain `simctl launch`, network on). Welcome, signed out, **no notification prompt**
  (30b5-01-relaunch-after-delete.png). Console: `[LAUNCH] onesignal started; permission ask + heal wait for an athlete id`.
  Caveat: this simulator's permission was already decided (Don't Allow at A's signup), so iOS would not ask again anyway;
  the evidence for the fix is the A run: on a fresh install the prompt did not show on the signed-out Welcome at the first
  launch (30a-01-welcome.png) nor through onboarding, and first showed after the signup code was accepted.
  **PASS 01-010** for its scope: no prompt on the signed-out Welcome. Correction found at the close: the ask waits for
  *an athlete id*, and an anonymous id counts: `[LAUNCH] permission prompt wait 112ms granted=false` at 13:07:06Z came one
  second after Build My Plan minted anonymous 1ffc8851… (permission already decided, so no prompt showed). On a fresh
  install with network, the prompt would therefore come up at Build My Plan, not after signup. In A's run it came after
  the code only because A's anonymous sign-in was forced to fail. Added to 30-003. Ticket 22's half: the wait was logged as `permission prompt wait
  19037ms` and happened after sign-in, outside the startup `deferred.notifications` step; no `Slow operation` line and no
  SlowOperation event in Sentry for this run (re-checked at the end).

## 30b, order run: 7(i) → 1-4 (B) → 6(a) → 3 anonymous pass → 6(b)-(d) → 7(ii) (C)
The anonymous pass of step 3 ran in the middle, not at the end: 6(a) needed a fresh Build My Plan (no signup path from
Log In), which minted the anonymous user anyway, so the pass used it.

### 7(i) failed lookup, empty cache (01-007)
- 13:05:59Z the ticket's `simctl spawn defaults delete com.milkman.mealvanaendurance.dev <key>` failed ("Domain not
  found"), so the first held relaunch (13:06:00Z) ran on the warm geo cache (US/AL). Idea 30-012. Redone 13:06:2xZ with the
  container plist path: keys gone (read back: none).
- 13:06:30Z `netcut.sh slow 3000 --only app.mealvana.io --relaunch`: slowproxy.log shows 216.198.79.1:443 held 3000 ms
  (first byte after 3105 ms). App terminated, prefs read: `privacy_region_source=device`, no `privacy_geo_*`
  (prefs-30b7i-after-failed-lookup.txt). Matches expected.
- Build My Plan (13:07:05Z): no consent screen, straight to sports. B on the Timeline later: Settings → Privacy, Share
  anonymous usage data OFF (30b7i-03-privacy-B.png). **PASS 01-007 (i).**
- Console: region lookup timeout logs `error_reported {severity: degraded, area: privacy, TimeoutException}` and a Sentry
  warning each held launch. Known noise: caused on purpose by the held host; it is the D9 record of the fallback.

### 30b-1 (01-017): new Finding 30-009 (gender silently required) and 30-010 (a11y)
Back once/forward on every page kept answers; sports page empty → "Please select at least one sport"; goal can be empty;
Last name keeps its label once typed (A's run). "Build My Plan" is StaticText, not a Button (30-010).

### 30b-2 (01-018): new Finding 30-004 (ssot-conflict)
B's inputs: Running + Cycling, no goal, Female, 1994, 173 cm, 62 kg, gut High, sweat Heavy.
Workout day 9.3 g/kg 576 g C / 1.4 g/kg 87 g P / 2.0 g/kg 126 g F / 3786 kcal; Rest 4.0/248, 1.4/87, 1.0/64, 1916 kcal;
Carb load 9.0/558, 1.4/87, 0.8/50, 3030 kcal. Fuelling plan: long run 70 g/hr, long ride 90 g/hr, fluid 800 ml/hr,
sodium 660 mg/hr. Checked against docs/ssot/spec/daily-macros/* and fueling/* (read via a research sub-agent, quotes
verified by me): only the workout-day protein contradicts a ratified rule (session bump missing). Consistent: fat cap
0.30 × TDEE / 9, carb-load floor 9.0 g/kg (a floor, so 9.0 below the workout day's 9.3 is allowed), fat floor 0.8 g/kg,
run ceiling 70 g/hr (Moderate and High both cap there). No ratified rule defines the preview's representative session
or its three day types. Not filed (judgment call, for the lead): A's fluid 768 ml/hr / sodium 634 mg/hr look computed at
22 °C / 50 % where the hydration spec's ruled fallback is 20 °C / 60 % (would give ~721 / ~595); the ruling's wording is
about failed weather fetches, the preview never fetches.

### 30b-3 (01-015): new Findings 30-005 and 30-006
- Back from Create account → Your daily plan with answers kept (576 g, 3786 kcal), forward again: fine.
- Google: sheet "wants to use google.com", Cancel → back on Create account, no error box; but `error_reported fault
  OAuthCancelledException area unknown` (30-005).
- Apple: simulator has no Apple account; sheet "Sign in to your Apple Account", Close → snackbar "Sign in failed. Please
  try again." + `error_reported degraded` (30-005).
- Continue without an account (13:20:00Z, anonymous a8e2c6a5-b533-4567-9843-c25129e3ac83): Timeline opens; Settings has
  no Delete Account for an anonymous athlete, so the pass could not delete it (30-006). Left over, see below.

### 30b-4 (01-014), on the upgrade path (B's Build My Plan minted anonymous 1ffc8851… at 13:07:05Z, network on)
New Findings 30-007 (relaunch loses the signup; (a)-(e) detail there) and 30-008 (429 inside 60 s).
- The first B address (…T130654Z) was replaced by a second address (…T131238Z, "B2") in (a); B2 finished the signup and
  is "account B" from there on. Code accepted 13:17:05Z after the offline retry.
- B records (db-30b-B-records.txt): auth email = public email, lowercase; email_confirmed_at 13:17:05.1Z; users.created_at
  13:17:05Z; first daily_macro_targets 13:17:08.8Z; onboarding_surveys 13:17:06Z. Within 4 s (01-004/01-009 hold on the
  upgrade path too).
- (e) expired code: not seen live (first B code 13:12:10Z; run ended before 14:12Z).

### 30b-5 (01-010): see above (PASS 01-010).

### 30b-6 (01-016), B signed in
- (a) Signed out B (Sign Out dialog all raw keys), Build My Plan → onboarding → Sign up with email at B's live address
  (13:19:36Z): "Account Already Exists … Would you like to sign in?" with Cancel / Sign In. SQL: one auth user for the
  address, the anonymous user's `email_change` empty: no second account. Screen PASS; Sentry/console events filed in 30-005.
- (b) Logged in as B (13:21:16Z), `netcut on` 13:21:38Z, Delete → Delete: stayed on Settings, snackbar
  `settings.delete_needs_connection` (raw key, 30-001), B still on the server (db-30b6b-B-after-offline-delete.txt), no
  edge request. The bug from code in the ticket (logged out with B alive) is gone. **PASS 01-016 (b).** `netcut off` 13:21:54Z.
- (c) Delete double-tapped 13:22:05.7Z (two taps 0.15 s apart): one `delete-user` POST 200 at 13:22:07Z (edge-delete-user.txt),
  Welcome, no error. footprint 1ffc8851: no rows, auth row gone. **PASS 01-016 (c).**
- (d) Log In with B's address and old password (13:23:01Z): refused, line `auth.login.error_wrong_credentials` (right
  reason, raw key, 30-001); Sentry error event (30-005).

### 7(ii) strict-country geo answer (C)
- App terminated; wrote `privacy_region_source=geo`, `privacy_geo_country=GB` (plist path form; `privacy_geo_region` was
  already absent). Relaunch held 13:23:16Z; keys read back unchanged (prefs-30b7ii-after-relaunch.txt).
- Build My Plan (13:23:34Z): "Your privacy" consent screen before onboarding. It has no Decline button: a switch "Share
  usage data" (off by default) and Continue; took Continue with it off (13:23:48Z).
- Prefs: `analytics_consent_status=denied`, `analytics_consent_regime=strict`, `analytics_consent_at=2026-10-08T08:23:49.007833`
  (local time, no offset; noted in followup 30-014), `analytics_consent_version=1`. Matches expected.
- Signup as C (9f270ed1-2b60-414a-9d10-ed4148e251bf, upgrade path), code accepted 13:25:05Z. Records fine
  (db-30b-C-records.txt). Settings → Privacy: usage data OFF. **PASS 01-007 (ii).**
- Delete C 13:25:58Z → Welcome; footprint no rows, auth gone; CRED deleted. `netcut.sh off` 13:26:14Z.

## Retest summary
- 01-002: FAIL → 30-001 (right reason chosen, raw key shown)
- 01-003: PASS 01-003 (delivery; snackbar text in 30-001)
- 01-005: PASS 01-005 (verification outcomes; other auth outcomes in 30-005)
- 01-009: PASS 01-009
- 01-004: PASS 01-004
- 01-006: PASS 01-006 (no event; duration_ms not in the console, not seen)
- 01-007: PASS 01-007 (both (i) and (ii))
- 01-010: PASS 01-010 (prompt waits for a signed-in athlete; see caveat)
- 01-014: → 30-007, 30-008 ((e) not seen live)
- 01-015: → 30-005, 30-006
- 01-016: (a) screen pass, (b) PASS, (c) PASS, (d) screen pass; Sentry noise → 30-005
- 01-017: → 30-009, 30-010
- 01-018: → 30-004 (ssot-conflict)
Other: 30-002 (RenderFlex overflow in onboarding), 30-003 (idea: prompt with no context), 30-011 (signed-out launch
warning), 30-012 (idea: defaults path), 30-013..30-015 (follow-up tests).

## Console notes
- The console carries only `print` lines (analytics, `[LAUNCH]`, logger boxes); FlutterError dumps and report breadcrumbs
  are not in it, so 30-002 was found in Sentry, not the console.
- Every `error_reported` line in the run is accounted for: OAuthCancelled / SignInWithApple / AccountAlreadyExists /
  AuthApiException 422 (30-005); AuthApiException 429 (30-008); TimeoutException privacy (known noise, held host);
  AuthRetryableFetchException on offline verify and _ClientSocketException on offline delete (real failures caused by the
  test's netcut, correctly reported as degraded).
- Plugin "uses deprecated application lifecycle events" lines at each launch: known noise, third-party plugin
  deprecation warnings (app_links, flutter_web_auth_2, google_sign_in), no effect.

## Spend
No AI call; no `cost.mjs spend`.

## Leftover accounts
- Anonymous auth user `a8e2c6a5-b533-4567-9843-c25129e3ac83` (made by Build My Plan at 13:18:41Z, used for the
  "Continue without an account" pass): the app offers no delete for it (30-006). Holds auth.users 1, public.users 1,
  daily_macro_targets 7, onboarding_surveys 1. For the lead's sweep.
- `lee+e2e-30-20261008T130654Z@rightpathprogramming.com` (CRED state never-created): it was only ever a pending
  `email_change` on 1ffc8851…, replaced by B2 and then deleted with B; no auth row holds it now (checked 13:26Z).
