/// Unit tests for [SubscriptionService].
///
/// The RevenueCat SDK cannot run in dart:test, so — as with
/// revenuecat_service_test.dart — these cover the logic layer: the pure
/// EntitlementInfo → SubscriptionStatus mapping and the not-configured guards
/// that keep every method a safe no-op.
library;

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
  });

  @override
  final bool isActive;
  @override
  final String? expirationDate;
  @override
  final PeriodType periodType;
  @override
  final String productIdentifier;
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

    test('inactive entitlement → none', () {
      expect(
        SubscriptionService.statusFromEntitlement(
          _FakeEntitlement(isActive: false),
        ),
        SubscriptionStatus.none,
      );
    });

    test(
      'active normal entitlement → active, revenuecat, expiry parsed to UTC',
      () {
        final s = SubscriptionService.statusFromEntitlement(
          _FakeEntitlement(expirationDate: '2026-10-01T12:00:00Z'),
        );
        expect(s.active, isTrue);
        expect(s.source, SubscriptionSource.revenuecat);
        expect(s.expiresAt, DateTime.utc(2026, 10, 1, 12));
        expect(s.isTrial, isFalse);
        expect(s.productId, 'mealvana_pro_monthly');
      },
    );

    test('trial and intro periods flag isTrial', () {
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

    test('missing expiry → open-ended (null), still active', () {
      final s = SubscriptionService.statusFromEntitlement(_FakeEntitlement());
      expect(s.active, isTrue);
      expect(s.expiresAt, isNull);
    });

    test('carries the granting product id', () {
      final s = SubscriptionService.statusFromEntitlement(
        _FakeEntitlement(productIdentifier: 'mealvana_pro_annual_prod'),
      );
      expect(s.productId, 'mealvana_pro_annual_prod');
    });
  });

  group('not-configured guards (SDK absent in tests)', () {
    test('isAvailable is false before configure', () {
      expect(service.isAvailable, isFalse);
    });

    test('fetchStatus returns null without touching the SDK', () async {
      expect(await service.fetchStatus(), isNull);
    });

    test('restore returns null without touching the SDK', () async {
      expect(await service.restore(), isNull);
    });
  });

  group('fetchProOffering', () {
    test('null offerings → null', () async {
      when(() => rc.getOfferings()).thenAnswer((_) async => null);
      expect(await service.fetchProOffering(), isNull);
    });

    test('prefers the `default` offering', () async {
      final def = _FakeOffering('default');
      final other = _FakeOffering('other');
      when(() => rc.getOfferings()).thenAnswer(
        (_) async => _FakeOfferings(
          byId: {'default': def, 'other': other},
          current: other,
        ),
      );
      expect(await service.fetchProOffering(), same(def));
    });

    test('falls back to `current` when `default` is missing', () async {
      final cur = _FakeOffering('renamed');
      when(() => rc.getOfferings()).thenAnswer(
        (_) async => _FakeOfferings(byId: {'renamed': cur}, current: cur),
      );
      expect(await service.fetchProOffering(), same(cur));
    });

    test('kProOfferingId is `default` (matches the RevenueCat dashboard)', () {
      expect(kProOfferingId, 'default');
    });
  });
}
