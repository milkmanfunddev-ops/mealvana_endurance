/// GoRouter redirect rule for the app gate (mp-280: everything is behind
/// the one gate).
///
/// Pure functions so the rule is unit-testable without a router:
/// `app_router.dart` combines [gateRedirect] with `readAppGate(ref)`.
library;

import '../domain/entitlement.dart';

/// Where a locked user is sent, and stays.
const String kPaywallPath = '/paywall';

/// The paywall as onboarding's last step: plans and Restore only, no
/// account actions (a person who just created the account is not lapsed).
/// Same route; the query selects the shape. The gate's redirect still moves
/// an unlocked account on to `/main`.
const String kOnboardingPaywallQuery = 'onboarding';
const String kOnboardingPaywallLocation =
    '$kPaywallPath?$kOnboardingPaywallQuery=1';

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

/// The routes that call AI the moment they open: Vana's chat and
/// everything under it, the legacy `/jade` alias (Vana general), and the
/// meal-AI log screens (photo, describe). A lapsed account is sent to the
/// paywall instead (mp-457 §3); Vana's own settings are not an AI call.
const List<String> kAiRoutePrefixes = [
  '/vana',
  '/jade',
  '/meal-log/photo',
  '/meal-log/describe',
];

/// Whether [path] is one of [kAiRoutePrefixes] or under one.
bool isAiPath(String path) => kAiRoutePrefixes.any(
  (prefix) => path == prefix || path.startsWith('$prefix/'),
);

/// The redirect for [path] given the gate's [access] (mp-457):
/// - an ungated path is never redirected;
/// - the paywall renders unless the gate is open, and yields to `/main` once
///   it is, so a purchase, restore or background refresh moves the person
///   in without the screen navigating itself;
/// - never: every other route lands on the paywall;
/// - lapsed: app routes render (read-only, under the plan-ended bar), and an
///   AI route opens the paywall instead;
/// - open: everything renders.
String? gateRedirect({required String path, required AppAccess access}) {
  if (isUngatedPath(path)) return null;
  if (path == kPaywallPath) return access == AppAccess.open ? '/main' : null;
  return switch (access) {
    AppAccess.open => null,
    AppAccess.lapsed => isAiPath(path) ? kPaywallPath : null,
    AppAccess.never => kPaywallPath,
  };
}
