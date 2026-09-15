/// Where the Vana launcher appears (mp-264): on three screens, and nowhere
/// else. Checked against every route the real router declares, so a new
/// route never shows the launcher by accident.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_launcher_rule.dart';
import 'package:mealvana_endurance/shared/core/app_router.dart';

/// The three screens, as mp-264 names them: the main tabs screen, the
/// meal-planning screen and coach formulas (the formula library).
const _allowed = {'/main', '/food', '/settings/food-preferences/formula-library'};

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

  test('the rule names the three screens, and the router declares them', () {
    expect(vanaLauncherRoutes.toSet(), _allowed);
    expect(paths, containsAll(_allowed));
  });

  test('the launcher is present on exactly the three screens', () {
    for (final path in paths) {
      expect(vanaLauncherShownOn(path), _allowed.contains(path), reason: path);
    }
  });

  test('a route pushed over one of the three is not one of the three', () {
    // The tree under an allowed screen is pushed over it, so it hides the
    // launcher: no prefix match.
    expect(vanaLauncherShownOn('/food/meals/D-048'), isFalse);
    expect(vanaLauncherShownOn('/food/cook/D-048'), isFalse);
    expect(vanaLauncherShownOn('/food/kroger/plan-1'), isFalse);
    expect(
      vanaLauncherShownOn(
        '/settings/food-preferences/formula-library/personal/f-1',
      ),
      isFalse,
    );
    expect(vanaLauncherShownOn('/main/anything'), isFalse);
    // Nor a partial segment.
    expect(vanaLauncherShownOn('/mainly'), isFalse);
    expect(vanaLauncherShownOn('/foods'), isFalse);
  });

  test('the routes the old deny-list named are simply not allowed', () {
    for (final path in [
      '/',
      '',
      '/settings',
      '/events',
      '/events/create',
      '/plan',
      '/fuel-log',
      '/distancepacegut',
      '/meal-log/review',
      '/pro',
      '/onboarding',
      '/vana',
      '/vana/browse',
      '/settings/vana',
    ]) {
      expect(vanaLauncherShownOn(path), isFalse, reason: path);
    }
  });

  test('a location matches its screen whatever its query string carried', () {
    // The host hands the rule a path, never a query: `/main?tab=food` is the
    // main tabs screen.
    expect(vanaLauncherShownOn('/main'), isTrue);
    expect(vanaLauncherShownOn('/food'), isTrue);
    expect(vanaLauncherShownOn('/settings/food-preferences/formula-library'),
        isTrue);
  });

  test('Vana routes are Vana routes, and nothing else is', () {
    expect(isVanaRoute('/vana'), isTrue);
    expect(isVanaRoute('/vana/conversations'), isTrue);
    expect(isVanaRoute('/settings/vana'), isTrue);
    expect(isVanaRoute('/jade'), isTrue);
    expect(isVanaRoute('/settings'), isFalse);
    expect(isVanaRoute('/pro'), isFalse);
    // A prefix match is on the segment: `/vanadium` is not a Vana route.
    expect(isVanaRoute('/vanadium'), isFalse);
  });
}
