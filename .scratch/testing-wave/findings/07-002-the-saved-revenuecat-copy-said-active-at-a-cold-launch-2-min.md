# 07-002 · The saved RevenueCat copy said active at a cold launch 2 minutes after its own expiry, while RevenueCat held no active entitlement

- kind: ssot-conflict
- status: triaged
- ticket: 07
- run: w6-20260924T1118Z
- screen: Timeline
- decision: mp-335

**Steps.**
1. Account C, paid (Test Store Monthly, period 11:31:56-11:36:56Z), signed in after a reinstall; app last fetched the customer at 11:34:29Z.
2. At 11:38:37Z RevenueCat's API showed no active entitlement for C (the renewal had not landed yet, 07-003).
3. At 11:39:00Z terminate and cold relaunch the app.

**Expected.**
mp-335 has the Gate read the saved copy, which "works offline". The edge: once the saved copy's own `expires_at` has passed, it should not keep the Gate open on its own; either the Gate treats a past `expires_at` as closed until a fresh answer arrives, or the record says the saved copy may outlive its expiry and for how long.

**Actual.**
At 06:39:04.061 local (11:39:04Z) the app logged `[SubscriptionService] customer info updated {active: true, expires_at: 2026-09-24T11:36:56.000Z}` and `customer info fetched {active: true, expires_at: …11:36:56…}`, then routed to `/main`: the saved copy counted as active 2 min 8 s after its own expiry, while RevenueCat's API had no active entitlement (read at 11:38:37Z). 0.6 s later the fresh fetch returned the renewal (`expires_at 11:41:56`), so no wrong screen was visible this time. But offline, or if the renewal had not come, the Gate would have stayed open on an expired copy for as long as the SDK keeps it (the RevenueCat SDK judges `isActive` against the time of the last server fetch, not the device clock). This is the other side of 05-005 (an app left open keeps the timeline).

Review note (wave lead): mp-335 says nothing about a saved copy past its own expiry, so this may be
a gap in the record rather than a conflict. The claim that the SDK judges `isActive` against the
last fetch has no evidence in the run.

**Evidence.**
- runs/07/device-reinstall.log, 06:39:04.057-06:39:04.666 local (11:39:04Z)
- runs/07/revenuecat-db-C-after-renewal-2.txt (11:38:16Z: subscription still at period end 11:36:56, row active_until 11:36:56)
- runs/07/14-cold-relaunch-1139Z.png (timeline, no paywall)

**Decision quote.**
> On a phone the Gate reads the copy of RevenueCat's answer saved on the device, so it answers at once after a purchase and works offline; the web build has no RevenueCat and reads the server's Entitlement row instead, which opens the coach portal on the web. Startup waits for the Gate, at most two seconds, so a subscriber never sees the paywall flash, and the saved copy counts only once it belongs to the signed-in account. The router is the one place that sends people to or from the paywall, so an account with access can never see it, and the old tester shortcuts and switches are gone.

**Triage.**

Fix ticket 67 (Lee, 2026-09-25). Closed by the retest after it merges.
