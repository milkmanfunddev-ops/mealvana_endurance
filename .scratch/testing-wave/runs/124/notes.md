# Ticket 124 run notes (w37-20260926T0221Z)

- App on UDID 0A765B02-B0C1-44F1-B54B-CE53F0AAE874 (wave-pool-1): testing build from commit 72d3723e (app-build.json, prompt). App data cleared by the lead.
- Base 7abead8d checked; mealplanning at 7abead8d. Slot claimed 02:20:42Z.

## Auth emails sent by this run (budget 20/hour)

| # | UTC | address | kind | delivered |
|---|-----|---------|------|-----------|
| 1 | 02:25:58Z | A (...0224Za) | signup code | yes 02:25:59Z |
| 2 | 02:27:27Z | B (...0226Zb) | signup code | yes 02:27:27Z |
| 3 | 02:30:15Z | B | signup code (signed up again after relaunch) | yes 02:30:16Z |
| 4 | 02:32:45Z | B (already confirmed) | signup request, GoTrue sent nothing | no |
| 5 | 02:33:29Z | B (already confirmed) | Resend on the decoy verify screen, nothing sent | no |
| 6 | 02:34:14Z | A | signup code (signed up again) | yes 02:34:15Z |
| 7 | 02:35:51Z | ...0235Zn (no account) | reset request, nothing sent | no |
| 8 | 02:36:22Z | A | reset code | yes 02:36:22Z |
| 9 | 02:36:43Z | A | reset Resend, refused 429 | no |
| 10 | 02:37:43Z | A | reset Resend | yes 02:37:44Z |
| 11 | 02:40:05Z | A | reset code (32-006 run 2) | yes 02:40:05Z |
| 12 | 02:41:42Z | A | reset code (32-006 run 3) | yes 02:41:43Z |
| 13 | 02:43:10Z | A | reset code (final reset) | yes 02:43:10Z |

13 auth requests in 18 minutes, 9 emails delivered; under the 20/hour budget. The 32-006 Cancel run used code 10.

## Log
- 02:22Z app on Welcome, signed out (01-welcome-signed-out.png). Onboarding: Running, "Eat healthier", "Energy crash", no platform, about-you first name typed "WaveOnetwofour" (idb put the last name into the first-name field; fine as a marker), Male, defaults after. About-you screen was NOT prefilled this time (02-001 not seen after the clear).
- 02:23:51Z Create Your Account: price line "$9.95 a month or $69.00 a year. Cancel any time." no trial wording (03-create-your-account-price-line.png).
- 02:24:23Z 04-007 mismatched confirm: "Passwords do not match" under Confirm (05). 02:24:41Z the same message stayed on screen after both fields were changed to a matching short password, until the next submit (06). 02:24:41Z short 5-char password: "Password must be at least 8 characters" (07). 02:25:11Z address with no @: "Please enter a valid email address" (08). Console: no auth call for any of the three (only GoRouter/analytics lines after /auth/email-signup).
- idb `ui text` into the email field produced '.com' only; retyped with the mobile MCP. A field clear left a trailing ".com" once; cleared again. Known noise: tool typing.
- 02:25:57Z Create Account with account A (lee+e2e-124-20260926T0224Za): Verify your email, code to the address, Verify, "Resend code in 28s", "Use a different email" (09). auth.users f153ee51-0b0d-41d3-9576-68ccb3835d3a, email_confirmed_at NULL, confirmation_sent_at 02:25:58Z. No public.users row yet.
- 02:26:32Z Use a different email: back on Sign Up with Email with the address and both passwords kept (10).
- 02:26:45Z my field-clear tap at x=380 hit the password fields' show-password toggles, so B's first password showed in plain text on screen and in the element list. Not an app fault (the toggles work as designed). The screenshot was deleted before any commit, the toggles set back, and B's password rotated with `CRED update --new-password` before B was ever created. Known noise: tool tap.
- 02:27:26Z B created: Verify your email (11). auth.users 13f2e03f, unconfirmed.
- 02:27:36Z 32-005: terminate on the code screen, relaunch: Welcome (12). 02:28:15Z Log In with B: "Login failed. Please check your credentials." (15), console email_not_confirmed. Finding 124-001. The Log In chooser's back arrow has no accessibility element (16). Finding 124-005.
- 02:28:56Z Build My Plan again: every onboarding answer gone (17). Second pass: Cycling, first name "Rerun", Female.
- 02:30:15Z Sign up with B again: same auth user, new code sent. 02:30:30Z B's first code (superseded) auto-submitted on the sixth digit and was refused (19); 02:30:41Z the new code verified (20), onboarding paywall with ⋯ menu (21). public.users for B: first_name Rerun, female; no row for A (db-after-B-verified.txt).
- public.users.created_at for B reads 2026-09-25 21:30:41+00 while updated_at is 02:30:42+00: local wall clock stored as UTC. Already filed as 121-004 (seen again).
- 02:31:30Z paywall ⋯ > Sign out > "Sign out?" > Sign out: Welcome. No "Pro entitlement clear failed" or disposed-Ref lines this time (02-003 not seen).
- 02:32:45Z 02-013: third onboarding pass (Swimming, "Third", Non-binary), Sign up with B's address and password: Verify your email opened for a code never sent (22); Resend "New code sent" and nothing sent (23); a code refused (24). Finding 124-002. B's profile unchanged.
- 02:34:13Z Use a different email > A's address and password > Create Account: code sent to A (same auth id). 02:34:30Z A's first code refused (26); 02:34:35Z the new code verified; A's profile = the third pass (Third, other). A is no longer a leftover.
- 02:35:08Z script password grant for A (session 7b114bf7), the "other device" for 32-003. App sessions: 6371c76e (verify). 02:35:26Z app sign-out removed 6371c76e (local scope).
- 02:35:51Z 02-011: Forgot Password for never-used ...0235Zn: "Check your email for a reset code" + Enter Reset Code (29, 30), same as a real address. No auth.users row; Gmail has nothing for it (checked 02:47Z, in:anywhere with trash).
- 02:36:21Z reset code to A. 02:36:33Z wrong code: "Invalid or expired code. Please try again." (32). 02:36:43Z Resend: "Failed to resend code. Please try again.", server 429 "after 37 seconds" (33); Finding 124-004. 02:37:42Z Resend: "A new code has been sent to your email" (34). 02:37:58Z first code: same invalid message (35). The console shows two verify calls per wrong code 0.6 s apart: the field submits on the sixth digit, then my Verify Code tap sent a second. Followup 124-008.
- 02:38:08Z right code: Set New Password (36), with "Password is required" already shown: my Verify Code tap landed on the next screen's Reset Password button after the auto-submit. Known noise: tool tap timing (124-008 covers the double submit).
- 02:38:20Z 32-006 run 1 Cancel: Log In (37). Relaunch 02:38:36Z: iOS notification prompt, then the paywall, signed in as A (38, 39). Recovery session efd424ee still in auth.sessions. 02:39:03Z old password still works (script grant 200, session 7bceb219). Finding 124-003. Signed out from the paywall menu.
- 02:40:19Z run 2: right code, back arrow (35,90) pops to Enter Reset Code (40), Back to Forgot Password, Back to Log In (41). Relaunch 02:40:51Z: paywall, signed in (42). Session 18cbc8dd stayed.
- 02:42:01Z run 3: right code, terminate on Set New Password, relaunch: paywall, signed in (43). Session 66c82c28 stayed. Signed out.
- 02:43:27Z script refresh on 7b114bf7 worked (200) before the final reset. 02:43:28Z right code (recovery session efa827a9). CRED rotated A's password, typed twice. 02:43:48.9Z Reset Password: 0.4 s "Resetting...", 1.0 s to 4.0 s Log In with "Password reset successfully", gone by 4.5 s (45-after-reset-1/3/8). 32-008 pass.
- 02:44:11Z auth.sessions for A: none (all three gone). 02:44:12Z script refresh: 400 refresh_token_not_found; old password: 400 invalid_credentials. 02:44:34Z in-app Log In with the new password: paywall; auth.sessions holds only 0ec7bdc7 (02:44:35Z). 32-003 pass.
- 02:45Z RevenueCat: customers A and B exist with no active entitlements; dev public.user_entitlements has no rows for either (as expected).
- 02:45:38Z paywall ⋯ > Delete account > "Delete account?" (47) > Delete: Welcome (48). No auth.users or public.users row for A. CRED state deleted.
- 02:46:08Z Log In as B (paywall), 02:46:31Z Delete account: Welcome (49). No rows for B; no lee+e2e-124 auth users left. CRED state deleted.
- 02:46Z log stream stopped (by PID), app terminated. Slot released 02:47Z.
- Console: the raw stream was 83 MB of OS debug lines in 25 minutes. console-redacted.log keeps only the app's `flutter:` lines, with the 24 token lines cut (scan clean after). None of the three passwords appear in either file (checked by string match in SCRATCH, files removed). Error lines, each accounted for: otp_expired x4 and "Reset code verification failed" x4 (two wrong codes, each verified twice, 124-008); InvalidVerificationCodeException / "Email verification failed" x3 (B's superseded code, the decoy screen's code, A's first code: expected refusals); email_not_confirmed x2 + "Email sign in failed" (124-001); 429 over_email_send_rate_limit + "Failed to send reset code" (124-004).
- RevenueCat v2 `?expand=active_entitlements` returns 400; plain GET includes them. Known noise: API usage.

## Look-around (screens visited)
- Welcome, onboarding (sports, goals, pitfalls, connect training, about you, body composition, nutrition settings, plan reveal, daily plan), Create Your Account, Sign Up with Email, Verify your email, onboarding paywall + ⋯ menu, Sign out dialog, Log In chooser, Log In with email, Forgot Password, Enter Reset Code, Set New Password, Delete account dialog.
- Filed as followups: 124-006 (weak 8+ password), 124-007 (existing address, different password), 124-008 (double verify on Enter Reset Code), 124-009 (Forgot Password for an unverified address), 124-010 (second phone after a reset).
- Already filed, not re-filed: Verify your email Resend 30 s vs server 60 s (121-001); kill on the verify screen and an hour-old code (121-015); signup eye toggles unlabeled (118-005); price line has no trial on Test Store (05-002); public.users.created_at local clock (121-004).
- Sign Up with Email: a field error stays after the field is corrected until the next submit (06). Ordinary Flutter form behaviour, noted only.

## Leftover accounts
None. A (f153ee51-0b0d-41d3-9576-68ccb3835d3a), left unconfirmed by 32-004, was signed up again, verified and deleted in the app. The no-account address ...0235Zn never got an auth user.
