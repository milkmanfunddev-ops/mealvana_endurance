# Ticket 121 run notes

- RUN: w34-20260925T2320Z. Slot claimed 23:20:28Z.
- App build commit: e3367d2c914d59f0fcde4b854ff4805416a6dc20 (installed by the lead; not built here). Every
  Finding ties to it.
- Worktree base: ec06df3e (checked; main clone's mealplanning has not moved past it).
- Simulator: wave-pool-2 728201D9-609F-4941-BCB7-AA9911A52E88, app data cleared by the lead.
- 23:20:56Z launch; simctl launch left the home screen in front, relaunched, Welcome (01-welcome.png).
  `app_opened {device_id: 4B95E9C7-0F08-4A6C-B018-D3F7AEEE9FFA}` at 18:21:05 local (the device id for 86-006).
- 23:21:43Z onboarding: Running, PR goal, no pitfalls, Continue on Connect training (no platform), male,
  1994 default, 5 ft 8 in / 150 lb defaults, gut/sweat defaults. Plan reveal 70 g/hr. Daily plan preview shows
  a "Connect with Garmin" card (run 86 saw none; judged out of scope here, no platform connected).
- 23:22:32Z Create Your Account → Sign up with Email.
- Account A = lee+e2e-121-20260925T2321Za@rightpathprogramming.com (CRED new). 23:22:57Z Create Account →
  Verify your email (05-verify-A.png). auth.users 22ae6961-ddc0-4fbc-9f72-d5d6a6eea039 created unconfirmed.
- 23:23:15Z Use a different email → back on Sign Up with Email, the form still holding A's address and A's
  password in both fields (06-after-use-different-email.png).
- Account B = lee+e2e-121-20260925T2323Zb@rightpathprogramming.com. Email field cleared, B typed, both
  password fields cleared and B's typed. 23:23:46Z Create Account → Verify your email for B (07-verify-B.png),
  user 9cd57a3f-cc25-429d-8929-8dfc0d9e4ffb.
- 23:24:24Z Resend code as soon as the in-app countdown ended (27 s shown, ~37 s after the first code):
  "Could not resend the code. Please try again." (08-after-resend.png). Edge log: POST /auth/v1/resend 429 at
  18:24:24 local. Dev auth config (read-only GET): smtp_max_frequency 60 s, rate_limit_email_sent 30/h. The
  app's countdown is shorter than the server's per-address minimum. Nothing in the console for the failed
  resend. Filed.
- 23:24:48Z second Resend tap (61 s after the first B mail): "New code sent to …", countdown restarts.
- 23:25:01Z typed the superseded first B code 343796: it submits on its own at six digits (ticket 94 item 3
  works now) and reads "That code is wrong or has expired. Check the digits, or tap Resend for a new one."
  (10-superseded-code-typed.png). Nothing points the athlete to the newest email. Console: the
  InvalidVerificationCodeException block is this deliberate wrong code (known noise).
- 23:25:13Z newest code 929295 → "Create Your Account" screen visible for ~1 s under an "Account created
  successfully!" snackbar, then the paywall (11-after-verify-B.png, 12-onboarding-paywall.png).
- 86-006: `user_registered {device_id: 4B95E9C7-0F08-4A6C-B018-D3F7AEEE9FFA, …}` at 18:25:13 local, the same id
  app_opened sent. Pass.
- First status after verify `active: false`; RevenueCat logged in; /paywall?onboarding=1.
- 23:25:37Z dev (db-A-B-after-signup.txt): A left an unconfirmed auth.users row (22ae6961…, no
  public.users row); B confirmed, public.users row, no user_entitlements row. public.users.created_at for B
  reads 2026-09-25 18:25:13+00 while auth.users.created_at is 23:23:46Z and updated_at 23:25:17Z: the app
  writes the phone's local wall clock (CDT, UTC-5) as UTC. Filed.
- Auth emails sent so far (Gmail, from support@mealvana.io): A 23:22:58Z, B 23:23:47Z, B 23:24:48Z = 3.
- RevenueCat customer id for B = its user id 9cd57a3f-cc25-429d-8929-8dfc0d9e4ffb; first_seen_at 23:21:04Z (the
  SDK's anonymous customer from the Welcome launch, aliased on logIn). No entitlements, subscriptions or
  purchases after signup (revenuecat-B-*.json).
- 23:26:33Z 86-004: paywall ⋯ → Sign out confirm reads "Sign out?" / "You'll need to sign in again to use
  Mealvana. Your data stays with your account." (14-paywall-signout-confirm.png): Settings' text word for word
  (run 86's 10-settings-signout-dialog.png); both come from ContentKeys.settingsSignOutConfirmBody at e3367d2c.
  Cancel. Pass.
- 23:26:40Z 04-003: ⋯ → Restore purchases: "No active subscription was found for this account." (15-restore-a.png),
  gone by ~3 s, stays on the paywall; `restore completed {active: false}`; no user_entitlements row, no RC
  active entitlement (db-rc-B-after-restore.txt). Pass.
- 23:26:59Z 04-002: terminate + launch; frames 0.3 s apart (cold-relaunch-seq/, 16-cold-relaunch-contact.png):
  splash, dark frames, then the paywall's own phone-mockup clip (a timeline inside a phone frame, that is the
  paywall's animation, not the real app) and the paywall. Route: `No initial matches: /` → `/paywall`; never
  /main. The iOS notification prompt appeared over the paywall on this first signed-in launch; Allow.
  23:27:47Z Home, 23:28:50Z back (62 s, same PID 20911): paywall on every frame (19b-resume-contact.png).
  Left-edge swipe: still on the paywall (20-after-edge-swipe.png). Pass.
- 23:29:16Z 04-005: Monthly, Continue → Test Store sheet (mealvana_pro_monthly, $9.95), Cancel: `purchase
  cancelled by user`, no snackbar, paywall (22-*.png). Pass for the cancel.
  23:29:35Z and 23:29:53Z "Test failed purchase" twice: `purchase failed (unexpected): PlatformException(42 …
  TEST_STORE_SIMULATED_PURCHASE_ERROR`, and NO snackbar either time (23-after-failed-purchase.png;
  failed-seq/ frames every ~0.2 s from the tap, 24-failed-purchase-contact.png). Code at e3367d2c:
  `ProPaywallController.buy` maps `_service.purchase(pkg) == false` to `cancelled` for both a cancel and a
  store error, so the `purchase_failed` snackbar never fires. Filed. RC and user_entitlements stay empty
  (db-rc-B-after-04-005.txt).
- 23:30:35Z netcut on --relaunch. 04-004: paywall with "Plans aren't available right now. Please check back
  later." in place of the plans, Continue dimmed and a tap does nothing, ⋯ menu opens with all four items
  (25-, 26-, 27-*.png). Gate closed from the cached customer info. Pass.
  Offline ⋯ → Restore purchases: "No active subscription was found for this account." (29-offline-restore-contact.png;
  the first try's screenshot missed it, 28-). The app never reached RevenueCat, yet tells the athlete there is
  no subscription. Filed.
  Console offline: `[IS_ADMIN] is_admin read failed; treating as not admin` and `getOfferings failed … NETWORK_ERROR`:
  expected offline (known noise: caused by the cut).
- 23:31:50Z 86-011 (still offline, all other B checks finished): ⋯ → Delete account → "Delete account?" /
  "This permanently deletes your account and all of its data. This cannot be undone." → Delete. Console:
  `Error calling delete-user Edge Function` (SocketException), `RevenueCatService logOut failed … NETWORK_ERROR`,
  then `Signing out user with scope: local`, `user_signed_out`, `/welcome`. Welcome within 0.5 s, no message
  (31-offline-delete-contact.png, 32-after-offline-delete.png). The code continues local cleanup on any
  delete-user failure (settings_controller.dart "Continue with local cleanup even if edge function call fails").
  23:32:11Z online SELECT: B's auth.users and public.users rows still there; RC customer still there
  (db-rc-B-after-offline-delete.txt). A half delete: local wiped and signed out, server kept. Fail, filed.
- 23:33:02Z logged B in online (Log In → email): paywall. 23:33:16Z ⋯ → Delete account → Delete: `logged out`,
  Welcome. 23:33:21Z dev: no auth.users, no public.users row; RevenueCat v2 now answers resource_missing for
  the customer (the delete removed it; run 86 saw it kept, 02-005) (db-rc-B-after-online-delete.txt).
- Account C = lee+e2e-121-20260925T2333Zc@rightpathprogramming.com, user and RevenueCat customer id
  f9aa0cdc-5c0a-4c31-94d1-90a029003a49. Onboarding as for B; 23:34:26Z code mail; verified; paywall.
  RevenueCat before: no entitlement, no subscription; no user_entitlements row (db-rc-C-before-purchase.txt).
- 05-010, plan Annual (the paywall's default; no plan named in the steps; Annual has 1-hour Test Store periods so
  nothing renews during the run):
  23:35:02.05Z two Continue taps sent in parallel (~2 ms apart): console shows `purchase started {sku:
  mealvana_pro_annual}` TWICE, and the second is refused by the SDK: `purchase failed (unexpected):
  PlatformException(15, The operation is already in progress for this product.`. One Test Store sheet
  (38-double-tap-sheet.png). The app's own busy guard did not stop the second call; the SDK did. Filed.
  23:35:14Z "Test failed purchase" in that sheet: no snackbar (same as 04-005's filed bug).
  23:35:22Z Continue again → sheet → 23:35:24.77Z "Test valid purchase", then Continue-position taps every
  ~0.6 s for 4 s (purchase-seq/, 40-purchase-then-continue-contact.png). `purchase succeeded` at 18:35:25.99,
  `redirecting to /main` 20 ms later: the paywall no longer stays live ~2.4 s (05-004 behaviour gone), so the
  later taps landed on the timeline, a "New in Mealvana: Shake to tell us what's wrong" sheet and then the
  Events tab (my taps, not a bug). One `purchase started` for this intent, one `purchase succeeded`, one
  "Welcome to Mealvana Endurance!" snackbar, no error snackbar.
  23:36:07Z RevenueCat: one subscription (test_store, sandbox, active, ends 1790382925457 = 2026-09-26
  00:35:25.457Z), one active entitlement with the same expiry; user_entitlements active_until
  2026-09-26 00:35:25.457+00, will_renew true (db-rc-C-after-purchase.txt). Webhook: one POST 200 at 18:35:26,
  one `[rc-webhook] INITIAL_PURCHASE … for f9aa0cdc` plus its allowance grant (edge extract). Pass.
- 23:36:39Z Settings (C): Sign Out confirm "Sign out?" / "You'll need to sign in again to use Mealvana. Your
  data stays with your account." (43-settings-signout-confirm.png), the same as the paywall's: 86-004 seen on
  both screens in this build. Cancel.
- 23:36:52Z Settings → Delete account (C, Pro): confirm adds "Deleting your account does not cancel your
  subscription. It keeps renewing until you cancel it in the App Store or Google Play." and a Manage
  subscription button (44-*.png). 23:36:59Z Delete → Welcome; 23:37:05Z no auth.users, public.users or
  user_entitlements row; RevenueCat customer resource_missing although the Test Store subscription was active
  to 00:35Z (db-rc-C-after-delete.txt; filed as follow-up 121-019).
- Auth emails Resend sent this run (Gmail, from support@mealvana.io): A 23:22:58Z, B 23:23:47Z, B resend
  23:24:48Z, C 23:34:26Z = 4. The 429 resend at 23:24:24Z sent nothing.
- Leftover on dev for the lead: unconfirmed auth.users 22ae6961-ddc0-4fbc-9f72-d5d6a6eea039 (address A; no
  public.users row, never had a RevenueCat customer of its own). B and C fully gone (auth, public, RevenueCat).
- Edge extract 18:19-18:38 local (edge-requests-2320-2338.txt, edge-function-logs-2320-2338.txt,
  edge-auth-requests-2320-2338.txt). Not this run's: sync-all-data 18:21:50 for 607f9dd5
  (test@test.com) with the token login at 18:21:44, search-catalog / search-nutrition-products 18:28:38-39 and
  calculate-daily-macros 18:21:52: ticket 112's run (known noise: the other run on test@test.com, per the
  prompt). ensure-credits x2 at 18:23:02 (functions booted 18:23:01 with two Deno GET /auth/v1/user): not tied
  to a signed-in session of this run (A was never signed in); most likely ticket 112, known noise. Mine:
  auth signup/resend/verify lines, sync-all-data 18:25:18 (B), 18:32:56 (B relogin), 18:34:39 (C),
  delete-user 18:33:17 and 18:37:00, revenuecat-webhook 18:35:26, calculate-daily-macros 18:35:26 (C),
  /auth/v1/logout 403 x2 after the deletes (filed 121-009). garmin-push no_user_mapping failures at 18:26
  (filed 121-010, not this run).
- Console error lines: all accounted for above (deliberate wrong code, offline cut, Test Store simulated
  failures, the double-tap purchase refused by the SDK).
- No COST spend: the run made no plan, logging or chat call.
