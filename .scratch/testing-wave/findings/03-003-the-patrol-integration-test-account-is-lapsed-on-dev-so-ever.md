# 03-003 · The Patrol integration-test account is lapsed on dev, so every credentialed flow meets the paywall

- kind: bug
- status: closed
- ticket: 03
- run: w3-20260923T1942Z
- screen: Paywall
- decision: 

**Steps.**
1. Run any credentialed Patrol flow with `secrets/integration_test.env` (the M1 runner's
   INTEGRATION_TEST_EMAIL account, 37129f7e…).
2. Sign in lands on the paywall.

**Expected.**
The Patrol account holds live Pro on dev (or is an Admin), so the suite reaches the tabs
shell and tests the app behind the Gate. The runner's "a skip is not a pass" check depends on it.

**Actual.**
Its dev entitlement is an `eval` row that ended 2026-09-16 19:05Z, RevenueCat has no active
entitlement for it, and `users.is_admin` is false. Signed in alone, it lands on the paywall; the
auth flow then waited 300 s for a tabs shell that never came, and `ensureAuthenticated` sees
neither the shell nor the welcome screen, so every other credentialed flow self-skipped, and
Patrol reported those skips as passes (03-001). The Gate itself behaved: closed for this account. This run finished the suite as the dev admin
(test@test.com) instead. The fix is a grant, an admin flag or a new account on dev, and a matching
update to the `INTEGRATION_TEST_*` repo secrets the M1 runner uses; none is a code change, and
this run did not write it (the runbook allows only writes a ticket names).

**Evidence.**
- runs/03/patrol-auth.log (auth alone, 298 s, no shell)
- runs/03/auth-after-login.png (paywall after login)
- runs/03/revenuecat-test-account-active-entitlements.json
- dev `user_entitlements` / `users` rows for 37129f7e… (Management API query, run notes)

**Decision quote.**
> 

**Triage.**

Closed (Lee, 2026-09-25): the Patrol account was made `is_admin` on dev in wave 7.
