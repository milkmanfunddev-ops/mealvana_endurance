import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/entitlement.dart';
import 'subscription_status_provider.dart';

part 'pro_gate.g.dart';

/// The one rule for "may this user see the app": the resolved subscription
/// status is active. There is no build flag, no tester grant and no coach
/// branch (mp-279, mp-280, mp-286).
bool computeUnlocked(SubscriptionStatus status) => status.active;

/// The app gate, as the router reads it (mp-280: everything is behind it).
///
/// Loading while the status is unresolved — the status controller bounds
/// that wait (mp-284), so awaiting `.future` here answers within a couple of
/// seconds. keepAlive so the router's `ref.read` sees the same value every
/// screen watches.
@Riverpod(keepAlive: true)
class AppGate extends _$AppGate {
  @override
  FutureOr<bool> build() async {
    final status = await ref.watch(subscriptionStatusProvider.future);
    return computeUnlocked(status);
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
