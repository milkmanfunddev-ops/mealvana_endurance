# RevenueCat Integration for Mealvana Endurance

**Last Updated**: January 18, 2025
**Status**: Planning Phase
**Target Launch**: Phase 4 (6-8 weeks)

---

## Overview

RevenueCat is a subscription infrastructure platform that will power Mealvana Endurance's $19.99/month premium subscription. This document provides a comprehensive overview of RevenueCat, implementation strategy, and integration with our existing architecture.

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

At $19.99/month subscription price:

- **50 subscribers**: $999.50 MTR = **$0** (Free tier)
- **150 subscribers**: $2,998.50 MTR = **$23.99/month** ($8 per $1K)
- **500 subscribers**: $9,995 MTR = **$79.96/month** ($8 per $1K)
- **1,000 subscribers**: $19,990 MTR = **$239.88/month** ($12 per $1K)

**Break-Even Analysis**:
- Free tier covers first ~125 subscribers
- At 150 subscribers: $2,999 monthly revenue - $24 RevenueCat = **$2,975 net**
- ROI is excellent given weeks of development time saved

---

## Premium Features Strategy

### Freemium Model

Based on business requirements, premium subscription ($19.99/month with 7-day free trial) will unlock:

**Premium Features** (Subscription Required):
1. **Barcode Scanning** - Quick food entry via barcode scanning
2. **Coach Integration** - Connect with coaches for guided plans
3. **Pro Recipes** - Advanced nutrition recipes and meal plans
4. **TrainingPeaks Integration** - Sync training plans and workouts
5. **Final Surge Integration** - Connect training data
6. **Canva Integration** - Visual nutrition plan exports
7. **Strava Integration** - Connect activities and performance data

**Free Features** (Available to All Users):
- Basic nutrition plan generation (manual input)
- Up to 3 saved nutrition plans
- Food preferences management
- Basic gut training guidance
- Access to general nutrition content

### Paywall Strategy

**Presentation Timing**: After onboarding completion
- User completes profile setup
- Shown value of premium features
- Clear 7-day free trial offer
- Easy "Skip for now" option to continue with free tier

**Trial Configuration**:
- **Duration**: 7 days
- **Type**: Free trial (no charge during trial)
- **Eligibility**: First-time subscribers only
- **Cancel Policy**: Can cancel anytime, no charge if cancelled during trial

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
    state = AsyncData(info.entitlements.active.containsKey('premium'));
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

**Content Structure** (`content_defaults.json`):
```json
{
  "ui_text": {
    "paywall": {
      "title": "Upgrade to Premium",
      "subtitle": "Unlock advanced nutrition features",
      "features": {
        "barcode_scanning": "Quick food entry with barcode scanning",
        "coach_integration": "Connect with your coach",
        "pro_recipes": "Access premium nutrition recipes",
        "training_peaks": "TrainingPeaks integration",
        "final_surge": "Final Surge integration",
        "canva": "Export plans to Canva",
        "strava": "Strava activity sync"
      },
      "trial_cta": "Start 7-Day Free Trial",
      "subscribe_cta": "Subscribe Now",
      "trial_terms": "Cancel anytime. $19.99/month after trial."
    }
  }
}
```

---

## Implementation Timeline

### Phase Dependencies

**Prerequisites**:
- ✅ Phase 0: Domain model auth fields (COMPLETED)
- ✅ Phase 1: Anonymous auth (COMPLETED)
- ⏳ Phase 2: Email/OAuth authentication (IN PROGRESS)
- ⏳ Phase 3: Multi-device sync
- 🔜 Phase 4: Monetization + RevenueCat (TARGET)

**RevenueCat Integration**: Phase 4 (6-8 weeks, ~4-6 months from now based on roadmap)

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
