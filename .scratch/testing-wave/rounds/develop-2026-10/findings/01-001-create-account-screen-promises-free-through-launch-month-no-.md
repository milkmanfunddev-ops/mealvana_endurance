# 01-001 · Create-account screen promises "Free through launch month, no card needed" on a branch with no paywall

- kind: bug
- status: wontfix
- ticket: 01
- run: w1-20261007T1103Z
- screen: Post-Onboarding Auth ("Your plan is ready. Don't leave it behind.")
- decision: 

**Steps.**
1. Fresh app (data cleared), Welcome → Build My Plan.
2. Walk onboarding to the daily plan preview and tap Save My Plan.
3. Read the subtitle under "Your plan is ready. Don't leave it behind."

**Expected.**
No pricing, trial or Pro wording anywhere on develop-next: the ticket says this branch has no paywall, no Pro gate and no redeem codes, and "a paywall, 'Go Pro' upsell or entitlement read seen anywhere in this run is a bug Finding".

**Actual.**
The subtitle reads "Save it in seconds. Free through launch month, no card needed." It implies a paid plan after the launch month and a card later. Seen on all three signups in this run (passes A, B and C).
A second, smaller instance: Settings → Developer / Tester → "Mark this device as internal" says "Tester features (incl. the $0.99 test pack) are visible". That row is tester-only, so triage may rule it out of scope; it is listed so the ruling covers both.
No paywall screen, Pro gate or entitlement read was seen anywhere in the run, and no RevenueCat customer was created for any of the three users (404 on lookup).

**Evidence.**
- runs/01/17-create-account.png
- runs/01/49-C-settings-tester-rows.png
- runs/01/revenuecat-A-before-delete.json

**Decision quote.**
> 

**Triage.**
Lee: Xuan's copy, never changed by us anywhere; develop has no paywall, so no paywall tickets are needed
