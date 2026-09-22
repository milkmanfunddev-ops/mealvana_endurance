/// Where the paywall lives in the router, as the gate and the write guard
/// know it. Application-level so a controller can open the paywall without
/// importing presentation; `pro_gate_redirect.dart` re-exports it for the
/// router and the screens.
library;

import 'package:go_router/go_router.dart';

/// Where a locked user is sent, and stays.
const String kPaywallPath = '/paywall';

/// The paywall as onboarding's last step. Same route; the query selects the
/// shape. Its ⋯ menu carries the same entries as the lapsed shape (mp-494 §2,
/// which replaced mp-417 §3's "Restore only"). The gate's redirect still moves
/// an unlocked account on to `/main`.
const String kOnboardingPaywallQuery = 'onboarding';
const String kOnboardingPaywallLocation =
    '$kPaywallPath?$kOnboardingPaywallQuery=1';

/// The location path of the route on top of [config]; a pushed route
/// carries its own match list.
String topPathOf(RouteMatchList config) {
  if (config.matches.isEmpty) return '';
  final last = config.last;
  final list = last is ImperativeRouteMatch ? last.matches : config;
  return list.uri.path;
}
