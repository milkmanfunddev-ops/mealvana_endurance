/// Seam tests for [ProPaywallController] through the real notifier
/// (docs/test/README.md: every controller write path gets one).
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

import 'package:mealvana_endurance/features/subscription/application/pro_paywall_controller.dart';
import 'package:mealvana_endurance/features/subscription/application/subscription_status_provider.dart';
import 'package:mealvana_endurance/features/subscription/data/subscription_service.dart';
import 'package:mealvana_endurance/features/subscription/data/user_entitlements_repository.dart';
import 'package:mealvana_endurance/features/subscription/domain/entitlement.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';

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
  final pkg = _FakePackage();

  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
    registerFallbackValue(_FakePackage());
  });

  setUp(() {
    service = _MockSubscriptionService();
    repo = _MockRepository();
    sentry = _MockSentry();

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
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

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
