/// Unit tests for `subscriptionStatusProvider` ([SubscriptionStatusController]).
///
/// The resolution rule under test: RevenueCat ∪ server row ∪ tester flag,
/// first active source wins in that order; a RevenueCat push re-merges with
/// the last server answer; clear() drops the cache and resets to none (or
/// the tester grant); build never surfaces an error.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:mealvana_endurance/features/subscription/application/subscription_status_provider.dart';
import 'package:mealvana_endurance/features/subscription/data/subscription_service.dart';
import 'package:mealvana_endurance/features/subscription/data/user_entitlements_repository.dart';
import 'package:mealvana_endurance/features/subscription/domain/entitlement.dart';
import 'package:mealvana_endurance/shared/services/analytics/internal_user_service.dart';

class _MockSubscriptionService extends Mock implements SubscriptionService {}

class _MockRepository extends Mock implements UserEntitlementsRepository {}

class _FixedFlag extends InternalDeviceFlagNotifier {
  _FixedFlag(this.value);
  final bool value;
  @override
  bool build() => value;
}

/// A tester switch a test can flip mid-run (the real notifier talks to
/// secure storage).
class _MutableFlag extends InternalDeviceFlagNotifier {
  _MutableFlag(this.value);
  bool value;
  @override
  bool build() => value;
  void flip(bool next) {
    value = next;
    state = next;
  }
}

const _userId = '45a54f25-47c6-4730-8b21-78ea1df36bea';

final _rcActive = SubscriptionStatus(
  active: true,
  source: SubscriptionSource.revenuecat,
  expiresAt: DateTime.utc(2026, 10, 1),
  productId: 'mealvana_pro_monthly',
);
final _serverActive = SubscriptionStatus(
  active: true,
  source: SubscriptionSource.server,
  expiresAt: DateTime.utc(2026, 10, 1),
);

void main() {
  late _MockSubscriptionService service;
  late _MockRepository repo;

  /// The listener the controller registered with the service, so a test can
  /// simulate a RevenueCat CustomerInfo push.
  void Function(SubscriptionStatus)? capturedListener;

  setUpAll(() => registerFallbackValue(Entitlement.pro));

  setUp(() {
    service = _MockSubscriptionService();
    repo = _MockRepository();
    capturedListener = null;

    when(() => repo.currentUserId).thenReturn(_userId);
    when(
      () => repo.authUserIdChanges,
    ).thenAnswer((_) => const Stream<String?>.empty());
    when(() => repo.clearCache()).thenAnswer((_) async {});
    when(() => service.setStatusListener(any())).thenAnswer((inv) {
      capturedListener =
          inv.positionalArguments.first as void Function(SubscriptionStatus)?;
    });
    // Defaults: nothing anywhere.
    when(() => service.fetchStatus()).thenAnswer((_) async => null);
    when(
      () => repo.fetchRemote(any(), any()),
    ).thenAnswer((_) async => SubscriptionStatus.none);
    when(() => repo.readCached(any(), any())).thenAnswer((_) async => null);
    when(
      () => repo.mirrorInternalFlag(any(), any()),
    ).thenAnswer((_) async => true);
  });

  ProviderContainer container({bool internal = false}) {
    final c = ProviderContainer(
      overrides: [
        subscriptionServiceProvider.overrideWithValue(service),
        userEntitlementsRepositoryProvider.overrideWithValue(repo),
        internalDeviceFlagProvider.overrideWith(() => _FixedFlag(internal)),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<SubscriptionStatus> resolve(ProviderContainer c) =>
      c.read(subscriptionStatusProvider.future);

  group('resolution', () {
    test('nothing active anywhere → none', () async {
      final c = container();
      expect(await resolve(c), SubscriptionStatus.none);
    });

    test('RevenueCat active wins and reports source revenuecat', () async {
      when(() => service.fetchStatus()).thenAnswer((_) async => _rcActive);
      when(
        () => repo.fetchRemote(any(), any()),
      ).thenAnswer((_) async => _serverActive);
      final c = container();
      final s = await resolve(c);
      expect(s.active, isTrue);
      expect(s.source, SubscriptionSource.revenuecat);
      expect(s.productId, 'mealvana_pro_monthly');
    });

    test('server row active (RevenueCat silent) → source server', () async {
      when(
        () => repo.fetchRemote(any(), any()),
      ).thenAnswer((_) async => _serverActive);
      final c = container();
      final s = await resolve(c);
      expect(s.active, isTrue);
      expect(s.source, SubscriptionSource.server);
    });

    test('remote read failed → falls back to the Drift cache', () async {
      when(() => repo.fetchRemote(any(), any())).thenAnswer((_) async => null);
      when(
        () => repo.readCached(any(), any()),
      ).thenAnswer((_) async => _serverActive);
      final c = container();
      expect((await resolve(c)).source, SubscriptionSource.server);
      verify(() => repo.readCached(_userId, Entitlement.pro)).called(1);
    });

    test('cache is NOT consulted when the remote read succeeded', () async {
      final c = container();
      await resolve(c);
      verifyNever(() => repo.readCached(any(), any()));
    });

    test('tester flag alone unlocks with source internal', () async {
      final c = container(internal: true);
      final s = await resolve(c);
      expect(s, kInternalProStatus);
      expect(s.source, SubscriptionSource.internal);
    });

    test('a real subscription outranks the tester flag', () async {
      when(() => service.fetchStatus()).thenAnswer((_) async => _rcActive);
      final c = container(internal: true);
      expect((await resolve(c)).source, SubscriptionSource.revenuecat);
    });

    test(
      'signed out → none without contacting RevenueCat or the server',
      () async {
        when(() => repo.currentUserId).thenReturn(null);
        final c = container();
        expect(await resolve(c), SubscriptionStatus.none);
        verifyNever(() => service.fetchStatus());
        verifyNever(() => repo.fetchRemote(any(), any()));
      },
    );

    test('build never throws — an unexpected error degrades to none', () async {
      when(() => service.fetchStatus()).thenThrow(StateError('boom'));
      final c = container();
      expect(await resolve(c), SubscriptionStatus.none);
      expect(c.read(subscriptionStatusProvider).hasError, isFalse);
    });

    test('… or to the tester grant on an internal device', () async {
      when(() => service.fetchStatus()).thenThrow(StateError('boom'));
      final c = container(internal: true);
      expect(await resolve(c), kInternalProStatus);
    });
  });

  group('RevenueCat push (CustomerInfo listener)', () {
    test('registers exactly one listener on build', () async {
      final c = container();
      await resolve(c);
      verify(() => service.setStatusListener(any())).called(1);
      expect(capturedListener, isNotNull);
    });

    test('a push flips the status to active without a refresh', () async {
      final c = container();
      expect(await resolve(c), SubscriptionStatus.none);

      capturedListener!(_rcActive);

      final s = c.read(subscriptionStatusProvider).asData!.value;
      expect(s.active, isTrue);
      expect(s.source, SubscriptionSource.revenuecat);
    });

    test('a push saying "none" keeps a still-valid server row', () async {
      when(
        () => repo.fetchRemote(any(), any()),
      ).thenAnswer((_) async => _serverActive);
      final c = container();
      expect((await resolve(c)).source, SubscriptionSource.server);

      capturedListener!(SubscriptionStatus.none);

      expect(
        c.read(subscriptionStatusProvider).asData!.value.source,
        SubscriptionSource.server,
      );
    });

    test('a push saying "none" with no server row → none (expiry)', () async {
      when(() => service.fetchStatus()).thenAnswer((_) async => _rcActive);
      final c = container();
      expect((await resolve(c)).active, isTrue);

      capturedListener!(SubscriptionStatus.none);

      expect(c.read(subscriptionStatusProvider).asData!.value.active, isFalse);
    });
  });

  group('refresh / clear', () {
    test('refresh re-resolves every source', () async {
      final c = container();
      expect(await resolve(c), SubscriptionStatus.none);

      when(() => service.fetchStatus()).thenAnswer((_) async => _rcActive);
      await c.read(subscriptionStatusProvider.notifier).refresh();

      expect(c.read(subscriptionStatusProvider).asData!.value.active, isTrue);
      verify(() => service.fetchStatus()).called(2);
    });

    test('clear drops the Drift cache and resets to none', () async {
      when(() => service.fetchStatus()).thenAnswer((_) async => _rcActive);
      final c = container();
      expect((await resolve(c)).active, isTrue);

      await c.read(subscriptionStatusProvider.notifier).clear();

      verify(() => repo.clearCache()).called(1);
      expect(
        c.read(subscriptionStatusProvider).asData!.value,
        SubscriptionStatus.none,
      );
    });

    test('clear keeps the tester grant on an internal device', () async {
      final c = container(internal: true);
      await resolve(c);
      await c.read(subscriptionStatusProvider.notifier).clear();
      expect(
        c.read(subscriptionStatusProvider).asData!.value,
        kInternalProStatus,
      );
    });
  });

  group('users.is_internal mirror (the server-side tester bypass)', () {
    test(
      'an internal device mirrors true once, not on every resolve',
      () async {
        final c = container(internal: true);
        await c.read(subscriptionStatusProvider.future);
        verify(() => repo.mirrorInternalFlag(_userId, true)).called(1);

        await c.read(subscriptionStatusProvider.notifier).refresh();
        // Already mirrored — no second write.
        verifyNever(() => repo.mirrorInternalFlag(any(), any()));
      },
    );

    test('an ordinary device never writes users.is_internal', () async {
      // A false-mirror on every cold start would also clobber a flag an
      // admin set server-side for this account.
      final c = container();
      await c.read(subscriptionStatusProvider.future);
      await c.read(subscriptionStatusProvider.notifier).refresh();
      verifyNever(() => repo.mirrorInternalFlag(any(), any()));
    });

    test('a failed mirror is retried on the next resolve', () async {
      when(
        () => repo.mirrorInternalFlag(any(), any()),
      ).thenAnswer((_) async => false);
      final c = container(internal: true);
      await c.read(subscriptionStatusProvider.future);
      await c.read(subscriptionStatusProvider.notifier).refresh();
      verify(() => repo.mirrorInternalFlag(_userId, true)).called(2);
    });

    test('flipping the switch off in-session mirrors false once', () async {
      final flag = _MutableFlag(true);
      final c = ProviderContainer(
        overrides: [
          subscriptionServiceProvider.overrideWithValue(service),
          userEntitlementsRepositoryProvider.overrideWithValue(repo),
          internalDeviceFlagProvider.overrideWith(() => flag),
        ],
      );
      addTearDown(c.dispose);
      await c.read(subscriptionStatusProvider.future);
      verify(() => repo.mirrorInternalFlag(_userId, true)).called(1);

      flag.flip(false);
      await c.read(subscriptionStatusProvider.future);
      verify(() => repo.mirrorInternalFlag(_userId, false)).called(1);

      // …and only once: later resolves have nothing left to clear.
      await c.read(subscriptionStatusProvider.notifier).refresh();
      verifyNever(() => repo.mirrorInternalFlag(any(), any()));
    });

    test('an identity change re-mirrors for the new account', () async {
      final c = container(internal: true);
      await c.read(subscriptionStatusProvider.future);
      verify(() => repo.mirrorInternalFlag(_userId, true)).called(1);

      // A different tester signs in on the same device: the memo must not
      // carry over, or their account never gets the server-side flag.
      const other = '9c1f3f60-0000-4000-8000-000000000002';
      when(() => repo.currentUserId).thenReturn(other);
      await c.read(subscriptionStatusProvider.notifier).refresh();
      verify(() => repo.mirrorInternalFlag(other, true)).called(1);
    });

    test('signed out → nothing to mirror', () async {
      when(() => repo.currentUserId).thenReturn(null);
      final c = container(internal: true);
      await c.read(subscriptionStatusProvider.future);
      verifyNever(() => repo.mirrorInternalFlag(any(), any()));
    });
  });

  group('auth change', () {
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

      expect(await resolve(c), isNot(SubscriptionStatus.none));
    });
  });
}
