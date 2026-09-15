/// GoRouter redirect rule for the app gate (mp-280: everything is behind
/// the one gate).
///
/// Pure functions so the rule is unit-testable without a router:
/// `app_router.dart` combines [gateRedirect] with `readAppGate(ref)`.
library;

/// Where a locked user is sent, and stays.
const String kPaywallPath = '/paywall';

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

/// The redirect for [path] given whether the app is [unlocked]:
/// - an ungated path is never redirected;
/// - the paywall renders while locked and yields to `/main` once unlocked,
///   so a purchase, restore or background refresh moves the person in
///   without the screen navigating itself;
/// - every other route lands on the paywall while locked.
String? gateRedirect({required String path, required bool unlocked}) {
  if (isUngatedPath(path)) return null;
  if (path == kPaywallPath) return unlocked ? '/main' : null;
  return unlocked ? null : kPaywallPath;
}
