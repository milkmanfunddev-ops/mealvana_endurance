# RevenueCat Setup Guide for Mealvana Endurance
**Date**: November 2025
**Status**: Step-by-step setup instructions
**Audience**: Lee (Human Developer)

---

## Overview

This guide walks you through setting up RevenueCat for Mealvana Endurance from scratch. Follow these steps in order.

**Estimated Time**: 2-3 hours

---

## Prerequisites Checklist

Before starting, verify you have:

- [x] App Store Connect account with admin access
- [x] Paid Applications Agreement signed
- [x] Tax forms completed (Clear status)
- [x] Bank account linked to App Store Connect
- [ ] Phase 2 authentication complete (RECOMMENDED)

---

## Part 1: App Store Connect - Create Subscription Products

### Step 1: Access Subscriptions Dashboard

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Click **My Apps**
3. Select **Mealvana Endurance**
4. Click **Features** tab at top
5. Click **Subscriptions** in left sidebar

### Step 2: Create Subscription Group

**What is a Subscription Group?**
- A container for related subscription products (monthly, annual, etc.)
- Users can only have ONE active subscription per group
- If they upgrade/downgrade, it happens within the group

**Steps:**
1. Click the **blue "+" button** next to "Subscription Groups"
2. Enter **Reference Name**: `Premium Subscriptions`
   - This is internal only, users never see it
3. Click **Create**

### Step 3: Create Monthly Subscription Product

**Inside your new "Premium Subscriptions" group:**

1. Click the **blue "+" button** to add a subscription
2. Fill in the form:

**Reference Name** (required):
```
Monthly Premium Subscription
```
- This is internal only, users never see it
- Max 64 characters

**Product ID** (required):
```
mealvana_premium_monthly
```
- ⚠️ **IMPORTANT**: Cannot be changed later!
- ⚠️ **IMPORTANT**: Cannot be reused if you delete the product!
- Must be alphanumeric (letters, numbers, underscores, periods)
- Best practice: `{app}_{tier}_{duration}` format

**Alternative Product IDs** (pick one):
- Simple: `premium_monthly`
- Descriptive: `mealvana_1999_1m_trial7d`
- Versioned: `premium_monthly_v1`

3. **Subscription Duration**: Select **1 month**
4. Click **Create**

### Step 4: Set Subscription Price

1. In the **Subscription Prices** section, click **"+"**
2. **Start Date**: Select today's date
3. **Price**:
   - Select **$19.99 (USD)** from the price tier dropdown
   - OR manually enter $19.99 in your default currency
4. Apple automatically sets regional pricing (you can customize per-country later)
5. Click **Next** → **Create** → **Save**

### Step 5: Configure Free Trial (7 Days)

1. Click **Subscription** tab (if not already there)
2. Scroll to **Introductory Offers** section
3. Click **"+"** to add an introductory offer
4. Fill in:
   - **Countries or Regions**: Select all countries (or specific markets)
   - **Start Date**: Today
   - **Offer Type**: Select **Free**
   - **Duration**: Select **1 week** (7 days)
5. Click **Save**

**Important Notes:**
- Users are eligible for ONE introductory offer per subscription group (lifetime)
- After the 7-day trial, they're automatically charged $19.99/month
- Users can cancel during trial without being charged

### Step 6: Add Localization (Required for App Review)

1. Scroll to **App Store Information** section
2. Click **"+"** next to "Subscription Display Name"
3. Select **English (U.S.)**
4. Fill in:

**Subscription Display Name**:
```
Premium Membership
```
- This is what users see in App Store subscription management
- Must be the same for all products in the same tier

**Description**:
```
Unlock premium features including barcode scanning, pro recipes, coach integration, and advanced training platform integrations. Get personalized nutrition plans powered by AI.
```
- Sell the benefits!
- Max 45 characters for display name, unlimited for description

5. Click **Save**

### Step 7: Add App Review Information

1. Scroll to **Review Information** section
2. **Screenshot**: Upload a 640 x 920 pixel screenshot showing:
   - The paywall screen (can be a mockup if UI isn't built yet)
   - The monthly subscription option
   - The free trial callout

**How to create screenshot if UI isn't ready:**
- Take a screenshot of your existing ProVersionScreen
- OR use Figma/Sketch to create a mockup
- OR temporarily skip this (add before submitting app)

3. **Review Notes** (optional):
```
Monthly subscription with 7-day free trial. Users gain access to premium features including barcode scanning, recipe library, and third-party integrations.

Test Account:
Email: [your sandbox tester email]
Password: [sandbox tester password]
```

4. Click **Save**

### Step 8: Verify Product Status

Your subscription should now show:
- **Status**: "Ready to Submit" (yellow badge)
- **Price**: $19.99/month
- **Trial**: 7-day free trial
- **Localization**: At least one language

**If status is "Missing Metadata":**
- Add localization (Step 6)
- Add review screenshot (Step 7)

---

## Part 2: Generate In-App Purchase Key (.p8 File)

### What is an In-App Purchase Key?

This is a **StoreKit 2** credential that allows RevenueCat to validate receipts with Apple. It's **different** from your authentication key (`AuthKey_Z875MDK9BR.p8`).

### Step 1: Generate the Key

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Click **Users and Access** at the top
3. Click **Integrations** tab
4. Click **In-App Purchase** in the left sidebar
   - Direct link: https://appstoreconnect.apple.com/access/integrations/api/subs
5. Click **"Generate In-App Purchase Key"** or the **blue "+" button**
6. Enter a name:
   ```
   RevenueCat Production IAP Key
   ```
7. Click **Generate**

### Step 2: Download the .p8 File

⚠️ **CRITICAL**: You can only download this file **ONCE**. If you lose it, you must generate a new key.

1. Click **Download API Key**
2. Save the file to:
   ```
   /Users/leemartin/development/mealvana_endurance/secrets/apple/SubscriptionKey_XXXXXXXXXX.p8
   ```
   - The filename will be something like `SubscriptionKey_A1B2C3D4E5.p8`
   - The `XXXXXXXXXX` part is your **Key ID**

3. **IMPORTANT**: Also save this file to:
   - 1Password (or your password manager)
   - External backup drive
   - Secure cloud storage

### Step 3: Save the Key ID and Issuer ID

**Key ID:**
- Found in the filename: `SubscriptionKey_XXXXXXXXXX.p8`
- Example: If filename is `SubscriptionKey_A1B2C3D4E5.p8`, Key ID is `A1B2C3D4E5`
- Also shown in the table next to your key name

**Issuer ID:**
- Located at the **TOP of the page** (above the keys table)
- Looks like: `12345678-90ab-cdef-1234-567890abcdef` (UUID format)
- Same for all keys in your account

**Save these to a text file:**

Create this file:
```
/Users/leemartin/development/mealvana_endurance/secrets/apple/CREDENTIALS.md
```

With this content:
```markdown
# Apple App Store Connect Credentials

## In-App Purchase Key (RevenueCat)
- **Key Name**: RevenueCat Production IAP Key
- **Key ID**: A1B2C3D4E5 (replace with your actual Key ID)
- **Issuer ID**: 12345678-90ab-cdef-1234-567890abcdef (replace with your actual Issuer ID)
- **File**: SubscriptionKey_A1B2C3D4E5.p8
- **Created**: 2025-11-19
- **Purpose**: RevenueCat receipt validation

## App Store Connect API Key (Optional - for auto-importing products)
- Not yet created
- Required for automatic product sync between App Store Connect and RevenueCat

## Authentication Key (Sign in with Apple)
- **Key ID**: Z875MDK9BR
- **File**: AuthKey_Z875MDK9BR.p8
- **Purpose**: Sign in with Apple / OAuth
```

---

## Part 3: Create RevenueCat Account

### Step 1: Sign Up

1. Go to [RevenueCat](https://app.revenuecat.com)
2. Click **Sign Up** (if you haven't already)
3. Use your work email
4. Choose **Free** plan (covers first ~125 subscribers)

**Already have an account?**
- Log in at https://app.revenuecat.com

### Step 2: Create a Project

1. Click **"+ Create new project"** or **"+ New"** button
2. **Project Name**:
   ```
   Mealvana Endurance
   ```
3. Click **Create**

### Step 3: Add iOS App

1. Inside your project, click **"+ Add app"**
2. **Platform**: Select **iOS**
3. **App Name**:
   ```
   Mealvana Endurance (iOS)
   ```
4. **Bundle ID**: Enter your iOS bundle identifier
   - Find it in Xcode: Select project → Target → General → Bundle Identifier
   - Example: `com.mealvana.endurance` (replace with your actual bundle ID)
5. Click **Save**

---

## Part 4: Configure RevenueCat Dashboard

### Step 1: Upload In-App Purchase Key

1. In RevenueCat dashboard, click your **iOS app**
2. Click **Apple App Store configuration** (or **"Configure"** button)
3. Scroll to **In-app purchase key configuration** section
4. Click **Upload**
5. **Select your .p8 file**:
   ```
   /Users/leemartin/development/mealvana_endurance/secrets/apple/SubscriptionKey_XXXXXXXXXX.p8
   ```
6. **Issuer ID**: Paste your Issuer ID (from CREDENTIALS.md)
7. Click **Save changes**
8. **Verify**: You should see ✅ **"Valid credentials"** message

**If you see an error:**
- Verify the .p8 file is the In-App Purchase key (not AuthKey)
- Double-check the Issuer ID is correct (UUID format)
- Ensure you have at least one subscription product in App Store Connect

### Step 2: Create an Entitlement

**What is an Entitlement?**
- Represents a level of access in your app (e.g., "premium", "pro")
- Decouples your code from specific product IDs
- One entitlement can be unlocked by multiple products (monthly + annual both unlock "premium")

**Steps:**
1. Click **Project** → **Products** (or **Product catalog**)
2. Click **Entitlements** tab
3. Click **"+ New"**
4. **Identifier**:
   ```
   premium
   ```
   - ⚠️ Must be lowercase, alphanumeric, underscores only
   - This MUST match your code: `customerInfo.entitlements.active.containsKey('premium')`
   - Cannot change later!
5. **Description**:
   ```
   Premium features access
   ```
6. Click **Save**

### Step 3: Create Product in RevenueCat

**Why?** RevenueCat needs to know about your products before they can be purchased.

1. Still in **Product catalog**, click **Products** tab
2. Click **"+ New"**
3. **Product Identifier**:
   ```
   mealvana_premium_monthly
   ```
   - ⚠️ **MUST EXACTLY MATCH** your App Store Connect Product ID
4. **Store**: Select **App Store**
5. **Type**: Select **Subscription**
6. Click **Save**

### Step 4: Attach Product to Entitlement

**This is critical!** If you skip this step, purchases won't unlock features.

1. Click on your **"premium"** entitlement (from Step 2)
2. In the **Products** section, click **"Attach"**
3. Select **"mealvana_premium_monthly"**
4. Click **Save**

**Verify:**
- "premium" entitlement should show "1 product attached"
- "mealvana_premium_monthly" should show "Attached to: premium"

### Step 5: Create an Offering

**What is an Offering?**
- A collection of products you present to users (your paywall)
- Can have multiple offerings (e.g., "default", "promo_summer", "launch_week")
- Your code fetches the "current" offering to display

**Steps:**
1. Still in **Product catalog**, click **Offerings** tab
2. Click **"+ New"**
3. **Identifier**:
   ```
   default
   ```
   - This is what you'll use in code: `offerings.current`
4. **Description**:
   ```
   Default subscription offering
   ```
5. Click **Save**

### Step 6: Add Package to Offering

**What is a Package?**
- A product within an offering with a specific type (monthly, annual, lifetime)
- Uses pre-defined types for easy SDK access

**Steps:**
1. Click on your **"default"** offering
2. In the **Packages** section, click **"+ Add"**
3. **Package identifier**: Select **$rc_monthly**
   - This allows you to access it via `offering.monthly` in SDK
4. **Product**: Select **mealvana_premium_monthly**
5. **Set as default**: Check this box (makes it the highlighted option)
6. Click **Save**

### Step 7: Set as Current Offering

1. Next to your "default" offering, click the **star icon** or **"Set as current"**
2. Confirm

**Verify:**
- "default" offering should have a ⭐ icon
- Shows "Current" badge
- Has 1 package attached

---

## Part 5: Get Your API Keys

### Step 1: Find Public API Key (iOS)

1. In RevenueCat dashboard, click the **gear icon** (⚙️) top right
2. Click **Projects** → Select your project
3. Click **API keys** in left sidebar
4. Under **Public app-specific keys**, find the **Apple App Store** key
   - Format: `appl_XXXXXXXXXXXXXXXXXXXX`
   - This key is **safe to use in your app** (public key)

### Step 2: Save to Environment File

Create/update this file:
```
/Users/leemartin/development/mealvana_endurance/.env.dev.local
```

Add this line:
```bash
REVENUECAT_IOS_API_KEY=appl_XXXXXXXXXXXXXXXXXXXX
```

**For production** (when ready):
```
/Users/leemartin/development/mealvana_endurance/.env.prod.local
```

Add:
```bash
REVENUECAT_IOS_API_KEY=appl_XXXXXXXXXXXXXXXXXXXX
```

**Security:**
- These files are already git-ignored ✅
- Safe to store API keys here
- Never commit to version control

---

## Part 6: Create Sandbox Test Accounts

### Step 1: Create Sandbox Tester

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Click **Users and Access**
3. Click **Sandbox** (or **Sandbox Testers**) in left sidebar
4. Click **"+"** to add a tester
5. Fill in:
   - **First Name**: `Test`
   - **Last Name**: `Premium User`
   - **Email**:
     ```
     lee+sandbox1@mealvana.com
     ```
     - Use the `+` trick: `youremail+sandbox1@gmail.com`
     - Must be a valid, verifiable email format
   - **Password**: Create a strong password (save in 1Password)
   - **Country/Region**: Select **United States**
   - **Date of Birth**: Enter any date (must be 18+)
6. Click **Invite**

**Create 2-3 sandbox accounts** for different test scenarios:
- `lee+sandbox1@mealvana.com` - For purchase testing
- `lee+sandbox2@mealvana.com` - For restore testing
- `lee+sandbox3@mealvana.com` - For cancellation testing

### Step 2: Configure Sandbox Account on Device

⚠️ **Do this on your physical iOS device** (not simulator):

1. Open **Settings** app
2. Scroll down to **App Store**
3. Scroll to bottom → **Sandbox Account**
4. Sign in with your sandbox tester email
   - Email: `lee+sandbox1@mealvana.com`
   - Password: [your test password]

**You do NOT need to sign out of your regular Apple ID!**

### Step 3: Enable Sandbox View in RevenueCat

1. RevenueCat dashboard → **Customer Lists**
2. Toggle **"View Sandbox Data"** ON (top right)
3. Now you'll see sandbox purchases in the dashboard

---

## Part 7: Verification Checklist

Before proceeding to code implementation, verify:

### App Store Connect ✅
- [x] Paid Applications Agreement signed
- [ ] Subscription Group "Premium Subscriptions" created
- [ ] Product "mealvana_premium_monthly" created
- [ ] Product status: "Ready to Submit"
- [ ] Price set: $19.99/month
- [ ] Free trial: 7 days configured
- [ ] Localization added (English)
- [ ] Review screenshot uploaded

### Credentials ✅
- [ ] In-App Purchase Key (.p8 file) downloaded
- [ ] Key ID saved
- [ ] Issuer ID saved
- [ ] .p8 file stored in `/secrets/apple/`
- [ ] CREDENTIALS.md created with all info
- [ ] Backup copy stored in 1Password

### RevenueCat Dashboard ✅
- [ ] Account created
- [ ] Project "Mealvana Endurance" created
- [ ] iOS app added with correct bundle ID
- [ ] In-App Purchase Key uploaded (✅ "Valid credentials")
- [ ] Entitlement "premium" created
- [ ] Product "mealvana_premium_monthly" created
- [ ] Product attached to "premium" entitlement
- [ ] Offering "default" created
- [ ] Package "$rc_monthly" added to offering
- [ ] "default" marked as Current offering ⭐
- [ ] Public API key copied (starts with `appl_`)

### Environment Configuration ✅
- [ ] `.env.dev.local` updated with `REVENUECAT_IOS_API_KEY`
- [ ] `.env.prod.local` updated with `REVENUECAT_IOS_API_KEY`

### Testing Setup ✅
- [ ] 2-3 sandbox test accounts created
- [ ] Sandbox account configured on physical iOS device
- [ ] "View Sandbox Data" enabled in RevenueCat dashboard

---

## What's Next?

Once you've completed this setup guide, you're ready for **code implementation**!

The next steps are:
1. Install `purchases_flutter` SDK
2. Initialize RevenueCat in app startup service
3. Create subscription feature architecture
4. Build paywall screen
5. Implement purchase flow
6. Test in sandbox

Estimated time for code implementation: **2-3 days**

---

## Troubleshooting

### "Cannot find products in App Store Connect"
- Wait 24 hours after creating products
- Ensure product status is "Ready to Submit"
- Verify you're signed in with the correct Apple ID

### "Valid credentials" not showing in RevenueCat
- Verify you uploaded the In-App Purchase Key (.p8), not AuthKey
- Double-check Issuer ID is correct (UUID format)
- Ensure at least one product exists in App Store Connect

### "Products not appearing in app"
- Verify bundle ID matches between Xcode and RevenueCat
- Ensure products are configured in RevenueCat dashboard
- Check that product IDs match exactly
- Wait 24 hours if products were just created

### "Sandbox purchases not working"
- Verify sandbox account is signed in (Settings → App Store → Sandbox Account)
- Ensure you're testing on a **physical device** (not simulator)
- Try deleting and reinstalling the app
- Check that subscription product is "Ready to Submit"

---

## Resources

- **App Store Connect**: https://appstoreconnect.apple.com
- **RevenueCat Dashboard**: https://app.revenuecat.com
- **RevenueCat Docs**: https://www.revenuecat.com/docs
- **Support**: https://community.revenuecat.com

---

**Last Updated**: November 19, 2025
**Author**: Claude (AI Assistant)
**For**: Lee Martin
