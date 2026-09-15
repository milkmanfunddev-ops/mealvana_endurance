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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:mealvana_endurance/features/subscription/application/subscription_status_provider.dart';
import 'package:mealvana_endurance/features/subscription/data/subscription_service.dart';
import 'package:mealvana_endurance/features/subscription/data/user_entitlements_repository.dart';
import 'package:mealvana_endurance/features/subscription/domain/entitlement.dart';

class _MockSubscriptionService extends Mock implements SubscriptionService {}

class _MockRepository extends Mock implements UserEntitlementsRepository {}

const _userId = '45a54f25-47c6-4730-8b21-78ea1df36bea';
const _timeout = Duration(milliseconds: 60);

final _rcActive = SubscriptionStatus(
  active: true,
  source: SubscriptionSource.revenuecat,
  expiresAt: DateTime.utc(2026, 10, 1),
  productId: 'mealvana_pro_monthly',
);

void main() {
  late _MockSubscriptionService service;
  late _MockRepository repo;

  /// The listener the controller registered with the service, so a test can
  /// simulate a RevenueCat CustomerInfo push.
  void Function(SubscriptionStatus)? capturedListener;

  setUp(() {
    service = _MockSubscriptionService();
    repo = _MockRepository();
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
      expect(DateTime.now().difference(started), greaterThanOrEqualTo(_timeout));
    });

    test('a fetch that fails (offline, no cache) → none at once', () async {
      when(() => service.fetchStatus()).thenAnswer((_) async => null);
      final c = container();
      expect(await resolve(c), SubscriptionStatus.none);
    });

    test('the SDK announcing its cache before the timeout still counts', () async {
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
    });
  });

  group('a later refresh reopens (or closes) the app', () {
    test('a push flips none → active without a resolve', () async {
      final c = container();
      expect(await resolve(c), SubscriptionStatus.none);

      capturedListener!(_rcActive);

      expect(current(c).active, isTrue);
      expect(current(c).source, SubscriptionSource.revenuecat);
    });

    test('a push flips active → none (expiry, refund)', () async {
      when(() => service.fetchStatus()).thenAnswer((_) async => _rcActive);
      final c = container();
      expect((await resolve(c)).active, isTrue);

      capturedListener!(SubscriptionStatus.none);

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
    test(
      'signed out → none without contacting RevenueCat',
      () async {
        when(() => repo.currentUserId).thenReturn(null);
        final c = container();
        expect(await resolve(c), SubscriptionStatus.none);
        verifyNever(() => service.currentAppUserId());
        verifyNever(() => service.fetchStatus());
      },
    );

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
}
