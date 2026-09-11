/// Where the Vana launcher may appear.
///
/// vana-sheet spec, "Where the launcher does not appear": absent on
/// authentication, onboarding, privacy consent, paywall, force-upgrade, every
/// Vana route, and flow screens. Everywhere else it appears, including
/// screens with no Situation to report. A launcher that summons the surface
/// the athlete is already on is a bug, not a shortcut.
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

/// Flow screens: the screen's job ends in a full-width bottom action
/// (creating or editing something, a wizard step, a form), and the launcher
/// would cover its right end. Exact route patterns, not prefixes: the
/// browsing screens beside and below them keep the launcher.
///
/// A flow screen pushed without the router (a `MaterialPageRoute`) names
/// itself with `RouteSettings`; the name is one of these. The event form and
/// food detail reuse their router patterns.
const _flowPatterns = [
  // New activity ("Generate Plan"), and the macro step after it.
  '/distancepacegut',
  '/distance-pace-gut-entry',
  '/adjust-macros',
  '/events/create',
  // Settings that edit one thing and end in Save.
  '/settings/preferences',
  '/settings/sweat-profile',
  '/settings/sport-settings',
  '/settings/nutrition-targets',
  '/settings/food-preferences-consolidated',
  '/settings/food-preferences',
  '/settings/dietary-preference',
  '/settings/allergies',
  '/settings/running-details',
  '/settings/cycling-details',
  '/settings/swimming-details',
  '/settings/food-preferences/formula-library/personal/create',
  '/settings/food-preferences/formula-library/personal/:id',
  // Picking or creating a food.
  '/swap-food',
  '/food-detail',
  '/carb-loading-select-food',
  '/create-custom-carb-loading-food',
  '/coach/apply',
  // The coach chat's composer: its send button sits under the launcher.
  '/chat/:relationshipId',
  // Logging a meal.
  '/meal-log/edit',
  '/meal-log/manual',
  '/meal-log/describe',
  '/meal-log/review',
  '/meal-log/recent-saved',
  // Pushed without the router: the names their `routeSettings` carry.
  '/meal-log/build',
  '/meal-log/scanned',
  // Cooking steps (Back / Next) and the Kroger send.
  '/food/cook/:id',
  '/food/kroger/:planId',
];

bool _under(String path, String prefix) =>
    path == prefix || path.startsWith('$prefix/');

/// Whether [path] (a location or a pattern) is [pattern]: segment by segment,
/// where a `:param` segment stands for exactly one segment.
bool _matches(String path, String pattern) {
  final segments = path.split('/');
  final expected = pattern.split('/');
  if (segments.length != expected.length) return false;
  for (var i = 0; i < segments.length; i++) {
    final matches = expected[i].startsWith(':')
        ? segments[i].isNotEmpty
        : segments[i] == expected[i];
    if (!matches) return false;
  }
  return true;
}

/// Whether [path] is a flow screen (see [_flowPatterns]).
bool _isFlowRoute(String path) => _flowPatterns.any((p) => _matches(path, p));

/// Whether [path] is one of Vana's own routes.
bool isVanaRoute(String path) => _vanaPrefixes.any((p) => _under(path, p));

/// Whether the launcher renders over [path] (a location or a route pattern).
/// `/` is the startup splash, which is not a screen.
bool vanaLauncherShownOn(String path) {
  if (path.isEmpty || path == '/') return false;
  if (isVanaRoute(path) || _isFlowRoute(path)) return false;
  return !_gatePrefixes.any((p) => _under(path, p));
}
