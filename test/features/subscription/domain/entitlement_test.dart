/// Unit tests for the Pro entitlement domain model.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/subscription/domain/entitlement.dart';

void main() {
  group('Entitlement', () {
    test('pro key matches the RevenueCat / server identifier', () {
      expect(Entitlement.pro.key, 'pro');
    });
  });

  group('SubscriptionStatus.merge', () {
    const rc = SubscriptionStatus(
      active: true,
      source: SubscriptionSource.revenuecat,
    );
    const server = SubscriptionStatus(
      active: true,
      source: SubscriptionSource.server,
    );
    const internal = SubscriptionStatus(
      active: true,
      source: SubscriptionSource.internal,
    );

    test('first ACTIVE candidate wins, in the order given', () {
      expect(SubscriptionStatus.merge([rc, server, internal]), rc);
      expect(SubscriptionStatus.merge([null, server, internal]), server);
      expect(
        SubscriptionStatus.merge([SubscriptionStatus.none, null, internal]),
        internal,
      );
    });

    test('no active candidate → none (never an inactive row)', () {
      const inactiveWithProduct = SubscriptionStatus(
        active: false,
        source: SubscriptionSource.server,
        productId: 'mealvana_pro_monthly',
      );
      expect(
        SubscriptionStatus.merge([inactiveWithProduct, null]),
        SubscriptionStatus.none,
      );
      expect(SubscriptionStatus.merge(const []), SubscriptionStatus.none);
    });
  });

  group('SubscriptionStatus.isExpiredAt', () {
    test('no expiry is never expired', () {
      const s = SubscriptionStatus(active: true);
      expect(s.isExpiredAt(DateTime.utc(2099)), isFalse);
    });

    test('expiry in the past is expired; in the future is not', () {
      final s = SubscriptionStatus(
        active: true,
        expiresAt: DateTime.utc(2026, 9, 1, 12),
      );
      expect(s.isExpiredAt(DateTime.utc(2026, 9, 1, 12, 0, 1)), isTrue);
      expect(s.isExpiredAt(DateTime.utc(2026, 9, 1, 11)), isFalse);
    });
  });

  test('value equality', () {
    final a = SubscriptionStatus(
      active: true,
      expiresAt: DateTime.utc(2026, 10),
      source: SubscriptionSource.server,
      productId: 'x',
    );
    final b = a.copyWith();
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a.copyWith(active: false), isNot(a));
  });
}
