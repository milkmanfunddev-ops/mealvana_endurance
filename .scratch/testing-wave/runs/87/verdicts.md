# Ticket 87 verdicts (retest, wave 25, RUN w25-20260925T1325Z, app build 5e05f8a6)

| id | verdict | evidence | new Finding |
|---|---|---|---|
| 05-004 | pass | runs/87/16-A-05-004-purchase-frames-5fps-from-10s.png, runs/87/15-A-after-purchase.png, runs/87/notes.md (13:35:13Z) | none (redeem analogue filed as 87-001) |
| 05-005 | pass | runs/87/screen-watch-05-005.log, runs/87/23-A-05-005-paywall-after-grace.png, runs/87/console-redacted.log (09:15:14 local) | none (the 15-min grace applied because the copy still said renewing: 87-006) |
| 06-002 | pass | runs/87/probe-A-pro-check.log, runs/87/poll-A.log, runs/87/edge-logs-webhook-A.txt | none |
| 07-002 | fail | runs/87/30-A-07-002-offline-launch-frames-2fps.png, runs/87/29-A-07-002-offline-paywall.png, runs/87/31-A-07-002-online-20s-later.png, runs/87/console-redacted.log | 87-009 (ends on the paywall, but the router opens /main for 1.4 s first) |
| 08-001 | pass | runs/87/17-A-08-001-subscription-running.png | none |
| 09-001 | pass | runs/87/19-A-09-001-manage-message.png, runs/87/25-A-lapsed-manage-tapped.png | none (wording idea 87-007) |
| 09-009 | pass | runs/87/poll-A.log (14:01:51Z), runs/87/db-A-after-lapse.txt, runs/87/edge-logs-webhook-A.txt (EXPIRATION) | none |
| 10-002 | pass | runs/87/27-A-10-002-after-resubscribe-1.png … -6.png | none |
| 11-003 | pass | runs/87/api-11-003-redeem-overlong.txt | none (the app can no longer send an overlong code; server checked directly) |
| 11-004 | pass | runs/87/04-B-11-004-typed-45.png, runs/87/05-B-32char-refused.png | none |
| 11-012 | pass | runs/87/db-B-after-delete.txt, runs/87/13-A-11-012-giveaway-refused.png, runs/87/db-A-11-012-after-refusal.txt | none |
| 02-004 | pass | runs/87/32-A-02-004-settings-delete-confirm.png, runs/87/33-A-02-004-dialog-manage-tapped.png, runs/87/11-B-delete-confirm-no-subscription.png, runs/87/revenuecat-A-after-delete.json | none |
| 06-001 (follow-up) | pass | runs/87/20-A-06-001-offline-cold-launch-1s.png … -6s.png, runs/87/21-A-06-001-offline-10s.png | 87-002 (splash ~12 s offline, Supabase init slow) |
| 08-004 (follow-up) | fail | runs/87/17-A-08-001-subscription-running.png (running), runs/87/22-A-08-004-subscription-last-period.png (last period), runs/87/10-B-08-004-subscription-grant.png (Grant), runs/87/24-A-lapsed-paywall-menu.png (ended) | 87-006 (last period, will_not_renew, reads "Renews on"); 87-008 (ended state not reachable) |
| 11-006 (follow-up) | pass | runs/87/07-B-11-006-offline-unavailable.png, runs/87/db-B-11-006-after-offline-redeem.txt, runs/87/08-B-11-006-retry-online.png, runs/87/db-B-after-redeem.txt | 87-001 (paywall live 4 s after the redeem) |

Notes on scope:
- 08-004 "cancelled": the Test Store cannot be cancelled in the app, so the cancelled leg was checked on the Test Store's own last period (RevenueCat `will_not_renew`). The 30-day coach Grant and the Legacy grace month were not run; the Grant leg used the 365-day giveaway E2EGIVE365.
- 11-006: the offline connect failed at once (ENETUNREACH), so the 20 s timeout itself was not exercised.
