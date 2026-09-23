import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/providers/is_admin_provider.dart';
import '../domain/entitlement.dart';
import 'subscription_status_provider.dart';

part 'pro_gate.g.dart';

/// The gate's rule (mp-457): open when the resolved subscription status is
/// active or the signed-in user is a team admin (`users.is_admin`, set by
/// hand in the database; mp-416); closed otherwise, whether the account held
/// `pro` once or never did, and for an unknown answer (mp-284, mp-611).
/// There is no build flag, no tester grant and no coach branch (mp-279,
/// mp-280, mp-286).
AppAccess computeAccess(SubscriptionStatus status, {required bool isAdmin}) =>
    status.active || isAdmin ? AppAccess.open : AppAccess.closed;

/// The app gate, as the router reads it (mp-280: everything is behind it):
/// open or closed (mp-457).
///
/// Loading while the status is unresolved — the status controller bounds
/// that wait (mp-284), so awaiting `.future` here answers within a couple of
/// seconds. The admin read is consulted only for an inactive status and is
/// bounded by the same timeout, so a slow network still lands on the
/// paywall instead of hanging the redirect. keepAlive so the router's
/// `ref.read` sees the same value every screen watches.
@Riverpod(keepAlive: true)
class AppGate extends _$AppGate {
  @override
  FutureOr<AppAccess> build() async {
    final status = await ref.watch(subscriptionStatusProvider.future);
    if (status.active) return AppAccess.open;
    final timeout = ref.read(entitlementAnswerTimeoutProvider);
    final isAdmin = await ref
        .watch(isAdminProvider.future)
        .timeout(timeout, onTimeout: () => false);
    return computeAccess(status, isAdmin: isAdmin);
  }

  /// Sign-in's hand-off to the router (2026-09-16: the first login came back
  /// to the Log In screen; the second went through).
  ///
  /// Signing in changes the user the status and admin reads answer for, so
  /// the gate rebuilds a moment after the credentials land. A `go('/main')`
  /// sent while it is loading awaits the gate inside its async redirect; the
  /// gate's settling then rebuilds the root widget (which watches it) and
  /// fires the router's refresh. Flutter's Router keeps only its newest route
  /// parse, and that refresh re-parses the location last reported — the
  /// login screen — so the trip to main is discarded. The second login finds
  /// the gate settled and its redirect answers synchronously, which is why it
  /// works.
  ///
  /// Rebuilding the gate for the signed-in user here and waiting for its
  /// answer before navigating leaves the redirect nothing to await: it
  /// resolves in the same parse, and a later refresh with the same value
  /// never fires. Bounded by twice the entitlement timeout; no answer means
  /// closed, which the paywall then resolves the usual way.
  Future<AppAccess> settle() async {
    ref.invalidate(subscriptionStatusProvider);
    ref.invalidate(isAdminProvider);
    ref.invalidateSelf();
    final timeout = ref.read(entitlementAnswerTimeoutProvider) * 2;
    try {
      return await future.timeout(timeout);
    } catch (_) {
      return AppAccess.closed;
    }
  }
}

/// The gate's answer, for a non-widget caller (the GoRouter redirect).
/// Answers from the settled value when there is one; otherwise waits for the
/// status controller's bounded resolve.
Future<AppAccess> readAppGate(Ref ref) {
  final gate = ref.read(appGateProvider);
  if (gate.hasValue && !gate.isLoading) return Future.value(gate.value!);
  return ref.read(appGateProvider.future);
}

/// The one write-access rule (mp-457 §4): whether this account may write or
/// call AI right now. True only when the gate is open; an unresolved gate
/// waits for the gate's bounded answer (an unknown answer is closed, so no).
/// A write controller awaits this before writing and opens the paywall
/// instead when it says no (ticket 20 removes the check).
@Riverpod(keepAlive: true)
Future<bool> writeAccess(Ref ref) async =>
    (await ref.watch(appGateProvider.future)).canWrite;
