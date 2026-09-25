/// Seam tests for `subscriptionStatusProvider` ([SubscriptionStatusController])
/// through the real notifier (docs/test/README.md, Seam tests).
///
/// The rule under test (mp-284): RevenueCat's cached entitlement is the
/// answer whenever there is one, online or not; no cache and no answer
/// within the timeout is locked; a later push from RevenueCat reopens (or
/// closes) the app; a cache that belongs to another RevenueCat identity is
/// not an answer; build never surfaces an error.
library;

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:mealvana_endurance/features/subscription/application/pro_gate.dart';
import 'package:mealvana_endurance/features/subscription/application/subscription_status_provider.dart';
import 'package:mealvana_endurance/features/subscription/data/subscription_service.dart';
import 'package:mealvana_endurance/features/subscription/data/user_entitlements_repository.dart';
import 'package:mealvana_endurance/features/subscription/domain/entitlement.dart';
import 'package:mealvana_endurance/features/subscription/domain/trial_reminder.dart';
import 'package:mealvana_endurance/shared/providers/is_admin_provider.dart';
import 'package:mealvana_endurance/shared/services/notification_service.dart';

import '../customer_info_fixtures.dart';

class _MockSubscriptionService extends Mock implements SubscriptionService {}

class _MockRepository extends Mock implements UserEntitlementsRepository {}

/// Records cancellations instead of reaching the platform plugin.
class _FakeScheduler implements LocalNotificationScheduler {
  final cancelled = <int>[];

  @override
  Future<bool> scheduleOnce({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    String? payload,
  }) async => true;

  @override
  Future<void> cancel(int id) async => cancelled.add(id);
}

/// RevenueCat's `pro` entitlement in a trial, as the native bridge hands it
/// to `EntitlementInfo.fromJson`, through the service's own mapping.
SubscriptionStatus _trialFromRevenueCat({required bool willRenew}) =>
    SubscriptionService.statusFromEntitlement(
      EntitlementInfo.fromJson({
        'identifier': 'pro',
        'isActive': true,
        'willRenew': willRenew,
        'latestPurchaseDate': '2026-09-22T14:30:00Z',
        'originalPurchaseDate': '2026-09-22T14:30:00Z',
        'productIdentifier': 'me_pro_monthly',
        'isSandbox': true,
        'ownershipType': 'PURCHASED',
        'store': 'APP_STORE',
        'periodType': 'TRIAL',
        'expirationDate': '2026-09-29T14:30:00Z',
        'unsubscribeDetectedAt': willRenew ? null : '2026-09-23T08:00:00Z',
        'billingIssueDetectedAt': null,
        'verification': 'NOT_REQUESTED',
      }),
    );

const _userId = '45a54f25-47c6-4730-8b21-78ea1df36bea';
const _timeout = Duration(milliseconds: 60);

/// The clock the tests run at: before every fixture's expiry.
final _now = customerInfoFetchedAt;

final _rcActive = SubscriptionStatus(
  active: true,
  source: SubscriptionSource.revenuecat,
  expiresAt: DateTime.utc(2026, 10, 1),
  productId: 'mealvana_pro_monthly',
);

void main() {
  late _MockSubscriptionService service;
  late _MockRepository repo;
  late _FakeScheduler scheduler;

  /// The listener the controller registered with the service, so a test can
  /// simulate a RevenueCat CustomerInfo push.
  void Function(SubscriptionStatus)? capturedListener;

  setUp(() {
    service = _MockSubscriptionService();
    when(() => service.forgetCachedStatus()).thenAnswer((_) async {});
    repo = _MockRepository();
    scheduler = _FakeScheduler();
    capturedListener = null;

    when(() => repo.currentUserId).thenReturn(_userId);
    when(
      () => repo.authUserIdChanges,
    ).thenAnswer((_) => const Stream<String?>.empty());
    when(() => service.setStatusListener(any())).thenAnswer((inv) {
      capturedListener =
          inv.positionalArguments.first as void Function(SubscriptionStatus)?;
    });
    // Defaults: the SDK already holds this user's identity and has no
    // entitlement for them.
    when(() => service.currentAppUserId()).thenAnswer((_) async => _userId);
    when(() => service.logIn(any())).thenAnswer((_) async {});
    when(() => service.logOut()).thenAnswer((_) async {});
    when(
      () => service.fetchStatus(),
    ).thenAnswer((_) async => SubscriptionStatus.none);
  });

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        subscriptionServiceProvider.overrideWithValue(service),
        userEntitlementsRepositoryProvider.overrideWithValue(repo),
        entitlementAnswerTimeoutProvider.overrideWithValue(_timeout),
        localNotificationSchedulerProvider.overrideWithValue(scheduler),
        subscriptionClockProvider.overrideWithValue(() => _now),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<SubscriptionStatus> resolve(ProviderContainer c) =>
      c.read(subscriptionStatusProvider.future);

  SubscriptionStatus current(ProviderContainer c) =>
      c.read(subscriptionStatusProvider).asData!.value;

  group('the cache is the answer whenever there is one', () {
    test('a cached active entitlement opens the app', () async {
      when(() => service.fetchStatus()).thenAnswer((_) async => _rcActive);
      final c = container();
      final s = await resolve(c);
      expect(s.active, isTrue);
      expect(s.source, SubscriptionSource.revenuecat);
      expect(s.productId, 'mealvana_pro_monthly');
    });

    test('the identified cache is read without a network logIn', () async {
      when(() => service.fetchStatus()).thenAnswer((_) async => _rcActive);
      final c = container();
      await resolve(c);
      verifyNever(() => service.logIn(any()));
      verify(() => service.fetchStatus()).called(1);
    });

    test('a cached "none" (expired, or never subscribed) locks', () async {
      final c = container();
      expect(await resolve(c), SubscriptionStatus.none);
    });
  });

  group('no cache and no answer within the timeout locks', () {
    test('a fetch that never answers → none after the timeout', () async {
      when(
        () => service.fetchStatus(),
      ).thenAnswer((_) => Completer<SubscriptionStatus?>().future);
      final c = container();
      final started = DateTime.now();
      expect(await resolve(c), SubscriptionStatus.none);
      expect(
        DateTime.now().difference(started),
        greaterThanOrEqualTo(_timeout),
      );
    });

    test('a fetch that fails (offline, no cache) → none at once', () async {
      when(() => service.fetchStatus()).thenAnswer((_) async => null);
      final c = container();
      expect(await resolve(c), SubscriptionStatus.none);
    });

    test(
      'the SDK announcing its cache before the timeout still counts',
      () async {
        when(
          () => service.fetchStatus(),
        ).thenAnswer((_) => Completer<SubscriptionStatus?>().future);
        final c = container();
        final pending = resolve(c);
        // RevenueCat's listener fires with the cached info while the fetch
        // is still out.
        await Future<void>.delayed(Duration.zero);
        capturedListener!(_rcActive);
        expect((await pending).active, isTrue);
      },
    );
  });

  group('a later refresh reopens (or closes) the app', () {
    test('a push flips none → active without a resolve', () async {
      final c = container();
      expect(await resolve(c), SubscriptionStatus.none);

      capturedListener!(_rcActive);
      // The push checks the SDK's identity before it is taken.
      await pumpEventQueue();

      expect(current(c).active, isTrue);
      expect(current(c).source, SubscriptionSource.revenuecat);
    });

    test(
      'a push for another RevenueCat identity is not taken (32-002)',
      () async {
        // A phone that held another account: after sign-up the SDK still
        // pushes the cached customer of that account (or the anonymous one)
        // until logIn has moved the identity. That push is about someone
        // else and must never open the app for this user, not for a frame.
        final c = container();
        expect(await resolve(c), SubscriptionStatus.none);

        when(
          () => service.currentAppUserId(),
        ).thenAnswer((_) async => 'someone-else');
        capturedListener!(_rcActive);
        await pumpEventQueue();

        expect(current(c).active, isFalse);
      },
    );

    test('a push with nobody signed in is not taken', () async {
      final c = container();
      expect(await resolve(c), SubscriptionStatus.none);

      when(() => repo.currentUserId).thenReturn(null);
      capturedListener!(_rcActive);
      await pumpEventQueue();

      expect(current(c).active, isFalse);
    });

    test('a push flips active → none (expiry, refund)', () async {
      when(() => service.fetchStatus()).thenAnswer((_) async => _rcActive);
      final c = container();
      expect((await resolve(c)).active, isTrue);

      capturedListener!(SubscriptionStatus.none);
      await pumpEventQueue();

      expect(current(c).active, isFalse);
    });

    test('refresh re-resolves against RevenueCat', () async {
      final c = container();
      expect(await resolve(c), SubscriptionStatus.none);

      when(() => service.fetchStatus()).thenAnswer((_) async => _rcActive);
      await c.read(subscriptionStatusProvider.notifier).refresh();

      expect(current(c).active, isTrue);
      verify(() => service.fetchStatus()).called(2);
    });

    test('registers exactly one listener on build', () async {
      final c = container();
      await resolve(c);
      verify(() => service.setStatusListener(any())).called(1);
      expect(capturedListener, isNotNull);
    });
  });

  group("someone else's cache is not an answer", () {
    test('a different RevenueCat identity is moved with logIn first', () async {
      var rcUser = 'anonymous-rc-id';
      when(() => service.currentAppUserId()).thenAnswer((_) async => rcUser);
      when(() => service.logIn(any())).thenAnswer((inv) async {
        rcUser = inv.positionalArguments.first as String;
      });
      when(() => service.fetchStatus()).thenAnswer((_) async => _rcActive);

      final c = container();
      expect((await resolve(c)).active, isTrue);
      verify(() => service.logIn(_userId)).called(1);
    });

    test('logIn that cannot move the identity (offline) → locked, and the '
        'stale cache is never read', () async {
      when(
        () => service.currentAppUserId(),
      ).thenAnswer((_) async => 'previous-account');
      when(() => service.fetchStatus()).thenAnswer((_) async => _rcActive);

      final c = container();
      expect(await resolve(c), SubscriptionStatus.none);
      verifyNever(() => service.fetchStatus());
    });

    test('an unconfigured SDK (no identity at all) → locked', () async {
      when(() => service.currentAppUserId()).thenAnswer((_) async => null);
      final c = container();
      expect(await resolve(c), SubscriptionStatus.none);
      verifyNever(() => service.fetchStatus());
    });
  });

  group('edges', () {
    test('signed out → none without contacting RevenueCat', () async {
      when(() => repo.currentUserId).thenReturn(null);
      final c = container();
      expect(await resolve(c), SubscriptionStatus.none);
      verifyNever(() => service.currentAppUserId());
      verifyNever(() => service.fetchStatus());
    });

    test('build never throws — an unexpected error locks', () async {
      when(() => service.fetchStatus()).thenThrow(StateError('boom'));
      final c = container();
      expect(await resolve(c), SubscriptionStatus.none);
      expect(c.read(subscriptionStatusProvider).hasError, isFalse);
    });

    test('clear locks at once (sign-out)', () async {
      when(() => service.fetchStatus()).thenAnswer((_) async => _rcActive);
      final c = container();
      expect((await resolve(c)).active, isTrue);

      await c.read(subscriptionStatusProvider.notifier).clear();

      expect(current(c), SubscriptionStatus.none);
    });

    test('clear logs the RevenueCat SDK out (03-002)', () async {
      // Signed out, the SDK used to stay identified as the last account and
      // kept fetching that customer's entitlement.
      final c = container();
      await resolve(c);

      await c.read(subscriptionStatusProvider.notifier).clear();

      verify(() => service.logOut()).called(1);
    });

    test('a new session id rebuilds the status', () async {
      final auth = StreamController<String?>.broadcast();
      addTearDown(auth.close);
      when(() => repo.authUserIdChanges).thenAnswer((_) => auth.stream);
      final c = container();
      // Keep the auth stream provider alive by listening to the status.
      final sub = c.listen(subscriptionStatusProvider, (_, _) {});
      addTearDown(sub.close);
      expect(await resolve(c), SubscriptionStatus.none);

      when(() => service.fetchStatus()).thenAnswer((_) async => _rcActive);
      auth.add('another-user');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect((await resolve(c)).active, isTrue);
    });
  });

  group('the day-five reminder is cancelled when the trial will not renew '
      '(mp-456 §4)', () {
    test('an app open that finds a cancelled trial cancels it', () async {
      when(
        () => service.fetchStatus(),
      ).thenAnswer((_) async => _trialFromRevenueCat(willRenew: false));
      final c = container();

      final status = await resolve(c);
      await pumpEventQueue();

      expect(status.active, isTrue, reason: 'the free week still runs out');
      expect(scheduler.cancelled, [TrialReminder.notificationId]);
    });

    test('a trial that will renew keeps it', () async {
      when(
        () => service.fetchStatus(),
      ).thenAnswer((_) async => _trialFromRevenueCat(willRenew: true));
      await resolve(container());
      await pumpEventQueue();
      expect(scheduler.cancelled, isEmpty);
    });

    test('a stale cache at open, then RevenueCat pushes the cancellation: '
        'cancelled on the push', () async {
      when(
        () => service.fetchStatus(),
      ).thenAnswer((_) async => _trialFromRevenueCat(willRenew: true));
      final c = container();
      await resolve(c);
      expect(scheduler.cancelled, isEmpty);

      capturedListener!(_trialFromRevenueCat(willRenew: false));
      await pumpEventQueue();
      expect(scheduler.cancelled, [TrialReminder.notificationId]);
    });

    test('sign-out cancels it, so the next account never gets it', () async {
      when(
        () => service.fetchStatus(),
      ).thenAnswer((_) async => _trialFromRevenueCat(willRenew: true));
      final c = container();
      await resolve(c);
      expect(scheduler.cancelled, isEmpty);

      await c.read(subscriptionStatusProvider.notifier).clear();
      await pumpEventQueue();
      expect(scheduler.cancelled, [TrialReminder.notificationId]);
    });

    test(
      'an open with nobody signed in (deleted account) cancels it',
      () async {
        when(() => repo.currentUserId).thenReturn(null);
        await resolve(container());
        await pumpEventQueue();
        expect(scheduler.cancelled, [TrialReminder.notificationId]);
      },
    );

    test('no answer from RevenueCat cancels nothing', () async {
      when(
        () => service.fetchStatus(),
      ).thenAnswer((_) async => SubscriptionStatus.none);
      await resolve(container());
      await pumpEventQueue();
      expect(scheduler.cancelled, isEmpty);
    });
  });

  group('open or closed from customer info (mp-457, mp-611)', () {
    ProviderContainer gateContainer({bool isAdmin = false, DateTime? at}) {
      final now = at ?? _now;
      final c = ProviderContainer(
        overrides: [
          subscriptionServiceProvider.overrideWithValue(service),
          userEntitlementsRepositoryProvider.overrideWithValue(repo),
          entitlementAnswerTimeoutProvider.overrideWithValue(_timeout),
          localNotificationSchedulerProvider.overrideWithValue(scheduler),
          subscriptionClockProvider.overrideWithValue(() => now),
          isAdminProvider.overrideWith((_) async => isAdmin),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('the service maps an expired pro to held-once, not active', () {
      final lapsed = statusOf(customerInfoLapsed);
      expect(lapsed.active, isFalse);
      expect(lapsed.hadPro, isTrue);
      expect(lapsed.expiresAt, DateTime.utc(2026, 9, 1, 10));

      final never = statusOf(customerInfoNever);
      expect(never.active, isFalse);
      expect(never.hadPro, isFalse);

      final open = statusOf(customerInfoOpen);
      expect(open.active, isTrue);
      expect(open.hadPro, isTrue);
    });

    test('an active pro answers open', () async {
      when(
        () => service.fetchStatus(),
      ).thenAnswer((_) async => statusOf(customerInfoOpen));
      final c = gateContainer();
      expect(await c.read(appGateProvider.future), AppAccess.open);
      expect(await c.read(writeAccessProvider.future), isTrue);
    });

    test(
      'a pro that expired answers closed, and AI actions are refused',
      () async {
        when(
          () => service.fetchStatus(),
        ).thenAnswer((_) async => statusOf(customerInfoLapsed));
        final c = gateContainer();
        expect(await c.read(appGateProvider.future), AppAccess.closed);
        expect(await c.read(writeAccessProvider.future), isFalse);
      },
    );

    test('no pro ever answers closed, the same as an expired one', () async {
      when(
        () => service.fetchStatus(),
      ).thenAnswer((_) async => statusOf(customerInfoNever));
      final c = gateContainer();
      expect(await c.read(appGateProvider.future), AppAccess.closed);
      expect(await c.read(writeAccessProvider.future), isFalse);
    });

    test(
      'no answer in time answers closed (unknown is locked, mp-284)',
      () async {
        when(
          () => service.fetchStatus(),
        ).thenAnswer((_) => Completer<SubscriptionStatus?>().future);
        final c = gateContainer();
        expect(await c.read(appGateProvider.future), AppAccess.closed);
      },
    );

    test('a lapsed admin answers open (mp-416)', () async {
      when(
        () => service.fetchStatus(),
      ).thenAnswer((_) async => statusOf(customerInfoLapsed));
      final c = gateContainer(isAdmin: true);
      expect(await c.read(appGateProvider.future), AppAccess.open);
      expect(await c.read(writeAccessProvider.future), isTrue);
    });

    test('an expiry pushed mid-session turns open into closed', () async {
      when(
        () => service.fetchStatus(),
      ).thenAnswer((_) async => statusOf(customerInfoOpen));
      final c = gateContainer();
      final sub = c.listen(appGateProvider, (_, _) {});
      addTearDown(sub.close);
      expect(await c.read(appGateProvider.future), AppAccess.open);

      capturedListener!(statusOf(customerInfoLapsed));
      await pumpEventQueue();

      expect(await c.read(appGateProvider.future), AppAccess.closed);
      expect(await c.read(writeAccessProvider.future), isFalse);
    });

    test('a resubscribe pushed while closed opens writes again', () async {
      when(
        () => service.fetchStatus(),
      ).thenAnswer((_) async => statusOf(customerInfoLapsed));
      final c = gateContainer();
      final sub = c.listen(writeAccessProvider, (_, _) {});
      addTearDown(sub.close);
      expect(await c.read(writeAccessProvider.future), isFalse);

      capturedListener!(statusOf(customerInfoOpen));
      await pumpEventQueue();

      expect(await c.read(writeAccessProvider.future), isTrue);
    });
  });

  group('the saved copy counts 15 minutes past its own expiry, then not '
      '(mp-679, Finding 07-002)', () {
    // The period in the fixture ends at 11:36:56 UTC.
    final expiry = DateTime.utc(2026, 9, 24, 11, 36, 56);

    ProviderContainer at(DateTime now) {
      final c = ProviderContainer(
        overrides: [
          subscriptionServiceProvider.overrideWithValue(service),
          userEntitlementsRepositoryProvider.overrideWithValue(repo),
          entitlementAnswerTimeoutProvider.overrideWithValue(_timeout),
          localNotificationSchedulerProvider.overrideWithValue(scheduler),
          subscriptionClockProvider.overrideWithValue(() => now),
          isAdminProvider.overrideWith((_) async => false),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    setUp(() {
      when(
        () => service.fetchStatus(),
      ).thenAnswer((_) async => statusOf(customerInfoSavedMonthly));
    });

    test(
      'a cold launch 2 minutes past expiry opens from the saved copy',
      () async {
        final c = at(expiry.add(const Duration(minutes: 2)));
        expect((await resolve(c)).active, isTrue);
        expect(await c.read(appGateProvider.future), AppAccess.open);
      },
    );

    test(
      'a cold launch 16 minutes past expiry with no network is closed',
      () async {
        final c = at(expiry.add(const Duration(minutes: 16)));
        final s = await resolve(c);
        expect(s.active, isFalse);
        expect(s.hadPro, isTrue);
        expect(await c.read(appGateProvider.future), AppAccess.closed);
      },
    );

    test(
      'the saved copy pushed 16 minutes past expiry does not open it',
      () async {
        when(
          () => service.fetchStatus(),
        ).thenAnswer((_) async => SubscriptionStatus.none);
        final c = at(expiry.add(const Duration(minutes: 16)));
        final sub = c.listen(appGateProvider, (_, _) {});
        addTearDown(sub.close);
        expect(await c.read(appGateProvider.future), AppAccess.closed);

        capturedListener!(statusOf(customerInfoSavedMonthly));
        await pumpEventQueue();

        expect(current(c).active, isFalse);
        expect(await c.read(appGateProvider.future), AppAccess.closed);
      },
    );

    test('a fresh active answer reopens it', () async {
      final c = at(expiry.add(const Duration(minutes: 16)));
      final sub = c.listen(appGateProvider, (_, _) {});
      addTearDown(sub.close);
      expect(await c.read(appGateProvider.future), AppAccess.closed);

      // RevenueCat's fresh answer: the renewal landed, next period to
      // 11:41:56.
      capturedListener!(statusOf(customerInfoRenewedMonthly));
      await pumpEventQueue();

      expect(current(c).active, isTrue);
      expect(await c.read(appGateProvider.future), AppAccess.open);
    });

    test('a fresh active answer fetched on refresh reopens it', () async {
      final c = at(expiry.add(const Duration(minutes: 16)));
      expect((await resolve(c)).active, isFalse);

      when(
        () => service.fetchStatus(),
      ).thenAnswer((_) async => statusOf(customerInfoRenewedMonthly));
      await c.read(subscriptionStatusProvider.notifier).refresh();

      expect(current(c).active, isTrue);
    });
  });
  group('the Gate closes on time while the app stays open (mp-457, mp-679, '
      'Finding 05-005)', () {
    // The saved copy's period ends at 11:36:56 UTC; the controller starts
    // five minutes before that and nothing resumes the app.
    final expiry = DateTime.utc(2026, 9, 24, 11, 36, 56);
    final start = expiry.subtract(const Duration(minutes: 5));

    /// A container whose clock moves with the fake timers.
    ProviderContainer ticking(FakeAsync async) {
      final c = ProviderContainer(
        overrides: [
          subscriptionServiceProvider.overrideWithValue(service),
          userEntitlementsRepositoryProvider.overrideWithValue(repo),
          entitlementAnswerTimeoutProvider.overrideWithValue(_timeout),
          localNotificationSchedulerProvider.overrideWithValue(scheduler),
          subscriptionClockProvider.overrideWithValue(
            () => start.add(async.elapsed),
          ),
          isAdminProvider.overrideWith((_) async => false),
        ],
      );
      // Keep the gate listened to, as the router does.
      c.listen(appGateProvider, (_, _) {});
      return c;
    }

    AppAccess gate(ProviderContainer c) => c.read(appGateProvider).requireValue;

    /// Timers that wait (Riverpod's own zero-length refresh ticks aside).
    Iterable<FakeTimer> waits(FakeAsync async) =>
        async.pendingTimers.where((t) => t.duration > Duration.zero);

    test('a renewing answer closes 15 minutes past expiry, with no resume, '
        'after one re-fetch', () {
      fakeAsync((async) {
        // RevenueCat keeps serving the saved copy: the renewal never lands.
        when(
          () => service.fetchStatus(),
        ).thenAnswer((_) async => statusOf(customerInfoSavedMonthly));
        final c = ticking(async);
        async.flushMicrotasks();
        expect(gate(c), AppAccess.open);

        // Expiry + 14:59: still inside the grace.
        async.elapse(const Duration(minutes: 19, seconds: 59));
        expect(gate(c), AppAccess.open);
        verify(() => service.fetchStatus()).called(1);

        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(gate(c), AppAccess.closed);
        expect(current(c).hadPro, isTrue);
        // One re-fetch at the moment it stopped counting, and no more.
        verify(() => service.fetchStatus()).called(1);
        async.elapse(const Duration(hours: 2));
        verifyNever(() => service.fetchStatus());
        expect(gate(c), AppAccess.closed);
        c.dispose();
      });
    });

    test('a cancelled answer closes at its expiry', () {
      fakeAsync((async) {
        final cancelled = statusOf(
          customerInfoSavedMonthly,
        ).copyWith(willRenew: false);
        when(() => service.fetchStatus()).thenAnswer((_) async => cancelled);
        final c = ticking(async);
        async.flushMicrotasks();
        expect(gate(c), AppAccess.open);

        async.elapse(const Duration(minutes: 4, seconds: 59));
        expect(gate(c), AppAccess.open);

        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(gate(c), AppAccess.closed);
        c.dispose();
      });
    });

    test('the re-fetch that finds the renewal keeps it open and waits for '
        'the new period', () {
      fakeAsync((async) {
        when(
          () => service.fetchStatus(),
        ).thenAnswer((_) async => statusOf(customerInfoSavedMonthly));
        final c = ticking(async);
        async.flushMicrotasks();

        // The renewal is on RevenueCat by the time the timer fires.
        when(
          () => service.fetchStatus(),
        ).thenAnswer((_) async => statusOf(customerInfoRenewedMonthly));
        async.elapse(const Duration(minutes: 20));
        async.flushMicrotasks();
        expect(gate(c), AppAccess.open);
        expect(current(c).expiresAt, DateTime.utc(2026, 9, 24, 11, 41, 56));
        c.dispose();
      });
    });

    test('a fresh active answer before then cancels the close and '
        're-schedules it for the new period', () {
      fakeAsync((async) {
        when(
          () => service.fetchStatus(),
        ).thenAnswer((_) async => statusOf(customerInfoSavedMonthly));
        final c = ticking(async);
        async.flushMicrotasks();

        // Three minutes in, RevenueCat pushes the renewal: next period to
        // 11:41:56, so it counts to 11:56:56.
        async.elapse(const Duration(minutes: 3));
        capturedListener!(statusOf(customerInfoRenewedMonthly));
        async.flushMicrotasks();

        // Past the old deadline (11:51:56): still open, nothing re-fetched.
        async.elapse(const Duration(minutes: 18));
        async.flushMicrotasks();
        expect(gate(c), AppAccess.open);
        verify(() => service.fetchStatus()).called(1);

        // Past the new one (11:56:56): closed.
        async.elapse(const Duration(minutes: 5));
        async.flushMicrotasks();
        expect(gate(c), AppAccess.closed);
        c.dispose();
      });
    });

    test('a far expiry never re-fetches early', () {
      fakeAsync((async) {
        // An annual period, months away: the timer must not fire early
        // (a browser caps a timer at about 24.8 days).
        when(
          () => service.fetchStatus(),
        ).thenAnswer((_) async => statusOf(customerInfoFounding));
        final c = ticking(async);
        async.flushMicrotasks();

        async.elapse(const Duration(days: 30));
        async.flushMicrotasks();
        expect(gate(c), AppAccess.open);
        verify(() => service.fetchStatus()).called(1);
        c.dispose();
      });
    });

    test('a closed answer schedules nothing', () {
      fakeAsync((async) {
        final c = ticking(async);
        async.flushMicrotasks();
        expect(gate(c), AppAccess.closed);
        expect(waits(async), isEmpty);
        c.dispose();
      });
    });

    test('dispose cancels the timer', () {
      fakeAsync((async) {
        when(
          () => service.fetchStatus(),
        ).thenAnswer((_) async => statusOf(customerInfoSavedMonthly));
        final c = ticking(async);
        async.flushMicrotasks();
        expect(waits(async), isNotEmpty);

        c.dispose();
        expect(waits(async), isEmpty);
      });
    });

    test('sign-out cancels the timer', () {
      fakeAsync((async) {
        when(
          () => service.fetchStatus(),
        ).thenAnswer((_) async => statusOf(customerInfoSavedMonthly));
        final c = ticking(async);
        async.flushMicrotasks();

        unawaited(c.read(subscriptionStatusProvider.notifier).clear());
        async.flushMicrotasks();
        expect(waits(async), isEmpty);
        c.dispose();
      });
    });
  });
}
