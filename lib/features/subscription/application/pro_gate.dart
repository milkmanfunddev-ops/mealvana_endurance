import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/providers/is_admin_provider.dart';
import '../domain/entitlement.dart';
import 'subscription_status_provider.dart';

part 'pro_gate.g.dart';

/// The rule for "may this user see the app": the resolved subscription
/// status is active, or the signed-in user is a team admin (`users.is_admin`,
/// set by hand in the database). There is no build flag, no tester grant and
/// no coach branch (mp-279, mp-280, mp-286); the admin bypass is Lee's
/// 2026-09-16 exception so the team's own accounts never meet the paywall.
bool computeUnlocked(SubscriptionStatus status, {required bool isAdmin}) =>
    status.active || isAdmin;

/// The app gate, as the router reads it (mp-280: everything is behind it).
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
  FutureOr<bool> build() async {
    final status = await ref.watch(subscriptionStatusProvider.future);
    if (status.active) return true;
    final timeout = ref.read(entitlementAnswerTimeoutProvider);
    final isAdmin = await ref
        .watch(isAdminProvider.future)
        .timeout(timeout, onTimeout: () => false);
    return computeUnlocked(status, isAdmin: isAdmin);
  }
}

/// Whether the app is unlocked, for a non-widget caller (the GoRouter
/// redirect). Answers from the settled value when there is one; otherwise
/// waits for the status controller's bounded resolve.
Future<bool> readAppGate(Ref ref) {
  final gate = ref.read(appGateProvider);
  if (gate.hasValue && !gate.isLoading) return Future.value(gate.value!);
  return ref.read(appGateProvider.future);
}
