# 02-004 · Delete account leaves the store subscription active and renewing, and the confirm dialog does not say so

- kind: idea
- status: triaged
- ticket: 02
- run: w2-20260923T1442Z
- screen: Settings
- decision: 

**Steps.**
The idea: when the account being deleted has a live subscription, the delete confirm says the
store keeps billing until it is cancelled there and offers Manage subscription first (or the
decision says deletion is enough and why).

Seen in this run: account A2 bought Monthly through the Test Store at 15:01:17 UTC, then
Settings → Delete Account → Delete at 15:02:27. The dev database rows were all removed. After the
delete, RevenueCat still shows the Test Store subscription `status: active`,
`auto_renewal_status: will_renew` for the deleted user id. On the App Store that means a person
who deleted their account keeps being charged for an account that no longer exists. Neither the
Settings dialog ("This will permanently delete your account and all associated data. This action
cannot be undone.") nor the paywall's ("This permanently deletes your account and all of its
data…") mentions the subscription. mp-494 covers where Delete account sits, not what it does to a
subscription; no decision in the record covers that.

**Expected.**
A product decision on what deletion does to a live subscription.

**Actual.**
The subscription outlives the account and keeps renewing: at 15:07:12 UTC the Test Store renewed
it (RevenueCat `current_period_ends_at` moved from 15:06:18 to 15:11:18, still `will_renew`). The
revenuecat-webhook logged `user a816e3ba-… not in this project, ignoring event 8A0DB01D-…`, and
no row came back for the deleted id (footprint still empty). So the database side is safe; the
billing side is not.

**Evidence.**
- runs/02/revenuecat-A2-after-purchase.json, runs/02/revenuecat-A2-after-delete.json, runs/02/revenuecat-A2-after-period-end.json
- runs/02/edge-logs-A2-renewal.txt
- runs/02/db-A2-before-delete.txt, runs/02/db-A2-after-delete.txt
- runs/02/14-settings-delete-confirm.png, runs/02/07-delete-confirm-A.png

**Decision quote.**
> 

**Triage.**
Fix ticket 78 (the wave lead, 2026-09-25: Lee asked for every bug fix that can be done without him). Closed by the retest after it merges.
