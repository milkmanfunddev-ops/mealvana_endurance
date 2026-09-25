# Ticket 121 verdicts (run w34-20260925T2320Z, app build e3367d2c)

| Finding | Verdict | Evidence (under runs/121/) | New Finding |
|---|---|---|---|
| 86-004 | pass | 14-paywall-signout-confirm.png, 43-settings-signout-confirm.png: both read "Sign out?" / "You'll need to sign in again to use Mealvana. Your data stays with your account." | |
| 86-006 | pass | console-redacted.log: `user_registered {device_id: 4B95E9C7-0F08-4A6C-B018-D3F7AEEE9FFA}` at 18:25:13 local = `app_opened` device_id at 18:21:05 | |
| 86-009 | fail | 05-verify-A.png, 06-after-use-different-email.png, 08-after-resend.png, 10-superseded-code-typed.png, db-A-B-after-signup.txt, edge-auth-requests-2320-2338.txt | 121-001 (Resend 429 at the countdown's end), 121-002 (superseded code message), 121-003 (unconfirmed auth user left for address A) |
| 86-011 | fail | 31-offline-delete-contact.png, db-rc-B-after-offline-delete.txt: offline delete signs out and wipes locally, server account kept, no message | 121-007 |
| 04-002 | pass | 16-cold-relaunch-contact.png, 17-cold-relaunch-settled.png, 19b-resume-contact.png, 20-after-edge-swipe.png: paywall on cold launch and after 62 s in background, never /main | |
| 04-003 | pass | 15-restore-a.png, db-rc-B-after-restore.txt: "No active subscription was found for this account.", no entitlement anywhere | (offline variant: 121-006) |
| 04-004 | pass | 25-offline-paywall.png, 26-offline-continue-tapped.png, 27-offline-menu.png: pricing-unavailable text, Continue inert, ⋯ menu works, no way off | |
| 04-005 | fail | 22-after-cancel-b.png (cancel: no snackbar, pass), 24-failed-purchase-contact.png (failed purchase: no failure snackbar), db-rc-B-after-04-005.txt | 121-005 |
| 05-010 | pass | 38-double-tap-sheet.png, 40-purchase-then-continue-contact.png, db-rc-C-after-purchase.txt, edge-function-logs-2320-2338.txt: one sheet, one subscription, one INITIAL_PURCHASE, expiry matches in RevenueCat and user_entitlements | 121-008 (the second tap reached the SDK) |
