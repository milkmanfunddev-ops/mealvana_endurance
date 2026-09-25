/// Unit tests for the subscription domain model.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/subscription/domain/entitlement.dart';

void main() {
  group('Entitlement', () {
    test('pro key matches the RevenueCat identifier', () {
      expect(Entitlement.pro.key, 'pro');
    });
  });

  group('SubscriptionStatus', () {
    test('none is inactive with no source', () {
      expect(SubscriptionStatus.none.active, isFalse);
      expect(SubscriptionStatus.none.source, SubscriptionSource.none);
    });

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

    group('countedAt: the saved copy past its own expiry (mp-679)', () {
      final expiry = DateTime.utc(2026, 9, 24, 11, 36, 56);
      final saved = SubscriptionStatus(
        active: true,
        expiresAt: expiry,
        source: SubscriptionSource.revenuecat,
        productId: 'me_pro_monthly',
      );

      test('the grace is the server\'s RENEWAL_GRACE_MS, 15 minutes', () {
        expect(kRenewalGrace, const Duration(minutes: 15));
      });

      test('2 minutes past expiry still counts as it is', () {
        final now = expiry.add(const Duration(minutes: 2));
        expect(saved.countedAt(now), saved);
      });

      test('16 minutes past expiry counts as closed, held once', () {
        final c = saved.countedAt(expiry.add(const Duration(minutes: 16)));
        expect(c.active, isFalse);
        expect(c.hadPro, isTrue);
        expect(c.source, SubscriptionSource.none);
        expect(c.expiresAt, expiry);
        expect(c.productId, 'me_pro_monthly');
      });

      test('exactly at the end of the grace is closed, as on the server', () {
        expect(saved.countedAt(expiry.add(kRenewalGrace)).active, isFalse);
      });

      test(
        'a cancelled copy gets no grace: closed just past its expiry, '
        'as the server (isEntitled grants the grace only when it renews)',
        () {
          final cancelled = saved.copyWith(willRenew: false);
          final now = expiry.add(const Duration(minutes: 2));
          expect(cancelled.countedAt(now).active, isFalse);
          expect(
            cancelled.countedAt(expiry.subtract(const Duration(seconds: 1))),
            cancelled,
          );
        },
      );

      test('no expiry, or an inactive answer, counts as it is', () {
        const open = SubscriptionStatus(active: true);
        expect(open.countedAt(DateTime.utc(2099)), open);
        final lapsed = SubscriptionStatus(active: false, expiresAt: expiry);
        expect(lapsed.countedAt(DateTime.utc(2099)), lapsed);
      });

      group('the grace is asked about first (ticket 105, Finding 87-006)', () {
        test('in the grace: a renewing copy past its expiry, not past the '
            'grace', () {
          expect(saved.inRenewalGraceAt(expiry), isTrue);
          expect(
            saved.inRenewalGraceAt(expiry.add(const Duration(minutes: 2))),
            isTrue,
          );
          expect(
            saved.inRenewalGraceAt(expiry.subtract(const Duration(seconds: 1))),
            isFalse,
          );
          expect(saved.inRenewalGraceAt(expiry.add(kRenewalGrace)), isFalse);
        });

        test('a cancelled or inactive copy has no grace to ask about', () {
          final now = expiry.add(const Duration(minutes: 2));
          expect(
            saved.copyWith(willRenew: false).inRenewalGraceAt(now),
            isFalse,
          );
          expect(saved.copyWith(active: false).inRenewalGraceAt(now), isFalse);
        });

        test('a renewing copy is looked at again at its expiry, then at the '
            'end of the grace', () {
          final before = expiry.subtract(const Duration(minutes: 5));
          expect(saved.nextLookAt(before), expiry);
          expect(saved.nextLookAt(expiry), expiry.add(kRenewalGrace));
        });

        test('a cancelled copy is looked at again at its expiry; a closed or '
            'open-ended one never', () {
          final before = expiry.subtract(const Duration(minutes: 5));
          expect(saved.copyWith(willRenew: false).nextLookAt(before), expiry);
          expect(
            SubscriptionStatus(
              active: false,
              expiresAt: expiry,
            ).nextLookAt(before),
            isNull,
          );
          expect(
            const SubscriptionStatus(active: true).nextLookAt(before),
            isNull,
          );
        });
      });
    });

    test('value equality', () {
      final a = SubscriptionStatus(
        active: true,
        expiresAt: DateTime.utc(2026, 10),
        source: SubscriptionSource.revenuecat,
        productId: 'x',
      );
      final b = a.copyWith();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.copyWith(active: false), isNot(a));
    });
  });

  group('IntroOffer.daysFor', () {
    test("Apple's WEEK × 1 is the seven free days the copy promises", () {
      expect(IntroOffer.daysFor(unit: 'WEEK', count: 1), 7);
      expect(IntroOffer.daysFor(unit: 'week', count: 1), 7);
    });

    test('days pass through; months and years use the store convention', () {
      expect(IntroOffer.daysFor(unit: 'DAY', count: 7), 7);
      expect(IntroOffer.daysFor(unit: 'DAY', count: 3), 3);
      expect(IntroOffer.daysFor(unit: 'MONTH', count: 1), 30);
      expect(IntroOffer.daysFor(unit: 'YEAR', count: 1), 365);
    });

    test('an unknown unit or a non-positive count is no offer', () {
      expect(IntroOffer.daysFor(unit: 'unknown', count: 1), isNull);
      expect(IntroOffer.daysFor(unit: 'DAY', count: 0), isNull);
    });

    test('value equality', () {
      expect(const IntroOffer(freeDays: 7), const IntroOffer(freeDays: 7));
      expect(
        const IntroOffer(freeDays: 7),
        isNot(const IntroOffer(freeDays: 14)),
      );
    });
  });
}
