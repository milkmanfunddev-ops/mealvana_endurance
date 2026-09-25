/// GoRouter redirect rule for the app gate (mp-280: everything is behind
/// the one gate).
///
/// Pure functions so the rule is unit-testable without a router:
/// `app_router.dart` combines [gateRedirect] with `readAppGate(ref)`.
library;

import 'package:go_router/go_router.dart';

import '../application/paywall_location.dart';
import '../domain/entitlement.dart';

export '../application/paywall_location.dart';

/// Routes the gate never touches: the root (startup), the force-upgrade and
/// consent screens, and the public welcome / onboarding / auth flows —
/// everything a person can reach before they have an account to gate.
/// The session check in the router already sends a signed-out visitor of
/// any other route to `/welcome`.
bool isUngatedPath(String path) {
  if (path == '/' ||
      path == '/force-upgrade' ||
      path == '/privacy-consent' ||
      path == '/welcome') {
    return true;
  }
  for (final prefix in const ['/onboarding', '/auth']) {
    if (path == prefix || path.startsWith('$prefix/')) return true;
  }
  return false;
}

/// The redirect for [path] given the gate's [access] (mp-457, mp-611):
/// - an ungated path is never redirected;
/// - closed: every other route lands on the full-screen paywall and stays
///   there, whether the account never had Pro or it ran out (mp-280);
/// - open: everything renders, and the paywall yields to `/main`, so a
///   purchase, restore, redeemed Code or background refresh moves the person
///   in without the screen navigating itself.
String? gateRedirect({required String path, required AppAccess access}) {
  if (isUngatedPath(path)) return null;
  if (path == kPaywallPath) return access == AppAccess.open ? '/main' : null;
  return access == AppAccess.open ? null : kPaywallPath;
}

/// Where the startup redirect sends an onboarded, signed-in account from
/// `/`: the app when the Gate is open, and straight to the paywall when it
/// is closed, so the router never passes through `/main` on the way
/// (ticket 105, Finding 87-009).
String startupLanding(AppAccess access) =>
    access == AppAccess.open ? '/main' : kPaywallPath;

/// The location path of the route on top of [config]; a pushed route
/// carries its own match list.
String topPathOf(RouteMatchList config) {
  if (config.matches.isEmpty) return '';
  final last = config.last;
  final list = last is ImperativeRouteMatch ? last.matches : config;
  return list.uri.path;
}
