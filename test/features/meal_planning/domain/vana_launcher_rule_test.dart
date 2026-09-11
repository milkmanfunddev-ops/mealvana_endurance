/// Where the Vana launcher may appear (vana-sheet spec, "Where the launcher
/// does not appear"), checked against every route the real router declares.
///
/// The excluded set below is the spec's list written out as paths, on purpose
/// independent of the rule under test: a new route under `/auth` or `/vana`
/// is caught by the rule, and a new route the spec never named shows the
/// launcher.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_launcher_rule.dart';
import 'package:mealvana_endurance/shared/core/app_router.dart';

/// The spec's excluded set: authentication, onboarding, privacy consent,
/// paywall, force-upgrade, and every Vana route.
const _excluded = {
  '/welcome',
  '/auth/post-onboarding',
  '/auth/email-signup',
  '/auth/email-login',
  '/auth/forgot-password',
  '/auth/verify-reset-code',
  '/auth/set-new-password',
  '/onboarding',
  '/privacy-consent',
  '/pro',
  '/buy-credits',
  '/force-upgrade',
  '/vana',
  '/vana/browse',
  '/vana/conversations',
  '/settings/vana',
  '/jade',
};

List<String> _paths(List<RouteBase> routes, [String parent = '']) => [
  for (final r in routes)
    if (r is GoRoute) ...[
      r.path.startsWith('/')
          ? r.path
          : '${parent == '/' ? '' : parent}/${r.path}',
      ..._paths(
        r.routes,
        r.path.startsWith('/')
            ? r.path
            : '${parent == '/' ? '' : parent}/${r.path}',
      ),
    ] else
      ..._paths(r.routes, parent),
];

void main() {
  final container = ProviderContainer();
  tearDownAll(container.dispose);
  final router = container.read(AppRouter.routerProvider);
  final paths = _paths(router.configuration.routes);

  test('the router declares every route the spec excludes', () {
    expect(paths, containsAll(_excluded));
  });

  test('the launcher is absent on exactly the excluded set', () {
    for (final path in paths) {
      expect(
        vanaLauncherShownOn(path),
        !_excluded.contains(path),
        reason: path,
      );
    }
  });

  test('the root path is the startup splash, not a screen', () {
    expect(vanaLauncherShownOn('/'), isFalse);
  });

  test('concrete locations follow their pattern', () {
    expect(vanaLauncherShownOn('/food/meals/D-048'), isTrue);
    expect(vanaLauncherShownOn('/main'), isTrue);
    expect(vanaLauncherShownOn('/settings'), isTrue);
    expect(vanaLauncherShownOn('/vana/browse'), isFalse);
    expect(vanaLauncherShownOn('/onboarding/anything'), isFalse);
    // A prefix match is on the segment: `/vanadium` is not a Vana route.
    expect(vanaLauncherShownOn('/vanadium'), isTrue);
    expect(vanaLauncherShownOn('/professional'), isTrue);
  });

  test('Vana routes are Vana routes, and nothing else is', () {
    expect(isVanaRoute('/vana'), isTrue);
    expect(isVanaRoute('/vana/conversations'), isTrue);
    expect(isVanaRoute('/settings/vana'), isTrue);
    expect(isVanaRoute('/jade'), isTrue);
    expect(isVanaRoute('/settings'), isFalse);
    expect(isVanaRoute('/pro'), isFalse);
  });
}
