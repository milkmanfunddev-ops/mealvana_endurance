# 07-001 · A Test Store purchase survives an app reinstall: sign-in finds Pro on its own, so Restore is never needed on a simulator

- kind: idea
- status: open
- ticket: 07
- run: w6-20260924T1118Z
- screen: Log In
- decision: 

**Steps.**
1. Account C bought Test Store Monthly on the onboarding paywall at 11:31:55Z.
2. The flutter run was stopped, the app uninstalled (`simctl uninstall`) and the same built Runner.app installed again (`simctl install`, 1 s), then launched with `simctl launch`.
3. Welcome → I already have an account → Log in with email → account C's address and password.

**Expected.**
The ticket allows either: sign-in opens the app, or the paywall shows and ⋯ → Restore purchases opens it. RevenueCat shows no second purchase.

**Actual.**
Sign-in opened the app with no paywall frame (09-after-login-frames.png) and Restore was never needed. After `logIn` the SDK fetched the customer by the app user id (the Supabase user id) and reported `active: true, expires_at 11:36:56` 0.3 s after `active: false` from the fresh anonymous install; the router went to `/main`. RevenueCat afterwards held the same single subscription (`subTst4076cb8f…`, same `starts_at`) and no purchases; the webhook logged one INITIAL_PURCHASE only. So the criterion passes on its first branch.

The idea: on the Test Store, the purchase lives with RevenueCat against the app user id and there is no device receipt, so a reinstall cannot lose it. The Restore branch of this scenario cannot happen on a simulator. The case Restore exists for (a store receipt on the device that RevenueCat has not tied to this account, for example a purchase made before signing in, or on another account) needs the Apple sandbox on a phone. Suggest folding "reinstall, sign in, Restore" into the iPhone sandbox ticket (07-006) and treating the simulator run as proof of the first branch only.

**Evidence.**
- runs/07/09-after-login-frames.png (log-in to timeline, 0.5 s apart; no paywall)
- runs/07/device-reinstall.log, 06:33:24.510-06:33:25.992 local (11:33:24Z): `customer info updated {active: false…}`, `{active: true, expires_at: 2026-09-24T11:36:56.000Z}`, `[RevenueCatService] logged in`, `GoRouter: INFO: going to /main`
- runs/07/revenuecat-C-after-purchase.json, runs/07/revenuecat-C-after-reinstall-login.json (one subscription, same id and start, purchases empty)
- runs/07/edge-logs-rc-webhook-C.txt (one INITIAL_PURCHASE)

**Decision quote.**
> 

**Triage.**
