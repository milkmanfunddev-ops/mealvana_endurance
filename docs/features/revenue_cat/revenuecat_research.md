# RevenueCat Research for Flutter Subscription Implementation

**Research Date**: January 2025
**Target Implementation**: $19.99/month subscription for Mealvana Endurance
**Platform**: Flutter (iOS 12.0+, Android API 21+)

---

## Executive Summary

RevenueCat is a robust subscription infrastructure platform that simplifies in-app purchase implementation across iOS, Android, and web. For a $19.99/month subscription in Flutter, RevenueCat offers:

- **Free tier** for apps earning less than $2,500/month MTR (Monthly Tracked Revenue)
- **Zero code changes** for paywall configuration and A/B testing
- **5-60 second** webhook delivery for real-time subscription status
- **Cross-platform restoration** with automatic receipt validation
- **Complete Flutter SDK** with 48+ code examples and high reputation (79.4 benchmark score)

**Key Value**: RevenueCat can save weeks of development time by handling receipt validation, server-to-server notifications, cross-platform restoration, and subscription lifecycle management automatically.

---

## 1. What is RevenueCat?

### Core Platform Features

RevenueCat is a unified API for in-app subscriptions that abstracts away the complexity of managing subscriptions across multiple platforms.

**Primary Benefits**:
- **Unified API**: Single integration works across iOS App Store, Google Play, Amazon Appstore, and web
- **Receipt Validation**: Server-side validation prevents fraud and ensures transaction integrity
- **Cross-Platform Support**: Users can restore purchases across devices automatically
- **Backend Infrastructure**: No need to build and maintain your own subscription backend
- **Real-Time Updates**: Webhook notifications for subscription events (renewals, cancellations, billing issues)
- **Analytics & Insights**: Built-in dashboards for revenue tracking, churn analysis, and subscription metrics

**How It Works**:
1. Configure products in App Store Connect / Google Play Console
2. Link products to RevenueCat entitlements (e.g., "premium" entitlement)
3. Initialize RevenueCat SDK in your Flutter app with API key
4. Present offerings and handle purchases through SDK
5. Check entitlement status to unlock features
6. RevenueCat handles receipt validation, renewals, and status updates automatically

### Pricing Model (2025)

RevenueCat uses Monthly Tracked Revenue (MTR) pricing:

| Plan | MTR Threshold | Cost | Notes |
|------|---------------|------|-------|
| **Free** | < $2,500/month | $0 | All features included |
| **Starter** | $2,500 - $10,000/month | $8 per $1,000 MTR | ~$80/month at $10K MTR |
| **Pro** | > $10,000/month | $12 per $1,000 MTR | Priority support, advanced features |

**MTR Definition**: Total revenue tracked by RevenueCat in USD (before platform cut) during a billing period, including subscriptions, renewals, and one-time purchases.

**Cost Projection for Mealvana**:
- At 50 subscribers ($19.99/month): $999.50 MTR = **$0** (Free tier)
- At 150 subscribers: $2,998.50 MTR = **$23.99/month** ($8 per $1K)
- At 500 subscribers: $9,995 MTR = **$79.96/month** ($8 per $1K)
- At 1,000 subscribers: $19,990 MTR = **$239.88/month** ($12 per $1K)

---

## 2. Flutter Integration

### Installation & Setup

**Flutter SDK**: `purchases-flutter` (Version 9.12.0+)
- **Source Reputation**: High
- **Code Snippets Available**: 243
- **Benchmark Score**: 79.4/100
- **Context7 Library ID**: `/revenuecat/purchases-flutter`

#### Step 1: Add Dependencies

```yaml
# pubspec.yaml
dependencies:
  purchases_flutter: ^9.12.0
  purchases_ui_flutter: ^9.0.0  # Optional: For pre-built paywalls
```

**Requirements**:
- iOS: 13.0+ (Xcode 14.0+)
- Android: API 21+ (Android 5.0+)
- Flutter: 3.8.0+

#### Step 2: iOS Configuration

Edit `ios/Podfile`:

```ruby
platform :ios, '13.0'
```

Run pod install:

```bash
cd ios && pod install
```

#### Step 3: Initialize SDK

Create a RevenueCat service in your Flutter app:

```dart
import 'package:purchases_flutter/purchases_flutter.dart';

class RevenueCatService {
  static Future<void> initialize() async {
    // Enable debug logging in development
    await Purchases.setLogLevel(LogLevel.debug);

    // Configure SDK with API key
    final configuration = PurchasesConfiguration('appl_YOUR_IOS_API_KEY')
      ..appUserID = null  // Use anonymous IDs initially
      ..purchasesAreCompletedBy = const PurchasesAreCompletedByRevenueCat()
      ..shouldShowInAppMessagesAutomatically = true
      ..entitlementVerificationMode = EntitlementVerificationMode.disabled;

    await Purchases.configure(configuration);

    // Set up customer info listener for real-time updates
    Purchases.addCustomerInfoUpdateListener((customerInfo) {
      print('Customer info updated!');
      if (customerInfo.entitlements.active.containsKey('premium')) {
        print('User has premium access');
      }
    });
  }

  static Future<CustomerInfo> getCustomerInfo() async {
    return await Purchases.getCustomerInfo();
  }
}
```

#### Step 4: Initialize on App Startup

**IMPORTANT**: Follow Andrea Bizzotto's initialization pattern in `appStartupProvider`:

```dart
// lib/shared/services/app_startup_service.dart

class AppStartupService {
  Future<void> initialize() async {
    // Initialize RevenueCat after Drift database
    await RevenueCatService.initialize();

    // Check subscription status
    final customerInfo = await RevenueCatService.getCustomerInfo();
    final isPremium = customerInfo.entitlements.active.containsKey('premium');

    // Store premium status in local database
    await _syncPremiumStatus(isPremium);
  }
}
```

### Checking Subscription Status

```dart
// In any controller or service
Future<bool> checkPremiumAccess() async {
  try {
    final customerInfo = await Purchases.getCustomerInfo();

    // Check specific entitlement
    if (customerInfo.entitlements.all['premium']?.isActive == true) {
      print('User has premium access');
      return true;
    }

    // Check subscription details
    final subscription = customerInfo.subscriptions['premium_monthly'];
    if (subscription != null) {
      print('Expires: ${subscription.expiresDate}');
      print('Will renew: ${subscription.willRenew}');
      print('Billing issues: ${subscription.billingIssuesDetected}');
    }

    return false;
  } catch (e) {
    print('Error checking subscription: $e');
    return false;
  }
}
```

### Making a Purchase

```dart
Future<bool> purchasePremiumSubscription() async {
  try {
    // Get available offerings
    final offerings = await Purchases.getOfferings();
    final currentOffering = offerings.current;

    if (currentOffering == null) {
      print('No offerings available');
      return false;
    }

    // Get the monthly package
    final package = currentOffering.monthly;
    if (package == null) {
      print('Monthly package not found');
      return false;
    }

    // Purchase the package
    final params = PurchaseParams.package(package);
    final purchaseResult = await Purchases.purchase(params);

    // Check if purchase was successful
    final customerInfo = purchaseResult.customerInfo;
    if (customerInfo.entitlements.active.containsKey('premium')) {
      print('Purchase successful! Premium unlocked.');
      return true;
    }

    return false;
  } on PlatformException catch (e) {
    final errorCode = PurchasesErrorHelper.getErrorCode(e);
    if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
      print('User cancelled the purchase');
    } else {
      print('Purchase error: ${e.message}');
    }
    return false;
  }
}
```

### Restoring Purchases

```dart
Future<bool> restorePurchases() async {
  try {
    final customerInfo = await Purchases.restorePurchases();

    print('Purchases restored successfully');
    print('Active entitlements: ${customerInfo.entitlements.active.keys}');

    if (customerInfo.entitlements.active.isEmpty) {
      print('No active subscriptions found');
      return false;
    }

    return true;
  } catch (e) {
    print('Restore error: $e');
    return false;
  }
}
```

### Using Pre-Built Paywalls

RevenueCat offers pre-built paywall UI that you can configure remotely:

```dart
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

Future<void> showPaywall() async {
  try {
    final result = await RevenueCatUI.presentPaywall(
      displayCloseButton: true,
    );

    switch (result) {
      case PaywallResult.purchased:
        print('User completed purchase from paywall');
        break;
      case PaywallResult.restored:
        print('User restored purchases from paywall');
        break;
      case PaywallResult.cancelled:
        print('User dismissed paywall');
        break;
      case PaywallResult.notPresented:
        print('Paywall could not be presented');
        break;
      case PaywallResult.error:
        print('Error presenting paywall');
        break;
    }
  } catch (e) {
    print('Paywall error: $e');
  }
}

// Only show paywall if user doesn't have entitlement
Future<void> showPaywallIfNeeded() async {
  final result = await RevenueCatUI.presentPaywallIfNeeded(
    'premium',
    displayCloseButton: true,
  );

  if (result == PaywallResult.purchased) {
    print('User now has premium access');
  }
}
```

---

## 3. App Store Setup

### Overview

RevenueCat connects to App Store Connect to validate receipts, track subscriptions, and handle renewals automatically. Here's the complete setup process:

### Prerequisites

Before creating products:

1. **Signed Agreements**: Latest Paid Applications Agreement signed in App Store Connect "Business" module
2. **Tax Forms**: Complete all forms in the "Tax" tab
3. **Banking Information**: Link bank account with "Clear" status
4. **Bundle ID**: App must be created in App Store Connect with correct Bundle ID

### Step 1: Create Subscription Products in App Store Connect

**Navigation**: App Store Connect → My Apps → [Your App] → Features → Subscriptions

1. **Create Subscription Group**:
   - Click "+" to create a new Subscription Group
   - Name: "Premium Subscriptions" (or your preference)
   - Reference Name: Internal identifier

2. **Create Monthly Subscription**:
   - Click "+" within the subscription group
   - Product ID: `premium_monthly` (or your choice - must match RevenueCat)
   - Reference Name: "Premium Monthly"
   - Subscription Duration: 1 month
   - Price: $19.99 USD
   - Availability: Select countries

3. **Configure Subscription Details**:
   - Display Name: "Premium Access"
   - Description: Benefits of premium subscription
   - Review Information: Screenshot and notes for App Review

4. **Free Trial Setup** (Optional):
   - Add Introductory Offer
   - Type: Free Trial
   - Duration: 7 days (or your preference)
   - Eligibility: Automatically determined by App Store

### Step 2: Generate App Store Connect Credentials

RevenueCat needs three credentials to communicate with App Store Connect:

#### A. App-Specific Shared Secret

**Purpose**: Validates receipts from your app

**Steps**:
1. App Store Connect → [Your App] → App Information (General section)
2. Scroll to "App-Specific Shared Secret"
3. Click "Manage"
4. Click "Generate"
5. **Copy and save** the secret (you can't view it again)

#### B. In-App Purchase Key (Required)

**Purpose**: Server-to-server notifications and advanced API access

**Steps**:
1. App Store Connect → Users and Access → Integrations
2. Select "In-App Purchase" tab
3. Click "Generate In-App Purchase Key"
4. Name: "RevenueCat Integration"
5. **Download the .p8 key file immediately** (only one chance!)
6. Save the Key ID (e.g., `AB12CD34EF`)

**IMPORTANT**: Store the .p8 file securely - you cannot download it again.

#### C. App Store Connect API Key (Optional, Recommended)

**Purpose**: Enhanced analytics and subscription management

**Steps**:
1. App Store Connect → Users and Access → Integrations → App Store Connect API
2. Click "+" to generate new key
3. Name: "RevenueCat API"
4. Access Level: **App Manager** (minimum required)
5. **Download the .p8 key file**
6. Save Issuer ID and Key ID

### Step 3: Configure RevenueCat Dashboard

**Navigation**: RevenueCat Dashboard → Project Settings → Apps & Providers

1. **Select iOS Platform**:
   - Click "Add App" or select existing iOS app

2. **Enter App Information**:
   - App Name: "Mealvana Endurance"
   - Bundle ID: Your iOS app bundle ID (e.g., `com.mealvana.endurance`)
   - Shared Secret: Paste App-Specific Shared Secret from Step 2A

3. **Upload In-App Purchase Key**:
   - Click "Upload In-App Purchase Key"
   - Select the .p8 file downloaded in Step 2B
   - Enter Key ID (e.g., `AB12CD34EF`)
   - Click "Save"

4. **Upload App Store Connect API Key** (Optional):
   - Click "Upload App Store Connect API Key"
   - Select the .p8 file from Step 2C
   - Enter Issuer ID and Key ID
   - Click "Save"

### Step 4: Configure Products in RevenueCat

RevenueCat uses a three-tier architecture:

1. **Products**: Individual SKUs from App Store Connect
2. **Entitlements**: Features users get access to (e.g., "premium")
3. **Offerings**: Collections of products shown to users (e.g., default offering)

**Setup Process**:

1. **Create Entitlement**:
   - RevenueCat Dashboard → Entitlements
   - Click "New Entitlement"
   - Identifier: `premium`
   - Display Name: "Premium Access"

2. **Add Product**:
   - RevenueCat Dashboard → Products
   - Click "New Product"
   - Product Identifier: `premium_monthly` (must match App Store Connect)
   - Store: iOS App Store
   - Click "Save"

3. **Attach Product to Entitlement**:
   - Go to Entitlements → `premium`
   - Click "Attach Products"
   - Select `premium_monthly`
   - Click "Save"

4. **Create Offering**:
   - RevenueCat Dashboard → Offerings
   - Default offering is created automatically
   - Click "Add Package" → Monthly
   - Select `premium_monthly` product
   - Click "Save"

### Step 5: Server-to-Server Notifications

RevenueCat automatically receives App Store Server notifications after you upload credentials.

**What Gets Synced Automatically**:
- Initial purchases
- Subscription renewals
- Cancellations
- Refunds
- Billing issues
- Grace periods
- Price changes
- Product changes (upgrades/downgrades)

**No Additional Configuration Required** - RevenueCat handles this once credentials are uploaded.

### Step 6: Test in Sandbox

**Create Sandbox Test User**:
1. App Store Connect → Users and Access → Sandbox Testers
2. Click "+" to add tester
3. Enter email (doesn't need to be real)
4. Set password and country

**Testing Flow**:
1. Sign out of App Store on test device (Settings → App Store)
2. Build and run app in debug mode (`flutter run`)
3. Trigger purchase flow in app
4. When prompted, sign in with sandbox test account
5. Complete purchase (no real charges)
6. Verify subscription appears in RevenueCat dashboard

**Sandbox Limitations**:
- Subscriptions renew at accelerated rate (max 12 renewals/day)
- Total purchase time may be 15+ seconds (production is faster)
- Prices/descriptions may not be accurate
- Don't test metadata, focus on purchase flow

---

## 4. Implementation Steps

### Complete Implementation Checklist

#### Phase 1: Account Setup (30 minutes)

- [ ] Create RevenueCat account at https://app.revenuecat.com
- [ ] Create new project in RevenueCat dashboard
- [ ] Name project "Mealvana Endurance"
- [ ] Copy iOS API key (starts with `appl_`)
- [ ] Store API key in `secrets/` directory (not in version control)

#### Phase 2: App Store Configuration (1-2 hours)

- [ ] Verify Paid Applications Agreement signed
- [ ] Complete tax and banking information
- [ ] Create subscription group in App Store Connect
- [ ] Create `premium_monthly` product ($19.99/month)
- [ ] Configure subscription details and descriptions
- [ ] Add free trial (optional): 7 days
- [ ] Generate App-Specific Shared Secret
- [ ] Generate In-App Purchase Key (.p8 file)
- [ ] Download and securely store .p8 file
- [ ] Generate App Store Connect API Key (optional)

#### Phase 3: RevenueCat Configuration (30 minutes)

- [ ] Add iOS app to RevenueCat project
- [ ] Enter bundle ID and Shared Secret
- [ ] Upload In-App Purchase Key (.p8)
- [ ] Create `premium` entitlement
- [ ] Add `premium_monthly` product
- [ ] Attach product to entitlement
- [ ] Configure default offering with monthly package
- [ ] Verify configuration in dashboard

#### Phase 4: Flutter Integration (2-3 hours)

- [ ] Add `purchases_flutter` to pubspec.yaml
- [ ] Add `purchases_ui_flutter` for paywalls (optional)
- [ ] Run `flutter pub get`
- [ ] Update iOS Podfile for iOS 13.0+ requirement
- [ ] Run `pod install` in ios/ directory
- [ ] Create `RevenueCatService` class
- [ ] Initialize SDK in `appStartupProvider`
- [ ] Load API key from secure storage
- [ ] Implement customer info listener
- [ ] Create subscription status provider
- [ ] Sync premium status to Drift database

#### Phase 5: Feature Implementation (3-4 hours)

- [ ] Create paywall screen with subscription details
- [ ] Implement purchase flow with error handling
- [ ] Add restore purchases button
- [ ] Implement entitlement checks before premium features
- [ ] Add loading states during purchase
- [ ] Handle user cancellation gracefully
- [ ] Add success/error messages
- [ ] Create subscription management screen
- [ ] Add "Manage Subscription" deep link to App Store

#### Phase 6: Testing (2-3 hours)

- [ ] Create sandbox test accounts
- [ ] Test initial purchase flow
- [ ] Test subscription restoration
- [ ] Test purchase cancellation
- [ ] Test with no internet connection
- [ ] Verify subscription status updates in real-time
- [ ] Test expired trial scenario
- [ ] Test billing issue scenarios
- [ ] Verify analytics events fire correctly
- [ ] Test on multiple iOS versions

#### Phase 7: Production Preparation (1-2 hours)

- [ ] Switch to production API key
- [ ] Test with production Apple ID (before app review)
- [ ] Set up webhooks for backend integration
- [ ] Configure webhook authorization
- [ ] Implement webhook handler endpoint
- [ ] Add subscription analytics to Mixpanel
- [ ] Update privacy policy with subscription terms
- [ ] Add subscription terms and conditions
- [ ] Test production purchase with real money
- [ ] Request refund for test purchase

#### Phase 8: App Review & Launch (1-2 days)

- [ ] Submit app for review with IAP capability
- [ ] Provide test account credentials to Apple
- [ ] Include subscription screenshots in review notes
- [ ] Wait for approval (typically 24-48 hours)
- [ ] Monitor RevenueCat dashboard after launch
- [ ] Check webhook delivery
- [ ] Monitor error logs in Sentry
- [ ] Track conversion metrics in Mixpanel

**Total Estimated Time**: 12-18 hours of development + app review time

### API Key Management

**Security Best Practices**:

1. **Never commit API keys to version control**:

```yaml
# .gitignore
secrets/
.env
lib/config/keys.dart  # If storing keys here
```

2. **Store keys in secure location**:

```
secrets/
  ├── revenuecat_ios_api_key.txt
  ├── revenuecat_android_api_key.txt
  └── README.md  # Instructions for team members
```

3. **Load keys at runtime**:

```dart
// lib/shared/services/secrets_service.dart
class SecretsService {
  static String? _revenueCatIosKey;

  static Future<void> initialize() async {
    // Option 1: From bundled asset (encrypted)
    _revenueCatIosKey = await rootBundle.loadString('secrets/revenuecat_ios_api_key.txt');

    // Option 2: From environment variable (CI/CD)
    _revenueCatIosKey = Platform.environment['REVENUECAT_IOS_API_KEY'];

    // Option 3: From secure storage (for sensitive production keys)
    final storage = FlutterSecureStorage();
    _revenueCatIosKey = await storage.read(key: 'revenuecat_ios_api_key');
  }

  static String getRevenueCatIosKey() {
    if (_revenueCatIosKey == null) {
      throw Exception('RevenueCat iOS key not initialized');
    }
    return _revenueCatIosKey!;
  }
}
```

4. **Use platform-specific keys**:

```dart
Future<void> initializeRevenueCat() async {
  await Purchases.setLogLevel(LogLevel.debug);

  final apiKey = Platform.isIOS
      ? SecretsService.getRevenueCatIosKey()
      : SecretsService.getRevenueCatAndroidKey();

  final configuration = PurchasesConfiguration(apiKey);
  await Purchases.configure(configuration);
}
```

**Key Types**:
- **Public API Key** (`appl_*`, `goog_*`): Safe to use in client apps, used for SDK initialization
- **Secret API Key**: Only for server-side REST API calls, NEVER include in client app
- **Webhook Authorization**: Custom header value for securing webhook endpoints

### Entitlement Configuration

**Architecture**:

```
Entitlements (Features)
  └── Products (SKUs)
      └── Offerings (Marketing)
          └── Packages (Display)
```

**Example Configuration**:

```
Entitlement: "premium"
  ├── Product: "premium_monthly" ($19.99/month)
  ├── Product: "premium_annual" ($199.99/year) - Optional

Offering: "default"
  ├── Package: "monthly"
  │   └── Product: "premium_monthly"
  └── Package: "annual"
      └── Product: "premium_annual"
```

**Why This Matters**:
- **Entitlements** represent features in your code: `if (hasEntitlement('premium'))`
- **Products** can change without code updates
- **Offerings** can be A/B tested remotely
- **Packages** define how products are displayed (monthly, annual, weekly)

### Product Identifier Setup

**Best Practices**:

1. **Use descriptive, consistent naming**:
   - ✅ `premium_monthly`, `premium_annual`
   - ❌ `sub1`, `prod_abc123`

2. **Match identifiers across platforms**:
   - App Store Connect: `premium_monthly`
   - RevenueCat: `premium_monthly`
   - Your code: `premium_monthly`

3. **Include duration in name**:
   - Makes debugging easier
   - Prevents confusion with other products

4. **Create products for Mealvana**:
   - `premium_monthly` - $19.99/month
   - `premium_annual` - $199.99/year (optional, $16.67/month effective)

### Testing Subscriptions

#### Sandbox vs Production

| Aspect | Sandbox | Production |
|--------|---------|------------|
| **Renewal Rate** | Accelerated (max 12/day) | Normal monthly |
| **Purchase Time** | 15+ seconds typical | 2-5 seconds typical |
| **Real Charges** | No | Yes |
| **Metadata Accuracy** | Often incorrect | Always correct |
| **Grace Periods** | Shortened duration | Full duration |
| **Test Accounts** | Sandbox users only | Real Apple IDs only |
| **Receipt Validation** | Works | Works |

#### Recommended Testing Strategy

**Development Phase** (Use Test Store):
- RevenueCat provides "Test Store" for rapid iteration
- No Apple approval needed
- Instant purchase testing
- Focus on: UI flow, entitlement checks, error handling

**Pre-Launch Phase** (Use Sandbox):
- Test complete purchase flow end-to-end
- Verify receipt validation
- Test restoration across devices
- Focus on: Integration, edge cases, error scenarios

**Production Phase** (Use Production):
- Test with real Apple ID before launch
- Make actual purchase with real payment
- Request refund after verification
- Focus on: Production environment validation

#### Testing Environments

1. **Single Project Approach** (Recommended for small teams):
   - Same RevenueCat API keys for all environments
   - RevenueCat automatically detects sandbox vs production
   - Simpler to manage
   - Less overhead

2. **Multiple Project Approach** (Recommended for larger teams):
   - Separate RevenueCat projects for dev/staging/production
   - Different API keys per environment
   - Clear separation of concerns
   - More complex setup

**For Mealvana**: Use single project approach to start, upgrade to multiple projects if needed later.

---

## 5. Features

### Paywall Management

RevenueCat offers powerful paywall features that can be configured without code changes:

#### Remote Configuration

**Benefits**:
- Update paywall content without app updates
- A/B test different pricing strategies
- Localize for different markets
- Respond quickly to conversion data

**What Can Be Configured Remotely**:
- Product pricing (via App Store Connect)
- Display order of packages
- Featured badge on specific plans
- Promotional copy and imagery
- Offering visibility by audience segment

#### Pre-Built Paywalls

**purchases_ui_flutter** provides native paywalls:

```dart
// Show paywall with default offering
await RevenueCatUI.presentPaywall();

// Show paywall only if user lacks entitlement
await RevenueCatUI.presentPaywallIfNeeded('premium');

// Embed paywall in your UI
PaywallView(
  offering: offering,
  onRestoreCompleted: (customerInfo) {
    // Handle restoration
  },
)
```

**Advantages**:
- Native platform UI (feels integrated)
- Handles all purchase states automatically
- Respects system accessibility settings
- Updates remotely via RevenueCat dashboard

#### Custom Paywalls

For full control, build custom UI:

```dart
class PremiumPaywallScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<Offerings>(
      future: Purchases.getOfferings(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();

        final offering = snapshot.data!.current;
        final package = offering?.monthly;

        return Column(
          children: [
            Text('Premium Access'),
            Text('$19.99 / month'),
            ElevatedButton(
              onPressed: () => _purchasePackage(package),
              child: Text('Subscribe Now'),
            ),
            TextButton(
              onPressed: _restorePurchases,
              child: Text('Restore Purchases'),
            ),
          ],
        );
      },
    );
  }
}
```

### Subscription Status Tracking

**Real-Time Updates**:

```dart
// Set up listener in app initialization
Purchases.addCustomerInfoUpdateListener((customerInfo) {
  final isPremium = customerInfo.entitlements.active.containsKey('premium');

  // Update local state
  ref.read(premiumStatusProvider.notifier).update(isPremium);

  // Sync to database
  _syncPremiumStatus(isPremium);

  // Log analytics event
  _trackSubscriptionChange(customerInfo);
});
```

**Available Subscription Details**:
- `isActive`: Current subscription status
- `expiresDate`: When subscription will expire
- `willRenew`: Whether auto-renewal is enabled
- `billingIssuesDetected`: Payment problems detected
- `unsubscribeDetectedAt`: When user cancelled
- `periodType`: Trial, intro offer, or normal
- `originalPurchaseDate`: First purchase date
- `latestPurchaseDate`: Most recent renewal

**Checking Status Anywhere**:

```dart
Future<bool> hasFeatureAccess(String feature) async {
  final customerInfo = await Purchases.getCustomerInfo();
  return customerInfo.entitlements.active.containsKey(feature);
}
```

### Cross-Platform Restoration

**Automatic Restoration**:
- RevenueCat links purchases to user accounts automatically
- Users can restore on new devices with single button
- No server-side code required

**Implementation**:

```dart
Future<void> restorePurchases() async {
  try {
    // Show loading indicator
    _setLoading(true);

    // Restore purchases
    final customerInfo = await Purchases.restorePurchases();

    // Check if any entitlements were restored
    if (customerInfo.entitlements.active.isNotEmpty) {
      _showSuccess('Purchases restored successfully!');

      // Sync to local database
      await _syncEntitlements(customerInfo);

      // Navigate to premium content
      _navigateToApp();
    } else {
      _showInfo('No purchases found to restore.');
    }
  } catch (e) {
    _showError('Failed to restore purchases: $e');
  } finally {
    _setLoading(false);
  }
}
```

**User Identification**:

```dart
// Link purchases to user account after authentication
Future<void> identifyUser(String userId) async {
  try {
    await Purchases.logIn(userId);
    print('User identified: $userId');
  } catch (e) {
    print('Failed to identify user: $e');
  }
}

// Anonymous checkout
Future<void> logoutUser() async {
  try {
    await Purchases.logOut();
    print('User logged out, switched to anonymous');
  } catch (e) {
    print('Failed to logout: $e');
  }
}
```

### Webhooks and Integrations

**Available Webhook Events**:
- `INITIAL_PURCHASE`: New subscription started
- `RENEWAL`: Subscription renewed
- `CANCELLATION`: User cancelled (still active until expiration)
- `EXPIRATION`: Subscription expired and not renewed
- `BILLING_ISSUE`: Payment failed (may enter grace period)
- `PRODUCT_CHANGE`: User upgraded/downgraded
- `UNCANCELLATION`: User re-enabled auto-renewal
- `TRANSFER`: Subscription transferred between users

**Webhook Delivery**:
- **Typical delivery**: 5-60 seconds after event
- **Cancellations**: Usually within 2 hours
- **Retry policy**: Up to 5 retries with exponential backoff
- **Timeout**: 60 seconds per attempt

**Setup**:

1. Create webhook endpoint in your backend:

```typescript
// Supabase Edge Function: handle-subscription-webhook
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';

serve(async (req) => {
  // Verify authorization header
  const authHeader = req.headers.get('Authorization');
  if (authHeader !== `Bearer ${Deno.env.get('REVENUECAT_WEBHOOK_SECRET')}`) {
    return new Response('Unauthorized', { status: 401 });
  }

  // Parse webhook payload
  const payload = await req.json();
  const { event } = payload;

  // Handle different event types
  switch (event.type) {
    case 'INITIAL_PURCHASE':
      await handleNewSubscription(event);
      break;
    case 'RENEWAL':
      await handleRenewal(event);
      break;
    case 'CANCELLATION':
      await handleCancellation(event);
      break;
    case 'EXPIRATION':
      await handleExpiration(event);
      break;
  }

  return new Response('OK', { status: 200 });
});
```

2. Configure in RevenueCat dashboard:
   - Dashboard → Integrations → Webhooks
   - Add URL: `https://your-project.supabase.co/functions/v1/handle-subscription-webhook`
   - Add Authorization header: `Bearer YOUR_SECRET_KEY`
   - Select events to receive

**Recommended Integrations**:
- **Mixpanel**: Automatic subscription analytics
- **Slack**: Real-time notifications for new subscriptions
- **Customer.io**: Email campaigns based on subscription status
- **Segment**: Unified analytics pipeline

### Analytics and Charts

**Built-In Analytics Dashboard**:
- Monthly Recurring Revenue (MRR)
- Active subscriptions
- New subscriptions
- Churn rate
- Trial conversion rate
- Revenue by product/offering
- Cohort analysis
- LTV (Lifetime Value) projections

**Custom Charts**:
- Revenue growth over time
- Subscription duration distribution
- Conversion funnel by offering
- Refund rate
- Billing issue recovery rate

**Accessing Data**:

```dart
// Track custom analytics events
Future<void> trackPaywallView(String offeringId) async {
  await Purchases.recordPurchaseEvent(
    eventName: 'paywall_viewed',
    properties: {'offering_id': offeringId},
  );
}

// Get customer attributes
final customerInfo = await Purchases.getCustomerInfo();
print('First purchase: ${customerInfo.originalPurchaseDate}');
print('Last active: ${customerInfo.lastSeen}');
```

**Exporting Data**:
- CSV exports for offline analysis
- REST API for programmatic access
- Webhook events for real-time streaming
- Scheduled exports to S3/Google Cloud Storage

---

## 6. Best Practices

### Security Considerations

#### API Key Protection

**Critical Rules**:
1. **NEVER commit API keys to Git**:
   - Add to .gitignore: `secrets/`, `.env`, `lib/config/keys.dart`
   - Use environment variables for CI/CD
   - Encrypt sensitive files if bundled in app

2. **Use public keys in client apps**:
   - Public keys (starting with `appl_`, `goog_`) are safe in client code
   - Secret keys should ONLY be used server-side
   - RevenueCat validates all receipts server-side regardless

3. **Rotate keys periodically**:
   - Generate new keys every 6-12 months
   - Update across all environments simultaneously
   - Monitor for unauthorized usage

**Secure Storage Example**:

```dart
// Load from encrypted file or secure storage
class SecureConfig {
  static late String revenueCatApiKey;

  static Future<void> load() async {
    // Option 1: From encrypted asset bundle
    final encrypted = await rootBundle.load('secrets/api_keys.enc');
    final decrypted = await decrypt(encrypted);
    revenueCatApiKey = decrypted['revenuecat_ios'];

    // Option 2: From platform secure storage
    const storage = FlutterSecureStorage();
    revenueCatApiKey = await storage.read(key: 'revenuecat_api_key') ?? '';

    // Option 3: From environment variable (CI/CD)
    revenueCatApiKey = Platform.environment['REVENUECAT_API_KEY'] ?? '';
  }
}
```

#### Receipt Validation

**How It Works**:
- All purchases go through RevenueCat's servers for validation
- Prevents receipt forgery and jailbreak exploits
- No additional code needed - handled automatically by SDK

**Entitlement Verification**:

```dart
// Optional: Enable signature verification (Premium feature)
final configuration = PurchasesConfiguration(apiKey)
  ..entitlementVerificationMode = EntitlementVerificationMode.informational;
```

**Modes**:
- `disabled`: No verification (default, sufficient for most apps)
- `informational`: Logs verification failures, doesn't block access
- `enforced`: Blocks access if verification fails (Premium plan only)

#### User Privacy

**Best Practices**:
1. **Use anonymous IDs by default**:
   ```dart
   // Don't set appUserID initially
   PurchasesConfiguration(apiKey)..appUserID = null
   ```

2. **Link to account after authentication**:
   ```dart
   await Purchases.logIn(userId);
   ```

3. **Clear data on logout**:
   ```dart
   await Purchases.logOut();
   ```

4. **Don't store payment info**:
   - RevenueCat and App Store handle all payment data
   - You never see credit card details
   - Compliant with PCI DSS automatically

### Error Handling

**Common Error Scenarios**:

```dart
Future<bool> purchaseWithErrorHandling(Package package) async {
  try {
    final params = PurchaseParams.package(package);
    final result = await Purchases.purchase(params);

    if (result.customerInfo.entitlements.active.containsKey('premium')) {
      _showSuccess('Welcome to Premium!');
      return true;
    }

    return false;
  } on PlatformException catch (e) {
    final errorCode = PurchasesErrorHelper.getErrorCode(e);

    switch (errorCode) {
      case PurchasesErrorCode.purchaseCancelledError:
        // User cancelled - no message needed
        print('User cancelled purchase');
        break;

      case PurchasesErrorCode.purchaseNotAllowedError:
        _showError('Purchases are not allowed on this device. '
                   'Check parental controls.');
        break;

      case PurchasesErrorCode.purchaseInvalidError:
        _showError('This purchase is invalid. Please contact support.');
        break;

      case PurchasesErrorCode.productNotAvailableForPurchaseError:
        _showError('This subscription is currently unavailable. '
                   'Please try again later.');
        break;

      case PurchasesErrorCode.networkError:
        _showError('Network error. Please check your connection and try again.');
        break;

      case PurchasesErrorCode.storeProblemError:
        _showError('App Store error. Please try again in a few moments.');
        break;

      default:
        _showError('Purchase failed: ${e.message}');
        // Log to Sentry for investigation
        Sentry.captureException(e);
    }

    return false;
  } catch (e) {
    _showError('Unexpected error: $e');
    Sentry.captureException(e);
    return false;
  }
}
```

**Offline Handling**:

```dart
// RevenueCat caches customer info for offline access
Future<bool> checkPremiumOffline() async {
  try {
    // Attempt to fetch fresh data
    final customerInfo = await Purchases.getCustomerInfo();
    return customerInfo.entitlements.active.containsKey('premium');
  } catch (e) {
    // Fallback to cached data
    try {
      final cachedInfo = await Purchases.getCachedCustomerInfo();
      if (cachedInfo != null) {
        return cachedInfo.entitlements.active.containsKey('premium');
      }
    } catch (_) {}

    // Last resort: check local database
    return await _checkLocalPremiumStatus();
  }
}
```

### User Restoration Flows

**Onboarding Flow**:

```dart
class OnboardingController extends AsyncNotifier<OnboardingState> {
  @override
  FutureOr<OnboardingState> build() async {
    // Check for existing purchases on app launch
    try {
      final customerInfo = await Purchases.getCustomerInfo();

      if (customerInfo.entitlements.active.isNotEmpty) {
        // User has active subscription - skip onboarding
        return OnboardingState.completed(hasPremium: true);
      }

      // Show onboarding for new user
      return OnboardingState.initial();
    } catch (e) {
      // Continue with onboarding if check fails
      return OnboardingState.initial();
    }
  }
}
```

**Restore Purchases Screen**:

```dart
class RestorePurchasesScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<RestorePurchasesScreen> createState() =>
      _RestorePurchasesScreenState();
}

class _RestorePurchasesScreenState
    extends ConsumerState<RestorePurchasesScreen> {
  bool _isRestoring = false;

  Future<void> _restorePurchases() async {
    setState(() => _isRestoring = true);

    try {
      final customerInfo = await Purchases.restorePurchases();

      if (customerInfo.entitlements.active.isEmpty) {
        // No purchases found
        _showDialog(
          title: 'No Purchases Found',
          message: 'We could not find any purchases associated with this '
                   'Apple ID. If you purchased on a different device, '
                   'please sign in with that Apple ID.',
        );
      } else {
        // Purchases restored successfully
        _showDialog(
          title: 'Success!',
          message: 'Your purchases have been restored.',
          onDismiss: () => Navigator.of(context).pop(true),
        );
      }
    } catch (e) {
      _showDialog(
        title: 'Restore Failed',
        message: 'Could not restore purchases: $e',
      );
    } finally {
      setState(() => _isRestoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Restore Purchases')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Have you subscribed before?'),
            SizedBox(height: 16),
            Text(
              'If you previously purchased a subscription on this or '
              'another device, you can restore it here.',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isRestoring ? null : _restorePurchases,
              child: _isRestoring
                  ? CircularProgressIndicator()
                  : Text('Restore Purchases'),
            ),
          ],
        ),
      ),
    );
  }
}
```

**Device Transfer**:

```dart
// User signs in on new device
Future<void> handleUserSignIn(String userId) async {
  try {
    // Link existing purchases to this user
    final customerInfo = await Purchases.logIn(userId);

    // Check if they have premium
    if (customerInfo.entitlements.active.containsKey('premium')) {
      _showWelcomeBack();
      _syncPremiumStatus(true);
    }
  } catch (e) {
    print('Failed to sign in user: $e');
  }
}
```

### Trial Period Setup

**Free Trial Best Practices**:

1. **Configure in App Store Connect only** - RevenueCat detects automatically
2. **Typical duration**: 7 days (optimal conversion)
3. **Make trial terms clear** in paywall
4. **Show value during trial** to prevent cancellation

**Checking Trial Eligibility**:

```dart
Future<void> updatePaywallForTrialEligibility() async {
  try {
    final offerings = await Purchases.getOfferings();
    final package = offerings.current?.monthly;

    if (package == null) return;

    // Check if user is eligible for introductory offer
    final eligibility = await Purchases.checkTrialOrIntroDiscountEligibility(
      [package.storeProduct],
    );

    final isEligible = eligibility[package.storeProduct.identifier] ==
        IntroEligibilityStatus.eligible;

    // Update UI to show/hide trial messaging
    setState(() {
      _showTrialCopy = isEligible;
      _ctaText = isEligible ? 'Start Free Trial' : 'Subscribe Now';
    });
  } catch (e) {
    print('Failed to check trial eligibility: $e');
  }
}
```

**Trial-Aware Paywall Copy**:

```dart
Widget buildSubscriptionButton(bool hasTrialEligibility) {
  return Column(
    children: [
      if (hasTrialEligibility) ...[
        Text(
          'Start Your Free 7-Day Trial',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        SizedBox(height: 8),
        Text(
          'Cancel anytime. \$19.99/month after trial.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ] else ...[
        Text(
          'Subscribe to Premium',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        SizedBox(height: 8),
        Text(
          '\$19.99/month',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
      SizedBox(height: 24),
      ElevatedButton(
        onPressed: _handleSubscribe,
        child: Text(hasTrialEligibility ? 'Start Free Trial' : 'Subscribe'),
      ),
    ],
  );
}
```

**Trial Conversion Tracking**:

```dart
// Listen for renewal events
Purchases.addCustomerInfoUpdateListener((customerInfo) {
  final activeSubscriptions = customerInfo.subscriptions;

  for (final subscription in activeSubscriptions.values) {
    // Check if this renewal converted from trial
    if (subscription.periodType == PeriodType.normal &&
        subscription.originalPurchaseDate != subscription.latestPurchaseDate) {
      _trackTrialConversion(subscription);
    }
  }
});
```

### Subscription Lifecycle Management

**Monitoring Subscription Health**:

```dart
class SubscriptionHealthMonitor {
  Future<SubscriptionHealth> checkHealth() async {
    final customerInfo = await Purchases.getCustomerInfo();
    final subscription = customerInfo.subscriptions['premium_monthly'];

    if (subscription == null) {
      return SubscriptionHealth.none();
    }

    // Check for billing issues
    if (subscription.billingIssuesDetected) {
      return SubscriptionHealth.billingIssue(
        expiresAt: subscription.expiresDate,
      );
    }

    // Check if cancelled but still active
    if (subscription.unsubscribeDetectedAt != null && subscription.willRenew == false) {
      return SubscriptionHealth.cancelled(
        expiresAt: subscription.expiresDate,
        cancelledAt: subscription.unsubscribeDetectedAt!,
      );
    }

    // Check if in grace period
    final gracePeriodEnd = subscription.gracePeriodExpiresDate;
    if (gracePeriodEnd != null && DateTime.now().isBefore(gracePeriodEnd)) {
      return SubscriptionHealth.gracePeriod(
        gracePeriodEnds: gracePeriodEnd,
      );
    }

    // Active and healthy
    return SubscriptionHealth.active(
      renewsAt: subscription.expiresDate,
      willRenew: subscription.willRenew,
    );
  }

  Future<void> showHealthAlert(SubscriptionHealth health) async {
    switch (health.status) {
      case HealthStatus.billingIssue:
        _showBillingIssueAlert(health.expiresAt!);
        break;
      case HealthStatus.cancelled:
        _showCancellationAlert(health.expiresAt!);
        break;
      case HealthStatus.gracePeriod:
        _showGracePeriodAlert(health.gracePeriodEnds!);
        break;
      case HealthStatus.active:
      case HealthStatus.none:
        // No alert needed
        break;
    }
  }
}
```

**Grace Period Handling**:

```dart
void _showGracePeriodAlert(DateTime gracePeriodEnds) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Payment Issue'),
      content: Text(
        'There was a problem with your last payment. Please update '
        'your payment method to continue your subscription.\n\n'
        'You have access until ${DateFormat.yMMMd().format(gracePeriodEnds)}.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Remind Me Later'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            _openManageSubscription();
          },
          child: Text('Update Payment'),
        ),
      ],
    ),
  );
}

Future<void> _openManageSubscription() async {
  final url = await Purchases.getManagementURL();
  if (url != null) {
    await launchUrl(Uri.parse(url));
  }
}
```

**Cancellation Retention**:

```dart
void _showCancellationAlert(DateTime expiresAt) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('We\'ll Miss You'),
      content: Text(
        'Your premium subscription is set to expire on '
        '${DateFormat.yMMMd().format(expiresAt)}.\n\n'
        'Reactivate now to continue enjoying:\n'
        '• Personalized nutrition plans\n'
        '• AI-powered recommendations\n'
        '• Unlimited plan generation\n'
        '• Priority support',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Continue Cancellation'),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context);
            // Prompt user to re-enable subscription
            final url = await Purchases.getManagementURL();
            if (url != null) {
              await launchUrl(Uri.parse(url));
            }
          },
          child: Text('Reactivate Subscription'),
        ),
      ],
    ),
  );
}
```

---

## 7. Implementation Code Examples

### Complete RevenueCat Service

```dart
// lib/features/subscription/data/revenuecat_service.dart

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'revenuecat_service.g.dart';

@riverpod
RevenueCatService revenueCatService(RevenueCatServiceRef ref) {
  return RevenueCatService();
}

class RevenueCatService {
  bool _isConfigured = false;

  /// Initialize RevenueCat SDK with API key
  Future<void> initialize(String apiKey) async {
    if (_isConfigured) {
      print('RevenueCat already configured');
      return;
    }

    // Enable debug logging in development
    await Purchases.setLogLevel(LogLevel.debug);

    // Configure SDK
    final configuration = PurchasesConfiguration(apiKey)
      ..appUserID = null  // Anonymous by default
      ..purchasesAreCompletedBy = const PurchasesAreCompletedByRevenueCat()
      ..shouldShowInAppMessagesAutomatically = true
      ..entitlementVerificationMode = EntitlementVerificationMode.disabled;

    await Purchases.configure(configuration);
    _isConfigured = true;

    print('RevenueCat initialized successfully');
  }

  /// Get current customer info
  Future<CustomerInfo> getCustomerInfo() async {
    return await Purchases.getCustomerInfo();
  }

  /// Check if user has premium access
  Future<bool> hasPremiumAccess() async {
    try {
      final customerInfo = await getCustomerInfo();
      return customerInfo.entitlements.active.containsKey('premium');
    } catch (e) {
      print('Error checking premium access: $e');
      return false;
    }
  }

  /// Get available offerings
  Future<Offerings?> getOfferings() async {
    try {
      return await Purchases.getOfferings();
    } catch (e) {
      print('Error fetching offerings: $e');
      return null;
    }
  }

  /// Purchase a package
  Future<PurchaseResult?> purchasePackage(Package package) async {
    try {
      final params = PurchaseParams.package(package);
      final result = await Purchases.purchase(params);
      return PurchaseResult.success(result.customerInfo);
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      return PurchaseResult.error(errorCode, e.message ?? 'Unknown error');
    } catch (e) {
      return PurchaseResult.error(
        PurchasesErrorCode.unknownError,
        e.toString(),
      );
    }
  }

  /// Restore previous purchases
  Future<CustomerInfo> restorePurchases() async {
    return await Purchases.restorePurchases();
  }

  /// Link purchases to user account
  Future<CustomerInfo> identifyUser(String userId) async {
    return await Purchases.logIn(userId);
  }

  /// Logout and switch to anonymous
  Future<CustomerInfo> logout() async {
    return await Purchases.logOut();
  }

  /// Set up real-time customer info listener
  void setupCustomerInfoListener(void Function(CustomerInfo) onUpdate) {
    Purchases.addCustomerInfoUpdateListener(onUpdate);
  }

  /// Get subscription management URL
  Future<String?> getManagementURL() async {
    return await Purchases.getManagementURL();
  }

  /// Check trial eligibility
  Future<bool> isEligibleForTrial(String productId) async {
    try {
      final offerings = await getOfferings();
      final package = offerings?.current?.availablePackages.firstWhere(
        (p) => p.storeProduct.identifier == productId,
      );

      if (package == null) return false;

      final eligibility = await Purchases.checkTrialOrIntroDiscountEligibility(
        [package.storeProduct],
      );

      return eligibility[productId] == IntroEligibilityStatus.eligible;
    } catch (e) {
      print('Error checking trial eligibility: $e');
      return false;
    }
  }
}

/// Result of purchase attempt
sealed class PurchaseResult {
  const PurchaseResult();

  factory PurchaseResult.success(CustomerInfo customerInfo) =>
      PurchaseSuccess(customerInfo);

  factory PurchaseResult.error(PurchasesErrorCode code, String message) =>
      PurchaseError(code, message);
}

class PurchaseSuccess extends PurchaseResult {
  final CustomerInfo customerInfo;
  const PurchaseSuccess(this.customerInfo);
}

class PurchaseError extends PurchaseResult {
  final PurchasesErrorCode errorCode;
  final String message;
  const PurchaseError(this.errorCode, this.message);

  bool get isUserCancelled =>
      errorCode == PurchasesErrorCode.purchaseCancelledError;
}
```

### Subscription Status Provider

```dart
// lib/features/subscription/application/subscription_status_provider.dart

import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:mealvana_endurance/features/subscription/data/revenuecat_service.dart';

part 'subscription_status_provider.g.dart';

@riverpod
class SubscriptionStatus extends _$SubscriptionStatus {
  @override
  Future<bool> build() async {
    // Set up listener for real-time updates
    final service = ref.read(revenueCatServiceProvider);
    service.setupCustomerInfoListener(_handleCustomerInfoUpdate);

    // Get initial status
    return await service.hasPremiumAccess();
  }

  void _handleCustomerInfoUpdate(CustomerInfo customerInfo) {
    // Update state when customer info changes
    final hasPremium = customerInfo.entitlements.active.containsKey('premium');
    state = AsyncData(hasPremium);

    // Sync to local database
    _syncToLocalDatabase(hasPremium);
  }

  Future<void> _syncToLocalDatabase(bool hasPremium) async {
    // TODO: Update Drift database with premium status
    // This ensures offline access to premium status
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(revenueCatServiceProvider);
      return await service.hasPremiumAccess();
    });
  }
}
```

### Paywall Screen

```dart
// lib/features/subscription/presentation/screens/paywall_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:mealvana_endurance/features/subscription/data/revenuecat_service.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  Offerings? _offerings;
  bool _isLoading = true;
  bool _isPurchasing = false;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    final service = ref.read(revenueCatServiceProvider);
    final offerings = await service.getOfferings();

    setState(() {
      _offerings = offerings;
      _isLoading = false;
    });
  }

  Future<void> _handlePurchase(Package package) async {
    setState(() => _isPurchasing = true);

    final service = ref.read(revenueCatServiceProvider);
    final result = await service.purchasePackage(package);

    setState(() => _isPurchasing = false);

    switch (result) {
      case PurchaseSuccess(:final customerInfo):
        if (customerInfo.entitlements.active.containsKey('premium')) {
          _showSuccess('Welcome to Premium!');
          Navigator.of(context).pop(true);
        }
        break;

      case PurchaseError(:final errorCode, :final message):
        if (!result.isUserCancelled) {
          _showError(message);
        }
        break;

      case null:
        _showError('Purchase failed. Please try again.');
        break;
    }
  }

  Future<void> _handleRestore() async {
    setState(() => _isPurchasing = true);

    try {
      final service = ref.read(revenueCatServiceProvider);
      final customerInfo = await service.restorePurchases();

      if (customerInfo.entitlements.active.isNotEmpty) {
        _showSuccess('Purchases restored!');
        Navigator.of(context).pop(true);
      } else {
        _showInfo('No purchases found to restore.');
      }
    } catch (e) {
      _showError('Failed to restore purchases: $e');
    } finally {
      setState(() => _isPurchasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final offering = _offerings?.current;
    if (offering == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Premium')),
        body: const Center(
          child: Text('No subscription plans available.'),
        ),
      );
    }

    final monthlyPackage = offering.monthly;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upgrade to Premium'),
        actions: [
          TextButton(
            onPressed: _isPurchasing ? null : _handleRestore,
            child: const Text('Restore'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              // Premium Features
              const Text(
                'Premium Features',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              _buildFeatureRow('Unlimited nutrition plans'),
              _buildFeatureRow('AI-powered recommendations'),
              _buildFeatureRow('Advanced gut training protocols'),
              _buildFeatureRow('Priority support'),
              _buildFeatureRow('Ad-free experience'),

              const Spacer(),

              // Price
              if (monthlyPackage != null) ...[
                Text(
                  monthlyPackage.storeProduct.priceString,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'per month',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Subscribe Button
                ElevatedButton(
                  onPressed: _isPurchasing
                      ? null
                      : () => _handlePurchase(monthlyPackage),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isPurchasing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Start Premium',
                          style: TextStyle(fontSize: 18),
                        ),
                ),
              ],

              const SizedBox(height: 16),

              // Terms
              Text(
                'Cancel anytime. Subscription automatically renews unless '
                'cancelled at least 24 hours before the end of the current period.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
```

---

## 8. Next Steps for Mealvana Endurance

### Immediate Actions (This Week)

1. **Create RevenueCat Account**:
   - Sign up at https://app.revenuecat.com
   - Create project: "Mealvana Endurance"
   - Copy iOS API key

2. **Configure App Store Connect**:
   - Create subscription group: "Premium Subscriptions"
   - Create product: `premium_monthly` at $19.99/month
   - Add 7-day free trial (optional)
   - Generate shared secret and In-App Purchase key

3. **Add Flutter Dependencies**:
   ```bash
   flutter pub add purchases_flutter purchases_ui_flutter
   ```

### Short-Term (Next 2 Weeks)

4. **Implement RevenueCatService**:
   - Follow code examples in section 7
   - Initialize in `appStartupProvider`
   - Create subscription status provider

5. **Build Paywall**:
   - Use pre-built paywall or custom design
   - Add to onboarding flow
   - Implement restore purchases flow

6. **Test in Sandbox**:
   - Create sandbox test accounts
   - Test complete purchase flow
   - Verify restoration works
   - Test error scenarios

### Medium-Term (Next Month)

7. **Integrate with Backend**:
   - Set up webhooks for subscription events
   - Sync premium status to Supabase
   - Add subscription analytics to Mixpanel

8. **Premium Feature Gating**:
   - Add entitlement checks before premium features
   - Gracefully handle expired subscriptions
   - Show upgrade prompts for free users

9. **Production Testing**:
   - Test with real Apple ID
   - Make actual purchase
   - Request refund after verification

### Long-Term (Next Quarter)

10. **Launch & Monitor**:
    - Submit app for review
    - Monitor RevenueCat dashboard daily
    - Track conversion metrics
    - Optimize paywall based on data

11. **Experiment & Optimize**:
    - A/B test paywall copy
    - Try different trial lengths
    - Test annual plan offering
    - Optimize pricing based on conversions

---

## Resources

### Official Documentation
- **RevenueCat Docs**: https://www.revenuecat.com/docs
- **Flutter SDK**: https://www.revenuecat.com/docs/getting-started/installation/flutter
- **API Reference**: https://www.revenuecat.com/reference/basic
- **Webhook Events**: https://www.revenuecat.com/docs/integrations/webhooks/event-types-and-fields

### Community & Support
- **RevenueCat Community**: https://community.revenuecat.com
- **GitHub Repository**: https://github.com/RevenueCat/purchases-flutter
- **Support Email**: support@revenuecat.com
- **Status Page**: https://status.revenuecat.com

### App Store Resources
- **App Store Connect**: https://appstoreconnect.apple.com
- **In-App Purchase Guide**: https://developer.apple.com/in-app-purchase/
- **Subscription Best Practices**: https://developer.apple.com/app-store/subscriptions/

### Context7 Library Access
- **Library ID**: `/revenuecat/purchases-flutter`
- **Code Snippets**: 243 examples available
- **Documentation ID**: `/revenuecat/docs`
- **Code Snippets**: 646 examples available

---

## Conclusion

RevenueCat provides a robust, well-documented solution for implementing subscriptions in Mealvana Endurance. The platform's strengths include:

- **Zero-cost startup**: Free until $2,500/month revenue
- **Time savings**: Weeks of development time saved vs building from scratch
- **Flutter support**: Mature SDK with 79.4 benchmark score
- **Comprehensive features**: Webhooks, analytics, paywall management, and cross-platform restoration
- **Excellent documentation**: 646 code examples and active community

**Recommended Approach for Mealvana**:
1. Start with free tier (sufficient for first 125+ subscribers)
2. Use pre-built paywalls for rapid deployment
3. Implement 7-day free trial to maximize conversions
4. Monitor RevenueCat dashboard for optimization opportunities
5. Scale to paid tier when MTR exceeds $2,500/month

The investment in RevenueCat is justified by the time saved, reduced complexity, and professional subscription infrastructure that would otherwise require months to build and maintain.

---

**Research Date**: January 2025
**Last Updated**: January 18, 2025
**Researcher**: Claude (Anthropic)
**Project**: Mealvana Endurance
