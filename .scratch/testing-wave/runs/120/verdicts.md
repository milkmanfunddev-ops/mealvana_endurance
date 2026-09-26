# Ticket 120 verdicts (wave 39, run w39-20260926T1013Z, app build 72d3723e)

| Finding | Verdict | Evidence (under runs/120/) | New Finding |
|---|---|---|---|
| 86-001 | pass | local-drift-00-before-launch.txt (37129f7e rows present), local-drift-01-after-login-test.txt (all 37129f7e rows gone 16 s after test@test.com's login, incl. its users row), local-drift-06-C-signed-in.txt and 29-B-personal-info.png (other accounts see none of test@test.com's kept rows) | |
| 86-007 | pass | local-dirty-02-offline.txt (Manual log dirty), 27-signout-offline-line.png (offline line), local-drift-03-after-offline-signout.txt (only dirty rows, their users row and food_preferences kept), local-drift-04-after-B-signup.txt (kept under another sign-in), db-06-offline-meal-uploaded.txt and 38-admin-login-timeline.png (uploaded and shown at the next sign-in) | |
| 86-012 | not run | test-86-012-ticket103.txt (ticket 103's three test files, 28 tests pass). No row the server refuses could be made without writing to the local or dev database, so the device sync was not run | |
| 86-005 | pass | 15-dictate-tap-prompt.png, 16-after-dont-allow.png, 17-second-dictate-tap.png (Dictate stays; each tap shows the Settings line) | 120-005 (idea, wording on dev) |
| 86-002 | fail | local-plans-02-settled.txt (50390c90 archived locally), db-01-test-week0920-plans.txt (dev: draft) | 120-002 |
| 86-003 | fail | 08-plan-tab-stale-5-meals-101738.png (stale 5-meal draft 6 s after Log In), 09-plan-tab-1-meal-101739.png, 07-login-plan-sequence-sheet.png | 120-001 |
| 86-008 | pass | 04-wrong-password-message.png ("Login failed. Please check your credentials.", form usable), login-seq/t02-101733.png (second tap while busy), console-redacted.log (one `email_sign_in_success` 05:17:34 local, one navigation) | |
| 86-010 | pass | 12-profile-after-suggestion-tap.png, 13-profile-after-save.png, db-02-test-user-before-profile-save.txt, db-03-test-user-after-profile-save.txt (names Xuan Huang, email test@test.com in public.users and auth.users) | |
| 12-007 | pass | db-07-admin-and-C-entitlements.txt, revenuecat-C-lapsed-1035.json, 39-C-lapsed-login-after-admin.mp4, 40-C-lapsed-login-frames.png, 41-C-lapsed-paywall.png, 42-C-lapsed-paywall-menu.png (full-screen paywall, no close; first status after `logged in` is C's own `active: false`). The admin's own Gate opened on its Grant, not the admin check | |
| 06-004 | pass | 35-C-login-after-B.mp4, 37-C-login-after-B-frames.png (paid C after unpaid B: straight to Timeline, no paywall frame), 34-B-login-after-C.mp4, 36-B-login-after-C-frames.png (B after C: paywall, never the app), console-redacted.log (05:31:03-05:31:44 local) | |
