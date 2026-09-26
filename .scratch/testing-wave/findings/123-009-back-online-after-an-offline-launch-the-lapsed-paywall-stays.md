# 123-009 · Back online after an offline launch, the lapsed paywall stays on Plans aren't available and the Gate is not asked again until a resume

- kind: bug
- status: triaged
- ticket: 123
- run: w38-20260926T0341Z
- screen: Paywall
- decision: 

**Steps.**
87-009 step 3.
1. Account A resubscribed (Monthly) at 04:16:20Z; the app was terminated at 04:16:40Z with a saved copy that expires 04:21:20Z. RevenueCat kept renewing it while the account stayed signed in (row `active_until 04:36:20`, then 04:41:20 after the 04:39:29 RENEWAL).
2. 04:37:06Z cold launch offline (`netcut.sh on … --relaunch`): the paywall, with "Plans aren't available right now. Please check back later." and Continue dimmed.
3. 04:37:35Z netcut off. Leave the app in front, untouched, for 1 min 49 s.
4. 04:39:24Z Home, resume.

**Expected.**
87-009 / mp-335 with mp-679: once the network is back, a fresh answer arrives and opens the Gate (run 87 saw a fetch 1 s after the network returned). At least the paywall retries its plans once online, so an athlete who wants to buy can.

**Actual.**
From 04:37:35Z to 04:39:24Z the console shows no fetch at all (no `customer info`, no `offerings` line after the offline `getOfferings failed: … Could not connect to the server` at 23:37:12 local), and the paywall kept "Plans aren't available right now." (31-A-87-009-online-100s-still-paywall.png). On resume the SDK fetched by itself (`customer info updated {active: true, expires_at 04:41:20}` 23:39:29.283) and the router went to /main (32-A-87-009-after-resume.png). A subscriber who opens the app on a plane and lands after it will sit on a paywall with no plans and no way to buy until they leave and come back. Run 87's fetch at +1 s may have been its re-count timer, not a reconnect.

**Evidence.**
- runs/123/29-A-87-009-offline-launch-frames-2fps.png
- runs/123/31-A-87-009-online-100s-still-paywall.png
- runs/123/32-A-87-009-after-resume.png
- runs/123/console-redacted.log (23:37:10-23:39:30 local)

**Decision quote.**
> 

**Triage.**

Fix ticket 140, Paywall, purchases, codes, coach pairing (Lee, 2026-09-26). Closed by the retest after it merges. Record: `triage-20260926.md`.
