/// Unit tests for the app gate ([computeUnlocked] / `appGateProvider` /
/// [readAppGate]). The gate is the status and nothing else: no build flag,
/// no tester grant, no coach branch (mp-279, mp-286).
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/subscription/application/pro_gate.dart';
import 'package:mealvana_endurance/features/subscription/application/subscription_status_provider.dart';
import 'package:mealvana_endurance/features/subscription/domain/entitlement.dart';

const _active = SubscriptionStatus(
  active: true,
  source: SubscriptionSource.revenuecat,
);

/// A status controller pinned to one value — how widget/router tests stub
/// the subscription without RevenueCat.
class _FixedStatus extends SubscriptionStatusController {
  _FixedStatus(this.status);
  final SubscriptionStatus status;
  @override
  Future<SubscriptionStatus> build() async => status;
}

/// A status controller that answers when the test says so.
class _DeferredStatus extends SubscriptionStatusController {
  final completer = Completer<SubscriptionStatus>();
  @override
  Future<SubscriptionStatus> build() => completer.future;
}

void main() {
  group('computeUnlocked', () {
    test('active → unlocked', () {
      expect(computeUnlocked(_active), isTrue);
    });

    test('none → locked', () {
      expect(computeUnlocked(SubscriptionStatus.none), isFalse);
    });
  });

  group('appGateProvider', () {
    ProviderContainer container(
      SubscriptionStatusController Function() status,
    ) {
      final c = ProviderContainer(
        overrides: [subscriptionStatusProvider.overrideWith(status)],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('reflects an active status once resolved', () async {
      final c = container(() => _FixedStatus(_active));
      expect(await c.read(appGateProvider.future), isTrue);
    });

    test('reflects a locked status once resolved', () async {
      final c = container(() => _FixedStatus(SubscriptionStatus.none));
      expect(await c.read(appGateProvider.future), isFalse);
    });

    test('is loading while the status is unresolved, then settles', () async {
      final deferred = _DeferredStatus();
      final c = container(() => deferred);
      expect(c.read(appGateProvider).isLoading, isTrue);

      final pending = c.read(appGateProvider.future);
      deferred.completer.complete(_active);
      expect(await pending, isTrue);
    });

    test(
      'follows a status flip (the gate reacts when RevenueCat refreshes)',
      () async {
        final fixed = _FixedStatus(SubscriptionStatus.none);
        final c = container(() => fixed);
        final sub = c.listen(appGateProvider, (_, _) {});
        addTearDown(sub.close);
        expect(await c.read(appGateProvider.future), isFalse);

        // The controller's own setter path, as a RevenueCat push uses it.
        fixed.state = const AsyncData(_active);
        await Future<void>.delayed(Duration.zero);

        expect(await c.read(appGateProvider.future), isTrue);
      },
    );
  });

  group('readAppGate (the router redirect)', () {
    test('answers from the settled value without waiting', () async {
      final c = ProviderContainer(
        overrides: [
          subscriptionStatusProvider.overrideWith(() => _FixedStatus(_active)),
        ],
      );
      addTearDown(c.dispose);
      await c.read(appGateProvider.future);

      final viaRef = Provider<Future<bool>>((ref) => readAppGate(ref));
      expect(await c.read(viaRef), isTrue);
    });

    test('waits for an unresolved status', () async {
      final deferred = _DeferredStatus();
      final c = ProviderContainer(
        overrides: [subscriptionStatusProvider.overrideWith(() => deferred)],
      );
      addTearDown(c.dispose);

      final viaRef = Provider<Future<bool>>((ref) => readAppGate(ref));
      final pending = c.read(viaRef);
      deferred.completer.complete(SubscriptionStatus.none);
      expect(await pending, isFalse);
    });
  });
}
