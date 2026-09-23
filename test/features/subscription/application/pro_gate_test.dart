/// Unit tests for the app gate ([computeAccess] / `appGateProvider` /
/// [readAppGate] / `writeAccessProvider`). The gate answers open (the
/// status, or a team admin) or closed (no live Pro, whether the account held
/// it once or never did, mp-457, mp-611); no build flag, no tester grant, no
/// coach branch (mp-279, mp-286).
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/subscription/application/pro_gate.dart';
import 'package:mealvana_endurance/features/subscription/application/subscription_status_provider.dart';
import 'package:mealvana_endurance/features/subscription/domain/entitlement.dart';
import 'package:mealvana_endurance/shared/providers/is_admin_provider.dart';

const _active = SubscriptionStatus(
  active: true,
  source: SubscriptionSource.revenuecat,
  hadPro: true,
);

/// `pro` held once and expired.
const _lapsed = SubscriptionStatus(active: false, hadPro: true);

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

/// A status controller that re-reads its answer on every build, the way the
/// real one answers for whoever is signed in at the time.
class _MutableStatus extends SubscriptionStatusController {
  _MutableStatus(this.read);
  final SubscriptionStatus Function() read;
  @override
  Future<SubscriptionStatus> build() async => read();
}

void main() {
  group('computeAccess', () {
    test('active → open', () {
      expect(computeAccess(_active, isAdmin: false), AppAccess.open);
    });

    test('held once and expired → closed', () {
      expect(computeAccess(_lapsed, isAdmin: false), AppAccess.closed);
    });

    test('never held → closed', () {
      expect(
        computeAccess(SubscriptionStatus.none, isAdmin: false),
        AppAccess.closed,
      );
    });

    test('an admin is open whatever the status', () {
      for (final s in [SubscriptionStatus.none, _lapsed, _active]) {
        expect(computeAccess(s, isAdmin: true), AppAccess.open, reason: '$s');
      }
    });

    test('the gate has two answers, and only open runs AI', () {
      expect(AppAccess.values, [AppAccess.open, AppAccess.closed]);
      expect(AppAccess.open.allowsAi, isTrue);
      expect(AppAccess.closed.allowsAi, isFalse);
    });
  });

  group('appGateProvider', () {
    ProviderContainer container(
      SubscriptionStatusController Function() status, {
      Future<bool> Function(Ref ref)? admin,
    }) {
      final c = ProviderContainer(
        overrides: [
          subscriptionStatusProvider.overrideWith(status),
          isAdminProvider.overrideWith(admin ?? (_) async => false),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('reflects an active status once resolved', () async {
      final c = container(() => _FixedStatus(_active));
      expect(await c.read(appGateProvider.future), AppAccess.open);
    });

    test('a never-subscribed account is closed', () async {
      final c = container(() => _FixedStatus(SubscriptionStatus.none));
      expect(await c.read(appGateProvider.future), AppAccess.closed);
    });

    test(
      'a lapsed account is closed, the same as a never-subscribed one',
      () async {
        final c = container(() => _FixedStatus(_lapsed));
        expect(await c.read(appGateProvider.future), AppAccess.closed);
      },
    );

    test('an admin with no subscription is unlocked', () async {
      final c = container(
        () => _FixedStatus(SubscriptionStatus.none),
        admin: (_) async => true,
      );
      expect(await c.read(appGateProvider.future), AppAccess.open);
    });

    test('an admin read that never answers locks within the bound', () async {
      final c = ProviderContainer(
        overrides: [
          subscriptionStatusProvider.overrideWith(
            () => _FixedStatus(SubscriptionStatus.none),
          ),
          isAdminProvider.overrideWith((_) => Completer<bool>().future),
          entitlementAnswerTimeoutProvider.overrideWithValue(
            const Duration(milliseconds: 20),
          ),
        ],
      );
      addTearDown(c.dispose);
      expect(await c.read(appGateProvider.future), AppAccess.closed);
    });

    test('is loading while the status is unresolved, then settles', () async {
      final deferred = _DeferredStatus();
      final c = container(() => deferred);
      expect(c.read(appGateProvider).isLoading, isTrue);

      final pending = c.read(appGateProvider.future);
      deferred.completer.complete(_active);
      expect(await pending, AppAccess.open);
    });

    test(
      'follows a status flip (the gate reacts when RevenueCat refreshes)',
      () async {
        final fixed = _FixedStatus(SubscriptionStatus.none);
        final c = container(() => fixed);
        final sub = c.listen(appGateProvider, (_, _) {});
        addTearDown(sub.close);
        expect(await c.read(appGateProvider.future), AppAccess.closed);

        // The controller's own setter path, as a RevenueCat push uses it.
        fixed.state = const AsyncData(_active);
        await Future<void>.delayed(Duration.zero);

        expect(await c.read(appGateProvider.future), AppAccess.open);
      },
    );
  });

  group('settle (the sign-in hand-off to the router)', () {
    test(
      'rebuilds for the user now signed in and answers the new value',
      () async {
        // Before sign-in the status answers for nobody: locked.
        var status = SubscriptionStatus.none;
        final c = ProviderContainer(
          overrides: [
            subscriptionStatusProvider.overrideWith(
              () => _MutableStatus(() => status),
            ),
            isAdminProvider.overrideWith((_) async => false),
          ],
        );
        addTearDown(c.dispose);
        expect(await c.read(appGateProvider.future), AppAccess.closed);

        // The credentials land; the status now answers for the athlete.
        status = _active;
        expect(await c.read(appGateProvider.notifier).settle(), AppAccess.open);
        // The router's synchronous read sees the same settled answer.
        final gate = c.read(appGateProvider);
        expect(gate.hasValue && !gate.isLoading, isTrue);
        expect(gate.value, AppAccess.open);
      },
    );

    test(
      'a status that never answers settles locked within the bound',
      () async {
        final c = ProviderContainer(
          overrides: [
            subscriptionStatusProvider.overrideWith(_DeferredStatus.new),
            isAdminProvider.overrideWith((_) async => false),
            entitlementAnswerTimeoutProvider.overrideWithValue(
              const Duration(milliseconds: 20),
            ),
          ],
        );
        addTearDown(c.dispose);
        expect(
          await c.read(appGateProvider.notifier).settle(),
          AppAccess.closed,
        );
      },
    );
  });

  group('writeAccessProvider (the AI-action check)', () {
    ProviderContainer container(
      SubscriptionStatus status, {
      bool isAdmin = false,
    }) {
      final c = ProviderContainer(
        overrides: [
          subscriptionStatusProvider.overrideWith(() => _FixedStatus(status)),
          isAdminProvider.overrideWith((_) async => isAdmin),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('open runs AI', () async {
      expect(await container(_active).read(writeAccessProvider.future), isTrue);
    });

    test('closed (lapsed) runs no AI', () async {
      expect(
        await container(_lapsed).read(writeAccessProvider.future),
        isFalse,
      );
    });

    test('closed (never subscribed) runs no AI', () async {
      expect(
        await container(
          SubscriptionStatus.none,
        ).read(writeAccessProvider.future),
        isFalse,
      );
    });

    test('a lapsed admin runs AI', () async {
      expect(
        await container(
          _lapsed,
          isAdmin: true,
        ).read(writeAccessProvider.future),
        isTrue,
      );
    });
  });

  group('readAppGate (the router redirect)', () {
    test('answers from the settled value without waiting', () async {
      final c = ProviderContainer(
        overrides: [
          subscriptionStatusProvider.overrideWith(() => _FixedStatus(_active)),
          isAdminProvider.overrideWith((_) async => false),
        ],
      );
      addTearDown(c.dispose);
      await c.read(appGateProvider.future);

      final viaRef = Provider<Future<AppAccess>>((ref) => readAppGate(ref));
      expect(await c.read(viaRef), AppAccess.open);
    });

    test('waits for an unresolved status', () async {
      final deferred = _DeferredStatus();
      final c = ProviderContainer(
        overrides: [
          subscriptionStatusProvider.overrideWith(() => deferred),
          isAdminProvider.overrideWith((_) async => false),
        ],
      );
      addTearDown(c.dispose);

      final viaRef = Provider<Future<AppAccess>>((ref) => readAppGate(ref));
      final pending = c.read(viaRef);
      deferred.completer.complete(SubscriptionStatus.none);
      expect(await pending, AppAccess.closed);
    });
  });
}
