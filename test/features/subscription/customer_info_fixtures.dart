/// RevenueCat CustomerInfo fixtures, shaped the way the native bridge hands
/// them to `CustomerInfo.fromJson` (producer-shaped, docs/test/README.md
/// Seam tests), for the three answers the gate gives (mp-457): open (`pro`
/// active), lapsed (`pro` in `all` but not in `active`) and never (no `pro`
/// anywhere).
library;

import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:mealvana_endurance/features/subscription/data/subscription_service.dart';
import 'package:mealvana_endurance/features/subscription/domain/entitlement.dart';

Map<String, dynamic> _pro({
  required bool isActive,
  required String expires,
  String productId = 'me_pro_monthly',
  String periodType = 'NORMAL',
  String store = 'APP_STORE',
  bool? willRenew,
  String purchased = '2026-08-01T10:00:00Z',
}) => {
  'identifier': 'pro',
  'isActive': isActive,
  'willRenew': willRenew ?? isActive,
  'latestPurchaseDate': purchased,
  'originalPurchaseDate': purchased,
  'productIdentifier': productId,
  'isSandbox': true,
  'ownershipType': 'PURCHASED',
  'store': store,
  'periodType': periodType,
  'expirationDate': expires,
  'unsubscribeDetectedAt': (willRenew ?? isActive)
      ? null
      : '2026-08-20T10:00:00Z',
  'billingIssueDetectedAt': null,
  'verification': 'NOT_REQUESTED',
};

CustomerInfo _info({
  required Map<String, dynamic> all,
  required bool active,
  String requestDate = '2026-09-22T12:00:00Z',
}) {
  final sku = all.isEmpty ? null : all['pro']['productIdentifier'] as String;
  return CustomerInfo.fromJson({
    'entitlements': {
      'all': all,
      'active': active ? all : <String, dynamic>{},
      'verification': 'NOT_REQUESTED',
    },
    'allPurchaseDates': {if (all.isNotEmpty) sku!: '2026-08-01T10:00:00Z'},
    'activeSubscriptions': [if (active) sku!],
    'allPurchasedProductIdentifiers': [if (all.isNotEmpty) sku!],
    'nonSubscriptionTransactions': <dynamic>[],
    'firstSeen': '2026-08-01T09:00:00Z',
    'originalAppUserId': 'u-1',
    'allExpirationDates': {
      if (all.isNotEmpty) sku!: all['pro']['expirationDate'],
    },
    'requestDate': requestDate,
    'latestExpirationDate': all.isEmpty ? null : all['pro']['expirationDate'],
    'originalPurchaseDate': null,
    'originalApplicationVersion': null,
    'managementURL': null,
  });
}

/// When the fixtures above were fetched (their `requestDate`): before every
/// expiry here. Tests that run the real status controller pin its clock to
/// it, so the saved-copy grace (mp-679) never depends on the day the suite
/// runs.
final DateTime customerInfoFetchedAt = DateTime.utc(2026, 9, 22, 12);

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

/// `pro` in its free week on the monthly plan, ending 29 September; the
/// store will start charging then.
final CustomerInfo customerInfoTrial = _info(
  all: {
    'pro': _pro(
      isActive: true,
      expires: '2026-09-29T10:00:00Z',
      periodType: 'TRIAL',
    ),
  },
  active: true,
);

/// `pro` on the founding annual plan (mp-452), renewing 1 October 2027.
final CustomerInfo customerInfoFounding = _info(
  all: {
    'pro': _pro(
      isActive: true,
      expires: '2027-10-01T10:00:00Z',
      productId: 'me_pro_annual_founding',
    ),
  },
  active: true,
);

/// `pro` active until 1 November, cancelled: it will not renew.
final CustomerInfo customerInfoOpenCancelled = _info(
  all: {
    'pro': _pro(
      isActive: true,
      expires: '2026-11-01T10:00:00Z',
      willRenew: false,
    ),
  },
  active: true,
);

/// A Grant as RevenueCat reports it once `grant_entitlement` has run (the
/// grace run, `grace-claim`, `redeem-code`): the PROMOTIONAL store, product
/// `rc_promo_pro_custom` (every grant made with an end time reads so; checked
/// on the dev customer 2026-09-23), latest purchase the moment of the grant,
/// no renewal.
Map<String, dynamic> _grant({
  required String granted,
  required String expires,
}) => _pro(
  isActive: true,
  expires: expires,
  store: 'PROMOTIONAL',
  productId: 'rc_promo_pro_custom',
  willRenew: false,
  purchased: granted,
);

/// A giveaway Code's Grant: 365 days of `pro` from 22 September 2026. No
/// store page to manage.
final CustomerInfo customerInfoGranted = _info(
  all: {
    'pro': _grant(
      granted: '2026-09-22T10:00:00Z',
      expires: '2027-09-22T10:00:00Z',
    ),
  },
  active: true,
);

/// The Legacy grace month: 30 days of `pro` granted at the flip on
/// 1 October, ending 31 October.
final CustomerInfo customerInfoGraceGrant = _info(
  all: {
    'pro': _grant(
      granted: '2026-10-01T10:00:00Z',
      expires: '2026-10-31T10:00:00Z',
    ),
  },
  active: true,
);

/// The saved copy from Finding 07-002: a Test Store monthly period
/// 11:31:56-11:36:56 UTC on 24 September, fetched at 11:34:29 while it ran.
/// The SDK judged `isActive` at that fetch, so the copy still says active
/// after its own expiry until a fresh answer replaces it.
final CustomerInfo customerInfoSavedMonthly = _info(
  all: {'pro': _pro(isActive: true, expires: '2026-09-24T11:36:56Z')},
  active: true,
  requestDate: '2026-09-24T11:34:29Z',
);

/// RevenueCat's fresh answer once the renewal of [customerInfoSavedMonthly]
/// landed: the next period runs to 11:41:56.
final CustomerInfo customerInfoRenewedMonthly = _info(
  all: {'pro': _pro(isActive: true, expires: '2026-09-24T11:41:56Z')},
  active: true,
  requestDate: '2026-09-24T11:39:04Z',
);

/// No `pro`, ever.
final CustomerInfo customerInfoNever = _info(all: const {}, active: false);

/// The statuses the service maps each fixture to — what `fetchStatus` and
/// the CustomerInfo listener hand the status controller.
SubscriptionStatus statusOf(CustomerInfo info) =>
    SubscriptionService.statusFromCustomerInfo(info);
