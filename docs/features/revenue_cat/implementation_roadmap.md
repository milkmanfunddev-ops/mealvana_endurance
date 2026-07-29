# RevenueCat Implementation Roadmap

**Target Phase**: Phase 4 (Monetization)
**Estimated Duration**: 2-3 weeks
**Total Development Time**: 12-18 hours
**Prerequisites**: Phase 2 (Email/OAuth auth) and Phase 3 (Multi-device sync) must be complete

---

## Overview

This roadmap provides a step-by-step implementation guide for integrating RevenueCat subscriptions into Mealvana Endurance. Tasks are clearly divided between:

- **👤 YOUR TASKS**: Steps that require your manual action (App Store Connect, account setup, business decisions)
- **🤖 AI TASKS**: Steps that I (Claude) can implement for you (code, configuration files, documentation)
- **🤝 COLLABORATIVE**: Steps requiring both of us (testing, review, deployment)

---

## Phase 1: Account Setup & Configuration (Week 1, Days 1-2)

**Goal**: Create all necessary accounts and configure App Store Connect
**Duration**: 2-3 hours
**Prerequisites**: App Store developer account with admin access

### 1.1 Create RevenueCat Account

**👤 YOUR TASK**:
1. Navigate to https://app.revenuecat.com
2. Sign up with email (use company email for Mealvana)
3. Verify email address
4. Create new project
   - Name: "Mealvana Endurance"
   - Platform: iOS (we'll add Android later)
5. **COPY** the iOS API key (starts with `appl_`)
6. **SAVE** API key securely (we'll need it for code)

**Estimated Time**: 10 minutes

**Output Needed**:
- ✅ RevenueCat account created
- ✅ Project "Mealvana Endurance" exists
- ✅ iOS API key copied to secure location

---

### 1.2 Verify App Store Connect Prerequisites

**👤 YOUR TASK**:
1. Log in to https://appstoreconnect.apple.com
2. Navigate to **Business** module
3. Verify **Paid Applications Agreement** is signed (must show "Active")
4. Navigate to **Agreements, Tax, and Banking**
5. Click **Tax** tab
   - Complete all tax forms if not done
   - Status must show "Complete"
6. Click **Banking** tab
   - Add bank account if not done
   - Status must show "Clear"
7. Verify app "Mealvana Endurance" exists in "My Apps"
   - Bundle ID should be `com.mealvana.endurance` (or your chosen ID)

**Estimated Time**: 15-30 minutes (instant if already complete, longer if forms needed)

**Output Needed**:
- ✅ Paid Applications Agreement: Active
- ✅ Tax forms: Complete
- ✅ Banking: Clear
- ✅ App exists with correct Bundle ID

**⚠️ BLOCKER**: Cannot create subscription products until all three are complete.

---

### 1.3 Create Subscription Products in App Store Connect

**👤 YOUR TASK**:

#### Step 1: Create Subscription Group
1. App Store Connect → **My Apps** → **[Mealvana Endurance]**
2. Click **Features** tab → **Subscriptions**
3. Click **"+"** to create new Subscription Group
4. **Subscription Group Reference Name**: `premium_subscriptions`
5. Click **Create**

#### Step 2: Create Monthly Subscription Product
1. Within the subscription group, click **"+"** to add subscription
2. **Product ID**: `premium_monthly` (CRITICAL: Must match exactly)
3. **Reference Name**: `Premium Monthly Subscription`
4. Click **Create**

#### Step 3: Configure Subscription Details
1. **Subscription Duration**: Select **1 month**
2. **Subscription Prices**:
   - Click **Add Subscription Price**
   - Select **United States** → **$19.99 USD**
   - Add other countries/regions as desired
   - Click **Next** → **Create**

#### Step 4: Add Subscription Information
1. **Subscription Display Name**: `Premium Access`
2. **Description**:
   ```
   Get unlimited access to premium features including barcode scanning,
   coach integration, pro recipes, and integrations with TrainingPeaks,
   Final Surge, Canva, and Strava.
   ```
3. Click **Save**

#### Step 5: Add Free Trial (7 Days)
1. Scroll to **Subscription Prices**
2. Click **Add Introductory Offer**
3. **Offer Type**: Free
4. **Duration**: 7 Days
5. **Countries/Regions**: Select all (or as desired)
6. Click **Create**

#### Step 6: App Store Promotion (Optional)
1. Upload promotional image (1024x1024 PNG)
2. Provide promotional text highlighting premium features
3. Click **Save**

#### Step 7: Submit Subscription for Review
1. **Review Information** section:
   - Upload screenshot showing subscription benefits
   - Provide reviewer notes if needed
2. Click **Submit for Review**
   - Note: Subscriptions can be in "Waiting for Review" status until app submitted

**Estimated Time**: 30-45 minutes

**Output Needed**:
- ✅ Subscription Group: `premium_subscriptions` created
- ✅ Product ID: `premium_monthly` at $19.99/month
- ✅ Free trial: 7 days configured
- ✅ Subscription submitted for review

---

### 1.4 Generate App Store Connect Credentials

**👤 YOUR TASK**:

#### Credential 1: App-Specific Shared Secret

1. App Store Connect → **My Apps** → **[Mealvana Endurance]**
2. Click **App Information** (in General section on left)
3. Scroll to **App-Specific Shared Secret**
4. Click **Manage**
5. Click **Generate** (or use existing if already generated)
6. **COPY** the secret immediately
7. **SAVE** to secure location: `/Users/leemartin/development/mealvana_endurance/secrets/app_store_shared_secret.txt`

**⚠️ CRITICAL**: You can only view this once! Save it immediately.

#### Credential 2: In-App Purchase Key (.p8 File)

1. App Store Connect → **Users and Access** (top right)
2. Click **Integrations** tab
3. Click **In-App Purchase** sub-tab
4. Click **Generate In-App Purchase Key**
5. **Name**: `RevenueCat Integration`
6. Click **Generate**
7. **DOWNLOAD** the .p8 file immediately (you cannot download again!)
8. **COPY** the Key ID (e.g., `AB12CD34EF`)
9. **SAVE** .p8 file to: `/Users/leemartin/development/mealvana_endurance/secrets/AuthKey_[KEYID].p8`
10. **SAVE** Key ID to: `/Users/leemartin/development/mealvana_endurance/secrets/in_app_purchase_key_id.txt`

**⚠️ CRITICAL**: .p8 file can only be downloaded ONCE. Keep it safe!

#### Credential 3: App Store Connect API Key (Optional but Recommended)

1. App Store Connect → **Users and Access** → **Integrations**
2. Click **App Store Connect API** tab
3. Click **"+"** to generate new key
4. **Name**: `RevenueCat API Access`
5. **Access**: Select **App Manager**
6. Click **Generate**
7. **DOWNLOAD** the .p8 file immediately
8. **COPY** Issuer ID (top of page, e.g., `12345678-1234-1234-1234-123456789012`)
9. **COPY** Key ID (e.g., `XYZ123ABCD`)
10. **SAVE** .p8 file to: `/Users/leemartin/development/mealvana_endurance/secrets/AuthKey_API_[KEYID].p8`
11. **SAVE** Issuer ID to: `/Users/leemartin/development/mealvana_endurance/secrets/app_store_api_issuer_id.txt`
12. **SAVE** Key ID to: `/Users/leemartin/development/mealvana_endurance/secrets/app_store_api_key_id.txt`

**Estimated Time**: 15-20 minutes

**Output Needed**:
- ✅ App-Specific Shared Secret saved
- ✅ In-App Purchase .p8 file downloaded and saved
- ✅ In-App Purchase Key ID saved
- ✅ App Store Connect API .p8 file downloaded and saved
- ✅ API Issuer ID and Key ID saved

**⚠️ SECURITY NOTE**: These files are in `.gitignore` and will NOT be committed to Git.

---

### 1.5 Configure RevenueCat Dashboard

**👤 YOUR TASK**:

#### Step 1: Add iOS App
1. RevenueCat Dashboard → **Project Settings** → **Apps**
2. Click **Add App** or **Configure** next to iOS
3. **App Name**: `Mealvana Endurance iOS`
4. **Bundle ID**: `com.mealvana.endurance` (must match Xcode exactly)
5. Click **Save**

#### Step 2: Add App Store Connect Credentials
1. In the iOS app settings, scroll to **App Store Connect Integration**
2. **App-Specific Shared Secret**:
   - Paste the shared secret from step 1.4
   - Click **Save**
3. **In-App Purchase Key**:
   - Click **Upload In-App Purchase Key**
   - Select the .p8 file from step 1.4
   - Enter Key ID
   - Click **Upload**
4. **App Store Connect API Key** (Optional):
   - Click **Upload App Store Connect API Key**
   - Select the API .p8 file from step 1.4
   - Enter Issuer ID
   - Enter Key ID
   - Click **Upload**

#### Step 3: Create Entitlement
1. RevenueCat Dashboard → **Entitlements**
2. Click **New Entitlement**
3. **Identifier**: `premium` (CRITICAL: Must match code exactly)
4. **Display Name**: `Premium Access`
5. Click **Save**

#### Step 4: Add Product
1. RevenueCat Dashboard → **Products**
2. Click **New Product**
3. **Product Identifier**: `premium_monthly` (CRITICAL: Must match App Store Connect exactly)
4. **Store**: iOS App Store
5. Click **Save**

**Note**: It may take a few minutes for RevenueCat to sync with App Store Connect and fetch product details.

#### Step 5: Attach Product to Entitlement
1. RevenueCat Dashboard → **Entitlements** → Click `premium`
2. Click **Attach Products**
3. Select `premium_monthly`
4. Click **Save**

#### Step 6: Configure Default Offering
1. RevenueCat Dashboard → **Offerings**
2. Default offering should exist automatically
3. Click **Edit** on default offering
4. Click **Add Package** → **Monthly**
5. Select `premium_monthly` product
6. Click **Save**

**Estimated Time**: 20-30 minutes

**Output Needed**:
- ✅ iOS app configured in RevenueCat
- ✅ All credentials uploaded successfully
- ✅ Entitlement `premium` created
- ✅ Product `premium_monthly` added
- ✅ Product attached to entitlement
- ✅ Default offering configured with monthly package

**✅ PHASE 1 COMPLETE**: All accounts configured, ready for code implementation!

---

## Phase 2: Flutter SDK Integration (Week 1, Days 3-4)

**Goal**: Install RevenueCat SDK and create service layer
**Duration**: 3-4 hours
**Prerequisites**: Phase 1 complete, iOS API key available

### 2.1 Update Dependencies

**🤖 AI TASK** (I'll do this):

1. Update `pubspec.yaml`:
```yaml
dependencies:
  # ... existing dependencies ...
  purchases_flutter: ^9.12.0
  purchases_ui_flutter: ^9.0.0  # For pre-built paywalls
```

2. Update iOS minimum version in `ios/Podfile`:
```ruby
platform :ios, '13.0'
```

3. Run:
```bash
flutter pub get
cd ios && pod install && cd ..
```

**Estimated Time**: 5 minutes

**Output**:
- ✅ Dependencies added to pubspec.yaml
- ✅ iOS Podfile updated
- ✅ Packages installed

---

### 2.2 Create Secrets Service

**🤖 AI TASK** (I'll do this):

Create `/lib/shared/services/secrets_service.dart`:
```dart
import 'dart:io';
import 'package:flutter/services.dart';

class SecretsService {
  static String? _revenueCatIosKey;

  static Future<void> initialize() async {
    // Load RevenueCat API key from secure storage
    try {
      _revenueCatIosKey = await rootBundle.loadString(
        'secrets/revenuecat_ios_api_key.txt',
      );
      _revenueCatIosKey = _revenueCatIosKey?.trim();
    } catch (e) {
      throw Exception('Failed to load RevenueCat API key: $e');
    }
  }

  static String getRevenueCatApiKey() {
    if (_revenueCatIosKey == null || _revenueCatIosKey!.isEmpty) {
      throw Exception('RevenueCat API key not initialized');
    }
    return _revenueCatIosKey!;
  }
}
```

**Estimated Time**: 5 minutes

---

### 2.3 Store RevenueCat API Key

**👤 YOUR TASK**:

1. Create file: `/Users/leemartin/development/mealvana_endurance/secrets/revenuecat_ios_api_key.txt`
2. Paste your RevenueCat iOS API key (starts with `appl_`) from step 1.1
3. Save the file

**🤖 AI TASK** (I'll do this):

Update `pubspec.yaml` to include secrets in assets:
```yaml
flutter:
  assets:
    # ... existing assets ...
    - secrets/revenuecat_ios_api_key.txt
```

Update `.gitignore` to ensure secrets never committed:
```
# Secrets directory
secrets/
!secrets/.gitkeep
!secrets/README.md
```

Create `secrets/README.md` with instructions for team members.

**Estimated Time**: 5 minutes

**Output**:
- ✅ API key stored in secrets/
- ✅ pubspec.yaml updated with assets
- ✅ .gitignore protects secrets
- ✅ README.md documents secret management

---

### 2.4 Create RevenueCat Service

**🤖 AI TASK** (I'll do this):

Create full-featured RevenueCat service following Andrea Bizzotto's patterns:

**File**: `/lib/features/subscription/data/revenuecat_service.dart`

This service will include:
- SDK initialization
- Customer info retrieval
- Premium access checking
- Offering fetching
- Purchase handling with error management
- Restore purchases
- User identification (login/logout)
- Customer info listener setup
- Trial eligibility checking

Plus supporting files:
- Domain models for `PurchaseResult`
- Riverpod provider with `@riverpod` annotation

**Estimated Time**: 30 minutes

**Output**:
- ✅ RevenueCatService class created
- ✅ All methods implemented
- ✅ Error handling included
- ✅ Riverpod provider configured

---

### 2.5 Create Subscription Status Provider

**🤖 AI TASK** (I'll do this):

Create state management for subscription status:

**File**: `/lib/features/subscription/application/subscription_status_provider.dart`

Features:
- AsyncNotifier pattern
- Real-time subscription status updates
- Sync to Drift database for offline access
- Integration with RevenueCat customer info listener

**Estimated Time**: 20 minutes

**Output**:
- ✅ SubscriptionStatus provider created
- ✅ Real-time updates configured
- ✅ Database sync implemented

---

### 2.6 Update App Startup Service

**🤖 AI TASK** (I'll do this):

Integrate RevenueCat initialization into app startup:

**File**: `/lib/shared/services/app_startup_service.dart`

Changes:
1. Load secrets service
2. Initialize RevenueCat SDK
3. Check initial subscription status
4. Sync premium status to Drift database
5. Set up real-time listener

Following Andrea Bizzotto's pattern: happens in `appStartupProvider`, NOT `main()`.

**Estimated Time**: 15 minutes

**Output**:
- ✅ RevenueCat initialized on app startup
- ✅ Premium status cached locally
- ✅ Follows Andrea Bizzotto initialization pattern

---

### 2.7 Update Drift Database Schema

**🤖 AI TASK** (I'll do this):

Add subscription fields to Users table:

**File**: `/lib/shared/database/app_database.dart`

Fields to add:
```dart
BoolColumn get isPremium => boolean().withDefault(const Constant(false))();
DateTimeColumn get premiumExpiresAt => dateTime().nullable()();
TextColumn get subscriptionStatus => text().nullable()();
DateTimeColumn get subscriptionUpdatedAt => dateTime().nullable()();
```

Generate migration and schema snapshot.

**Estimated Time**: 20 minutes

**Output**:
- ✅ Database schema updated
- ✅ Migration generated
- ✅ Schema snapshot updated

---

### 2.8 Run Code Generation

**🤖 AI TASK** (I'll do this):

```bash
dart run build_runner build --delete-conflicting-outputs
```

This generates:
- `.g.dart` files for Riverpod providers
- Drift database classes
- Schema migrations

**Estimated Time**: 2 minutes

**Output**:
- ✅ All code generation complete
- ✅ No build errors

---

### 2.9 Test Basic Integration

**🤝 COLLABORATIVE TASK**:

**🤖 AI**: Create simple test screen to verify SDK initialization

**👤 YOU**: Run app on device and verify:
1. App starts without errors
2. RevenueCat SDK initializes successfully
3. Customer info can be retrieved
4. Check debug logs for RevenueCat initialization

```bash
flutter run
# Watch console for: "RevenueCat initialized successfully"
```

**Estimated Time**: 10 minutes

**Output**:
- ✅ SDK initializes without errors
- ✅ Can retrieve customer info
- ✅ No crashes or exceptions

**✅ PHASE 2 COMPLETE**: RevenueCat SDK integrated and operational!

---

## Phase 3: UI Implementation (Week 2, Days 1-3)

**Goal**: Build paywall, subscription management, and feature gating
**Duration**: 4-5 hours
**Prerequisites**: Phase 2 complete, can run app successfully

### 3.1 Update Content Management System

**🤖 AI TASK** (I'll do this):

Add paywall content to `assets/config/content_defaults.json`:

```json
{
  "ui_text": {
    "paywall": {
      "title": "Upgrade to Premium",
      "subtitle": "Unlock advanced nutrition features for endurance athletes",
      "trial_cta": "Start 7-Day Free Trial",
      "subscribe_cta": "Subscribe Now",
      "trial_terms": "Cancel anytime. $19.99/month after trial.",
      "features": {
        "barcode_scanning": {
          "title": "Barcode Scanning",
          "description": "Quickly add foods by scanning product barcodes"
        },
        "coach_integration": {
          "title": "Coach Integration",
          "description": "Connect with your coach for personalized guidance"
        },
        "pro_recipes": {
          "title": "Pro Recipes",
          "description": "Access premium nutrition recipes and meal plans"
        },
        "training_peaks": {
          "title": "TrainingPeaks",
          "description": "Sync your training plans and workouts"
        },
        "final_surge": {
          "title": "Final Surge",
          "description": "Connect your training data seamlessly"
        },
        "canva": {
          "title": "Canva Export",
          "description": "Export beautiful nutrition plan graphics"
        },
        "strava": {
          "title": "Strava Integration",
          "description": "Sync activities and performance data"
        }
      },
      "restore": {
        "title": "Restore Purchases",
        "description": "If you previously purchased Premium, you can restore it here.",
        "button": "Restore Purchases",
        "success": "Purchases restored successfully!",
        "no_purchases": "No purchases found to restore.",
        "error": "Failed to restore purchases. Please try again."
      },
      "errors": {
        "purchase_cancelled": "Purchase was cancelled.",
        "purchase_not_allowed": "Purchases are not allowed on this device. Check parental controls.",
        "product_unavailable": "This subscription is currently unavailable. Please try again later.",
        "network_error": "Network error. Please check your connection and try again.",
        "store_error": "App Store error. Please try again in a few moments.",
        "unknown_error": "An unexpected error occurred. Please try again."
      }
    }
  }
}
```

**Estimated Time**: 15 minutes

**Output**:
- ✅ All paywall text in CMS
- ✅ Error messages configured
- ✅ Feature descriptions defined

---

### 3.2 Create Paywall Screen

**🤖 AI TASK** (I'll do this):

Create premium paywall following Andrea Bizzotto patterns:

**File**: `/lib/features/subscription/presentation/screens/paywall_screen.dart`

Features:
- Display all 7 premium features with icons
- Show pricing ($19.99/month)
- 7-day free trial messaging
- Subscribe button with loading states
- Restore purchases button
- Error handling with user-friendly messages
- Analytics tracking for paywall views
- Integration with ContentService for all text

**Controller**: `/lib/features/subscription/presentation/controllers/paywall_controller.dart`

Features:
- AsyncNotifier pattern
- Purchase flow orchestration
- Error handling
- Loading states
- Analytics events

**Estimated Time**: 90 minutes

**Output**:
- ✅ Paywall screen created
- ✅ Controller with business logic
- ✅ Error handling implemented
- ✅ Analytics tracking added

---

### 3.3 Create Subscription Management Screen

**🤖 AI TASK** (I'll do this):

Create screen for managing active subscription:

**File**: `/lib/features/subscription/presentation/screens/subscription_management_screen.dart`

Features:
- Show current subscription status
- Display renewal date
- Show premium features unlocked
- "Manage Subscription" button (deep link to App Store)
- Subscription health alerts (billing issues, cancellations)
- Restore purchases option

**Estimated Time**: 45 minutes

**Output**:
- ✅ Management screen created
- ✅ Subscription status display
- ✅ Deep links to App Store
- ✅ Health monitoring UI

---

### 3.4 Implement Feature Gating

**🤖 AI TASK** (I'll do this):

Create reusable widget for gating premium features:

**File**: `/lib/features/subscription/presentation/widgets/premium_feature_gate.dart`

Usage:
```dart
PremiumFeatureGate(
  feature: PremiumFeature.barcodeScanning,
  child: BarcodeScannerScreen(),
  fallback: PaywallScreen(),
)
```

Also create helper functions:
- `requiresPremium()` - Check if feature needs premium
- `showUpgradeDialog()` - Prompt user to upgrade
- `trackFeatureBlock()` - Analytics for blocked feature attempts

**Estimated Time**: 30 minutes

**Output**:
- ✅ PremiumFeatureGate widget
- ✅ Helper functions
- ✅ Analytics tracking

---

### 3.5 Add Paywall to Onboarding Flow

**🤖 AI TASK** (I'll do this):

Update onboarding flow to show paywall after completion:

**File**: `/lib/features/onboarding/presentation/screens/onboarding_completion_screen.dart`

Changes:
- After user completes profile setup
- Navigate to PaywallScreen
- Allow "Skip for now" option
- Track paywall presentation in analytics
- Don't block access to app if user skips

**Estimated Time**: 20 minutes

**Output**:
- ✅ Paywall shown after onboarding
- ✅ Skip option available
- ✅ Analytics tracking

---

### 3.6 Add Premium Indicators to UI

**🤖 AI TASK** (I'll do this):

Add visual indicators for premium features throughout app:

Locations:
- Navigation menu: "Premium" badge if not subscribed
- Settings screen: Premium status section
- Feature buttons: Lock icon + "Premium" badge for locked features
- Food preferences: Premium recipe categories

**Estimated Time**: 30 minutes

**Output**:
- ✅ Premium badges added
- ✅ Lock icons on gated features
- ✅ Clear premium status visibility

---

### 3.7 Update App Router

**🤖 AI TASK** (I'll do this):

Add subscription routes to app router:

**File**: `/lib/shared/core/app_router.dart`

New routes:
- `/paywall` - Premium paywall
- `/subscription-management` - Manage subscription
- `/restore-purchases` - Restore purchases screen

**Estimated Time**: 15 minutes

**Output**:
- ✅ Routes added
- ✅ Navigation configured
- ✅ Deep linking support

---

### 3.8 Test UI Flow

**🤝 COLLABORATIVE TASK**:

**👤 YOU**: Run app and test:
1. Complete onboarding → Should see paywall
2. Try "Start Free Trial" button → Should trigger purchase flow (will fail without sandbox account)
3. Click "Restore Purchases" → Should show message
4. Navigate to subscription management
5. Try accessing premium feature while not subscribed → Should see upgrade prompt
6. Check all UI text comes from CMS

```bash
flutter run
```

**Estimated Time**: 30 minutes

**Output**:
- ✅ Paywall displays correctly
- ✅ All buttons functional
- ✅ Feature gating works
- ✅ UI follows design system
- ✅ All text from CMS

**✅ PHASE 3 COMPLETE**: Complete UI implementation finished!

---

## Phase 4: Sandbox Testing (Week 2, Days 4-5)

**Goal**: Test complete purchase flow in App Store Sandbox
**Duration**: 2-3 hours
**Prerequisites**: Phase 3 complete, sandbox test accounts created

### 4.1 Create Sandbox Test Accounts

**👤 YOUR TASK**:

1. App Store Connect → **Users and Access** → **Sandbox Testers**
2. Click **"+"** to add tester
3. Fill in details:
   - **First Name**: Test
   - **Last Name**: User
   - **Email**: test.user.mealvana@icloud.com (doesn't need to be real)
   - **Password**: Create strong password and save it
   - **Country/Region**: United States
   - **App Store Territory**: United States
4. Click **Create**
5. **SAVE** email and password to: `/Users/leemartin/development/mealvana_endurance/secrets/sandbox_test_account.txt`
6. Create 2-3 test accounts (for testing restoration across devices)

**Estimated Time**: 10 minutes

**Output Needed**:
- ✅ At least 2 sandbox test accounts created
- ✅ Credentials saved securely

---

### 4.2 Prepare Device for Testing

**👤 YOUR TASK**:

#### On iOS Device:
1. Settings → App Store
2. Tap your name at top
3. **Sign Out** of App Store (not iCloud!)
4. Verify signed out: Should say "Sign In to App Store"

**⚠️ IMPORTANT**: Do NOT sign in with sandbox account yet. Wait until app prompts during purchase.

**Estimated Time**: 2 minutes

**Output**:
- ✅ Signed out of App Store
- ✅ Device ready for sandbox testing

---

### 4.3 Enable Debug Logging

**🤖 AI TASK** (I'll do this):

Temporarily enable verbose RevenueCat logging:

```dart
// In RevenueCatService.initialize()
await Purchases.setLogLevel(LogLevel.verbose);
```

This helps debug any issues during testing.

**Estimated Time**: 2 minutes

---

### 4.4 Build and Deploy to Device

**👤 YOUR TASK**:

```bash
flutter run --release
```

Or build via Xcode:
1. Open `ios/Runner.xcworkspace` in Xcode
2. Select your device
3. Click Run (▶️)

**⚠️ IMPORTANT**: Must test in Release mode or on actual device, NOT simulator.

**Estimated Time**: 10 minutes (build time)

**Output**:
- ✅ App running on physical device
- ✅ Release mode or Xcode build

---

### 4.5 Test Initial Purchase Flow

**🤝 COLLABORATIVE TASK**:

**👤 YOU** (Following these steps exactly):

1. **Launch app** on device
2. **Complete onboarding** → Paywall should appear
3. **Tap "Start Free Trial"**
4. **Sign in prompt appears** → Use sandbox account credentials
5. **Confirm purchase** → Review subscription details
6. **Tap "Subscribe"**
7. **Wait 10-30 seconds** (sandbox is slower than production)
8. **Verify success** → Should see "Welcome to Premium!" message
9. **Check RevenueCat dashboard** → Should see new subscriber

**Expected Flow**:
```
Tap "Start Free Trial"
  ↓
Sign in with Apple ID (sandbox account)
  ↓
App Store sheet appears
  ↓
Review: $19.99/month, 7-day free trial
  ↓
Tap "Subscribe"
  ↓
Touch ID/Face ID confirmation
  ↓
Purchase processes (10-30 seconds)
  ↓
Success! Premium unlocked
```

**Debug Checklist**:
- [ ] App Store purchase sheet appears
- [ ] Subscription shows $19.99/month
- [ ] Free trial shows 7 days
- [ ] Purchase completes without errors
- [ ] App shows premium unlocked
- [ ] RevenueCat dashboard shows subscriber

**Estimated Time**: 15 minutes

**Output**:
- ✅ Purchase completed successfully
- ✅ Premium status active in app
- ✅ Subscriber visible in RevenueCat dashboard

---

### 4.6 Test Feature Access

**👤 YOUR TASK**:

After successful purchase, verify premium features unlocked:

1. **Navigation menu** → Premium badge should disappear
2. **Try accessing barcode scanner** → Should work (or show "Coming soon" if not built yet)
3. **Check subscription management** → Should show "Active" status
4. **Verify renewal date** → Should show 7 days from now (trial end)

**Estimated Time**: 5 minutes

**Output**:
- ✅ Premium features accessible
- ✅ Status shows "Active"
- ✅ Trial end date correct

---

### 4.7 Test Restore Purchases

**👤 YOUR TASK**:

Test restoration on same device:

1. **Delete app** from device
2. **Reinstall** via Xcode or `flutter run`
3. **Complete onboarding** → Paywall appears
4. **Tap "Restore Purchases"**
5. **Verify restoration** → Should show "Purchases restored!" and unlock premium

**Test cross-device restoration** (if multiple devices available):
1. Install app on second device
2. Complete onboarding
3. Tap "Restore Purchases"
4. **Sign in** with same sandbox account
5. Verify restoration works

**Estimated Time**: 15 minutes

**Output**:
- ✅ Same-device restoration works
- ✅ Cross-device restoration works (if tested)
- ✅ Premium unlocked after restore

---

### 4.8 Test Purchase Cancellation

**👤 YOUR TASK**:

Test user cancelling purchase:

1. **Delete app** and reinstall
2. **Tap "Start Free Trial"**
3. **Tap "Subscribe"** in App Store sheet
4. **Immediately tap "Cancel"** before Touch ID
5. **Verify graceful handling** → Should return to paywall, no error shown

**Estimated Time**: 5 minutes

**Output**:
- ✅ Cancellation handled gracefully
- ✅ No error message shown
- ✅ User can try again

---

### 4.9 Test Offline Scenario

**👤 YOUR TASK**:

Test premium access while offline:

1. **With active subscription**, enable Airplane Mode
2. **Force quit** app
3. **Relaunch** app
4. **Verify premium status** → Should still show "Premium" (cached from database)
5. **Try accessing premium feature** → Should work

**Estimated Time**: 5 minutes

**Output**:
- ✅ Premium status persists offline
- ✅ Features accessible offline
- ✅ No errors when offline

---

### 4.10 Test Error Scenarios

**👤 YOUR TASK**:

#### Test 1: Network Error During Purchase
1. Start purchase flow
2. Enable Airplane Mode before confirming
3. Try to complete purchase
4. Verify error message: "Network error. Please check your connection..."

#### Test 2: Restore with No Purchases
1. Sign out of App Store
2. Sign in with NEW sandbox account (no purchases)
3. Tap "Restore Purchases"
4. Verify message: "No purchases found to restore."

**Estimated Time**: 10 minutes

**Output**:
- ✅ Network errors handled gracefully
- ✅ Appropriate error messages shown
- ✅ App doesn't crash

---

### 4.11 Monitor RevenueCat Dashboard

**👤 YOUR TASK**:

Check RevenueCat dashboard after testing:

1. Navigate to https://app.revenuecat.com
2. Select "Mealvana Endurance" project
3. Check **Overview** tab:
   - Should show 1+ active subscriber
   - Should show $0 revenue (sandbox)
   - Should show purchase events
4. Check **Customers** tab:
   - Should see sandbox test user
   - Click to view customer details
   - Verify entitlement "premium" is active
   - Check subscription expiration date (7 days from purchase)

**Estimated Time**: 10 minutes

**Output**:
- ✅ Dashboard shows active subscribers
- ✅ Customer details correct
- ✅ Entitlement active
- ✅ Events logged

---

### 4.12 Test Subscription Renewal (Accelerated)

**👤 YOUR TASK** (Optional, if time allows):

In sandbox, subscriptions renew at accelerated rate:
- 1 month subscription → Renews every 5 minutes
- Maximum 12 renewals per day

Wait 5-10 minutes and check:
1. RevenueCat dashboard → Should show renewal event
2. App → Should still show premium active
3. Subscription management screen → Expiration date should update

**Estimated Time**: 10 minutes (mostly waiting)

**Output**:
- ✅ Renewal events appear in dashboard
- ✅ Premium status maintained
- ✅ Expiration date updates

---

### 4.13 Document Test Results

**🤝 COLLABORATIVE TASK**:

**🤖 AI**: Create test results template

**👤 YOU**: Fill in results:

```markdown
# Sandbox Test Results

**Date**: [Date]
**Tester**: [Your name]
**Device**: [iPhone model, iOS version]
**Build**: [Version number]

## Test Results

- [ ] Initial purchase: ✅ Pass / ❌ Fail
- [ ] Feature access: ✅ Pass / ❌ Fail
- [ ] Restore purchases: ✅ Pass / ❌ Fail
- [ ] Purchase cancellation: ✅ Pass / ❌ Fail
- [ ] Offline access: ✅ Pass / ❌ Fail
- [ ] Error handling: ✅ Pass / ❌ Fail
- [ ] Dashboard tracking: ✅ Pass / ❌ Fail

## Issues Found

[List any issues or bugs]

## Notes

[Additional observations]
```

**Estimated Time**: 10 minutes

**Output**:
- ✅ Test results documented
- ✅ Issues logged (if any)
- ✅ Ready for production preparation

**✅ PHASE 4 COMPLETE**: Sandbox testing successful!

---

## Phase 5: Webhook & Analytics Integration (Week 3, Days 1-2)

**Goal**: Connect RevenueCat events to backend and analytics
**Duration**: 2-3 hours
**Prerequisites**: Supabase edge functions available

### 5.1 Create Webhook Handler Edge Function

**🤖 AI TASK** (I'll do this):

Create Supabase edge function:

**File**: `/supabase/functions/handle-subscription-webhook/index.ts`

Features:
- Validate RevenueCat webhook authorization
- Parse webhook payload
- Handle event types:
  - `INITIAL_PURCHASE` - Log new subscriber
  - `RENEWAL` - Update subscription status
  - `CANCELLATION` - Mark subscription cancelled
  - `EXPIRATION` - Remove premium access
  - `BILLING_ISSUE` - Alert user
- Sync subscription status to Supabase `users` table
- Log events for analytics
- Return 200 OK within 60 seconds

**Estimated Time**: 45 minutes

**Output**:
- ✅ Edge function created
- ✅ All event types handled
- ✅ Database sync logic

---

### 5.2 Generate Webhook Authorization Secret

**👤 YOUR TASK**:

1. Generate random secret:
```bash
openssl rand -base64 32
```
2. **COPY** output
3. **SAVE** to: `/Users/leemartin/development/mealvana_endurance/secrets/revenuecat_webhook_secret.txt`

**Estimated Time**: 2 minutes

**Output**:
- ✅ Webhook secret generated and saved

---

### 5.3 Deploy Webhook Edge Function

**🤖 AI TASK** (I'll do this):

Deploy to Supabase:

```bash
# Set secret
supabase secrets set REVENUECAT_WEBHOOK_SECRET="[your-secret]"

# Deploy function
supabase functions deploy handle-subscription-webhook
```

Get webhook URL:
```
https://[your-project].supabase.co/functions/v1/handle-subscription-webhook
```

**Estimated Time**: 5 minutes

**Output**:
- ✅ Edge function deployed
- ✅ Webhook URL available
- ✅ Secret configured

---

### 5.4 Configure RevenueCat Webhook

**👤 YOUR TASK**:

1. RevenueCat Dashboard → **Integrations** → **Webhooks**
2. Click **Add Webhook**
3. **Webhook URL**: `https://[your-project].supabase.co/functions/v1/handle-subscription-webhook`
4. **Authorization Header**:
   - Key: `Authorization`
   - Value: `Bearer [your-webhook-secret]`
5. **Select Events**:
   - ✅ Initial Purchase
   - ✅ Renewal
   - ✅ Cancellation
   - ✅ Expiration
   - ✅ Billing Issue
6. Click **Add Webhook**
7. Click **Send Test Event** to verify

**Estimated Time**: 10 minutes

**Output**:
- ✅ Webhook configured
- ✅ Authorization header set
- ✅ Test event successful

---

### 5.5 Add Mixpanel Subscription Events

**🤖 AI TASK** (I'll do this):

Add analytics tracking for subscription events:

Events to track:
- `paywall_viewed` - User sees paywall
- `subscription_purchase_started` - User taps subscribe
- `subscription_purchase_completed` - Purchase successful
- `subscription_purchase_failed` - Purchase failed
- `subscription_restored` - Restore successful
- `premium_feature_accessed` - User uses premium feature
- `premium_feature_blocked` - User tried premium while free

Properties to include:
- `offering_id`
- `package_id`
- `price`
- `trial_eligible`
- `feature_name` (for feature events)

**Estimated Time**: 30 minutes

**Output**:
- ✅ Analytics events added
- ✅ Event properties configured
- ✅ Integration with RudderStack

---

### 5.6 Test Webhook Delivery

**👤 YOUR TASK**:

1. Make test purchase in sandbox
2. Wait 30-60 seconds
3. Check RevenueCat Dashboard → **Integrations** → **Webhooks**
   - Should show successful delivery
   - Status should be "200 OK"
4. Check Supabase logs:
```bash
supabase functions logs handle-subscription-webhook
```
5. Verify database updated:
   - Check `users` table
   - `is_premium` should be `true`
   - `subscription_status` should be `active`

**Estimated Time**: 15 minutes

**Output**:
- ✅ Webhook delivered successfully
- ✅ Database updated
- ✅ No errors in logs

---

### 5.7 Test Analytics Events

**👤 YOUR TASK**:

1. Complete purchase flow while monitoring:
   - RudderStack debugger
   - Mixpanel live view
2. Verify events appear:
   - `paywall_viewed`
   - `subscription_purchase_started`
   - `subscription_purchase_completed`
3. Check event properties are correct

**Estimated Time**: 15 minutes

**Output**:
- ✅ All events tracked
- ✅ Properties correct
- ✅ Events appear in Mixpanel

**✅ PHASE 5 COMPLETE**: Backend integration finished!

---

## Phase 6: Production Preparation (Week 3, Days 3-4)

**Goal**: Prepare for production launch
**Duration**: 2-3 hours
**Prerequisites**: All previous phases complete

### 6.1 Switch to Production API Key

**👤 YOUR TASK**:

1. RevenueCat Dashboard → **Project Settings** → **API Keys**
2. Find **Production** section
3. **COPY** production iOS API key (starts with `appl_`)
4. **UPDATE** `/Users/leemartin/development/mealvana_endurance/secrets/revenuecat_ios_api_key.txt`
5. Replace sandbox key with production key

**⚠️ CRITICAL**: From this point forward, real money will be charged!

**Estimated Time**: 5 minutes

**Output**:
- ✅ Production API key in use
- ✅ File updated and saved

---

### 6.2 Disable Debug Logging

**🤖 AI TASK** (I'll do this):

Change log level for production:

```dart
// In RevenueCatService.initialize()
await Purchases.setLogLevel(LogLevel.warn); // Only warnings and errors
```

**Estimated Time**: 2 minutes

---

### 6.3 Test Production Purchase

**👤 YOUR TASK** (IMPORTANT):

Before submitting to App Store, test with real Apple ID:

1. Build app in Release mode
2. Deploy to device
3. **Sign in to App Store** with your personal Apple ID (NOT sandbox)
4. Complete purchase flow with **real payment method**
5. **Verify**:
   - Subscription appears in App Store subscriptions
   - Premium unlocked in app
   - RevenueCat dashboard shows production purchase
6. **Request refund**:
   - https://reportaproblem.apple.com
   - Find subscription
   - Request refund (test purchase)

**⚠️ WARNING**: This will charge your real payment method! Request refund immediately after testing.

**Estimated Time**: 20 minutes

**Output**:
- ✅ Production purchase successful
- ✅ Everything works with real App Store
- ✅ Refund requested

---

### 6.4 Update Legal Documents

**👤 YOUR TASK**:

#### Update Privacy Policy

Add section about payments:
```
## Subscription Payments

Mealvana Endurance offers premium features via auto-renewing subscription.
Payment will be charged to your Apple ID account at the confirmation of
purchase. Subscription automatically renews unless cancelled at least 24
hours before the end of the current period. Your account will be charged
for renewal within 24 hours prior to the end of the current period.

Subscriptions may be managed and auto-renewal may be turned off by going
to Account Settings in the App Store after purchase.

For more information, see our Terms of Service.
```

#### Create Subscription Terms

Create document or page covering:
- Subscription price and billing frequency
- Free trial terms (if applicable)
- Cancellation policy
- Refund policy (link to Apple's policy)
- What happens when subscription expires
- How to manage subscription

**Estimated Time**: 30 minutes

**Output**:
- ✅ Privacy policy updated
- ✅ Subscription terms created
- ✅ Documents accessible in app

---

### 6.5 Add Subscription Terms to App

**🤖 AI TASK** (I'll do this):

Add links to legal docs in paywall:

1. Privacy Policy link
2. Terms of Service link
3. Subscription Terms link
4. "Restore Purchases" option

Footer text:
```
By subscribing, you agree to our Terms of Service and Privacy Policy.
Subscription automatically renews unless cancelled at least 24 hours
before the end of the current period. Manage subscription in App Store
Account Settings.
```

**Estimated Time**: 15 minutes

---

### 6.6 Prepare App Store Metadata

**👤 YOUR TASK**:

Prepare for app submission:

#### In-App Purchases Section

1. App Store Connect → **My Apps** → **[Mealvana Endurance]**
2. **Features** → **In-App Purchases**
3. Select `premium_monthly`
4. **Review Information**:
   - Upload screenshot showing premium features
   - Add reviewer notes explaining subscription benefits
5. Mark as **Ready to Submit**

#### App Review Notes

Prepare notes for reviewer:
```
This app uses in-app subscriptions for premium features. To test:

1. Complete onboarding
2. You will see the premium paywall
3. Tap "Start Free Trial" to test subscription flow
4. Test account: [provide sandbox account]
5. Password: [provide password]

Premium features include: barcode scanning, coach integration, pro recipes,
and integrations with TrainingPeaks, Final Surge, Canva, and Strava.

The 7-day free trial is configured in App Store Connect. The subscription
is $19.99/month after the trial period.
```

**Estimated Time**: 20 minutes

**Output**:
- ✅ Screenshots uploaded
- ✅ Review notes prepared
- ✅ Test account ready

---

### 6.7 Final Testing Checklist

**🤝 COLLABORATIVE TASK**:

**👤 YOU**: Complete this checklist:

#### Functionality
- [ ] Paywall appears at correct time (after onboarding)
- [ ] Paywall shows correct price ($19.99/month)
- [ ] 7-day free trial messaging is clear
- [ ] Subscribe button works
- [ ] Restore purchases works
- [ ] Premium features unlock after purchase
- [ ] Premium features locked for free users
- [ ] Subscription management screen shows correct info
- [ ] Deep link to App Store works

#### Content
- [ ] All text comes from ContentService
- [ ] No hardcoded strings on paywall
- [ ] Error messages are user-friendly
- [ ] Legal links work (Privacy, Terms)
- [ ] All 7 premium features listed

#### Analytics
- [ ] Paywall view tracked
- [ ] Purchase events tracked
- [ ] Feature access tracked
- [ ] Events appear in Mixpanel

#### Technical
- [ ] No crashes or exceptions
- [ ] Works offline (cached status)
- [ ] Webhooks delivering successfully
- [ ] Database syncing correctly
- [ ] Production API key in use
- [ ] Debug logging disabled

**Estimated Time**: 30 minutes

**Output**:
- ✅ All items checked
- ✅ Ready for submission

**✅ PHASE 6 COMPLETE**: Production ready!

---

## Phase 7: App Store Submission & Launch (Week 3, Day 5+)

**Goal**: Submit app and monitor launch
**Duration**: 1-2 days (mostly waiting for review)
**Prerequisites**: All testing complete, production ready

### 7.1 Submit App for Review

**👤 YOUR TASK**:

1. **Final build**:
```bash
flutter build ios --release
# OR use Xcode Archive
```

2. **Upload to App Store Connect** via Xcode:
   - Product → Archive
   - Validate
   - Distribute App
   - Upload

3. **Configure App Store Connect**:
   - Select uploaded build
   - Add What's New text
   - Include subscription information in description
   - Upload screenshots (including paywall)

4. **Submit for Review**:
   - Include review notes with test account
   - Explain in-app purchase testing process
   - Submit

**Estimated Time**: 45 minutes + wait time

**Output**:
- ✅ Build uploaded
- ✅ Metadata complete
- ✅ Submitted for review

---

### 7.2 Monitor Review Status

**👤 YOUR TASK**:

Check App Store Connect daily for review status:
- **Waiting for Review**: Usually 24-48 hours
- **In Review**: Usually 24 hours
- **Ready for Sale**: Approved! 🎉

Common rejection reasons (and how to fix):
- Missing test account: Provide in review notes
- Subscription not clear: Add to description
- Price not shown: Ensure paywall shows "$19.99/month"
- Can't test features: Provide better instructions

**Estimated Time**: 1-3 days waiting

**Output**:
- ✅ App approved
- ✅ Live on App Store

---

### 7.3 Launch Day Monitoring

**👤 YOUR TASK**:

On launch day, monitor closely:

#### RevenueCat Dashboard
- Check every few hours
- Watch for new subscribers
- Monitor conversion rate
- Check for errors or issues

#### Sentry
- Monitor for crashes
- Check error rates
- Look for subscription-related exceptions

#### Mixpanel
- Track paywall views
- Monitor conversion funnel
- Analyze feature usage

#### App Store Connect
- Read user reviews
- Respond to questions
- Track downloads

**Estimated Time**: 2-3 hours throughout day

**Output**:
- ✅ No critical issues
- ✅ Users subscribing successfully
- ✅ Metrics being tracked

---

### 7.4 Week 1 Review

**🤝 COLLABORATIVE TASK**:

**👤 YOU** + **🤖 AI**: After first week, analyze:

#### Metrics to Review
1. **Conversion Rate**:
   - Paywall views
   - Trial starts
   - Trial-to-paid conversions
   - Target: 5-10% paywall conversion, 20-30% trial conversion

2. **Revenue**:
   - Number of subscribers
   - MRR (Monthly Recurring Revenue)
   - When will hit $2,500/month (RevenueCat free tier limit)

3. **User Experience**:
   - Support tickets about subscriptions
   - App Store reviews mentioning pricing
   - Completion rate of purchase flow

4. **Technical Health**:
   - Error rate on purchases
   - Webhook delivery success rate
   - Database sync issues

#### Action Items
- [ ] A/B test paywall copy if conversion low
- [ ] Adjust trial length if needed
- [ ] Fix any technical issues
- [ ] Respond to user feedback

**Estimated Time**: 2 hours

**Output**:
- ✅ Metrics analyzed
- ✅ Issues identified
- ✅ Optimization plan created

**✅ PHASE 7 COMPLETE**: Successfully launched! 🎉

---

## Ongoing Optimization (Post-Launch)

### Monthly Tasks

**👤 YOUR TASKS**:

1. **Monitor Dashboard** (Weekly):
   - Check MRR growth
   - Review churn rate
   - Analyze cohort retention

2. **Review Analytics** (Bi-weekly):
   - Paywall conversion trends
   - Feature usage by tier
   - Cancellation reasons (if collected)

3. **A/B Testing** (Monthly):
   - Test different trial lengths
   - Experiment with pricing
   - Try different paywall copy
   - Test offering annual plans

4. **User Feedback** (Ongoing):
   - Read App Store reviews
   - Analyze support tickets
   - Survey premium users
   - Identify pain points

### Quarterly Goals

1. **Q1**: Achieve product-market fit
   - Target: 50-100 subscribers
   - Focus: Retention and value delivery
   - Goal: < 5% monthly churn

2. **Q2**: Scale acquisition
   - Target: 200-500 subscribers
   - Focus: Conversion optimization
   - Goal: 10%+ paywall conversion

3. **Q3**: Maximize LTV
   - Target: 500-1000 subscribers
   - Focus: Annual plans, upsells
   - Goal: $150+ LTV per subscriber

4. **Q4**: Profitability
   - Target: 1000+ subscribers ($20K MRR)
   - Focus: Operational efficiency
   - Goal: Positive unit economics

---

## Risk Management & Contingency Plans

### If Conversion Rate is Low (< 5%)

**Actions**:
1. A/B test paywall variations
2. Extend trial to 14 days
3. Add more premium features
4. Improve paywall copy and design
5. Show value earlier in onboarding

### If Churn Rate is High (> 10%)

**Actions**:
1. Survey cancelling users
2. Improve premium feature value
3. Send re-engagement emails
4. Offer pause subscription option
5. Add more exclusive content

### If Technical Issues Arise

**Actions**:
1. Check Sentry for exceptions
2. Review RevenueCat error logs
3. Monitor webhook delivery rates
4. Test purchase flow on multiple devices
5. Contact RevenueCat support if needed

### If App Store Rejects Subscription

**Actions**:
1. Review rejection reason carefully
2. Address specific issues mentioned
3. Update screenshots/description as needed
4. Provide more detailed test instructions
5. Resubmit with explanation

---

## Success Criteria

### Technical Success
- ✅ Zero subscription-related crashes
- ✅ 99%+ purchase success rate
- ✅ < 2% support tickets about payments
- ✅ Webhook delivery > 95% within 60s
- ✅ Database sync accuracy 100%

### Business Success
- ✅ 100+ subscribers within 3 months
- ✅ 5-10% paywall conversion rate
- ✅ 20-30% trial-to-paid conversion
- ✅ < 5% monthly churn rate
- ✅ $120+ lifetime value

### User Success
- ✅ 4.5+ star average rating maintained
- ✅ Positive reviews about premium features
- ✅ High premium feature engagement
- ✅ Low cancellation requests
- ✅ Active premium user community

---

## Resources & Support

### RevenueCat Resources
- **Dashboard**: https://app.revenuecat.com
- **Docs**: https://www.revenuecat.com/docs
- **Community**: https://community.revenuecat.com
- **Support**: support@revenuecat.com

### App Store Resources
- **App Store Connect**: https://appstoreconnect.apple.com
- **Developer Support**: https://developer.apple.com/contact/
- **Guidelines**: https://developer.apple.com/app-store/review/guidelines/

### Internal Resources
- **Research Doc**: `/docs/revenue_cat/revenuecat_research.md`
- **Overview**: `/docs/revenue_cat/README.md`
- **Architecture**: `/docs/technical/foa-architecture.md`
- **Content Management**: `/docs/technical/content-management.md`

---

## Summary

This roadmap provides a complete, step-by-step guide to implementing RevenueCat subscriptions in Mealvana Endurance. The implementation is divided into 7 phases:

1. **Account Setup** (2-3 hours) - YOU: Create accounts, configure App Store
2. **SDK Integration** (3-4 hours) - AI: Install SDK, create services
3. **UI Implementation** (4-5 hours) - AI: Build paywall and feature gating
4. **Sandbox Testing** (2-3 hours) - YOU: Test complete flow
5. **Backend Integration** (2-3 hours) - AI: Webhooks and analytics
6. **Production Prep** (2-3 hours) - BOTH: Final testing and legal
7. **Launch** (1-2 days) - YOU: Submit and monitor

**Total time investment**: 12-18 hours of development + 1-2 days review time

Following this roadmap will result in a production-ready subscription system that:
- Follows Andrea Bizzotto's FOA architecture
- Integrates with existing Drift database
- Uses content management for all text
- Tracks analytics in Mixpanel
- Handles errors gracefully
- Provides excellent user experience

**Next step**: Complete Phase 2 (Email/OAuth authentication) before beginning RevenueCat integration.

---

**Document Version**: 1.0
**Created**: January 18, 2025
**Last Updated**: January 18, 2025
**Status**: Ready for Phase 4 implementation
