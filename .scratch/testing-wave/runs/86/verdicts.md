# Ticket 86 verdicts (wave 25, run w25-20260925T1324Z, app build 5e05f8a6)

| Finding | Verdict | Evidence (under runs/86/) | New Finding |
|---|---|---|---|
| 02-001 | pass | 14-personal-info.png (empty, no TrainingPeaks tag), 15-plan-reveal.png ("We built your plan." with no name), db-A-after-signup.txt (email = signup address) | |
| 02-002 | pass | console-redacted.log (no "modify a provider while the widget tree was building" after `screen_viewed Personal Info Onboarding`), notes.md | |
| 02-003 | pass | console-redacted.log (`[RevenueCatService] logged out`, no "Pro entitlement clear failed" on the Settings sign-outs 08:29:04 and 08:38:22 local or the paywall sign-out 08:35:14), 11-after-settings-signout.png, 26-after-paywall-signout.png | |
| 02-006 | pass | 09-settings-delete-confirm.png, 24-paywall-delete-confirm.png (both "Delete account?" / "This permanently deletes your account and all of its data. This cannot be undone.") | |
| 03-002 | pass | console-redacted.log (relaunch 08:29:25 local signed out: first status `active: false`, every request for `$RCAnonymousID`), 12-welcome-relaunch-after-signout.png | |
| 03-004 | pass | 01-launch-leftover.png (first launch signed out, no prompt), 06-notification-prompt-after-signed-in-relaunch.png (the never-answered prompt came only after sign-in) | |
| 03-009 | pass | 17-longrun-edited-85.png, db-A-after-signup.txt (`nutrition_target_overrides.duringRun.carbRateGPerH = 85`) | |
| 06-003 | pass | 10-settings-signout-dialog.png ("You'll need to sign in again to use Mealvana. Your data stays with your account."), 11-after-settings-signout.png | |
| 09-004 | pass | 30-vana-open-4.png, 31-vana-full-screen.png (no prompt on open), 32-dictate-tap-prompt.png (prompt on the Dictate tap) | |
| 09-013 | pass | 05-cold-relaunch-signed-in.png, console-redacted.log (08:28:10 local: `logIn waiting for configure` x2, `configured`, `logIn skipped: already identified`; no "SDK not configured") | |
| 12-003 | pass | 02-login-sequence-sheet.png, login-seq/ (busy t01-t07, tabs shell t08, never an enabled form) | |
| 14-003 | pass | 04-food-tab.png (4 meals 47 s after login), 27-food-tab-second-login.png (4 meals 8 s after login), db-test-week0920-plans.txt | |
| 14-004 | fail | local-drift-00-before-launch.txt, local-drift-01-after-login-test.txt, local-drift-06-after-delete-A.txt (Lee's 37129f7e rows stay; the sign-out wipe itself works: local-drift-02, -03, -05) | 86-001 |
| 31-001 | pass | 10-settings-signout-dialog.png (no guest), 11-after-settings-signout.png | |
| 31-014 | pass | 28-profile-preferences.png (title "Profile & Preferences", Back at top) | |
| 32-001 | pass | 21-wrong-code.png ("That code is wrong or has expired. Check the digits, or tap Resend for a new one.") | |
| 32-002 | pass | console-redacted.log (08:33:45 local: after `email_verification_completed` only `active: false`), db-A-after-signup.txt (no entitlement row), revenuecat-A-active-entitlements.json | |
| 04-008 | pass | 18-daily-preview.png (no Connect with Garmin card; the plan reveal's Connect now in 15-plan-reveal.png is ticket 94's) | |

Follow-up tests to run: none listed for this ticket.
