// ai-cost ticket 03 (mp-432 / mp-468): nothing calls the server before the
// athlete opens the Food tab.
//
// Seam: [VanaTransport] — every `vana-action` / `vana-chat` request in the app
// goes through `postJson` / `streamNdjson`. The fake here counts them, so the
// assertion is "how many server calls did the shell start", not "which widget
// built". The device is reported online, because every Food controller
// short-circuits while offline and would hide the regression.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:mealvana_endurance/features/integrations/presentation/providers/integrations_providers.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_chat_repository.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_transport.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/screens/food_screen.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/screens/meals_tab.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/screens/plan_tab.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/screens/shopping_tab.dart';
import 'package:mealvana_endurance/shared/core/app_router.dart';
import 'package:mealvana_endurance/shared/services/connectivity_checker.dart';
import 'package:mealvana_endurance/shared/widgets/tabs_screen.dart';

import '../../helpers/widget_test_harness.dart';

/// Counts every request the app starts and answers each with an empty result,
/// so nothing downstream sees a network error.
class _CountingTransport extends Mock implements VanaTransport {
  final List<String> calls = [];

  @override
  Future<Map<String, dynamic>> postJson(
    String functionName,
    Map<String, dynamic> body,
  ) async {
    calls.add('$functionName:${body['type'] ?? body['action'] ?? ''}');
    return <String, dynamic>{'parts': <dynamic>[]};
  }

  @override
  Future<NdjsonResponse> streamNdjson(
    String functionName,
    Map<String, dynamic> body,
  ) async {
    calls.add('$functionName:stream');
    return NdjsonResponse(
      headers: const {},
      lines: const Stream<Map<String, dynamic>>.empty(),
    );
  }
}

class _AlwaysOnline implements ConnectivityChecker {
  const _AlwaysOnline();

  @override
  Future<bool> isOnline() async => true;
}

PackageInfo _packageInfo() => PackageInfo(
  appName: 'Mealvana',
  packageName: 'com.milkman.mealvanaendurance',
  version: '1.0.0',
  buildNumber: '1',
);

List<Override> _shellOverrides(_CountingTransport transport) => [
  vanaTransportProvider.overrideWithValue(transport),
  connectivityCheckerProvider.overrideWithValue(const _AlwaysOnline()),
  packageInfoProvider.overrideWith((ref) async => _packageInfo()),
];

/// `find.byType` skips offstage subtrees by default, and an `IndexedStack`
/// marks every unselected child offstage — so a tab that was built but is not
/// showing would read as "not built". These finders see the whole tree.
Finder _anywhere(Type type) => find.byType(type, skipOffstage: false);

Future<void> _settleShell(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

/// The real `/main` route builder ([mainTabsScreen]) under a router, with a
/// pushed chat page standing in for the Vana chat whose Confirm calls
/// [goToFoodTab]. `go` back to `/main` reuses the shell already under the
/// chat (same page key), which is what the device run hit (16-002).
GoRouter _confirmRouter() => GoRouter(
  initialLocation: '/main',
  routes: [
    GoRoute(path: '/main', builder: (_, state) => mainTabsScreen(state)),
    GoRoute(
      path: '/vana',
      builder: (context, _) => Scaffold(
        body: Center(
          child: TextButton(
            key: const ValueKey('test.confirm'),
            onPressed: () => goToFoodTab(context, FoodTab.shopping),
            child: const Text('Confirm plan'),
          ),
        ),
      ),
    ),
  ],
);

void main() {
  testWidgets('no Vana request fires between launch and the first Food visit', (
    tester,
  ) async {
    final transport = _CountingTransport();

    await pumpSeeded(
      tester,
      const TabsScreen(),
      overrides: _shellOverrides(transport),
    );
    await _settleShell(tester);

    expect(_anywhere(FoodScreen), findsNothing);
    expect(
      transport.calls,
      isEmpty,
      reason:
          'The shell called the server before the athlete opened Food: '
          '${transport.calls}',
    );
  });

  testWidgets('opening Food builds it, and only the Plan segment', (
    tester,
  ) async {
    final transport = _CountingTransport();

    await pumpSeeded(
      tester,
      const TabsScreen(),
      overrides: _shellOverrides(transport),
    );
    await _settleShell(tester);

    await tester.tap(find.text('Food').first);
    await _settleShell(tester);

    expect(_anywhere(FoodScreen), findsOneWidget);
    expect(_anywhere(PlanTab), findsOneWidget);
    // Meals and Shopping are not built until their pill is tapped.
    expect(_anywhere(MealsTab), findsNothing);
    expect(_anywhere(ShoppingTab), findsNothing);
    expect(transport.calls, isNotEmpty);
  });

  testWidgets(
    'a visited tab keeps its state when the athlete leaves and returns',
    (tester) async {
      final transport = _CountingTransport();

      await pumpSeeded(
        tester,
        const TabsScreen(),
        overrides: _shellOverrides(transport),
      );
      await _settleShell(tester);

      await tester.tap(find.text('Food').first);
      await _settleShell(tester);
      // Move the Food screen off its default segment.
      await tester.tap(find.byKey(const ValueKey('meal_planning.tab_meals')));
      await _settleShell(tester);
      expect(_anywhere(MealsTab), findsOneWidget);
      final callsBefore = List<String>.from(transport.calls);

      // Leave for the Timeline and come back.
      await tester.tap(find.text('Timeline').first);
      await _settleShell(tester);
      await tester.tap(find.text('Food').first);
      await _settleShell(tester);

      // Same FoodScreen State: still on Meals, and nothing re-fetched.
      expect(_anywhere(MealsTab), findsOneWidget);
      expect(_anywhere(PlanTab), findsOneWidget); // built earlier, kept alive
      expect(transport.calls, callsBefore);
    },
  );

  testWidgets(
    'a deep link straight to a Food segment still opens that segment',
    (tester) async {
      final transport = _CountingTransport();

      await pumpSeeded(
        tester,
        const TabsScreen(
          initialTabName: 'food',
          initialFoodTab: FoodTab.shopping,
        ),
        overrides: _shellOverrides(transport),
      );
      await _settleShell(tester);

      expect(_anywhere(FoodScreen), findsOneWidget);
      expect(_anywhere(ShoppingTab), findsOneWidget);
      expect(_anywhere(PlanTab), findsNothing);
    },
  );

  // 16-002 / mp-235: after Confirm the athlete lands on Food > Shopping with
  // the tab bar. The route said `food=shopping`, but the shell under the chat
  // had already built Food on Plan and kept it.
  testWidgets('Confirm from a chat over the shell lands on Food, Shopping', (
    tester,
  ) async {
    final transport = _CountingTransport();
    final router = _confirmRouter();
    addTearDown(router.dispose);

    await pumpSeeded(
      tester,
      Router.withConfig(config: router),
      overrides: _shellOverrides(transport),
    );
    await _settleShell(tester);

    // The athlete has seen Food (on Plan), then opens the planning chat.
    await tester.tap(find.text('Food').first);
    await _settleShell(tester);
    expect(find.byType(PlanTab), findsOneWidget);
    router.push('/vana');
    await _settleShell(tester);

    await tester.tap(find.byKey(const ValueKey('test.confirm')));
    await _settleShell(tester);

    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/main?tab=food&food=shopping',
    );
    expect(find.byType(ShoppingTab), findsOneWidget);
    expect(find.byType(PlanTab), findsNothing);
    // The tab bar is there: the shell, not a bare Food page.
    expect(find.byType(TabsScreen), findsOneWidget);
    expect(find.text('Timeline'), findsWidgets);
  });

  // A second Confirm after the athlete tapped Plan asks for the same location
  // again; every navigation carries a fresh request, so it still switches.
  testWidgets('Confirm again after tapping Plan lands on Shopping again', (
    tester,
  ) async {
    final transport = _CountingTransport();
    final router = _confirmRouter();
    addTearDown(router.dispose);

    await pumpSeeded(
      tester,
      Router.withConfig(config: router),
      overrides: _shellOverrides(transport),
    );
    await _settleShell(tester);

    router.push('/vana');
    await _settleShell(tester);
    await tester.tap(find.byKey(const ValueKey('test.confirm')));
    await _settleShell(tester);
    expect(find.byType(ShoppingTab), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('meal_planning.tab_plan')));
    await _settleShell(tester);
    expect(find.byType(PlanTab), findsOneWidget);

    router.push('/vana');
    await _settleShell(tester);
    await tester.tap(find.byKey(const ValueKey('test.confirm')));
    await _settleShell(tester);

    expect(find.byType(ShoppingTab), findsOneWidget);
    expect(find.byType(PlanTab), findsNothing);
  });
}
