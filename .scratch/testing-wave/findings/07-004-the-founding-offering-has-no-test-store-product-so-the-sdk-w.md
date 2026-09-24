# 07-004 · The founding offering has no Test Store product, so the SDK warns on every launch and the founding price cannot be bought on a simulator

- kind: idea
- status: open
- ticket: 07
- run: w6-20260924T1118Z
- screen: none
- decision: 

**Steps.**
1. Launch the dev app with the Test Store key and sign in (any account).
2. Read the device log for the RevenueCat SDK's offering lines.

**Expected.**
Every offering the app reads (`default`, `founding`, `credits`) has a Test Store product, so the whole paywall, the founding price included, can be tested on a simulator.

**Actual.**
Every launch logs `WARN: ⚠️ There's a problem with your configuration. No packages could be found for offering with identifier founding. This could be due to Test Store products not being configured correctly…`. The RevenueCat offerings list shows `founding` with `me_pro_monthly_founding` / `me_pro_annual_founding` products for the App Store and Play apps only, none for the Test Store app `appa283bb35a2`; `default` and `credits` do have Test Store products. The app uses the offering (`kFoundingOfferingId` in subscription_service.dart, pro_paywall_controller.dart and subscription_screen_controller.dart), so the founding branch cannot be bought or seen on a simulator. The three `credits` packages also warn "unknown duration" (one-time packs; likely noise). Idea: add Test Store founding products in RevenueCat dev, or note the founding path as iPhone-only.

**Evidence.**
- runs/07/device-reinstall.log, 06:33:24.859 and 06:39:04.830-.842 local (the WARN lines)
- runs/07/revenuecat-offerings.txt (offerings and their products per app)

**Decision quote.**
> 

**Triage.**
