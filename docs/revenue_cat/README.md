# RevenueCat Integration for Mealvana Endurance

**Last Updated**: March 17, 2026
**Status**: Infrastructure Setup In Progress
**Pricing**: $9.99/month or $69.99/year with 1-month free trial

---

## Overview

RevenueCat is a subscription infrastructure platform that powers Mealvana Endurance's "Pro" subscription tier. This document provides a comprehensive overview of RevenueCat, implementation strategy, and integration with our existing architecture.

### Current Progress (March 2026)
- RevenueCat project and test store fully configured (products, entitlements, offerings, packages)
- In-App Purchase Key (.p8) generated and saved
- App Store Connect subscription products: **not yet created**
- Real iOS app in RevenueCat: **not yet added**
- Flutter SDK: **not yet installed**
- See `SETUP_GUIDE.md` for detailed progress tracker and next steps

## Table of Contents

1. [Why RevenueCat?](#why-revenuecat)
2. [Pricing & Economics](#pricing--economics)
3. [Premium Features Strategy](#premium-features-strategy)
4. [Technical Architecture](#technical-architecture)
5. [Implementation Timeline](#implementation-timeline)
6. [Key Documentation](#key-documentation)
7. [Quick Start Guide](#quick-start-guide)

---

## Why RevenueCat?

### Platform Benefits

RevenueCat provides a unified API for in-app subscriptions that abstracts away the complexity of managing subscriptions across multiple platforms.

**Core Value Propositions**:
- **Time Savings**: Can save weeks of development time vs building from scratch
- **Zero Initial Cost**: Free until you reach $2,500/month revenue (~125 subscribers)
- **Server-Side Validation**: Automatic receipt validation prevents fraud
- **Cross-Platform Restoration**: Users can restore purchases across devices automatically
- **Real-Time Updates**: Webhook notifications for subscription events (5-60 seconds)
- **Remote Configuration**: Update paywalls without app updates
- **Analytics Dashboard**: Built-in MRR, churn, conversion tracking

### Flutter Integration Quality

- **Mature SDK**: `purchases-flutter` with 79.4/100 benchmark score
- **High Reputation**: Well-maintained with active community
- **Code Examples**: 243 Flutter-specific code examples available
- **Documentation**: 646 total code examples across all platforms
- **Context7 Library ID**: `/revenuecat/purchases-flutter`

### How It Works

```
1. Configure products in App Store Connect
2. Link products to RevenueCat entitlements (e.g., "premium")
3. Initialize RevenueCat SDK in Flutter app with API key
4. Present offerings and handle purchases through SDK
5. Check entitlement status to unlock features
6. RevenueCat handles receipt validation, renewals, status updates automatically
```

---

## Pricing & Economics

### RevenueCat Costs

| Plan | MTR Threshold | Cost | Notes |
|------|---------------|------|-------|
| **Free** | < $2,500/month | $0 | All features included |
| **Starter** | $2,500 - $10,000/month | $8 per $1,000 MTR | ~$80/month at $10K MTR |
| **Pro** | > $10,000/month | $12 per $1,000 MTR | Priority support |

**MTR Definition**: Monthly Tracked Revenue - total revenue tracked by RevenueCat in USD (before platform cut).

### Cost Projections for Mealvana

At $9.99/month or $69.99/year (blended ~$8/mo annual):

- **100 subscribers (all monthly)**: $999 MTR = **$0** (Free tier)
- **250 subscribers**: ~$2,500 MTR = **$20/month** ($8 per $1K)
- **500 subscribers**: ~$5,000 MTR = **$40/month** ($8 per $1K)
- **1,000 subscribers**: ~$10,000 MTR = **$120/month** ($12 per $1K)

**Break-Even Analysis**:
- Free tier covers first ~250 subscribers
- ROI is excellent given weeks of development time saved

---

## Pro Features Strategy

### Freemium Model

Pro subscription ($9.99/month or $69.99/year with 1-month free trial) unlocks:

**Pro Features** (Subscription Required):
1. **Training Platform Integration** - TrainingPeaks & FinalSurge workout import
2. **Write to TrainingPeaks** - Push nutrition data back to TrainingPeaks
3. **Coach/Dietitian Dashboard** - Connect with coaches for guided plans
4. **Brick Workout Nutrition Plan** - Multi-sport session planning
5. **Personal Fueling Templates** - Save and reuse fueling setups
6. **Mealvana 101** - Video fueling course led by Dr. Rachel Mitchel
7. **By-Hour Race Day Nutrition** - Timed race-day fueling plan
8. **Food Journaling** - Log and compare against targets
9. **Barcode Scanning** - Quick food entry via barcode
10. **Carb-Loading** - Structured carb-loading plans
11. **Adaptive Macro Adjustment** - Dynamic macro tuning

**Cookie-Gated Features** (NOT Pro, future):
- Meal planning
- Import recipes
- Coach intelligence: fueling plan pattern detection

**Free Features** (Available to All Users):
- Basic nutrition plan generation (manual input)
- Food preferences management
- Basic gut training guidance
- Access to general nutrition content

### Paywall Strategy

**Paywall Locations** (drawer variant):
- Settings > "Connected apps"
- Any pro feature card on home/dashboard
- Any pro feature CTA inside "Create activity"

**Gating Behavior**:
1. Show lock icon or `<Pro>` badge on locked features
2. On tap, open paywall drawer variant
3. After purchase, return user to the exact feature they tried to use

**Trial Configuration**:
- **Duration**: 1 month (closest to 4-week spec in Apple's tier system)
- **Type**: Free trial (no charge during trial)
- **Eligibility**: First-time subscribers only (per subscription group, lifetime)
- **Cancel Policy**: Can cancel anytime, no charge if cancelled during trial
- **After trial**: Automatically charged $9.99/month or $69.99/year

---

## Technical Architecture

### Integration with Existing Systems

RevenueCat will integrate seamlessly with Mealvana's existing architecture:

#### Andrea Bizzotto FOA Pattern

```
lib/features/subscription/
├── presentation/           # UI screens and widgets
│   ├── screens/
│   │   ├── paywall_screen.dart
│   │   ├── subscription_management_screen.dart
│   │   └── restore_purchases_screen.dart
│   └── controllers/
│       └── subscription_controller.dart
├── application/            # Service classes
│   ├── subscription_service.dart
│   └── subscription_status_provider.dart
├── domain/                 # Data models
│   ├── subscription_status.dart
│   └── purchase_result.dart
└── data/                   # Repositories and data sources
    ├── revenuecat_service.dart
    └── subscription_repository.dart
```

#### App Startup Integration

Following Andrea Bizzotto's initialization pattern:

```dart
// lib/shared/services/app_startup_service.dart

class AppStartupService {
  Future<void> initialize() async {
    // 1. Initialize non-recoverable dependencies (Supabase, Firebase)
    // 2. Initialize Drift database
    // 3. Initialize user session

    // 4. Initialize RevenueCat
    await _initializeRevenueCat();

    // 5. Check subscription status
    final isPremium = await _checkPremiumStatus();

    // 6. Sync to local database for offline access
    await _syncPremiumStatus(isPremium);

    // 7. Initialize analytics
  }
}
```

**Critical**: RevenueCat initialization happens in `appStartupProvider`, NOT in `main()`.

#### Riverpod State Management

All subscription logic follows AsyncNotifier pattern:

```dart
@riverpod
class SubscriptionStatus extends _$SubscriptionStatus {
  @override
  FutureOr<bool> build() async {
    // Set up real-time listener
    final service = ref.read(revenueCatServiceProvider);
    service.setupCustomerInfoListener(_handleUpdate);

    // Return initial premium status
    return await service.hasPremiumAccess();
  }

  void _handleUpdate(CustomerInfo info) {
    // Update state when subscription changes
    state = AsyncData(info.entitlements.active.containsKey('pro'));
  }
}
```

#### Drift Database Integration

Premium status cached locally for offline access:

```dart
// Database schema update
@DataClassName('User')
class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get deviceId => text().unique()();
  TextColumn get userId => text().nullable()();

  // Subscription fields
  BoolColumn get isPremium => boolean().withDefault(const Constant(false))();
  DateTimeColumn get premiumExpiresAt => dateTime().nullable()();
  TextColumn get subscriptionStatus => text().nullable()(); // active, cancelled, expired, etc.
}
```

#### Authentication Integration

**Current State**: Phase 1 - Anonymous auth with device_id
**Phase 4 Plan**: Use Supabase user_id for RevenueCat App User ID

```dart
// Phase 4: After Phase 2 email/OAuth auth is complete
Future<void> identifyUserAfterAuth(String supabaseUserId) async {
  await Purchases.logIn(supabaseUserId);
  // RevenueCat now links purchases to this user_id
}
```

**Migration Strategy**:
1. Phase 1-2: Use anonymous RevenueCat IDs
2. Phase 3: Plan migration
3. Phase 4: Migrate to Supabase user_id mapping
4. Use RevenueCat's `logIn()` to transfer anonymous purchases to authenticated user

#### Content Management System

All paywall text sourced from content management system:

```dart
class PaywallController extends AsyncNotifier<PaywallState> {
  ContentService get _content => ref.read(contentServiceProvider);

  String get paywallTitle => _content.getText('paywall.title');
  String get premiumFeature1 => _content.getText('paywall.features.barcode_scanning');
  // ...etc
}
```

**Content Structure** (`content_defaults.json`) - to be updated during implementation:
```json
{
  "ui_text": {
    "paywall": {
      "title": "Unlock {Feature}",
      "features": {
        "training_integration": "TrainingPeaks & FinalSurge Integration",
        "meal_logging": "Meal logging",
        "brick_workouts": "Brick workout planning",
        "personal_templates": "Personal fueling templates",
        "race_day": "By-hour race day nutrition planning",
        "mealvana_101": "Mealvana 101 (fueling course)"
      },
      "trial_cta": "Start 4-week free trial",
      "subscribe_cta": "Unlock Pro",
      "trial_terms": "After the free trial, you will be charged $9.99/month or $69.99/year unless you cancel.",
      "manage_note": "Manage your subscription in Settings anytime."
    }
  }
}
```

---

## Implementation Timeline

### Current Status (March 2026)

- ✅ RevenueCat project created and test store configured
- ✅ In-App Purchase Key generated
- ✅ Email/OAuth authentication complete
- ⏳ App Store Connect subscription products (next step)
- ⏳ Real iOS app in RevenueCat (next step)
- 🔜 Flutter SDK integration
- 🔜 Paywall UI and feature gating

### Estimated Time Investment

**Total Development Time**: 12-18 hours over 2-3 weeks

| Phase | Tasks | Time Estimate |
|-------|-------|---------------|
| **Account Setup** | RevenueCat account, App Store config | 2 hours |
| **Flutter Integration** | SDK installation, service creation | 3-4 hours |
| **Feature Implementation** | Paywall, purchase flow, feature gating | 4-5 hours |
| **Testing** | Sandbox testing, error scenarios | 2-3 hours |
| **Production Prep** | Webhooks, analytics, legal docs | 2-3 hours |
| **App Review** | Submission, wait time | 1-2 days |

---

## Key Documentation

### Internal Documentation

- **This File**: `/docs/revenue_cat/README.md` - Overview and strategy
- **Research Document**: `/docs/revenue_cat/revenuecat_research.md` - Comprehensive technical research
- **Implementation Roadmap**: `/docs/revenue_cat/implementation_roadmap.md` - Step-by-step implementation guide
- **Official Docs**: `/docs/revenue_cat/official_docs/` - RevenueCat reference materials

### External Resources

**RevenueCat**:
- Dashboard: https://app.revenuecat.com
- Docs: https://www.revenuecat.com/docs
- Flutter SDK: https://www.revenuecat.com/docs/getting-started/installation/flutter
- Community: https://community.revenuecat.com

**App Store**:
- App Store Connect: https://appstoreconnect.apple.com
- In-App Purchase Guide: https://developer.apple.com/in-app-purchase/
- Subscription Best Practices: https://developer.apple.com/app-store/subscriptions/

**Context7**:
- Library ID: `/revenuecat/purchases-flutter` (243 code examples)
- Documentation: `/revenuecat/docs` (646 code examples)

---

## Quick Start Guide

### For Developers

When Phase 4 begins, follow this sequence:

1. **Read Implementation Roadmap**: `/docs/revenue_cat/implementation_roadmap.md`
2. **Read Research Document**: `/docs/revenue_cat/revenuecat_research.md`
3. **Set up App Store Connect**: Create subscription products
4. **Create RevenueCat Account**: Configure project and API keys
5. **Install Flutter SDK**: Add dependencies to pubspec.yaml
6. **Implement Service Layer**: Follow FOA pattern in roadmap
7. **Build Paywall**: Use content management system for all text
8. **Test Thoroughly**: Sandbox testing before production
9. **Deploy Webhooks**: Integrate with Supabase edge functions
10. **Launch**: Submit for App Store review

### For Product/Business

**Before Implementation**:
- [ ] Define exact feature list for premium tier
- [ ] Finalize pricing ($19.99/month confirmed)
- [ ] Decide on trial length (7 days confirmed)
- [ ] Create App Store Connect account with completed agreements
- [ ] Complete tax and banking setup in App Store Connect
- [ ] Draft subscription terms and conditions
- [ ] Update privacy policy for payment processing

**During Implementation**:
- [ ] Review paywall designs and copy
- [ ] Approve premium feature gating decisions
- [ ] Test purchase flow on device
- [ ] Review subscription management UX
- [ ] Approve trial messaging and legal disclaimers

**After Launch**:
- [ ] Monitor RevenueCat dashboard daily for first week
- [ ] Track conversion metrics in Mixpanel
- [ ] Review churn rate weekly
- [ ] A/B test paywall variations
- [ ] Optimize based on data

---

## Success Metrics

### Technical Metrics

- [ ] Purchase flow completes in < 10 seconds
- [ ] 99.9%+ receipt validation success rate
- [ ] < 1% error rate on purchase attempts
- [ ] Webhook delivery < 60 seconds average
- [ ] Cross-platform restoration works 100% of time

### Business Metrics

- [ ] Trial-to-paid conversion rate: Target 20-30%
- [ ] Monthly churn rate: Target < 5%
- [ ] Lifetime Value (LTV): Target > $120 (6+ months)
- [ ] Paywall conversion rate: Target 5-10%
- [ ] Subscription renewal rate: Target 90%+

### User Experience Metrics

- [ ] < 2% support tickets related to purchases
- [ ] Restore purchases success rate > 95%
- [ ] Average rating maintained at 4.5+ stars
- [ ] No payment-related 1-star reviews
- [ ] Positive sentiment about premium features

---

## Risk Mitigation

### Technical Risks

| Risk | Mitigation |
|------|------------|
| **Receipt validation failures** | RevenueCat handles server-side, automatic retries |
| **Offline purchase attempts** | SDK queues purchases, processes when online |
| **Cross-platform issues** | Test on iOS 12.0+ and Android API 21+ |
| **API key exposure** | Store in secure location, never commit to Git |
| **Subscription status sync delays** | Cache premium status in Drift database |

### Business Risks

| Risk | Mitigation |
|------|------------|
| **Low conversion rates** | A/B test paywalls, offer 7-day trial |
| **High churn rate** | Monitor health metrics, retention campaigns |
| **App Store rejection** | Follow guidelines, test thoroughly |
| **RevenueCat costs exceed budget** | Free tier covers first 125 subscribers |
| **Users expect refunds** | Clear terms, easy cancellation process |

### Compliance Risks

| Risk | Mitigation |
|------|------------|
| **Privacy policy gaps** | Update for payment data handling |
| **Terms of service issues** | Include subscription terms clearly |
| **App Store guideline violations** | Follow IAP requirements exactly |
| **Tax/banking problems** | Complete setup before product creation |
| **Refund policy confusion** | Display App Store's refund policy |

---

## Next Steps

1. ✅ **Complete Phase 2**: Email/OAuth authentication (REQUIRED before Phase 4)
2. ✅ **Complete Phase 3**: Multi-device sync
3. 🔜 **Review Implementation Roadmap**: Read `/docs/revenue_cat/implementation_roadmap.md`
4. 🔜 **Set Up App Store Connect**: Create products and generate credentials
5. 🔜 **Create RevenueCat Account**: Configure project
6. 🔜 **Begin Implementation**: Follow roadmap steps

---

## Support & Questions

**Internal**:
- Refer to `/docs/revenue_cat/implementation_roadmap.md` for detailed steps
- Refer to `/docs/revenue_cat/revenuecat_research.md` for technical details
- Consult `/docs/technical/foa-architecture.md` for architecture patterns

**External**:
- RevenueCat Support: support@revenuecat.com
- RevenueCat Community: https://community.revenuecat.com
- App Store Support: https://developer.apple.com/contact/

---

**Document Version**: 1.0
**Created**: January 18, 2025
**Last Updated**: January 18, 2025
**Next Review**: Before Phase 4 implementation begins
