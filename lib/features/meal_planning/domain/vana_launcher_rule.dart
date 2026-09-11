/// Where the Vana launcher may appear.
///
/// vana-sheet spec, "Where the launcher does not appear": absent on
/// authentication, onboarding, privacy consent, paywall, force-upgrade and
/// every Vana route. Everywhere else it appears, including screens with no
/// Situation to report. A launcher that summons the surface the athlete is
/// already on is a bug, not a shortcut.
library;

/// Vana's own surfaces: the chat and everything under it, her settings, and
/// the legacy `/jade` alias.
const _vanaPrefixes = ['/vana', '/settings/vana', '/jade'];

/// Authentication, onboarding, privacy consent, the paywalls (Pro and the
/// credits paywall the 402 flows push) and force-upgrade.
const _gatePrefixes = [
  '/welcome',
  '/auth',
  '/onboarding',
  '/privacy-consent',
  '/pro',
  '/buy-credits',
  '/force-upgrade',
];

bool _under(String path, String prefix) =>
    path == prefix || path.startsWith('$prefix/');

/// Whether [path] is one of Vana's own routes.
bool isVanaRoute(String path) => _vanaPrefixes.any((p) => _under(path, p));

/// Whether the launcher renders over [path] (a location or a route pattern).
/// `/` is the startup splash, which is not a screen.
bool vanaLauncherShownOn(String path) {
  if (path.isEmpty || path == '/') return false;
  if (isVanaRoute(path)) return false;
  return !_gatePrefixes.any((p) => _under(path, p));
}
