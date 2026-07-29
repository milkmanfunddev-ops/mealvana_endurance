# RevenueCat Setup Guide for Mealvana Endurance

**Last Updated**: March 17, 2026
**Status**: In Progress - Phase 2 Complete

---

## Setup Progress Tracker

### PHASE 1: Prerequisites
- [x] App Store Connect account with admin access
- [x] Paid Applications Agreement signed (Active)
- [x] Tax forms completed (Clear)
- [x] Bank account linked to App Store Connect
- [x] Bundle ID `com.milkman.mealvanaendurance` registered (Apple Developer)
- [ ] Verify In-App Purchase capability enabled on Bundle ID (Apple Developer)

### PHASE 2: In-App Purchase Key (.p8)
- [x] Generated In-App Purchase Key (App Store Connect -> Users and Access -> Integrations -> In-App Purchase)
- [x] Downloaded .p8 file (one-time download)
- [x] Saved to `/secrets/apple/SubscriptionKey_3Q27QQ626C.p8`
- [x] Key ID: `3Q27QQ626C`
- [x] Issuer ID: `4ddd5f89-a054-4c06-b65a-ac9ed980786d`

### PHASE 3: Create Subscription Products (App Store Connect)
- [ ] Create subscription group "Pro Subscriptions"
- [ ] Create monthly product `mealvana_pro_monthly` ($9.99/mo)
- [ ] Create annual product `mealvana_pro_annual` ($69.99/yr)
- [ ] Configure 1-month free trial on both products
- [ ] Add English (U.S.) localization on both products
- [ ] Add review information on both products

### PHASE 4: Sandbox Test Accounts (App Store Connect)
- [ ] Create sandbox tester: `lee+sandbox1@mealvana.com`
- [ ] Create sandbox tester: `lee+sandbox2@mealvana.com`
- [ ] Configure sandbox account on physical iPhone

### PHASE 5: Xcode Configuration
- [ ] Enable In-App Purchase capability (Runner target -> Signing & Capabilities)

### PHASE 6: Connect RevenueCat to iOS App
- [ ] Add real iOS app in RevenueCat dashboard (bundle ID: `com.milkman.mealvanaendurance`)
- [ ] Upload .p8 file to RevenueCat
- [ ] Enter Key ID and Issuer ID
- [ ] Confirm "Valid credentials" message
- [ ] Create iOS products in RevenueCat matching App Store Connect product IDs
- [ ] Attach iOS products to `pro` entitlement
- [ ] Add iOS products to `default` offering packages

### PHASE 7: Flutter SDK Integration (Claude can do this)
- [ ] Add `purchases_flutter` to pubspec.yaml
- [ ] Create subscription feature module (FOA pattern)
- [ ] Initialize RevenueCat in app startup service
- [ ] Build paywall UI (drawer variant per Notion spec)
- [ ] Implement feature gating with lock icons
- [ ] Cache entitlement status in Drift for offline access

---

## Credentials Reference

| Credential | Value | Location |
|-----------|-------|----------|
| IAP Key ID | `3Q27QQ626C` | App Store Connect -> Users and Access -> Integrations -> In-App Purchase |
| Issuer ID | `4ddd5f89-a054-4c06-b65a-ac9ed980786d` | Same page, shown at top |
| .p8 File | `SubscriptionKey_3Q27QQ626C.p8` | `/secrets/apple/` |
| Bundle ID | `com.milkman.mealvanaendurance` | Apple Developer -> Identifiers |
| RC Project ID | `proj77b3c48f` | RevenueCat dashboard |
| RC Entitlement | `pro` (lookup key) / `entla441faaeb4` (ID) | RevenueCat dashboard |
| RC Offering | `default` / `ofrngabf12e1136` | RevenueCat dashboard |
| RC Test Store App | `appa283bb35a2` | RevenueCat dashboard (test store only) |
| RC Test API Key | `test_tQzQdGyaWsLgqlXuxRYJkoRHNDo` | RevenueCat dashboard |

---

## RevenueCat Dashboard State (configured via MCP on 2026-03-17)

The following are set up on the **Test Store** app in RevenueCat. Once the real iOS app is added (Phase 6), equivalent products/packages need to be created for that app.

| Component | ID | Details |
|-----------|-----|---------|
| Entitlement | `entla441faaeb4` | lookup_key: `pro`, display: "Mealvana Endurance Pro" |
| Product: Monthly | `prod350601b768` | `mealvana_pro_monthly` - $9.95/mo, P1M, attached to `pro` |
| Product: Annual | `prodcaf0460693` | `mealvana_pro_annual` - $69/yr, P1Y, attached to `pro` |
| Offering | `ofrngabf12e1136` | lookup_key: `default`, is_current: true |
| Package: Monthly | `pkge316803098d` | `$rc_monthly`, monthly product attached |
| Package: Annual | `pkge4a1810d707` | `$rc_annual`, annual product attached |

---

## Subscription Plan Details

### Pricing (per Notion Paywall Logistics)

| Plan | Your Spec | Apple Tier | Actual Price |
|------|-----------|------------|-------------|
| Monthly | $9.95/mo | Tier 10 | **$9.99/mo** |
| Annual | $69/yr | Tier 70 | **$69.99/yr** |
| Free Trial | 4 weeks | 1 Month | **1 month** |

**Note**: Apple's price tiers don't support $9.95 or $69.00 exactly. Marketing copy should be updated to match actual Apple tier prices.

### Pro Features (unlocked by `pro` entitlement)

1. Training platform integration (TrainingPeaks, FinalSurge)
2. Writing to TrainingPeaks
3. Coach/Dietitian dashboard
4. Brick workout nutrition plan
5. Personal fueling templates
6. Mealvana 101 (fueling course)
7. By-hour race day nutrition planning
8. Food journaling
9. Barcode scanning
10. Carb-loading
11. Adaptive macro adjustment

### NOT included in Pro (cookie-gated, future)

- Meal planning
- Import recipes
- Coach intelligence: fueling plan pattern detection

### Paywall Locations

- Settings > "Connected apps"
- Any pro feature card on home/dashboard
- Any pro feature CTA inside "Create activity"

### Gating Behavior

1. Show lock icon or `<Pro>` badge
2. On tap, open paywall drawer variant
3. After purchase, return user to the exact feature they tried to use

### Trial Rules

- **4-week free trial** (configured as 1-month in App Store Connect)
- Eligibility: first-time subscribers only (per subscription group)
- After trial: automatically charged $9.99/month or $69.99/year
- Users can cancel anytime during trial without being charged

### Paywall Copy (from Notion)

```
Unlock {Feature}

{feature description}

Why it's locked:
- (trial available): This feature is included with Pro. Start your 4-week free trial to unlock it.
- (trial used): This feature is included with Pro. Upgrade to unlock it.

Pro Plan:
 TrainingPeaks & FinalSurge Integration
 Meal logging
 Brick workout planning
 Personal fueling templates
 By-hour race day nutrition planning
 Mealvana 101 (fueling course)
 10 expiring cookies each month + one-time 10 status cookies

CTA Button:
- (trial available): Start 4-week free trial
- (trial used): Unlock Pro
-> jump to the pricing page

Secondary CTA: Not now

About Cookies:
Cookies unlock meal planning and recipe import. Pro includes 10 expiring
cookies each month. You can also buy status cookies that never expire.

Notes (small font):
Manage your subscription in Settings anytime.
After the free trial, you will be charged $9.95/month or $69/year unless you cancel.
```

---

## Step-by-Step Instructions for Remaining Phases

### PHASE 3: Create Subscription Products

**Website**: https://appstoreconnect.apple.com

1. My Apps -> **Mealvana Endurance** -> left sidebar **Monetization** -> **Subscriptions**
2. Click **+** next to "Subscription Groups" -> name: `Pro Subscriptions` -> **Create**
3. Inside the group, click **+** to add subscription:
   - Reference Name: `Pro Monthly`
   - Product ID: `mealvana_pro_monthly` (MUST match RevenueCat)
   - Duration: **1 Month**
   - Price: **$9.99** (United States)
   - Localization (English U.S.): Display Name `Mealvana Pro`, description of features
   - Introductory Offer: **Free**, **1 Month**, all territories
4. Repeat for annual:
   - Reference Name: `Pro Annual`
   - Product ID: `mealvana_pro_annual`
   - Duration: **1 Year**
   - Price: **$69.99**
   - Same localization and free trial config
5. Set subscription level order: Annual = position 1, Monthly = position 2

### PHASE 4: Sandbox Test Accounts

**Website**: https://appstoreconnect.apple.com -> Users and Access -> Sandbox

1. Click **+**, create `lee+sandbox1@mealvana.com` (US region)
2. Click **+**, create `lee+sandbox2@mealvana.com` (US region)
3. On iPhone: Settings -> Developer -> Sandbox Apple Account -> sign in

### PHASE 5: Xcode Capability

1. Open `ios/Runner.xcworkspace` in Xcode
2. Runner target -> **Signing & Capabilities** -> **+ Capability** -> **In-App Purchase**

### PHASE 6: Connect RevenueCat

**Website**: https://app.revenuecat.com -> Mealvana Endurance project

1. **+ Add app** -> Apple App Store
2. App Name: `Mealvana Endurance iOS`
3. Bundle ID: `com.milkman.mealvanaendurance`
4. Upload `SubscriptionKey_3Q27QQ626C.p8`
5. Key ID: `3Q27QQ626C`
6. Issuer ID: `4ddd5f89-a054-4c06-b65a-ac9ed980786d`
7. Save -> confirm "Valid credentials"
8. Tell Claude the new app ID so MCP can create products/packages for the iOS app

---

## Key Architecture Decisions

- **Entitlement name**: `pro` (not `premium` as in old docs)
- **Product IDs**: `mealvana_pro_monthly` and `mealvana_pro_annual`
- **Offering**: `default` with `$rc_monthly` and `$rc_annual` packages
- **User identification**: Use Supabase `user_id` via `Purchases.logIn(supabaseUserId)`
- **Offline caching**: Premium status cached in Drift `users` table
- **Initialization**: In `appStartupProvider` (not `main()`) per Andrea Bizzotto pattern
- **Feature gating**: Drawer-style paywall that returns user to attempted feature after purchase

---

## Websites Quick Reference

| Task | Website | Path |
|------|---------|------|
| Agreements/Tax/Banking | appstoreconnect.apple.com | Business |
| Bundle ID + Capabilities | developer.apple.com/account | Certificates, Identifiers & Profiles -> Identifiers |
| Subscription Products | appstoreconnect.apple.com | My Apps -> [App] -> Monetization -> Subscriptions |
| IAP Key (.p8) | appstoreconnect.apple.com | Users and Access -> Integrations -> In-App Purchase |
| Sandbox Testers | appstoreconnect.apple.com | Users and Access -> Sandbox |
| Xcode Capability | Xcode | Runner -> Signing & Capabilities -> + In-App Purchase |
| RevenueCat Dashboard | app.revenuecat.com | Project -> Apps -> + Add App |

---

## Document History

| Date | Change |
|------|--------|
| 2025-11-19 | Initial guide created (old pricing: $19.99/mo, 7-day trial) |
| 2026-03-17 | Major update: new pricing ($9.99/mo, $69.99/yr), 4-week trial, updated feature list from Notion paywall spec, RevenueCat test store configured via MCP, IAP key generated |
