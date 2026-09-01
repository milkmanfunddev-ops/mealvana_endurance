# RevenueCat - Your Next Steps

**Last Updated**: March 17, 2026
**Current Status**: IAP Key generated, RevenueCat test store configured

---

## What's Done

1. **RevenueCat Project**: "Mealvana Endurance" (`proj77b3c48f`) exists
2. **Entitlement**: `pro` - "Mealvana Endurance Pro" (active)
3. **Test Store Products**: Monthly ($9.95) and Annual ($69) created and attached to `pro` entitlement
4. **Default Offering**: Created with `$rc_monthly` and `$rc_annual` packages
5. **In-App Purchase Key**: Generated and saved to `/secrets/apple/SubscriptionKey_3Q27QQ626C.p8`
   - Key ID: `3Q27QQ626C`
   - Issuer ID: `4ddd5f89-a054-4c06-b65a-ac9ed980786d`

---

## What's Next (in order)

### Your Tasks (manual, ~1 hour total)

**1. Create Subscription Products in App Store Connect** (~30 min)
- Website: https://appstoreconnect.apple.com
- Path: My Apps -> Mealvana Endurance -> Monetization -> Subscriptions
- Create group "Pro Subscriptions"
- Create `mealvana_pro_monthly` ($9.99/mo, 1-month free trial)
- Create `mealvana_pro_annual` ($69.99/yr, 1-month free trial)
- See SETUP_GUIDE.md Phase 3 for exact steps

**2. Create Sandbox Test Accounts** (~5 min)
- Website: https://appstoreconnect.apple.com
- Path: Users and Access -> Sandbox
- Create 2 test accounts

**3. Enable In-App Purchase in Xcode** (~2 min)
- Open Runner.xcworkspace
- Runner target -> Signing & Capabilities -> + In-App Purchase

**4. Add Real iOS App to RevenueCat** (~10 min)
- Website: https://app.revenuecat.com
- Add Apple App Store app with bundle ID `com.milkman.mealvanaendurance`
- Upload the .p8 file, enter Key ID and Issuer ID
- Tell Claude the new app ID for MCP product setup

### Claude's Tasks (code, after your tasks)

5. Install `purchases_flutter` SDK
6. Create `lib/features/subscription/` module (FOA pattern)
7. Initialize RevenueCat in app startup
8. Build paywall UI (drawer variant)
9. Implement feature gating
10. Cache entitlement in Drift database

---

## Timeline

Not launching soon, but getting infrastructure ready. Complete steps 1-4 whenever convenient, then Claude can handle steps 5-10.
