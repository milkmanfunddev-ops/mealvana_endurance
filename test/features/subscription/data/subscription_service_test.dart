/// Unit tests for [SubscriptionService].
///
/// The RevenueCat SDK cannot run in dart:test, so — as with
/// revenuecat_service_test.dart — these cover the logic layer: the pure
/// EntitlementInfo → SubscriptionStatus and StoreProduct → IntroOffer
/// mappings, the store fallback for "Manage subscription", and the
/// not-configured guards that keep every method a safe no-op.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:mealvana_endurance/features/ai_credits/data/revenuecat_service.dart';
import 'package:mealvana_endurance/features/subscription/data/subscription_service.dart';
import 'package:mealvana_endurance/features/subscription/domain/entitlement.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';

class _MockRevenueCatService extends Mock implements RevenueCatService {}

class _FakeEntitlement extends Fake implements EntitlementInfo {
  _FakeEntitlement({
    this.isActive = true,
    this.expirationDate,
    this.periodType = PeriodType.normal,
    this.productIdentifier = 'mealvana_pro_monthly',
    this.willRenew = true,
  });

  @override
  final bool isActive;
  @override
  final String? expirationDate;
  @override
  final PeriodType periodType;
  @override
  final String productIdentifier;
  @override
  final bool willRenew;
}

class _FakeOfferings extends Fake implements Offerings {
  _FakeOfferings({this.byId = const {}, this.current});

  final Map<String, Offering> byId;
  @override
  final Offering? current;
  @override
  Map<String, Offering> get all => byId;
  @override
  Offering? getOffering(String identifier) => byId[identifier];
}

class _FakeOffering extends Fake implements Offering {
  _FakeOffering(this.identifier);
  @override
  final String identifier;
}

class _FakeStoreProduct extends Fake implements StoreProduct {
  _FakeStoreProduct({this.introductoryPrice});
  @override
  final String identifier = 'mealvana_pro_monthly';
  @override
  final IntroductoryPrice? introductoryPrice;
}

void main() {
  late _MockRevenueCatService rc;
  late SubscriptionService service;

  setUp(() {
    rc = _MockRevenueCatService();
    service = SubscriptionService(
      revenueCat: rc,
      sentry: const NoopSentryReporter(),
    );
  });

  group('statusFromEntitlement', () {
    test('null → none', () {
      expect(
        SubscriptionService.statusFromEntitlement(null),
        SubscriptionStatus.none,
      );
    });

    test('inactive → none', () {
      expect(
        SubscriptionService.statusFromEntitlement(
          _FakeEntitlement(isActive: false),
        ),
        SubscriptionStatus.none,
      );
    });

    test('active → revenuecat source with UTC expiry', () {
      final s = SubscriptionService.statusFromEntitlement(
        _FakeEntitlement(expirationDate: '2026-10-01T00:00:00Z'),
      );
      expect(s.active, isTrue);
      expect(s.source, SubscriptionSource.revenuecat);
      expect(s.expiresAt, DateTime.utc(2026, 10, 1));
      expect(s.isTrial, isFalse);
    });

    test('trial and intro periods are marked as trial', () {
      expect(
        SubscriptionService.statusFromEntitlement(
          _FakeEntitlement(periodType: PeriodType.trial),
        ).isTrial,
        isTrue,
      );
      expect(
        SubscriptionService.statusFromEntitlement(
          _FakeEntitlement(periodType: PeriodType.intro),
        ).isTrial,
        isTrue,
      );
    });

    test('a cancelled trial is still active but will not renew (mp-456)', () {
      final s = SubscriptionService.statusFromEntitlement(
        _FakeEntitlement(periodType: PeriodType.trial, willRenew: false),
      );
      expect(s.active, isTrue);
      expect(s.isTrial, isTrue);
      expect(s.willRenew, isFalse);
      expect(
        SubscriptionService.statusFromEntitlement(_FakeEntitlement()).willRenew,
        isTrue,
      );
    });

    test('carries the granting product id', () {
      final s = SubscriptionService.statusFromEntitlement(
        _FakeEntitlement(productIdentifier: 'mealvana_pro_annual_prod'),
      );
      expect(s.productId, 'mealvana_pro_annual_prod');
    });
  });

  group('introOfferOf (the store price is the source, mp-279)', () {
    test("Apple's free week → seven free days", () {
      final product = _FakeStoreProduct(
        introductoryPrice: const IntroductoryPrice(
          0,
          r'$0.00',
          'P1W',
          1,
          PeriodUnit.week,
          1,
        ),
      );
      expect(
        SubscriptionService.introOfferOf(product),
        const IntroOffer(freeDays: 7),
      );
    });

    test("Google's P7D → seven free days", () {
      final product = _FakeStoreProduct(
        introductoryPrice: const IntroductoryPrice(
          0,
          r'$0.00',
          'P7D',
          1,
          PeriodUnit.day,
          7,
        ),
      );
      expect(
        SubscriptionService.introOfferOf(product),
        const IntroOffer(freeDays: 7),
      );
    });

    test('no introductory price → no offer', () {
      expect(SubscriptionService.introOfferOf(_FakeStoreProduct()), isNull);
    });

    test('a paid introductory price is not a free offer', () {
      final product = _FakeStoreProduct(
        introductoryPrice: const IntroductoryPrice(
          4.99,
          r'$4.99',
          'P1M',
          1,
          PeriodUnit.month,
          1,
        ),
      );
      expect(SubscriptionService.introOfferOf(product), isNull);
    });
  });

  group('storeSubscriptionsUrl (Manage subscription fallback)', () {
    test('iOS → the App Store subscriptions page', () {
      expect(
        SubscriptionService.storeSubscriptionsUrl(TargetPlatform.iOS),
        Uri.parse(kAppleSubscriptionsUrl),
      );
    });

    test('Android → the Play subscriptions page', () {
      expect(
        SubscriptionService.storeSubscriptionsUrl(TargetPlatform.android),
        Uri.parse(kGoogleSubscriptionsUrl),
      );
    });

    test('elsewhere → nothing to open', () {
      expect(
        SubscriptionService.storeSubscriptionsUrl(TargetPlatform.linux),
        isNull,
      );
    });
  });

  group('not-configured guards (SDK absent in tests)', () {
    test('isAvailable is false before configure', () {
      expect(service.isAvailable, isFalse);
    });

    test('fetchStatus returns null without touching the SDK', () async {
      expect(await service.fetchStatus(), isNull);
    });

    test('currentAppUserId is null: no cache to trust', () async {
      expect(await service.currentAppUserId(), isNull);
    });

    test('introIneligibleProductIds is empty (nobody is refused the '
        'offer on a guess)', () async {
      expect(await service.introIneligibleProductIds(['a']), isEmpty);
    });

    test('restore returns null without touching the SDK', () async {
      expect(await service.restore(), isNull);
    });

    test('logIn delegates to RevenueCatService', () async {
      when(() => rc.logIn(any())).thenAnswer((_) async {});
      await service.logIn('user-1');
      verify(() => rc.logIn('user-1')).called(1);
    });
  });

  group('fetchOfferings', () {
    test('null offerings → null', () async {
      when(() => rc.getOfferings()).thenAnswer((_) async => null);
      expect(await service.fetchOfferings(), isNull);
    });

    test('hands back every offering with the current one marked', () async {
      final def = _FakeOffering('default');
      final founding = _FakeOffering('founding');
      final offerings = _FakeOfferings(
        byId: {'default': def, 'founding': founding},
        current: founding,
      );
      when(() => rc.getOfferings()).thenAnswer((_) async => offerings);
      expect(await service.fetchOfferings(), same(offerings));
    });

    test('offering ids match the RevenueCat dashboard', () {
      expect(kProOfferingId, 'default');
      expect(kFoundingOfferingId, 'founding');
    });
  });
}
