/// Unit tests for the Pro gate rule ([computeProUnlocked] / `proUnlockedProvider`).
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/subscription/application/pro_gate.dart';
import 'package:mealvana_endurance/features/subscription/application/subscription_status_provider.dart';
import 'package:mealvana_endurance/features/subscription/domain/entitlement.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';

const _active = SubscriptionStatus(
  active: true,
  source: SubscriptionSource.revenuecat,
);

/// A status controller pinned to one value — how widget/router tests stub
/// the subscription without RevenueCat or Supabase.
class _FixedStatus extends SubscriptionStatusController {
  _FixedStatus(this.status);
  final SubscriptionStatus status;
  @override
  Future<SubscriptionStatus> build() async => status;
}

class _LoadingStatus extends SubscriptionStatusController {
  @override
  Future<SubscriptionStatus> build() => Completer<SubscriptionStatus>().future;
}

void main() {
  group('computeProUnlocked', () {
    final gateOn = AppConfig.forTesting(proGateEnabled: true);
    final gateOff = AppConfig.forTesting(proGateEnabled: false);

    test('gate off → unlocked whatever the status (dev builds)', () {
      expect(
        computeProUnlocked(status: const AsyncLoading(), config: gateOff),
        isTrue,
      );
      expect(
        computeProUnlocked(
          status: const AsyncData(SubscriptionStatus.none),
          config: gateOff,
        ),
        isTrue,
      );
    });

    test('gate on + active status → unlocked', () {
      expect(
        computeProUnlocked(status: const AsyncData(_active), config: gateOn),
        isTrue,
      );
    });

    test('gate on + none → locked', () {
      expect(
        computeProUnlocked(
          status: const AsyncData(SubscriptionStatus.none),
          config: gateOn,
        ),
        isFalse,
      );
    });

    test('gate on + still loading → locked (fail closed)', () {
      expect(
        computeProUnlocked(status: const AsyncLoading(), config: gateOn),
        isFalse,
      );
    });

    test('gate on + error → locked', () {
      expect(
        computeProUnlocked(
          status: AsyncError(StateError('x'), StackTrace.empty),
          config: gateOn,
        ),
        isFalse,
      );
    });
  });

  group('proUnlockedProvider', () {
    ProviderContainer container({
      required bool gate,
      required SubscriptionStatusController Function() status,
    }) {
      final c = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.forTesting(proGateEnabled: gate),
          ),
          subscriptionStatusProvider.overrideWith(status),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('reflects an active status once resolved', () async {
      final c = container(gate: true, status: () => _FixedStatus(_active));
      await c.read(subscriptionStatusProvider.future);
      expect(c.read(proUnlockedProvider), isTrue);
    });

    test('locked while loading, unlocked when the gate is off', () {
      expect(
        container(
          gate: true,
          status: _LoadingStatus.new,
        ).read(proUnlockedProvider),
        isFalse,
      );
      expect(
        container(
          gate: false,
          status: _LoadingStatus.new,
        ).read(proUnlockedProvider),
        isTrue,
      );
    });

    test('isProUnlocked reads the same value', () async {
      final c = container(
        gate: true,
        status: () => _FixedStatus(SubscriptionStatus.none),
      );
      await c.read(subscriptionStatusProvider.future);
      final viaRef = Provider<bool>((ref) => isProUnlocked(ref));
      expect(c.read(viaRef), isFalse);
    });
  });
}
