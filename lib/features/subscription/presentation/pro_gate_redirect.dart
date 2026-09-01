/// GoRouter redirect helper for the Pro gate.
///
/// Pure functions so the redirect rule is unit-testable without a router:
/// `app_router.dart` combines [isProGatedPath] with `isProUnlocked(ref)`.
library;

/// Route prefixes that require Pro. Meal planning lands here in Phase 4
/// (`/food/*` — plan, meals, cook; `/vana/*` — the Vana chat).
const List<String> kProGatedPathPrefixes = ['/food', '/vana'];

/// Where a locked user is sent.
const String kProPaywallPath = '/pro';

/// Whether [path] is behind the Pro gate. Prefix match on the path segment,
/// so `/foods` (were it ever added) would not be caught by `/food`.
bool isProGatedPath(String path) {
  for (final prefix in kProGatedPathPrefixes) {
    if (path == prefix || path.startsWith('$prefix/')) return true;
  }
  return false;
}

/// The redirect for [path] given whether Pro is [unlocked]: the paywall for a
/// locked gated path, null (no redirect) otherwise.
String? proGateRedirect({required String path, required bool unlocked}) {
  if (isProGatedPath(path) && !unlocked) return kProPaywallPath;
  return null;
}
