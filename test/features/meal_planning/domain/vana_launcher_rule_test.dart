/// Where the Vana launcher may appear (vana-sheet spec, "Where the launcher
/// does not appear"), checked against every route the real router declares.
///
/// The excluded sets below are the spec's lists written out as paths, on
/// purpose independent of the rule under test: a new route under `/auth` or
/// `/vana` is caught by the rule, and a new route the spec never named shows
/// the launcher.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/features/events/presentation/screens/event_form_screen.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/screens/build_meal_screen.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/screens/log_scanned_food_screen.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_launcher_rule.dart';
import 'package:mealvana_endurance/shared/core/app_router.dart';
import 'package:mealvana_endurance/shared/screens/food_detail_screen.dart';

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

/// Flow screens (the spec's "Also absent on flow screens"): the screen's job
/// ends in a full-width bottom action, which the launcher would cover.
const _flow = {
  '/distancepacegut',
  '/distance-pace-gut-entry',
  '/adjust-macros',
  '/events/create',
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
  '/swap-food',
  '/food-detail',
  '/carb-loading-select-food',
  '/create-custom-carb-loading-food',
  '/coach/apply',
  '/chat/:relationshipId',
  '/meal-log/edit',
  '/meal-log/manual',
  '/meal-log/describe',
  '/meal-log/review',
  '/meal-log/recent-saved',
  '/meal-log/build',
  '/meal-log/scanned',
  '/food/cook/:id',
  '/food/kroger/:planId',
};

/// Flow screens the app pushes without the router, named by their
/// `routeSettings`: the router does not declare them.
const _pageless = {'/meal-log/build', '/meal-log/scanned'};

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

  test('the router declares every flow screen it opens', () {
    expect(paths, containsAll(_flow.difference(_pageless)));
    expect(paths, isNot(contains(anyOf(_pageless.toList()))));
  });

  test('flow screens pushed without the router name themselves as flow '
      'screens', () {
    for (final settings in [
      EventFormScreen.routeSettings,
      FoodDetailScreen.routeSettings,
      BuildMealScreen.routeSettings,
      LogScannedFoodScreen.routeSettings,
    ]) {
      expect(_flow, contains(settings.name), reason: settings.name);
      expect(
        vanaLauncherShownOn(settings.name!),
        isFalse,
        reason: settings.name,
      );
    }
  });

  test('the launcher is absent on exactly the excluded set and the flow '
      'screens', () {
    for (final path in paths) {
      expect(
        vanaLauncherShownOn(path),
        !_excluded.contains(path) && !_flow.contains(path),
        reason: path,
      );
    }
  });

  test('a flow screen is itself, not the tree under it', () {
    // Browsing screens beside and below flow screens keep the launcher.
    expect(vanaLauncherShownOn('/events'), isTrue);
    expect(vanaLauncherShownOn('/events/e1/checklist'), isTrue);
    expect(vanaLauncherShownOn('/food/meals/D-048'), isTrue);
    expect(vanaLauncherShownOn('/plan'), isTrue);
    expect(vanaLauncherShownOn('/settings/food-preferences/add-food'), isTrue);
    expect(
      vanaLauncherShownOn('/settings/food-preferences/formula-library'),
      isTrue,
    );
    expect(vanaLauncherShownOn('/events/create/extra'), isTrue);
  });

  test('a flow screen with a parameter matches at its concrete location', () {
    expect(vanaLauncherShownOn('/food/cook/D-048'), isFalse);
    expect(vanaLauncherShownOn('/food/kroger/plan-1'), isFalse);
    expect(vanaLauncherShownOn('/chat/rel-1'), isFalse);
    expect(
      vanaLauncherShownOn(
        '/settings/food-preferences/formula-library/personal/f-1',
      ),
      isFalse,
    );
    // A parameter stands for one segment, never zero or two.
    expect(vanaLauncherShownOn('/food/cook'), isTrue);
    expect(vanaLauncherShownOn('/food/cook/D-048/more'), isTrue);
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
