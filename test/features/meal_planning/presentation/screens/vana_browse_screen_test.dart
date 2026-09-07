import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/meal_planning/application/meal_catalog_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/application/meal_plan_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_exceptions.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/cooking_session.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_plan.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_ref.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_source.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_type.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/ui_action.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/screens/vana_browse_screen.dart';

import '../helpers/test_content.dart';

/// `/vana/browse?c=` — the catalog with an Add affordance on every card:
/// a tap picks into THIS conversation's draft at the default servings,
/// ticks the card and toasts; a failure leaves the card untouched; "Done"
/// pops back to the chat. Rendered through a real GoRouter so `context.pop`
/// has a stack to pop.
void main() {
  final content = loadDefaultContent();

  MealRef recipe(String id, String name) => MealRef(
    source: MealSource.library,
    id: id,
    name: name,
    mealType: MealType.dinner,
    kind: MealKind.recipe,
  );

  final catalog = MealCatalogState(
    recipes: [recipe('D-1', 'Salmon quinoa bowl'), recipe('D-2', 'Dal')],
    assemblies: [recipe('A-1', 'Toast and eggs')],
    railsFromServer: true,
  );

  Future<GoRouter> pumpScreen(
    WidgetTester tester, {
    required _RecordingPlanController plan,
  }) async {
    final router = GoRouter(
      initialLocation: '/vana/browse?c=conv-1',
      routes: [
        GoRoute(
          path: '/vana',
          builder: (_, __) => const Scaffold(body: Text('chat')),
          routes: [
            GoRoute(
              path: 'browse',
              builder: (_, state) => VanaBrowseScreen(
                conversationId: state.uri.queryParameters['c']!,
              ),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentServiceProvider.overrideWith(testContentService),
          mealCatalogControllerProvider.overrideWith(
            () => _FixedCatalogController(catalog),
          ),
          mealPlanControllerProvider.overrideWith(() => plan),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    return router;
  }

  Finder addButton(String id) =>
      find.byKey(ValueKey('meal_planning.browse_add_$id'));

  testWidgets('every rail card carries an Add button', (tester) async {
    await pumpScreen(tester, plan: _RecordingPlanController());

    expect(find.text(content['meal_planning.browse_title']!), findsOneWidget);
    expect(addButton('D-1'), findsOneWidget);
    expect(addButton('D-2'), findsOneWidget);
    expect(addButton('A-1'), findsOneWidget);
  });

  testWidgets('Add picks into the conversation draft, ticks and toasts', (
    tester,
  ) async {
    final plan = _RecordingPlanController();
    await pumpScreen(tester, plan: plan);

    await tester.tap(addButton('D-1'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final pick = plan.picks.single;
    expect(pick.meals.single.id, 'D-1');
    expect(pick.meals.single.source, MealSource.library);
    expect(pick.servings, VanaBrowseScreen.defaultServings);
    expect(pick.conversationId, 'conv-1');

    // Ticked: the check icon inside this card's button, the plus gone.
    expect(
      find.descendant(of: addButton('D-1'), matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: addButton('D-1'), matching: find.byIcon(Icons.add)),
      findsNothing,
    );
    // The other cards are untouched.
    expect(
      find.descendant(of: addButton('D-2'), matching: find.byIcon(Icons.add)),
      findsOneWidget,
    );
    expect(
      find.text(content['meal_planning.browse_added_toast']!),
      findsOneWidget,
    );

    // A ticked card does not pick again.
    await tester.tap(addButton('D-1'), warnIfMissed: false);
    await tester.pump();
    expect(plan.picks, hasLength(1));
  });

  testWidgets('a failed pick leaves the card un-ticked and warns', (
    tester,
  ) async {
    final plan = _RecordingPlanController(
      failWith: const NeedsConnectionException('pick_meals'),
    );
    await pumpScreen(tester, plan: plan);

    await tester.tap(addButton('D-2'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(plan.picks, hasLength(1));
    expect(
      find.descendant(of: addButton('D-2'), matching: find.byIcon(Icons.add)),
      findsOneWidget,
    );
    expect(
      find.text(content['meal_planning.needs_connection']!),
      findsOneWidget,
    );
  });

  testWidgets('Done pops back to the chat', (tester) async {
    await pumpScreen(tester, plan: _RecordingPlanController());

    await tester.tap(find.byKey(const ValueKey('meal_planning.browse_done')));
    await tester.pumpAndSettle();

    expect(find.text('chat'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('meal_planning.vana_browse_screen')),
      findsNothing,
    );
  });
}

/// Serves a fixed catalog; no search, no server rails.
class _FixedCatalogController extends MealCatalogController {
  _FixedCatalogController(this.fixed);

  final MealCatalogState fixed;

  @override
  FutureOr<MealCatalogState> build() => fixed;
}

/// Records every `pickMeals` instead of running the remote-ack action.
class _RecordingPlanController extends MealPlanController {
  _RecordingPlanController({this.failWith});

  final Object? failWith;
  final List<PickMealsAction> picks = [];

  @override
  Future<MealPlan?> build() async => null;

  @override
  Future<MealPlan?> pickMeals(
    List<MealPick> meals, {
    int? servings,
    CookingSession? session,
    bool sendSession = false,
    String? conversationId,
    String? planId,
  }) async {
    picks.add(
      PickMealsAction(
        meals: meals,
        servings: servings,
        conversationId: conversationId,
      ),
    );
    if (failWith != null) throw failWith!;
    return null;
  }
}
