/// Where the Vana launcher appears.
///
/// mp-264: on three screens, and nowhere else. The rule is an allow-list of
/// three routes; there is no everywhere rule, no flow-screen list and no
/// auth-or-onboarding exclusion list. Any page pushed over one of the three
/// hides the launcher (the host sees the push; see `VanaCompanionObserver`),
/// so a pushed form never needs to name itself. Widening to more screens is
/// a later decision.
library;

/// The three screens: the main tabs screen, the meal-planning screen and
/// coach formulas (the formula library). Exact locations, not prefixes: the
/// tree under each is pushed over it, and hides the launcher.
const vanaLauncherRoutes = [
  '/main',
  '/food',
  '/settings/food-preferences/formula-library',
];

/// Vana's own surfaces: the chat and everything under it, her settings, and
/// the legacy `/jade` alias. They speak for no screen: the Situation keeps
/// the screen underneath.
const _vanaPrefixes = ['/vana', '/settings/vana', '/jade'];

bool _under(String path, String prefix) =>
    path == prefix || path.startsWith('$prefix/');

/// Whether [path] is one of Vana's own routes.
bool isVanaRoute(String path) => _vanaPrefixes.any((p) => _under(path, p));

/// Whether the launcher renders over [path], the location path of the route
/// on top (no query string: `/main?tab=food` arrives as `/main`).
bool vanaLauncherShownOn(String path) => vanaLauncherRoutes.contains(path);
