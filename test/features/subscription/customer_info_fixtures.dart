/// RevenueCat CustomerInfo fixtures, shaped the way the native bridge hands
/// them to `CustomerInfo.fromJson` (producer-shaped, docs/test/README.md
/// Seam tests), for the three answers the gate gives (mp-457): open (`pro`
/// active), lapsed (`pro` in `all` but not in `active`) and never (no `pro`
/// anywhere).
library;

import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:mealvana_endurance/features/subscription/data/subscription_service.dart';
import 'package:mealvana_endurance/features/subscription/domain/entitlement.dart';

Map<String, dynamic> _pro({required bool isActive, required String expires}) =>
    {
      'identifier': 'pro',
      'isActive': isActive,
      'willRenew': isActive,
      'latestPurchaseDate': '2026-08-01T10:00:00Z',
      'originalPurchaseDate': '2026-08-01T10:00:00Z',
      'productIdentifier': 'me_pro_monthly',
      'isSandbox': true,
      'ownershipType': 'PURCHASED',
      'store': 'APP_STORE',
      'periodType': 'NORMAL',
      'expirationDate': expires,
      'unsubscribeDetectedAt': isActive ? null : '2026-08-20T10:00:00Z',
      'billingIssueDetectedAt': null,
      'verification': 'NOT_REQUESTED',
    };

CustomerInfo _info({required Map<String, dynamic> all, required bool active}) {
  return CustomerInfo.fromJson({
    'entitlements': {
      'all': all,
      'active': active ? all : <String, dynamic>{},
      'verification': 'NOT_REQUESTED',
    },
    'allPurchaseDates': {
      if (all.isNotEmpty) 'me_pro_monthly': '2026-08-01T10:00:00Z',
    },
    'activeSubscriptions': [if (active) 'me_pro_monthly'],
    'allPurchasedProductIdentifiers': [if (all.isNotEmpty) 'me_pro_monthly'],
    'nonSubscriptionTransactions': <dynamic>[],
    'firstSeen': '2026-08-01T09:00:00Z',
    'originalAppUserId': 'u-1',
    'allExpirationDates': {
      if (all.isNotEmpty) 'me_pro_monthly': all['pro']['expirationDate'],
    },
    'requestDate': '2026-09-22T12:00:00Z',
    'latestExpirationDate': all.isEmpty ? null : all['pro']['expirationDate'],
    'originalPurchaseDate': null,
    'originalApplicationVersion': null,
    'managementURL': null,
  });
}

/// `pro` active until 1 November.
final CustomerInfo customerInfoOpen = _info(
  all: {'pro': _pro(isActive: true, expires: '2026-11-01T10:00:00Z')},
  active: true,
);

/// `pro` held once, expired on 1 September.
final CustomerInfo customerInfoLapsed = _info(
  all: {'pro': _pro(isActive: false, expires: '2026-09-01T10:00:00Z')},
  active: false,
);

/// No `pro`, ever.
final CustomerInfo customerInfoNever = _info(all: const {}, active: false);

/// The statuses the service maps each fixture to — what `fetchStatus` and
/// the CustomerInfo listener hand the status controller.
SubscriptionStatus statusOf(CustomerInfo info) =>
    SubscriptionService.statusFromCustomerInfo(info);
