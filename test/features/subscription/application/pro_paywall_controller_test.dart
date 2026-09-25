/// Seam tests for [ProPaywallController] through the real notifier
/// (docs/test/README.md: every controller write path gets one).
///
/// `paywallPlans` reads RevenueCat's Current Offering (mp-453), fed the
/// SDK-decoded offerings of `offerings_fixtures.dart`.
///
/// `buy` and `restore` are the two writes the paywall makes (ticket 19,
/// mp-279/mp-280): both re-assert the RevenueCat identity, call the store,
/// and refresh the one status provider the router reads.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/content/domain/content_keys.dart';
import 'package:mealvana_endurance/features/subscription/application/pro_paywall_controller.dart';
import 'package:mealvana_endurance/features/subscription/application/subscription_status_provider.dart';
import 'package:mealvana_endurance/features/subscription/application/trial_reminder_service.dart';
import 'package:mealvana_endurance/features/subscription/data/subscription_service.dart';
import 'package:mealvana_endurance/features/subscription/data/user_entitlements_repository.dart';
import 'package:mealvana_endurance/features/subscription/domain/entitlement.dart';
import 'package:mealvana_endurance/features/subscription/domain/trial_reminder.dart';
import 'package:mealvana_endurance/shared/services/notification_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';

import '../../meal_planning/presentation/helpers/test_content.dart';
import '../offerings_fixtures.dart';

class _MockSubscriptionService extends Mock implements SubscriptionService {}

class _MockRepository extends Mock implements UserEntitlementsRepository {}

class _MockSentry extends Mock implements SentryReporter {}

class _FakeStoreProduct extends Fake implements StoreProduct {
  @override
  String get identifier => 'mealvana_pro_monthly';
}

class _FakePackage extends Fake implements Package {
  @override
  String get identifier => r'$rc_monthly';
  @override
  StoreProduct get storeProduct => _FakeStoreProduct();
}

/// Records what would reach the platform plugin.
class _FakeScheduler implements LocalNotificationScheduler {
  final scheduled =
      <({int id, DateTime when, String title, String body, String? payload})>[];
  final cancelled = <int>[];
  bool permitted = true;
  Object? failWith;

  @override
  Future<bool> scheduleOnce({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (failWith != null) throw failWith!;
    if (!permitted) return false;
    scheduled.add((
      id: id,
      when: when,
      title: title,
      body: body,
      payload: payload,
    ));
    return true;
  }

  @override
  Future<void> cancel(int id) async => cancelled.add(id);
}

/// RevenueCat's `pro` entitlement as its native bridge hands it to
/// `EntitlementInfo.fromJson`, mapped by the service's own mapping — the
/// producer side of the status the controller reads after a purchase.
SubscriptionStatus _statusFromRevenueCat({
  required String periodType,
  required DateTime expiresAt,
  String productId = 'me_pro_monthly',
  bool willRenew = true,
}) => SubscriptionService.statusFromEntitlement(
  EntitlementInfo.fromJson({
    'identifier': 'pro',
    'isActive': true,
    'willRenew': willRenew,
    'latestPurchaseDate': '2026-09-22T14:30:00Z',
    'originalPurchaseDate': '2026-09-22T14:30:00Z',
    'productIdentifier': productId,
    'isSandbox': true,
    'ownershipType': 'PURCHASED',
    'store': 'APP_STORE',
    'periodType': periodType,
    'expirationDate': expiresAt.toUtc().toIso8601String(),
    'unsubscribeDetectedAt': null,
    'billingIssueDetectedAt': null,
    'verification': 'NOT_REQUESTED',
  }),
);

const _userId = '45a54f25-47c6-4730-8b21-78ea1df36bea';

final _rcActive = SubscriptionStatus(
  active: true,
  source: SubscriptionSource.revenuecat,
  expiresAt: DateTime.utc(2026, 10, 1),
  productId: 'mealvana_pro_monthly',
);

void main() {
  late _MockSubscriptionService service;
  late _MockRepository repo;
  late _MockSentry sentry;
  late _FakeScheduler scheduler;
  final pkg = _FakePackage();
  final content = loadDefaultContent();
  // The purchase moment: Tuesday 22 September 2026, 15:30 local.
  final purchasedAt = DateTime(2026, 9, 22, 15, 30);

  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
    registerFallbackValue(_FakePackage());
  });

  setUp(() {
    service = _MockSubscriptionService();
    repo = _MockRepository();
    sentry = _MockSentry();
    scheduler = _FakeScheduler();

    when(() => repo.currentUserId).thenReturn(_userId);
    when(() => repo.isAnonymousUser).thenReturn(false);
    when(
      () => repo.authUserIdChanges,
    ).thenAnswer((_) => const Stream<String?>.empty());
    when(() => service.setStatusListener(any())).thenReturn(null);
    when(() => service.currentAppUserId()).thenAnswer((_) async => _userId);
    when(() => service.logIn(any())).thenAnswer((_) async {});
    when(
      () => service.fetchStatus(),
    ).thenAnswer((_) async => SubscriptionStatus.none);
    when(() => service.purchase(any())).thenAnswer((_) async => true);
    when(() => service.restore()).thenAnswer((_) async => null);
    when(
      () => sentry.reportCriticalError(
        any(),
        stackTrace: any(named: 'stackTrace'),
        context: any(named: 'context'),
        tags: any(named: 'tags'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => sentry.addBreadcrumb(
        message: any(named: 'message'),
        category: any(named: 'category'),
        data: any(named: 'data'),
      ),
    ).thenReturn(null);
  });

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        subscriptionServiceProvider.overrideWithValue(service),
        userEntitlementsRepositoryProvider.overrideWithValue(repo),
        sentryReporterProvider.overrideWithValue(sentry),
        entitlementAnswerTimeoutProvider.overrideWithValue(
          const Duration(milliseconds: 60),
        ),
        localNotificationSchedulerProvider.overrideWithValue(scheduler),
        contentServiceProvider.overrideWith(
          (ref) => TestContentService(ref, content),
        ),
        trialReminderClockProvider.overrideWithValue(() => purchasedAt),
        subscriptionClockProvider.overrideWithValue(() => purchasedAt),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('paywallPlans — the Current Offering (mp-453)', () {
    setUp(() {
      when(
        () => service.introIneligibleProductIds(any()),
      ).thenAnswer((_) async => const {});
    });

    test('with `default` current, the plans are the default packages at '
        'their plain prices, nothing struck through', () async {
      when(
        () => service.fetchOfferings(),
      ).thenAnswer((_) async => offeringsFixture(current: 'default'));
      final plans = await container().read(paywallPlansProvider.future);

      expect(plans.isFounding, isFalse);
      expect(plans.monthly!.storeProduct.identifier, 'me_pro_monthly');
      expect(plans.annual!.storeProduct.identifier, 'me_pro_annual');
      expect(plans.monthly!.storeProduct.priceString, r'$24.99');
      expect(plans.annual!.storeProduct.priceString, r'$199.99');
      expect(plans.regularPriceFor(plans.monthly!), isNull);
      expect(plans.regularPriceFor(plans.annual!), isNull);
      expect(plans.introOfferFor(plans.monthly!)?.freeDays, 7);
    });

    test(
      'with `founding` current, each plan is the founding package and '
      'carries the `default` price of the same slot to strike through',
      () async {
        when(
          () => service.fetchOfferings(),
        ).thenAnswer((_) async => offeringsFixture(current: 'founding'));
        final plans = await container().read(paywallPlansProvider.future);

        expect(plans.isFounding, isTrue);
        expect(
          plans.monthly!.storeProduct.identifier,
          'me_pro_monthly_founding',
        );
        expect(plans.annual!.storeProduct.identifier, 'me_pro_annual_founding');
        expect(plans.monthly!.storeProduct.priceString, r'$12.49');
        expect(plans.annual!.storeProduct.priceString, r'$99.99');
        expect(plans.regularPriceFor(plans.monthly!), r'$24.99');
        expect(plans.regularPriceFor(plans.annual!), r'$199.99');
        expect(plans.introOfferFor(plans.annual!)?.freeDays, 7);
      },
    );

    test('intro eligibility is asked for the packages actually sold', () async {
      when(
        () => service.fetchOfferings(),
      ).thenAnswer((_) async => offeringsFixture(current: 'founding'));
      when(
        () => service.introIneligibleProductIds(any()),
      ).thenAnswer((_) async => const {'me_pro_monthly_founding'});
      final plans = await container().read(paywallPlansProvider.future);

      verify(
        () => service.introIneligibleProductIds([
          'me_pro_monthly_founding',
          'me_pro_annual_founding',
        ]),
      ).called(1);
      expect(plans.introOfferFor(plans.monthly!), isNull);
      expect(plans.introOfferFor(plans.annual!)?.freeDays, 7);
    });

    test('no offering marked current falls back to `default`', () async {
      when(
        () => service.fetchOfferings(),
      ).thenAnswer((_) async => offeringsFixture(current: null));
      final plans = await container().read(paywallPlansProvider.future);

      expect(plans.isFounding, isFalse);
      expect(plans.monthly!.storeProduct.identifier, 'me_pro_monthly');
    });

    test('no offerings at all is the empty plans', () async {
      when(() => service.fetchOfferings()).thenAnswer((_) async => null);
      final plans = await container().read(paywallPlansProvider.future);
      expect(plans.isEmpty, isTrue);
      expect(plans.isFounding, isFalse);
    });
  });

  group('the annual plan beside the monthly one (mp-493 §3)', () {
    final defaults = offeringFixture('default');
    final founding = offeringFixture('founding');

    test('default: save 33% and \$16.67 a month, from the store prices', () {
      final plans = PaywallPlans(
        monthly: defaults.monthly,
        annual: defaults.annual,
      );
      expect(plans.annualSavingPercent, 33);
      expect(plans.annualPerMonthPrice(), r'$16.67');
    });

    test('founding: the founding prices set both, \$8.33 a month', () {
      final plans = PaywallPlans(
        monthly: founding.monthly,
        annual: founding.annual,
        isFounding: true,
        regularMonthly: defaults.monthly,
        regularAnnual: defaults.annual,
      );
      expect(plans.annualSavingPercent, 33);
      expect(plans.annualPerMonthPrice(), r'$8.33');
    });

    test('no monthly plan: no saving to claim; no annual: neither', () {
      expect(PaywallPlans(annual: defaults.annual).annualSavingPercent, isNull);
      expect(
        PaywallPlans(annual: defaults.annual).annualPerMonthPrice(),
        r'$16.67',
      );
      expect(
        PaywallPlans(monthly: defaults.monthly).annualSavingPercent,
        isNull,
      );
      expect(
        PaywallPlans(monthly: defaults.monthly).annualPerMonthPrice(),
        isNull,
      );
    });
  });

  group('paywallHasSubscription (mp-494 §1)', () {
    test('answers from the store record', () async {
      when(
        () => service.hasStoreSubscriptionOnRecord(),
      ).thenAnswer((_) async => true);
      expect(
        await container().read(paywallHasSubscriptionProvider.future),
        isTrue,
      );
    });

    test('a restore asks again', () async {
      var answers = 0;
      when(() => service.hasStoreSubscriptionOnRecord()).thenAnswer((_) async {
        answers += 1;
        return answers > 1;
      });
      final c = container();
      expect(await c.read(paywallHasSubscriptionProvider.future), isFalse);
      await c.read(proPaywallControllerProvider.notifier).restore();
      expect(await c.read(paywallHasSubscriptionProvider.future), isTrue);
    });
  });

  group('buy', () {
    test('a confirmed purchase re-asserts the identity, refreshes the status '
        'and reports activated once the SDK says active', () async {
      // Locked before the purchase, active on the refresh after it.
      var calls = 0;
      when(() => service.fetchStatus()).thenAnswer((_) async {
        calls += 1;
        return calls == 1 ? SubscriptionStatus.none : _rcActive;
      });
      final c = container();
      expect(await c.read(subscriptionStatusProvider.future), isNot(_rcActive));

      final outcome = await c
          .read(proPaywallControllerProvider.notifier)
          .buy(pkg);

      expect(outcome, ProPurchaseOutcome.activated);
      verifyInOrder([
        () => service.logIn(_userId),
        () => service.purchase(pkg),
      ]);
      expect(c.read(subscriptionStatusProvider).asData!.value.active, isTrue);
    });

    // 05-004: the router has the Gate open before the paywall is gone; an
    // idle controller in that window re-enables Continue and a second tap
    // starts a second purchase.
    test('after an activated purchase the paywall stays busy until the '
        'router moves on', () async {
      var calls = 0;
      when(() => service.fetchStatus()).thenAnswer((_) async {
        calls += 1;
        return calls == 1 ? SubscriptionStatus.none : _rcActive;
      });
      final c = container();
      await c.read(subscriptionStatusProvider.future);

      final outcome = await c
          .read(proPaywallControllerProvider.notifier)
          .buy(pkg);

      expect(outcome, ProPurchaseOutcome.activated);
      expect(c.read(proPaywallControllerProvider), isA<AsyncLoading<void>>());
      // A later push that keeps the account open changes nothing.
      await c.read(subscriptionStatusProvider.notifier).refresh();
      expect(c.read(proPaywallControllerProvider), isA<AsyncLoading<void>>());
    });

    test('the hold lets go once the account is closed again, so a later '
        'paywall can sell', () async {
      var active = false;
      when(
        () => service.fetchStatus(),
      ).thenAnswer((_) async => active ? _rcActive : SubscriptionStatus.none);
      when(() => service.purchase(any())).thenAnswer((_) async {
        active = true;
        return true;
      });
      final c = container();
      await c.read(subscriptionStatusProvider.future);
      await c.read(proPaywallControllerProvider.notifier).buy(pkg);
      expect(c.read(proPaywallControllerProvider), isA<AsyncLoading<void>>());

      // The subscription lapses (or another account signs in).
      active = false;
      await c.read(subscriptionStatusProvider.notifier).refresh();

      expect(c.read(proPaywallControllerProvider), isA<AsyncData<void>>());
    });

    test(
      'a confirmed purchase the SDK has not caught up with is pending',
      () async {
        final c = container();
        final outcome = await c
            .read(proPaywallControllerProvider.notifier)
            .buy(pkg);
        expect(outcome, ProPurchaseOutcome.purchasedPending);
        expect(
          c.read(subscriptionStatusProvider).asData!.value.active,
          isFalse,
        );
        // Nothing opens the app yet, so the paywall stays usable.
        expect(c.read(proPaywallControllerProvider), isA<AsyncData<void>>());
      },
    );

    test('a dismissed store sheet is cancelled, not an error', () async {
      when(() => service.purchase(any())).thenAnswer((_) async => false);
      final c = container();
      final outcome = await c
          .read(proPaywallControllerProvider.notifier)
          .buy(pkg);
      expect(outcome, ProPurchaseOutcome.cancelled);
      expect(c.read(proPaywallControllerProvider), isA<AsyncData<void>>());
      verifyNever(
        () => sentry.reportCriticalError(
          any(),
          stackTrace: any(named: 'stackTrace'),
          context: any(named: 'context'),
          tags: any(named: 'tags'),
        ),
      );
    });

    test(
      'a store failure is failed, reported, and leaves the app locked',
      () async {
        when(() => service.purchase(any())).thenThrow(StateError('store down'));
        final c = container();
        final outcome = await c
            .read(proPaywallControllerProvider.notifier)
            .buy(pkg);
        expect(outcome, ProPurchaseOutcome.failed);
        expect(c.read(proPaywallControllerProvider), isA<AsyncError<void>>());
        verify(
          () => sentry.reportCriticalError(
            any(),
            stackTrace: any(named: 'stackTrace'),
            context: 'subscription',
            tags: any(named: 'tags'),
          ),
        ).called(1);
        expect(
          await c.read(subscriptionStatusProvider.future),
          SubscriptionStatus.none,
        );
      },
    );

    test('nobody signed in refuses before touching the store', () async {
      when(() => repo.currentUserId).thenReturn(null);
      final c = container();
      final outcome = await c
          .read(proPaywallControllerProvider.notifier)
          .buy(pkg);
      expect(outcome, ProPurchaseOutcome.notSignedIn);
      verifyNever(() => service.purchase(any()));
      verifyNever(() => service.logIn(any()));
    });

    test('an anonymous session must make an account first', () async {
      when(() => repo.isAnonymousUser).thenReturn(true);
      final c = container();
      final outcome = await c
          .read(proPaywallControllerProvider.notifier)
          .buy(pkg);
      expect(outcome, ProPurchaseOutcome.requiresAccount);
      verifyNever(() => service.purchase(any()));
    });
  });

  group('the day-five reminder (mp-456)', () {
    final plans = offeringFixture('default');
    final monthly = plans.monthly!;
    final annual = plans.annual!;
    // A seven-day trial from the purchase moment ends Tuesday 29th at 15:30.
    final trialEnds = DateTime(2026, 9, 29, 15, 30);

    /// Locked before the purchase, [after] on the refresh after it.
    void statusAfterPurchase(SubscriptionStatus after) {
      var calls = 0;
      when(() => service.fetchStatus()).thenAnswer((_) async {
        calls += 1;
        return calls == 1 ? SubscriptionStatus.none : after;
      });
    }

    test('a purchase that starts a trial schedules one notification at '
        '10:00 local two days before it ends, with the price after', () async {
      statusAfterPurchase(
        _statusFromRevenueCat(periodType: 'TRIAL', expiresAt: trialEnds),
      );
      final c = container();
      await c.read(subscriptionStatusProvider.future);

      final outcome = await c
          .read(proPaywallControllerProvider.notifier)
          .buy(monthly);

      expect(outcome, ProPurchaseOutcome.activated);
      expect(scheduler.scheduled, hasLength(1));
      final n = scheduler.scheduled.single;
      expect(n.id, TrialReminder.notificationId);
      expect(n.when, DateTime(2026, 9, 27, 10));
      expect(n.payload, TrialReminder.payload);
      // The text is the content system's, with the store's price in it.
      expect(n.title, content[ContentKeys.paywallTrialReminderTitle]);
      expect(
        n.body,
        ContentKeys.format(
          content[ContentKeys.paywallTrialReminderBodyMonthly]!,
          {'price': r'$24.99'},
        ),
      );
      expect(n.body, contains(r'$24.99 a month'));
    });

    test('the annual plan says the annual price after', () async {
      statusAfterPurchase(
        _statusFromRevenueCat(
          periodType: 'TRIAL',
          expiresAt: trialEnds,
          productId: 'me_pro_annual',
        ),
      );
      final c = container();
      await c.read(subscriptionStatusProvider.future);
      await c.read(proPaywallControllerProvider.notifier).buy(annual);

      expect(
        scheduler.scheduled.single.body,
        ContentKeys.format(
          content[ContentKeys.paywallTrialReminderBodyAnnual]!,
          {'price': r'$199.99'},
        ),
      );
    });

    test('a purchase with no trial schedules nothing', () async {
      statusAfterPurchase(
        _statusFromRevenueCat(
          periodType: 'NORMAL',
          expiresAt: DateTime(2026, 10, 22, 15, 30),
        ),
      );
      final c = container();
      await c.read(subscriptionStatusProvider.future);
      final outcome = await c
          .read(proPaywallControllerProvider.notifier)
          .buy(monthly);

      expect(outcome, ProPurchaseOutcome.activated);
      expect(scheduler.scheduled, isEmpty);
    });

    test('a dismissed store sheet schedules nothing', () async {
      when(() => service.purchase(any())).thenAnswer((_) async => false);
      await container()
          .read(proPaywallControllerProvider.notifier)
          .buy(monthly);
      expect(scheduler.scheduled, isEmpty);
    });

    test('a trial too short to remind about schedules nothing', () async {
      // Ends tomorrow: 10:00 two days before is already past.
      statusAfterPurchase(
        _statusFromRevenueCat(
          periodType: 'TRIAL',
          expiresAt: DateTime(2026, 9, 23, 15, 30),
        ),
      );
      final c = container();
      await c.read(subscriptionStatusProvider.future);
      await c.read(proPaywallControllerProvider.notifier).buy(monthly);
      expect(scheduler.scheduled, isEmpty);
    });

    test(
      'a reminder that cannot be scheduled never fails the purchase',
      () async {
        statusAfterPurchase(
          _statusFromRevenueCat(periodType: 'TRIAL', expiresAt: trialEnds),
        );
        scheduler.failWith = StateError('plugin missing');
        final c = container();
        await c.read(subscriptionStatusProvider.future);
        final outcome = await c
            .read(proPaywallControllerProvider.notifier)
            .buy(monthly);

        expect(outcome, ProPurchaseOutcome.activated);
        // Not an error: the paywall holds busy for the open Gate (05-004).
        expect(c.read(proPaywallControllerProvider), isA<AsyncLoading<void>>());
      },
    );
  });

  group('restore', () {
    test('restore re-asserts the identity, restores through the store, and '
        'answers with whether the app is unlocked now', () async {
      var calls = 0;
      when(() => service.fetchStatus()).thenAnswer((_) async {
        calls += 1;
        return calls == 1 ? SubscriptionStatus.none : _rcActive;
      });
      final c = container();
      await c.read(subscriptionStatusProvider.future);

      final unlocked = await c
          .read(proPaywallControllerProvider.notifier)
          .restore();

      expect(unlocked, isTrue);
      verifyInOrder([() => service.logIn(_userId), () => service.restore()]);
      expect(c.read(subscriptionStatusProvider).asData!.value.active, isTrue);
    });

    test('a restore that finds nothing leaves the app locked', () async {
      final c = container();
      final unlocked = await c
          .read(proPaywallControllerProvider.notifier)
          .restore();
      expect(unlocked, isFalse);
      expect(c.read(subscriptionStatusProvider).asData!.value.active, isFalse);
    });

    test(
      'a failing restore is an error state, and the app stays locked',
      () async {
        when(() => service.restore()).thenThrow(StateError('offline'));
        final c = container();
        final unlocked = await c
            .read(proPaywallControllerProvider.notifier)
            .restore();
        expect(unlocked, isFalse);
        expect(c.read(proPaywallControllerProvider), isA<AsyncError<void>>());
      },
    );
  });
}
