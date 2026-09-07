import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/services/app_config.dart';
import '../domain/entitlement.dart';
import 'subscription_status_provider.dart';

part 'pro_gate.g.dart';

/// The one rule for "may this user see Pro surfaces on the client":
/// the gate is off for this build, or the resolved status is active.
///
/// While the status is still loading (cold start, before RevenueCat and the
/// server have answered) the answer is "locked" when the gate is on — the
/// Drift cache makes that window short for a subscriber, and a locked deep
/// link lands on `/pro`, not on an error.
bool computeProUnlocked({
  required AsyncValue<SubscriptionStatus> status,
  required AppConfig config,
}) {
  if (!config.proGateEnabled) return true;
  return status.asData?.value.active ?? false;
}

/// Reactive form of [computeProUnlocked]. keepAlive so the router's
/// `ref.read` sees the same value the tabs screen is watching.
@Riverpod(keepAlive: true)
bool proUnlocked(Ref ref) {
  return computeProUnlocked(
    status: ref.watch(subscriptionStatusProvider),
    config: ref.watch(appConfigProvider),
  );
}

/// Imperative read for non-widget callers (the GoRouter redirect).
bool isProUnlocked(Ref ref) => ref.read(proUnlockedProvider);
