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
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:mealvana_endurance/features/integrations/presentation/providers/integrations_providers.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_chat_repository.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_transport.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/screens/food_screen.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/screens/meals_tab.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/screens/plan_tab.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/screens/shopping_tab.dart';
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

  // mp-596: "Open shopping list" goes to `/main?tab=food&food=shopping`, which
  // reuses the shell already on screen. The Food tab had opened on Plan, and
  // kept Plan.
  testWidgets(
    'asking an already-built shell for Food, Shopping lands on Shopping',
    (tester) async {
      final transport = _CountingTransport();
      final requested = ValueNotifier<(String?, FoodTab)>((null, FoodTab.plan));

      await pumpSeeded(
        tester,
        ValueListenableBuilder<(String?, FoodTab)>(
          valueListenable: requested,
          builder: (_, r, _) =>
              TabsScreen(initialTabName: r.$1, initialFoodTab: r.$2),
        ),
        overrides: _shellOverrides(transport),
      );
      await _settleShell(tester);

      // The athlete visits Food (on Plan), then goes back to the Timeline.
      await tester.tap(find.text('Food').first);
      await _settleShell(tester);
      await tester.tap(find.text('Timeline').first);
      await _settleShell(tester);

      requested.value = ('food', FoodTab.shopping);
      await _settleShell(tester);

      expect(find.byType(ShoppingTab), findsOneWidget);
      expect(find.byType(PlanTab), findsNothing);
    },
  );

  // A repeat of the same location, after the athlete tapped another segment,
  // still switches: every navigation carries a fresh request.
  testWidgets('asking again for Shopping after tapping Plan lands on Shopping', (
    tester,
  ) async {
    final transport = _CountingTransport();
    final requested = ValueNotifier<Object>(foodTabRequest());

    await pumpSeeded(
      tester,
      ValueListenableBuilder<Object>(
        valueListenable: requested,
        builder: (_, r, _) => TabsScreen(
          initialTabName: 'food',
          initialFoodTab: FoodTab.shopping,
          request: r,
        ),
      ),
      overrides: _shellOverrides(transport),
    );
    await _settleShell(tester);
    expect(find.byType(ShoppingTab), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('meal_planning.tab_plan')));
    await _settleShell(tester);
    expect(find.byType(PlanTab), findsOneWidget);

    requested.value = foodTabRequest();
    await _settleShell(tester);
    expect(find.byType(ShoppingTab), findsOneWidget);
  });

  // "Add meal" on Plan switches to Meals inside the tab; it used to push a
  // second, tab-less Food page over the shell.
  testWidgets('"Add meal" switches to Meals and keeps the tab bar', (
    tester,
  ) async {
    final transport = _CountingTransport();

    await pumpSeeded(
      tester,
      const TabsScreen(initialTabName: 'food'),
      overrides: _shellOverrides(transport),
    );
    await _settleShell(tester);

    await tester.ensureVisible(
      find.byKey(const ValueKey('meal_planning.btn_add_meal')),
    );
    await tester.tap(find.byKey(const ValueKey('meal_planning.btn_add_meal')));
    await _settleShell(tester);

    expect(find.byType(MealsTab), findsOneWidget);
    expect(find.byType(TabsScreen), findsOneWidget);
    expect(find.text('Timeline'), findsWidgets);
  });
}
