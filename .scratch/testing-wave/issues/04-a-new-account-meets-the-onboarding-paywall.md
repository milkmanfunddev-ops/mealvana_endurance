# 04: A new account meets the onboarding paywall

**Status:** ready-for-agent
**Blocked by:** 02, 03 (touches integration_test/flows/onboarding_signup_flow_test.dart).
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** A new athlete signs up and finishes onboarding, then meets the full-screen paywall with no close button. RevenueCat has a customer for the account and the dev database has no Entitlement row yet.

**Decisions:** mp-457, mp-494; approved as mp-624.

**Touches:** integration_test/flows/onboarding_signup_flow_test.dart

- [ ] Runs by the runbook: a slot and the build lock taken and released, the console saved to the run folder, a look-around on every screen visited, every problem written as a Finding and nothing fixed.
- [ ] Signs up its own account at a new plus address, logs it in the credentials file, and deletes it in the app at the end (a failed delete is a Finding).
- [ ] Expected before the run: RevenueCat customer exists with no active entitlement; no `user_entitlements` row. Checked by API and SQL.
- [ ] The paywall has no close button and its ⋯ menu lists what mp-494 says for an account with nothing to manage.
- [ ] The rewritten onboarding signup flow passes against a plus-address account.

Next: /implement-lee testing-wave
