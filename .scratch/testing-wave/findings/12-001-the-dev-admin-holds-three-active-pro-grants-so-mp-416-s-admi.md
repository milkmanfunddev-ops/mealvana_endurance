# 12-001 · The dev admin holds three active pro Grants, so mp-416's admin-with-no-Pro case (paywall skipped, Vana refused) cannot be observed on it

- kind: followup-test
- status: triaged
- ticket: 12
- run: w4-20260924T0417Z
- screen: Timeline
- decision: 

**Steps.**
1. Read the admin's records: `users.is_admin`, `user_entitlements`, RevenueCat active entitlements and subscriptions.
2. Sign in as test@test.com on a fresh install, relaunch, send one Vana message.
3. Retest mp-416's own example on an Admin that holds no Pro: either a second Admin account on dev with no Grant, or test@test.com once its Grants end (the longest runs to 2027-09-15). Which one is Lee's call; this run wrote nothing to the account.

**Expected.**
On an Admin with no Pro: no paywall at sign-in or relaunch (the Gate reads `users.is_admin` because the status is inactive), and a Vana message answered 403 `{error: pro_required}`, with the screen showing whatever the app shows for that refusal (record it).

**Actual.**
test@test.com holds three active promotional Grants on `pro` in RevenueCat (2026-09-15 → 2027-09-15, 2026-09-22 → 2026-10-22, 2026-09-23 → 2026-10-23), mirrored in `user_entitlements` (`active_until` 2027-09-15 19:39Z, NORMAL). So the app's status is active and `AppGate.build` returns open before it ever reads the admin flag, and `vana-chat`'s `requirePro` passes. What the run saw matches mp-416 for an account with a Grant: no paywall at sign-in or relaunch, and Vana answered both the opener and the message (two 200s, two `vana_calls` rows, `debited: true`). The Admin-only bypass and the server's refusal were not exercised. `admin_bypass_flow_test.dart` checks both when run on an Admin with no Pro, and passed here on the Gate and `/paywall` legs only (its server leg does not run while the account holds Pro, to avoid a billed turn).

**Evidence.**
- runs/12/db-admin-before.txt, runs/12/db-admin-after.txt
- runs/12/revenuecat-admin-before.json, runs/12/revenuecat-admin-after.json
- runs/12/expected.md
- runs/12/patrol-admin-bypass.log

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 107 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
